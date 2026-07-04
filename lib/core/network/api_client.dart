import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/database/secure_database.dart';
import 'package:uuid/uuid.dart';

// Manual Toggle for Simulating Offline Mode (Great for Demoing/Testing)
final forceOfflineProvider = StateProvider<bool>((ref) => false);

// ── HMAC REQUEST SIGNING INTERCEPTOR ──────────────────────────────────────────
class HmacSigningInterceptor extends Interceptor {
  static const String _apiSecret = 'svps_vault_hmac_secret_2026';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data != null) {
      final payload = jsonEncode(options.data);
      
      // Calculate HMAC-SHA256 signature to verify request integrity
      final key = utf8.encode(_apiSecret);
      final bytes = utf8.encode(payload);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);

      options.headers['X-Signature'] = digest.toString();
      options.headers['X-Timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    super.onRequest(options, handler);
  }
}

// ── OFFLINE INTERCEPTOR & QUEUE MANAGER ───────────────────────────────────────
class MockSyncQueueInterceptor extends Interceptor {
  final Ref _ref;

  MockSyncQueueInterceptor(this._ref);

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {}

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isForcedOffline = _ref.read(forceOfflineProvider);
    final isOffline = isForcedOffline || connectivity.contains(ConnectivityResult.none);

    // Bypass interceptor trigger from SyncEngine queue replayer
    if (options.headers.containsKey('X-Bypass-Interceptor')) {
      options.headers.remove('X-Bypass-Interceptor');
      if (isOffline) {
        // Simulating actual network lookup failure for the queue runner
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            error: 'Connection timeout. Device is offline.',
          ),
        );
      }
      
      // Simulating a successful backend upload response for the queue runner
      await Future.delayed(const Duration(milliseconds: 300));
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'status': 'success',
            'message': 'Transaction synced successfully with server.',
          },
        ),
      );
    }

    if (isOffline && (options.method == 'POST' || options.method == 'PUT')) {
      // 1. Capture payload and serialize
      final payloadStr = jsonEncode(options.data);
      final db = _ref.read(databaseProvider);
      final operationId = const Uuid().v4();

      // 2. Enqueue mutation transaction into local SyncQueue SQLite table
      await db.into(db.syncQueue).insert(
        SyncQueueEntity(
          id: operationId,
          operation: options.method,
          payloadJson: payloadStr,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          retryCount: 0,
        ),
      );

      // 3. Complete request locally returning a synthetic 202 Accepted response
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 202,
          data: {
            'status': 'queued_offline',
            'operationId': operationId,
            'message': 'No internet connection. Task queued for eventual sync.',
          },
        ),
      );
    }

    // If Online, simulate hitting mock server and returning success instantly
    await Future.delayed(const Duration(milliseconds: 200));
    return handler.resolve(
      Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'status': 'success',
          'message': 'Transaction synced successfully with server.',
        },
      ),
    );
  }
}

// ── DIO API CLIENT PROVIDER ──────────────────────────────────────────────────────
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.securevault.mock',
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  dio.interceptors.addAll([
    HmacSigningInterceptor(),
    MockSyncQueueInterceptor(ref),
  ]);

  return dio;
});
