import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/database/secure_database.dart';
import 'package:secure_vault_offline/core/network/api_client.dart';

class SyncEngine {
  final Ref _ref;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncEngine(this._ref);

  void initialize() {
    // Listen to network status changes to auto-trigger queue replay
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isForcedOffline = _ref.read(forceOfflineProvider);
      final hasInternet = !isForcedOffline && 
          results.isNotEmpty && 
          !results.contains(ConnectivityResult.none);
          
      if (hasInternet) {
        processQueue();
      }
    });

    // Also listen to the forceOfflineProvider toggle!
    _ref.listen<bool>(forceOfflineProvider, (previous, next) {
      final isForcedOffline = next;
      if (!isForcedOffline) {
        // Just went back online! Trigger queue sync.
        processQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    final db = _ref.read(databaseProvider);
    final dio = _ref.read(apiClientProvider);

    try {
      // 1. Fetch queued mutations chronologically (First-In, First-Out sequence)
      final queue = await (db.select(db.syncQueue)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
          .get();

      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      debugPrint('SyncEngine: processing ${queue.length} pending mutations');

      for (final task in queue) {
        final payload = jsonDecode(task.payloadJson) as Map<String, dynamic>;
        final idempotencyKey = payload['idempotencyKey'] ?? '';

        // Calculate Exponential Backoff delay with 15% random Jitter
        final backoffMs = pow(2, task.retryCount) * 1000;
        final jitter = (Random().nextDouble() * 0.15 * backoffMs).toInt();
        final totalDelay = Duration(milliseconds: (backoffMs + jitter).toInt());

        if (task.retryCount > 0) {
          debugPrint('SyncEngine: Waiting $totalDelay before retrying task ${task.id}');
          await Future.delayed(totalDelay);
        }

        try {
          // Re-attempting sync request. Adding bypass header to let it through interceptor.
          final response = await dio.post(
            '/transactions',
            data: payload,
            options: Options(
              headers: {
                'X-Bypass-Interceptor': 'true',
                'X-Idempotency-Key': idempotencyKey,
              },
            ),
          );

          if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 222 || response.statusCode == 202) {
            // Success: Clean up queue and update local transaction status
            await (db.delete(db.syncQueue)..where((t) => t.id.equals(task.id))).go();
            
            // Mark local transaction record as fully synced
            if (idempotencyKey.isNotEmpty) {
              await (db.update(db.transactions)
                    ..where((t) => t.idempotencyKey.equals(idempotencyKey)))
                  .write(const TransactionsCompanion(syncStatus: Value('synced')));
            }
            debugPrint('SyncEngine: Mutation ${task.id} synced successfully');
          }
        } catch (e) {
          // Network request failed again. Increment retry count and break loop to try later.
          await (db.update(db.syncQueue)..where((t) => t.id.equals(task.id)))
              .write(SyncQueueCompanion(retryCount: Value(task.retryCount + 1)));

          debugPrint('SyncEngine: Sync failed for task ${task.id}: $e. Aborting loop.');
          break; // Stop processing subsequent items to preserve sequence order
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}

// ── SYNC ENGINE RIVERPOD PROVIDER ───────────────────────────────────────────────
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(ref);
  engine.initialize();
  ref.onDispose(() => engine.dispose());
  return engine;
});
