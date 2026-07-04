# System Design: Secure Vault & Portfolio Sync (SVPS)

> **Interview & Practice Context:** This document outlines the system design for the Secure Vault & Portfolio Sync (SVPS) mini-project. It maps client-side security boundaries, offline-first data structures, JSON-driven form generation, and concurrent performance considerations in a unified mobile architecture.

---

## 1. Requirements Clarification

### Functional Requirements
- **Secure Access:** Users must authenticate using a 4-digit PIN or biometrics (FaceID/Fingerprint) to enter the app.
- **Privacy Shield:** Sensitive portfolio visual details must be blurred/hidden in the OS task switcher.
- **Dynamic Assets Onboarding:** The forms to add new holdings (crypto, bank FDs, stocks) must be dynamically generated from a JSON schema config.
- **Offline Storage:** Browse holdings and transaction logs without network access.
- **Background calculation:** Annualized performance returns (XIRR) must run in the background.
- **Network Isolation:** Operations queue locally when offline and synchronize silently when connectivity is restored.

### Non-Functional Requirements
- **Data Encryption:** Local SQLite database tables must be encrypted on disk using SQLCipher (AES-256).
- **Execution Performance:** Render 10,000+ transaction rows at a consistent 60fps/120fps scroll rate.
- **Computation Isolation:** Calculations must not freeze the UI thread (main isolate budget < 8ms).
- **Sync Reliability:** Deduplicate synchronization tasks using time-bucketed idempotency keys.

---

## 2. System Architecture

```
                                 FLUTTER CLIENT
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                        │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                                   UI LAYER                                     │   │
│   │  - AppLifecycleObserver (App lock & task switcher blur overlay)                 │   │
│   │  - DynamicFormBuilder (compiles JSON configurations to factory input widgets)  │   │
│   │  - PortfolioDashboard (uses SliverList for 10k transactions list)              │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │ reads / writes                             │
│                                           ▼                                            │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                            STATE MANAGEMENT LAYER                              │   │
│   │  - AuthBloc (maintains PIN, biometric tokens, session lock timer)              │   │
│   │  - DynamicFormBloc (handles values dictionary, error maps, visibility logic)    │   │
│   │  - PortfolioBloc (triggers XIRR calculations on background isolates)           │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│                    ┌──────────────────────┴──────────────────────┐                     │
│                    ▼ CRUD operations                             ▼ Sync queue tasks    │
│   ┌───────────────────────────────────┐        ┌───────────────────────────────────┐   │
│   │          DATA LAYER               │        │       NETWORK & SYNC LAYER        │   │
│   │                                   │        │                                   │   │
│   │  - DriftDatabase (SQLCipher)      │        │  - Dio Client (Retry interceptor) │   │
│   │  - FlutterSecureStorage           │        │  - SyncEngine (processes SQLite   │   │
│   │    (encrypter key storage)        │        │    pending queue on reconnect)    │   │
│   └───────────────────────────────────┘        └───────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┬─────────────────────┘
                                                                   │
                                                            HTTPS REST / JSON
                                                                   │
                                                                   ▼
                                                             MOCK BACKEND
```

---

## 3. Core Engine Design Deep Dives

### A. The Security & Biometric Lock State Machine
The app lock sequence is designed defensively around OS-level lifecycle transitions to prevent authentication bypass.

```
                              ┌─────────────┐
                              │    LOCKED   │
                              └──────┬──────┘
                                     │ Enter valid PIN / Biometric match
                                     ▼
                              ┌─────────────┐
                              │   UNLOCKED  │
                              └──────┬──────┘
                                     │ App goes to background (paused)
                                     ▼
                              ┌─────────────┐
                              │  SUSPENDED  │ ◄── [Privacy shield overlay applied]
                              └──────┬──────┘     [Save timestamp: backgroundTime]
                                     │
               ┌─────────────────────┴─────────────────────┐
               │ App resumed within 30s                    │ App resumed after 30s
               ▼                                           ▼
        ┌─────────────┐                             ┌─────────────┐
        │   UNLOCKED  │                             │    LOCKED   │
        │             │                             │             │
        └─────────────┘                             └─────────────┘
  [Remove privacy overlay]                     [Remove privacy overlay]
                                               [Push Lock Screen Route]
```

### B. Offline-First Sync & Reconciliation Engine
The application treats the local database as the single source of truth. UI elements bind to database streams, while the network is treated as an asynchronous replication link.

```
Write Transaction (User action)
        │
        ▼
Insert to SQLCipher DB (sync_status = 'pending')
        │
        ├─────────────────────────────────────────────────┐
        ▼ (Online)                                        ▼ (Offline)
Enqueue Sync Task                                 Write to local sync_queue table
        │                                                 │
        ▼                                                 ▼
API Client tries network POST                     Show "Stored Offline" confirmation
        │                                                 │
        ├────────────────────────┐                        │
        ▼ (Success)              ▼ (Network Timeout)      │
Update status to 'synced'    Mark sync_status = 'failed'  │
                             Enqueue to local queue table │
                                                          │
                                                          ▼
                                             On Reconnect (Connectivity Stream):
                                             Pull entries from sync_queue
                                             Batch post with Exponential Backoff
                                             Reconcile status -> mark 'synced'
```

#### Idempotency Key Design:
To prevent duplicate resource creation (e.g., adding the same Transaction twice due to network disconnects during the POST response), each locally created holding transaction generates a deterministic client-side ID:
$$\text{idempotencyKey} = \text{hash}(\text{holdingId} + \text{amount} + \text{type} + \text{timestampBucket})$$
When the network retries the request, the backend detects the duplicate key and returns the identical response of the first transaction instead of duplicating the database entry.

