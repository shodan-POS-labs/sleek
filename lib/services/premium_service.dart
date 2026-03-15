import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PremiumService extends ChangeNotifier {
  static final PremiumService _instance = PremiumService._internal();
  factory PremiumService() => _instance;
  PremiumService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // The singleton premium state
  bool _isPremium = false;
  bool get isPremium => _isPremium;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _purchasePending = false;
  bool get purchasePending => _purchasePending;

  String? _error;
  String? get error => _error;

  // The product ID as registered in Google Play Console
  // In a real app this might come from remote config
  static const String _kPremiumProductId = 'sleek_premium_onetime';

  Future<void> init() async {
    // 1. Check local secure storage first for fast load
    final storedStatus = await _storage.read(key: 'has_premium');
    if (storedStatus == 'true') {
      _isPremium = true;
      notifyListeners();
    }

    // 2. Initialize the listener for incoming purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (Object error) {
      _error = error.toString();
      notifyListeners();
    });

    // 3. Connect to store and load products
    await _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      _isAvailable = false;
      _products = [];
      _purchasePending = false;
      notifyListeners();
      return;
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails({_kPremiumProductId});
    
    if (productDetailResponse.error != null) {
      _error = productDetailResponse.error!.message;
      _isAvailable = isAvailable;
      _products = productDetailResponse.productDetails;
      _purchasePending = false;
      notifyListeners();
      return;
    }

    if (productDetailResponse.productDetails.isEmpty) {
      _error = 'Premium product not found in Google Play.';
      _isAvailable = isAvailable;
      _products = [];
      _purchasePending = false;
      notifyListeners();
      return;
    }

    _isAvailable = true;
    _products = productDetailResponse.productDetails;
    _purchasePending = false;
    notifyListeners();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _error = purchaseDetails.error!.message;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          
          if (purchaseDetails.productID == _kPremiumProductId) {
             _unlockPremium();
          }
        }
        
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
        _purchasePending = false;
        notifyListeners();
      }
    }
  }

  Future<void> _unlockPremium() async {
    _isPremium = true;
    await _storage.write(key: 'has_premium', value: 'true');
    notifyListeners();
  }

  // Debug utility to remove premium
  Future<void> removePremiumLocally() async {
    if (!kDebugMode) return;
    _isPremium = false;
    await _storage.delete(key: 'has_premium');
    notifyListeners();
  }

  Future<void> buyPremium() async {
    if (_products.isEmpty) {
      _error = 'Premium product is not loaded yet.';
      notifyListeners();
      return;
    }
    
    final ProductDetails productDetails = _products.firstWhere((p) => p.id == _kPremiumProductId);
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _error = 'Failed to restore purchases: \${e.toString()}';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
