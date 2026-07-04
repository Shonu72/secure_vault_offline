import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:secure_vault_offline/core/constants.dart';

class LockScreenState {
  final String pin;
  final bool isAuthenticated;
  final bool shouldShake;

  const LockScreenState({
    this.pin = '',
    this.isAuthenticated = false,
    this.shouldShake = false,
  });

  LockScreenState copyWith({
    String? pin,
    bool? isAuthenticated,
    bool? shouldShake,
  }) {
    return LockScreenState(
      pin: pin ?? this.pin,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      shouldShake: shouldShake ?? this.shouldShake,
    );
  }
}

class LockScreenNotifier extends StateNotifier<LockScreenState> {
  LockScreenNotifier() : super(const LockScreenState());

  static const int _maxPinLength = 4;
  static const String _correctPin = AppConstants.defaultPinSeed;

  void addDigit(String digit) {
    if (state.pin.length >= _maxPinLength || state.shouldShake) return;

    // Haptic tick
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
        // Success haptic confirmation
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 80), () {
          HapticFeedback.mediumImpact();
        });

        state = state.copyWith(isAuthenticated: true);
      } else {
        // Failure haptic alert and trigger shake animation flag
        HapticFeedback.heavyImpact();
        state = state.copyWith(shouldShake: true);

        // Reset state after shake completes (300ms delay)
        Future.delayed(const Duration(milliseconds: 400), () {
          state = const LockScreenState(pin: '', shouldShake: false, isAuthenticated: false);
        });
      }
    });
  }

  void logout() {
    state = const LockScreenState();
  }
}

final lockScreenProvider = StateNotifierProvider<LockScreenNotifier, LockScreenState>((ref) {
  return LockScreenNotifier();
});

final privacyShieldProvider = StateProvider<bool>((ref) => false);

