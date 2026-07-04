# Implementation Roadmap: Secure Vault & Portfolio Sync (SVPS)

Based on the [System Design](file:///Users/shouryasonu/Development/system%20design/mini-project/secure_vault_offline/system_design.md) specification, the implementation is divided into 5 logical phases.

---

## 🔒 Phase 1: Security Guard & Session Lock
Implement OS-level lifecycle defenses to protect database secrets and UI visibility.
- [x] Create `lib/core/security/security_guard.dart` incorporating `WidgetsBindingObserver`.
- [x] Build the **Privacy Shield Overlay** (blur/dark mask overlay displayed when app is paused/inactive).
- [x] Implement the **30-second Auto-Lock Timer** (records timestamp on pause, locks session on resume if expired).
- [x] Securely clear device clipboard memory on session lockout.
- [x] Wrap `MaterialApp`'s home container in the `SecurityOverlay` wrapper inside `main.dart`.

---

## 🗄️ Phase 2: Encrypted Local Database (SQLCipher & Drift)
Set up type-safe local storage encrypted on disk using SQLCipher keys.
- [x] Initialize `flutter_secure_storage` to generate/fetch a cryptographically secure 256-bit DB passphrase key.
- [x] Configure `drift` schema tables inside `lib/core/database/secure_database.dart`:
  - `HoldingsTable` (asset name, symbol, quantities, purchase value, current NAV).
  - `TransactionsTable` (amounts, prices, timestamp, idempotency key, sync status).
  - `SyncQueueTable` (payload JSON, operations mapping, retry tracking).
- [x] Build the native platform database opener linking `SQLCipher` libraries with your encryption key.
- [ ] Run `flutter pub run build_runner build` to generate the type-safe database schemas.

---

## 📊 Phase 3: Core CRUD & Reactive Streams
Link your UI views directly to local SQLite reactive database streams.
- [ ] Replace mock transaction lists in `portfolio_dashboard.dart` with a reactive `StreamBuilder` watching `drift` tables.
- [ ] Add the database writing task to `AddAssetPage`'s save action (inserts holding transaction into local DB).
- [ ] Implement data mapping: convert raw DB entities to clean presentation `Holding` and `Transaction` models.

---

## 🔄 Phase 4: Sync Engine & Network Interceptor
Set up the offline replication queue and automated retry loop.
- [ ] Write the `HmacSigningInterceptor` in `lib/core/network/api_client.dart` to sign outgoing REST writes.
- [ ] Build `MockSyncQueueInterceptor` to catch timeout/connectivity issues, cache them to the local `sync_queue` table, and returns a `222/202 Accepted` response.
- [ ] Build the background `SyncEngine` that listens to `connectivity_plus` streams, grabs queued transactions, and uploads them using an **exponential backoff + jitter** retry pattern when connection is active.

---

## ⚡ Phase 5: Thread Isolation & Performance Tuning
Tune the CPU and rendering pipeline for heavy loads.
- [ ] Offload the compound interest return calculations (XIRR) to a secondary background thread using Dart's `compute()` isolate helper.
- [ ] Wire the isolate return rate value to update the portfolio statistics card.
- [ ] Verify list scrolling layout passes: populate 10,000 mock items to check `itemExtent` performance in DevTools.