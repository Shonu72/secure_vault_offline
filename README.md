# Secure Vault — Offline-First Portfolio Tracker

A Flutter app I built from scratch to practice real-world system design concepts — specifically how to keep sensitive financial data safe, work perfectly without internet, and still sync everything when the connection comes back.

> This isn't a tutorial follow-along. Every decision here was made by designing the system first, then implementing it steps by steps.

---

## What this app actually does

It's a personal portfolio tracker where you can log your investments — crypto, stocks, mutual funds, fixed deposits — completely offline. The app encrypts everything on your device, never sends your raw data anywhere, and quietly syncs to a backend when you're back online.

Think of it like a secure notes app, but for your money.

---

## Why I built it this way

I wanted to build something that solves problems we actually face in production:

- **What happens when the user has no internet?** The app still works. It queues writes locally and syncs later.
- **What if someone picks up your phone?** The app hides its contents and locks itself after 30 seconds in the background.
- **What if the database is stolen off the device?** The data is encrypted at rest — useless without the key.
- **What if XIRR calculation takes 100ms?** It runs on a background thread so the UI never stutters.

These aren't hypothetical. These are real problems every finance app has to solve.

---

## Tech choices and why

| What | Tool | Why |
|---|---|---|
| State management | Riverpod | Zero `setState` anywhere. All state is reactive and injectable. |
| Database | Drift + SQLCipher | Type-safe queries + AES-256 encryption at rest |
| HTTP client | Dio + interceptors | Easy to intercept and mock offline behaviour |
| Background work | Dart `compute()` | Offloads CPU work without managing isolates manually |
| Scroll performance | `SliverFixedExtentList` | O(1) layout — same frame budget for 10 or 10,000 rows |
| Request signing | HMAC-SHA256 | Prevents tampering with queued offline payloads |

---

## Run this app

**Steps:**

```bash
# Generate Drift database code (only once)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```
**Default PIN:** `1234`

>  If you're running on macOS without a paid Apple Developer account, the app will show a signing warning. It's fine — it automatically falls back to a local file for the encryption key instead of the keychain.

---

## What this project demonstrates

If you're a recruiter or senior dev reading this:

- **System design thinking** — I wrote the architecture spec first, then implemented it in phases. The [system_design.md](./system_design.md) has the full design.
- **Security awareness** — Encryption at rest, memory wipe, privacy shield, HMAC request signing. Not checkbox security — actually implemented.
- **Offline-first architecture** — The app is fully functional without a server. It queues, signs, and replays mutations when connectivity returns.
- **No setState discipline** — Every single piece of state in the app flows through Riverpod. No local widget state at all.
- **Performance thinking** — XIRR runs on a background isolate. The list uses fixed-extent virtualization. These aren't premature optimizations — they're the right call for a finance app with potentially thousands of rows.
- **Error handling in the real world** — The macOS keychain entitlement issue is a real developer problem. Instead of giving up or commenting it out, I built a graceful fallback.

## Snapshots
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-04 at 19 12 19" src="https://github.com/user-attachments/assets/4177f0f4-bb24-4099-a344-094e61f930b1" />
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-04 at 19 12 11" src="https://github.com/user-attachments/assets/bc4c2eac-0aa5-4da7-b294-d71f7abf4bdf" />
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-04 at 19 10 50" src="https://github.com/user-attachments/assets/5243ca4a-2c2a-4bb9-a48d-e147f92c7ff4" />
<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-04 at 19 10 35" src="https://github.com/user-attachments/assets/4c728aa7-05c3-4d79-8175-3ffa13cb5946" />



