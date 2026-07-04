import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:secure_vault_offline/core/constants.dart';

// local_auth v3 removed error_codes.dart — error codes are plain strings
// on PlatformException.code. Values are documented in local_auth README.
class _AuthError {
  static const notEnrolled = 'NotEnrolled';
  static const passcodeNotSet = 'PasscodeNotSet';
  static const notAvailable = 'NotAvailable';
  static const lockedOut = 'LockedOut';
  static const permanentlyLockedOut = 'PermanentlyLockedOut';
}

// ── BIOMETRIC AVAILABILITY PROVIDER ──────────────────────────────────────────
// Checks once on startup: does this device have fingerprint / Face ID enrolled?
// UI uses this to decide whether to show the biometric button at all.
final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = LocalAuthentication();
  final canCheckBiometrics = await auth.canCheckBiometrics;
  final isDeviceSupported = await auth.isDeviceSupported();
  if (!canCheckBiometrics || !isDeviceSupported) return false;

  final enrolled = await auth.getAvailableBiometrics();
  return enrolled.isNotEmpty;
});

// ── LOCK SCREEN STATE ─────────────────────────────────────────────────────────
class LockScreenState {
  final String pin;
  final bool isAuthenticated;
  final bool shouldShake;
  final bool isBiometricLoading;
  final bool wasLoggedOut; // Track if user explicitly clicked logout to skip auto-prompt

  const LockScreenState({
    this.pin = '',
    this.isAuthenticated = false,
    this.shouldShake = false,
    this.isBiometricLoading = false,
    this.wasLoggedOut = false,
  });

  LockScreenState copyWith({
    String? pin,
    bool? isAuthenticated,
    bool? shouldShake,
    bool? isBiometricLoading,
    bool? wasLoggedOut,
  }) {
    return LockScreenState(
      pin: pin ?? this.pin,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      shouldShake: shouldShake ?? this.shouldShake,
      isBiometricLoading: isBiometricLoading ?? this.isBiometricLoading,
      wasLoggedOut: wasLoggedOut ?? this.wasLoggedOut,
    );
  }
}

class LockScreenNotifier extends StateNotifier<LockScreenState> {
  LockScreenNotifier() : super(const LockScreenState());


  static const int _maxPinLength = 4;
  static const String _correctPin = AppConstants.defaultPinSeed;
  final _auth = LocalAuthentication();

  void addDigit(String digit) {
    if (state.pin.length >= _maxPinLength || state.shouldShake) return;

    // Haptic tick on each key press
    HapticFeedback.lightImpact();

    final newPin = state.pin + digit;
    state = state.copyWith(pin: newPin);

    if (newPin.length == _maxPinLength) {
      _verifyPin();
    }
  }

  void backspace() {
    if (state.pin.isEmpty || state.shouldShake) return;
    HapticFeedback.lightImpact();
    state = state.copyWith(
      pin: state.pin.substring(0, state.pin.length - 1),
    );
  }

  void _verifyPin() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (state.pin == _correctPin) {
        // Double-tap haptic for success
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 80), () {
          HapticFeedback.mediumImpact();
        });
        state = state.copyWith(isAuthenticated: true);
      } else {
        // Heavy impact for wrong PIN
        HapticFeedback.heavyImpact();
        state = state.copyWith(shouldShake: true);

        // Reset state after shake animation completes
        Future.delayed(const Duration(milliseconds: 400), () {
          state = const LockScreenState(pin: '', shouldShake: false, isAuthenticated: false);
        });
      }
    });
  }

  // ── REAL BIOMETRIC AUTHENTICATION ─────────────────────────────────────────
  Future<void> authenticateWithBiometrics() async {
    if (state.isBiometricLoading) return;

    HapticFeedback.mediumImpact();
    state = state.copyWith(isBiometricLoading: true);

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock your Secure Vault portfolio',
        biometricOnly: true,               // Never fall back to device passcode
        persistAcrossBackgrounding: true,  // Keep prompt alive if user switches apps (renamed from stickyAuth in v3)
        sensitiveTransaction: true,        // Tells OS this is a financial/sensitive action
      );

      if (didAuthenticate) {
        // Success — double haptic feedback same as PIN success
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 80), () {
          HapticFeedback.mediumImpact();
        });
        state = state.copyWith(isAuthenticated: true, isBiometricLoading: false);
      } else {
        // User cancelled or dismissed — just reset loading, don't shake
        state = state.copyWith(isBiometricLoading: false);
      }
    } on PlatformException catch (e) {
      state = state.copyWith(isBiometricLoading: false);

      // Not enrolled = biometrics exist but user hasn't set them up
      // passcodeNotSet = device has no lock screen at all
      // These are informational, not errors we need to crash on.
      if (e.code == _AuthError.notEnrolled ||
          e.code == _AuthError.passcodeNotSet ||
          e.code == _AuthError.notAvailable) {
        // Silently degrade — user can still use PIN
        return;
      }

      // lockedOut = too many failed attempts, temporary lockout
      // permanentlyLockedOut = requires device PIN to unlock biometrics again
      // In both cases, gracefully let the user fall back to PIN
      if (e.code == _AuthError.lockedOut || e.code == _AuthError.permanentlyLockedOut) {
        HapticFeedback.heavyImpact();
        return;
      }
    }
  }

  void logout({bool isExplicit = false}) {
    state = LockScreenState(wasLoggedOut: isExplicit);
  }
}

final lockScreenProvider = StateNotifierProvider<LockScreenNotifier, LockScreenState>((ref) {
  return LockScreenNotifier();
});

final privacyShieldProvider = StateProvider<bool>((ref) => false);
