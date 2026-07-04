import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/theme.dart';
import 'package:secure_vault_offline/features/auth/auth_provider.dart';

class SecurityOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const SecurityOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SecurityOverlay> createState() => _SecurityOverlayState();
}

class _SecurityOverlayState extends ConsumerState<SecurityOverlay> with WidgetsBindingObserver {
  DateTime? _backgroundTime;
  static const Duration _lockTimeout = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // 1. Instantly display privacy shield overlay using Riverpod state
        ref.read(privacyShieldProvider.notifier).state = true;
        _backgroundTime ??= DateTime.now();
        break;

      case AppLifecycleState.resumed:
        // 2. Clear privacy overlay using Riverpod state
        ref.read(privacyShieldProvider.notifier).state = false;

        // 3. Evaluate Session Lock (30 seconds background timeout)
        if (_backgroundTime != null) {
          final elapsed = DateTime.now().difference(_backgroundTime!);
          if (elapsed >= _lockTimeout) {
            _lockSession();
          }
          _backgroundTime = null;
        }
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Wipe session proactively on app detach
        _lockSession();
        break;
    }
  }

  void _lockSession() {
    // Call Riverpod Auth notifier to wipe volatile session details
    ref.read(lockScreenProvider.notifier).logout();
    
    // 4. Securely wipe the device clipboard memory to protect copied secrets
    Clipboard.setData(const ClipboardData(text: ''));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch privacy shield status from Riverpod
    final showPrivacyShield = ref.watch(privacyShieldProvider);

    return Stack(
      children: [
        widget.child,
        if (showPrivacyShield)
          Positioned.fill(
            child: Container(
              color: AppColors.background,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield,
                    color: AppColors.primary,
                    size: 80,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Secure Vault Hidden',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
