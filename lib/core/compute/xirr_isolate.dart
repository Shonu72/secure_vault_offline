import 'dart:math';
import 'package:flutter/foundation.dart';

// ── XIRR DATA MODEL ───────────────────────────────────────────────────────────
class CashFlowEntry {
  final double amount;
  final DateTime date;

  const CashFlowEntry({required this.amount, required this.date});
}

// ── ISOLATE ENTRY POINT (top-level function required by compute()) ─────────────
// Must be a top-level function — isolates cannot capture enclosing state.
double _computeXirr(List<CashFlowEntry> cashFlows) {
  if (cashFlows.isEmpty) return 0.0;

  // Newton-Raphson iterative solver for XIRR
  const double tolerance = 1e-7;
  const int maxIterations = 200;
  double rate = 0.1; // Initial guess: 10% annual return

  for (int i = 0; i < maxIterations; i++) {
    double npv = 0.0;
    double dnpv = 0.0; // Derivative of NPV w.r.t. rate

    final firstDate = cashFlows.first.date;

    for (final entry in cashFlows) {
      final t = entry.date.difference(firstDate).inDays / 365.0;
      final denominator = pow(1 + rate, t);
      npv += entry.amount / denominator;
      dnpv -= (t * entry.amount) / (denominator * (1 + rate));
    }

    if (dnpv.abs() < 1e-12) break;

    final newRate = rate - npv / dnpv;

    // Convergence check
    if ((newRate - rate).abs() < tolerance) {
      return newRate;
    }

    rate = newRate;
    if (rate < -0.999) rate = -0.999; // Clamp to prevent infinite divergence
  }

  return rate;
}

// ── TOP-LEVEL WRAPPER for compute() ──────────────────────────────────────────
// compute() requires a top-level or static function signature.
Future<double> computeXirrInIsolate(List<CashFlowEntry> cashFlows) {
  return compute(_computeXirr, cashFlows);
}