---

## 4. Database Schema (SQLite / SQLCipher via Drift)

Drift compiles these tables into reactive Dart streams.

```
   ┌───────────────────────────────────────────────────────────┐
   │                       TABLE: holdings                     │
   ├──────────────────┬──────────────┬─────────────────────────┤
   │ id               │ TEXT (UUID)  │ PRIMARY KEY             │
   │ asset_name       │ TEXT         │                         │
   │ asset_symbol     │ TEXT         │                         │
   │ amount_held      │ REAL         │                         │
   │ purchase_value   │ REAL         │                         │
   │ current_nav      │ REAL         │                         │
   │ last_updated_at  │ INTEGER      │ Epoch timestamp         │
   └──────────────────┴──────────────┴─────────────────────────┘
                                 ▲
                                 │ One-to-Many
                                 │
   ┌─────────────────────────────┴─────────────────────────────┐
   │                     TABLE: transactions                   │
   ├──────────────────┬──────────────┬─────────────────────────┤
   │ id               │ TEXT (UUID)  │ PRIMARY KEY             │
   │ holding_id       │ TEXT         │ FOREIGN KEY -> holdings │
   │ transaction_type │ TEXT         │ 'buy' | 'sell'          │
   │ amount           │ REAL         │                         │
   │ price            │ REAL         │                         │
   │ timestamp        │ INTEGER      │                         │
   │ idempotency_key  │ TEXT         │ For request dedup       │
   │ sync_status      │ TEXT         │ 'synced' | 'pending'    │
   └──────────────────┴──────────────┴─────────────────────────┘
   
   ┌───────────────────────────────────────────────────────────┐
   │                     TABLE: sync_queue                     │
   ├──────────────────┬──────────────┬─────────────────────────┤
   │ id               │ TEXT (UUID)  │ PRIMARY KEY             │
   │ operation        │ TEXT         │ 'POST' | 'DELETE' etc.  │
   │ payload_json     │ TEXT         │ Serialized payload      │
   │ created_at       │ INTEGER      │ For FIFO sequencing     │
   │ retry_count      │ INTEGER      │ For backoff limit       │
   └──────────────────┴──────────────┴─────────────────────────┘
```

---

## 5. Dynamic Form Engine Dependency Graph

The JSON form schema is parsed into a tree configuration. Some fields have conditions matching state variables of sibling fields.

```
       JSON Schema Load
              │
              ▼
    DynamicFormBloc (State: values = { "asset_type": "crypto" })
              │
              ├───────────► Evaluates Visibility Conditions
              │
              ▼
   Calculates Visible Set:
   { "asset_type", "wallet_address" } -> "bank_name" hidden because asset_type != "fd"
              │
              ▼
     FormFieldFactory.build()
              │
   ┌──────────┼──────────┐
   ▼          ▼          ▼
TextField  Dropdown  Checkbox
   │
   ▼ User Types inside TextField
FieldValueChanged("wallet_address", "0x51...")
   │
   ▼
State re-evaluation -> Re-validate patterns -> Rebuild visible widgets using Keys
```

---

## 6. Performance Optimization Matrix

| Optimization | Target | Mechanism | Verification (DevTools) |
|--------------|--------|-----------|-------------------------|
| **Newton-Raphson math in Isolate** | UI thread freezing / frame drops | Offload recursive calculations to secondary threads via `compute()` | Timeline: UI thread contains zero long-running tasks (>8ms) |
| **Static List Item Extent** | Layout calculation jank | Configure `itemExtent: 72.0` in custom Sliver lists | Layout duration remains constant regardless of scroll speed |
| **Asset Image Cache Bounds** | Memory usage overhead (OutOfMemory) | Restrict image assets size via `cacheWidth`/`cacheHeight` | Memory Tab: Heap footprint stays low under image scrolls |
| **Repaint Boundaries** | Redundant paints of unchanged elements | Wrap dynamic inputs in `RepaintBoundary` nodes | Repaint rainbow highlights only the modified field |

---

## 7. Common Pitfalls

- **State Leakage:** Storing database encryption keys in the standard shared preferences package. **Fix:** Keep database encryption passphrase keys strictly within platform Keychains using the `flutter_secure_storage` package.
- **Concurrent Task Out of Order:** Offline mutations executed sequentially out-of-order on reconnect (e.g., delete note, then edit note). **Fix:** Force strict FIFO (First-In, First-Out) queuing in the `sync_queue` table using database timestamps.
- **Isolate Overhead:** Spawning an isolate for a trivial calculation of 5 elements. Spawning isolates has ~50-100ms startup cost. **Fix:** Only execute isolates for large datasets (e.g., calculations on list items > 500).

---

## 8. Interviewer Follow-Up Questions

**Q: How does SQLCipher derive the encryption key safely?**
> The user's input PIN is passed through a key derivation function (PBKDF2) along with a device salt to generate a 256-bit key. This key is used to open SQLCipher. The key is kept purely in volatile memory during the session and is wiped when the session locks.

**Q: What happens if the app is killed while executing a synchronized transaction from the queue?**
> The sync operation is wrapped in a local database transaction. The queue item is not deleted from `sync_queue` until the API client completes the request and receives a success status code. If the app is killed mid-request, it is simply retried on the next cold launch.

**Q: How do you handle schema migrations on a dynamic offline form database?**
> If the JSON form configuration format changes, you increment the schema version. The local database migration helper uses migration strategies (e.g., adding nullable columns, executing default values) inside drift's `MigrationStrategy` callback.
