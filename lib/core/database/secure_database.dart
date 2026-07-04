import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

part 'secure_database.g.dart';

// ── DRIFT SCHEMA DEFINITIONS (SQLite Entities) ───────────────────────────────────

@DataClassName('HoldingEntity')
class Holdings extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get assetName => text().withLength(min: 1, max: 100)();
  TextColumn get assetSymbol => text().withLength(min: 1, max: 10)();
  RealColumn get amountHeld => real()();
  RealColumn get purchaseValue => real()();
  RealColumn get currentNav => real()();
  IntColumn get lastUpdatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionEntity')
class Transactions extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get holdingId => text().references(Holdings, #id)();
  TextColumn get transactionType => text().withLength(min: 3, max: 4)(); // 'buy' | 'sell'
  RealColumn get amount => real()();
  RealColumn get price => real()();
  IntColumn get timestamp => integer()();
  TextColumn get idempotencyKey => text()();
  TextColumn get syncStatus => text().withLength(min: 6, max: 7)(); // 'synced' | 'pending'

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncQueueEntity')
class SyncQueue extends Table {
  TextColumn get id => text().withLength(min: 36, max: 36)();
  TextColumn get operation => text()(); // e.g. 'POST', 'DELETE'
  TextColumn get payloadJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ── DRIFT DATABASE IMPLEMENTATION ───────────────────────────────────────────────

@DriftDatabase(tables: [Holdings, Transactions, SyncQueue])
class SecureDatabase extends _$SecureDatabase {
  SecureDatabase() : super(_openEncryptedConnection());

  @override
  int get schemaVersion => 1;

  // Key derivation and secure key generation
  static Future<String> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    const keyName = 'secure_vault_cipher_key';

    try {
      // Try hardware secure keychain storage first
      String? dbKey = await secureStorage.read(key: keyName);
      if (dbKey == null) {
        final random = Random.secure();
        final secureKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
        dbKey = base64Url.encode(secureKeyBytes);
        await secureStorage.write(key: keyName, value: dbKey);
      }
      return dbKey;
    } catch (e) {
      // Secure storage unavailable (e.g. running on macOS debug mode without developer signing)
      // Fallback to local sandbox hidden file key persistence for seamless debug execution
      final dbFolder = await getApplicationDocumentsDirectory();
      final keyFile = File(p.join(dbFolder.path, '.db_fallback_key'));

      if (await keyFile.exists()) {
        return await keyFile.readAsString();
      } else {
        final random = Random.secure();
        final secureKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
        final dbKey = base64Url.encode(secureKeyBytes);
        await keyFile.writeAsBytes(utf8.encode(dbKey), flush: true);
        return dbKey;
      }
    }
  }

  // Encryption execution layer
  static QueryExecutor _openEncryptedConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'secure_vault.db'));
      
      // Fetch key asynchronously
      final passphrase = await _getOrCreateEncryptionKey();

      return NativeDatabase(
        file,
        setup: (db) {
          // SQLCipher Setup immediately on database file opening
          db.execute("PRAGMA key = '$passphrase';");
          db.execute("PRAGMA cipher_memory_use = 4096;"); // 4MB page cache allocations
          db.execute("PRAGMA journal_mode = WAL;");        // WAL(Write-Ahead Logging) mode for concurrency
        },
      );
    });
  }

  // ── CUSTOM QUERIES & CRUD MUTATIONS ───────────────────────────────────────────

  // Watch portfolio holdings reactively
  Stream<List<HoldingEntity>> watchHoldings() {
    return select(holdings).watch();
  }

  // Watch transactions chronologically
  Stream<List<TransactionEntity>> watchTransactions() {
    return (select(transactions)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
        .watch();
  }

  // Multi-table atomic transaction to add an asset transaction
  Future<void> addAssetTransaction({
    required String assetName,
    required String assetSymbol,
    required double amount,
    required double price,
    required String type, // 'buy' | 'sell'
    required String idempotencyKey,
  }) {
    return transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 1. Check if holding already exists for this symbol
      final holdingQuery = select(holdings)..where((h) => h.assetSymbol.equals(assetSymbol));
      final existingHolding = await holdingQuery.getSingleOrNull();

      String holdingId;
      if (existingHolding != null) {
        holdingId = existingHolding.id;
        final isBuy = type == 'buy';
        final double newAmount = isBuy 
            ? existingHolding.amountHeld + amount 
            : existingHolding.amountHeld - amount;
            
        final double newPurchaseValue = isBuy
            ? existingHolding.purchaseValue + (amount * price)
            : existingHolding.purchaseValue - (amount * price);

        // Update holding properties atomically
        await update(holdings).replace(
          existingHolding.copyWith(
            amountHeld: newAmount,
            purchaseValue: newPurchaseValue,
            lastUpdatedAt: now,
          ),
        );
      } else {
        // Create new holding entry
        holdingId = const Uuid().v4();
        await into(holdings).insert(
          HoldingEntity(
            id: holdingId,
            assetName: assetName,
            assetSymbol: assetSymbol,
            amountHeld: amount,
            purchaseValue: amount * price,
            currentNav: price, // initial nav set to purchase price
            lastUpdatedAt: now,
          ),
        );
      }

      // 2. Log transaction in transactions table
      await into(transactions).insert(
        TransactionEntity(
          id: const Uuid().v4(),
          holdingId: holdingId,
          transactionType: type,
          amount: amount,
          price: price,
          timestamp: now,
          idempotencyKey: idempotencyKey,
          syncStatus: 'pending',
        ),
      );
    });
  }
}

// ── RIVERPOD INJECTION PROVIDER ──────────────────────────────────────────────────
final databaseProvider = Provider<SecureDatabase>((ref) {
  final db = SecureDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final holdingsStreamProvider = StreamProvider<List<HoldingEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchHoldings();
});

final transactionsStreamProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTransactions();
});

