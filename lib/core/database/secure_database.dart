import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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

    String? dbKey = await secureStorage.read(key: keyName);
    if (dbKey == null) {
      // 1. Generate 256-bit cryptographically secure passphrase
      final random = Random.secure();
      final secureKeyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      dbKey = base64Url.encode(secureKeyBytes);
      
      // 2. Persist safely inside hardware-backed storage (Keychain/KeyStore)
      await secureStorage.write(key: keyName, value: dbKey);
    }
    return dbKey;
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
}

// ── RIVERPOD INJECTION PROVIDER ──────────────────────────────────────────────────
final databaseProvider = Provider<SecureDatabase>((ref) {
  final db = SecureDatabase();
  ref.onDispose(() => db.close());
  return db;
});
