import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_plan.dart';
import 'storage_service.dart';

class BillingService {
  static const weeklyPlanId = 'doc_reader_weekly';
  static const monthlyPlanId = 'doc_reader_monthly';
  static const yearlyPlanId = 'doc_reader_yearly';
  static const lifetimePlanId = 'doc_reader_lifetime';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  bool _isPremium = false;
  bool _isBusy = false;
  String? _activePlanId;
  List<ProductDetails> _products = <ProductDetails>[];

  bool get isAvailable => _isAvailable;
  bool get isPremium => _isPremium;
  bool get isBusy => _isBusy;
  String? get activePlanId => _activePlanId;
  List<ProductDetails> get products =>
      List<ProductDetails>.unmodifiable(_products);

  List<SubscriptionPlan> get fallbackPlans => const <SubscriptionPlan>[
    SubscriptionPlan(
      id: weeklyPlanId,
      title: 'Weekly',
      priceLabel: '₹99',
      description: 'Fast access for short-term PDF projects.',
    ),
    SubscriptionPlan(
      id: monthlyPlanId,
      title: 'Monthly',
      priceLabel: '₹199',
      description: 'Best for regular reading and scanner workflows.',
    ),
    SubscriptionPlan(
      id: yearlyPlanId,
      title: 'Yearly',
      priceLabel: '₹999',
      description: 'Best value for ongoing document productivity.',
    ),
    SubscriptionPlan(
      id: lifetimePlanId,
      title: 'Lifetime',
      priceLabel: '₹4999',
      description: 'One purchase, permanent premium access.',
    ),
  ];

  Future<void> initialize(StorageService storageService) async {
    _isPremium = await storageService.getPremiumStatus();
    _activePlanId = await storageService.getActivePlan();
    _isAvailable = await _inAppPurchase.isAvailable();
    _purchaseSubscription ??= _inAppPurchase.purchaseStream.listen(
      (purchases) => _handlePurchaseUpdates(purchases, storageService),
    );

    if (_isAvailable) {
      final response = await _inAppPurchase.queryProductDetails(<String>{
        weeklyPlanId,
        monthlyPlanId,
        yearlyPlanId,
        lifetimePlanId,
      });
      _products = response.productDetails.toList()
        ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      await restorePurchases(storageService);
    }
  }

  Future<void> buyPlan(String planId, StorageService storageService) async {
    final details = _products.firstWhereOrNull((item) => item.id == planId);
    if (details == null) {
      await storageService.setPremiumStatus(true, planId: planId);
      _isPremium = true;
      _activePlanId = planId;
      return;
    }

    _isBusy = true;
    final purchaseParam = PurchaseParam(productDetails: details);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    _isBusy = false;
  }

  Future<void> restorePurchases(StorageService storageService) async {
    if (!_isAvailable) {
      return;
    }
    await _inAppPurchase.restorePurchases();
    _isPremium = await storageService.getPremiumStatus();
    _activePlanId = await storageService.getActivePlan();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
    StorageService storageService,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _isPremium = true;
        _activePlanId = purchase.productID;
        await storageService.setPremiumStatus(true, planId: purchase.productID);
      }
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
  }
}

extension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) {
        return value;
      }
    }
    return null;
  }
}
