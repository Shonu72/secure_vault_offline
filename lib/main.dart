import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/theme.dart';
import 'package:secure_vault_offline/core/security/security_guard.dart';
import 'package:secure_vault_offline/features/auth/auth_provider.dart';
import 'package:secure_vault_offline/features/auth/lock_screen.dart';
import 'package:secure_vault_offline/features/portfolio/portfolio_dashboard.dart';
import 'package:secure_vault_offline/core/network/sync_engine.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Instantiate SyncEngine background listeners
    ref.read(syncEngineProvider);
    final lockState = ref.watch(lockScreenProvider);

    return MaterialApp(
      title: 'Secure Vault',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: SecurityOverlay(
        child: lockState.isAuthenticated
            ? const PortfolioDashboard()
            : const LockScreen(),
      ),
    );
  }
}


