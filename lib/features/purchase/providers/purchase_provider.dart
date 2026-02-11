import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../models/purchase_state.dart';
import '../../../services/purchase_service.dart';

class PurchaseNotifier extends Notifier<PurchaseState> {
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  PurchaseState build() {
    _purchaseSubscription = PurchaseService.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        if (kDebugMode) debugPrint('Purchase stream error: $error');
      },
    );

    ref.onDispose(() {
      _purchaseSubscription?.cancel();
    });

    Future.microtask(_initialize);

    return const PurchaseState(isLoading: true);
  }

  Future<void> _initialize() async {
    try {
      final trialStart = await PurchaseService.initTrialStart();
      final daysRemaining = PurchaseService.trialDaysRemaining(trialStart);
      final trialActive = daysRemaining > 0;

      final locallyPurchased = await PurchaseService.isLocallyPurchased();

      final storeAvailable = await PurchaseService.isStoreAvailable();

      if (storeAvailable) {
        await PurchaseService.restorePurchases();
        state = state.copyWith(
          isPurchased: locallyPurchased,
          trialActive: trialActive,
          trialDaysRemaining: daysRemaining,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isPurchased: locallyPurchased,
          trialActive: trialActive,
          trialDaysRemaining: daysRemaining,
          isLoading: false,
          error: locallyPurchased ? null : 'store_unavailable',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Purchase initialization error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'init_error',
      );
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await PurchaseService.verifyAndCompletePurchase(purchase);
          if (verified) {
            state = state.copyWith(isPurchased: true, isLoading: false, clearError: true);
          }
          break;
        case PurchaseStatus.error:
          if (kDebugMode) debugPrint('Purchase error: ${purchase.error?.message}');
          state = state.copyWith(error: 'purchase_failed', isLoading: false);
          break;
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.canceled:
          state = state.copyWith(isLoading: false, clearError: true);
          break;
      }
    }
  }

  Future<void> buyPremium() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final product = await PurchaseService.getProductDetails();
    if (product == null) {
      state = state.copyWith(isLoading: false, error: 'product_not_found');
      return;
    }

    final initiated = await PurchaseService.buyPremium(product);
    if (!initiated) {
      state = state.copyWith(isLoading: false, error: 'purchase_init_failed');
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await PurchaseService.restorePurchases();
    Future.delayed(const Duration(seconds: 10), () {
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });
  }
}

final purchaseProvider = NotifierProvider<PurchaseNotifier, PurchaseState>(
  PurchaseNotifier.new,
);
