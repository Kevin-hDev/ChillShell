import 'package:flutter/foundation.dart';

/// État du système d'achat in-app et de la période d'essai.
@immutable
class PurchaseState {
  final bool isPurchased;
  final bool trialActive;
  final int trialDaysRemaining;
  final bool isLoading;
  final String? error;

  const PurchaseState({
    this.isPurchased = false,
    this.trialActive = true,
    this.trialDaysRemaining = 7,
    this.isLoading = true,
    this.error,
  });

  bool get hasAccess => isPurchased || trialActive;

  PurchaseState copyWith({
    bool? isPurchased,
    bool? trialActive,
    int? trialDaysRemaining,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return PurchaseState(
      isPurchased: isPurchased ?? this.isPurchased,
      trialActive: trialActive ?? this.trialActive,
      trialDaysRemaining: trialDaysRemaining ?? this.trialDaysRemaining,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
