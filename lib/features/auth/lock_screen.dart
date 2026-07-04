import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secure_vault_offline/core/theme.dart';
import 'package:secure_vault_offline/features/auth/auth_provider.dart';
import 'package:secure_vault_offline/core/constants.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  static const int _maxPinLength = 4;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    // Shake animation for wrong PIN
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation =
        Tween<double>(begin: 0.0, end: 20.0)
            .chain(CurveTween(curve: Curves.elasticIn))
            .animate(_shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _shakeController.reverse();
            }
          });

    // Automatically trigger biometrics on first open if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoLaunchBiometrics();
    });
  }

  Future<void> _tryAutoLaunchBiometrics() async {
    // Only auto-launch if biometrics are enrolled on this device
    final isAvailable = await ref.read(biometricAvailableProvider.future);
    final lockState = ref.read(lockScreenProvider);
    
    // Skip auto-prompt if user explicitly clicked logout
    if (lockState.wasLoggedOut) return;

    if (isAvailable && mounted) {
      await ref.read(lockScreenProvider.notifier).authenticateWithBiometrics();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(lockScreenProvider);
    final notifier = ref.read(lockScreenProvider.notifier);
    final biometricAsync = ref.watch(biometricAvailableProvider);
    final isBiometricAvailable = biometricAsync.value ?? false;

    // React to shake trigger from Riverpod state
    ref.listen<LockScreenState>(lockScreenProvider, (previous, next) {
      if (next.shouldShake && !(previous?.shouldShake ?? false)) {
        _shakeController.forward();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Spacer(flex: 2),

            // Header: Icon and Instruction
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  AppConstants.lockScreenTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle changes based on whether biometrics are available
                Text(
                  isBiometricAvailable
                      ? 'Use fingerprint or enter your PIN'
                      : AppConstants.lockScreenSubtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            const Spacer(flex: 1),

            // PIN Indicator Circles with shake animation
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_maxPinLength, (index) {
                      final isFilled = index < lockState.pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled ? AppColors.primary : AppColors.surface,
                          border: Border.all(
                            color: isFilled ? AppColors.primary : AppColors.borderNormal,
                            width: 1.5,
                          ),
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: .4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                      );
                    }),
                  ),
                );
              },
            ),

            const Spacer(flex: 2),

            // Numeric Keypad Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['1', '2', '3']
                        .map((d) => _buildKeypadButton(d, notifier))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['4', '5', '6']
                        .map((d) => _buildKeypadButton(d, notifier))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['7', '8', '9']
                        .map((d) => _buildKeypadButton(d, notifier))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Biometric button — real or empty placeholder
                      isBiometricAvailable
                          ? _buildBiometricButton(notifier, lockState)
                          : const SizedBox(width: 72, height: 72),
                      _buildKeypadButton('0', notifier),
                      _buildBackspaceButton(notifier),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit, LockScreenNotifier notifier) {
    return GestureDetector(
      onTap: () => notifier.addDigit(digit),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderNormal, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(LockScreenNotifier notifier) {
    return GestureDetector(
      onTap: notifier.backspace,
      child: Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Icon(
          Icons.backspace_outlined,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildBiometricButton(LockScreenNotifier notifier, LockScreenState state) {
    return GestureDetector(
      onTap: state.isBiometricLoading ? null : notifier.authenticateWithBiometrics,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: state.isBiometricLoading
            // Spinner while the biometric prompt is open
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            // Show fingerprint or face icon based on enrolled type
            : FutureBuilder<List<BiometricType>>(
                future: LocalAuthentication().getAvailableBiometrics(),
                builder: (context, snapshot) {
                  final types = snapshot.data ?? [];
                  final hasFace = types.contains(BiometricType.face);
                  return Icon(
                    hasFace ? Icons.face_retouching_natural : Icons.fingerprint_rounded,
                    color: AppColors.primary,
                    size: 32,
                  );
                },
              ),
      ),
    );
  }
}
