## Milestone 1: The Security Perimeter
- Security Overlay (WidgetsBindingObserver): Listen to app lifecycle events. When the app is in AppLifecycleState.paused, stack a solid/blurred barrier over the top of your layout to prevent details from leaking in the task switcher drawer.
- Auto-Lock Timer: When moving to the background, save the current timestamp. On resume, if now - backgroundTime > 30 seconds, push a block lock-screen layout forcing biometrics or a PIN.
##  📊Milestone 2: Offline-First Portfolio Engine
- Drift/sqflite Database: Configure the local tables holdings, transactions, and sync_queue.
- Reactive Stream UI: The UI only listens to watchAllTransactions() or watchPortfolioValue() streams from the DB.
- Mock Sync Interceptor: Wrap your network client with a custom Interceptor that intercepts failures, caches them to the local sync_queue table when offline, and automatically replays requests with an exponential backoff + jitter algorithm when connection is restored.
## 📝 Milestone 3: JSON-Driven Form Engine
- Create a local JSON config containing form controls, custom regex validations, and dependency targets.
- Use a Factory Pattern (FormFieldFactory) that maps the parsed JSON to TextField, DropdownButtonFormField, or Checkbox widgets dynamically.
- Implement visibility evaluation: a field only displays if its conditional dependency evaluates to true (e.g. show interestRate input only if assetType matches Fixed Deposit).
## ⚡ Milestone 4: Performance Optimization
- Isolate Calculations: Compute the portfolio performance over time (XIRR/IRR calculation) by passing the list of 10,000 mock transactions to a background thread using Dart's compute method.
- Viewport-Aware List: Render your transactions using SliverFixedExtentList or ListView.builder with a static itemExtent to skip costly height measurements for large datasets.
## 💡 How to Approach this Project
- Do not try to make it pretty: Focus 100% on the architecture and clean state transitions. The default Material 3 widgets will look modern enough without extra configuration.
- Mock all API calls: Use a mock client or local assets to load data. You do not need a backend for this.
Run with --profile mode to inspect the performance gains of the virtualized list and Isolate-driven math in DevTools.