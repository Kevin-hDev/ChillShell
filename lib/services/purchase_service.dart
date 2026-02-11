import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static const _trialStartKey = 'chillshell_trial_start';
  static const _purchasedKey = 'chillshell_purchased';
  static const _productId = 'chillshell_premium';
  static const _trialDurationDays = 7;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static final InAppPurchase _iap = InAppPurchase.instance;

  static Future<bool> isStoreAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e) {
      if (kDebugMode) debugPrint('Store availability check failed: $e');
      return false;
    }
  }

  static Future<DateTime> initTrialStart() async {
    final existing = await _storage.read(key: _trialStartKey);
    if (existing != null) {
      return DateTime.parse(existing);
    }
    final now = DateTime.now();
    await _storage.write(key: _trialStartKey, value: now.toIso8601String());
    if (kDebugMode) debugPrint('Trial started: ${now.toIso8601String()}');
    return now;
  }

  static int trialDaysRemaining(DateTime trialStart) {
    final elapsed = DateTime.now().difference(trialStart).inDays;
    final remaining = _trialDurationDays - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  static bool isTrialActive(DateTime trialStart) {
    return trialDaysRemaining(trialStart) > 0;
  }

  static Future<ProductDetails?> getProductDetails() async {
    try {
      final response = await _iap.queryProductDetails({_productId});
      if (response.notFoundIDs.isNotEmpty) {
        if (kDebugMode) debugPrint('Product not found: $_productId');
        return null;
      }
      if (response.productDetails.isEmpty) return null;
      return response.productDetails.first;
    } catch (e) {
      if (kDebugMode) debugPrint('Error querying product: $e');
      return null;
    }
  }

  static Future<bool> buyPremium(ProductDetails product) async {
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      if (kDebugMode) debugPrint('Error initiating purchase: $e');
      return false;
    }
  }

  static Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (kDebugMode) debugPrint('Error restoring purchases: $e');
    }
  }

  static Future<bool> verifyAndCompletePurchase(PurchaseDetails purchase) async {
    if (purchase.productID != _productId) return false;

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      await _storage.write(key: _purchasedKey, value: 'true');
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      if (kDebugMode) debugPrint('Purchase verified and completed');
      return true;
    }
    return false;
  }

  static Future<bool> isLocallyPurchased() async {
    final value = await _storage.read(key: _purchasedKey);
    return value == 'true';
  }

  static Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  static String get productId => _productId;
}
