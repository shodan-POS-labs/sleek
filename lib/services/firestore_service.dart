import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../models/business_config.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/receipt_settings.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // SHOP – root-level helpers (shopId discovery, shop config)
  // ---------------------------------------------------------------------------

  Future<bool> hasShop() async {
    final snapshot = await _db.collection('shops').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<String> createShop(String name) async {
    final docRef = await _db.collection('shops').add({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<Map<String, dynamic>?> getShopDetails(String shopId) async {
    try {
      final doc = await _db.collection('shops').doc(shopId).get();
      if (doc.exists) return doc.data();
    } catch (e) {
      debugPrint("Error fetching shop details: $e");
    }
    return null;
  }

  Future<void> updateShopDetails(String shopId, Map<String, dynamic> updates) async {
    await _db.collection('shops').doc(shopId).update(updates);
  }

  Future<BusinessConfig> getBusinessConfig(String shopId) async {
    final shop = await getShopDetails(shopId);
    final typeStr = shop?['businessType'] as String?;
    return BusinessConfig.forType(BusinessConfig.parseType(typeStr));
  }

  // ---------------------------------------------------------------------------
  // Convenience refs – all data lives under shops/{shopId}/…
  // ---------------------------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _products(String shopId) =>
      _db.collection('shops').doc(shopId).collection('products');

  CollectionReference<Map<String, dynamic>> _customers(String shopId) =>
      _db.collection('shops').doc(shopId).collection('customers');

  CollectionReference<Map<String, dynamic>> _sales(String shopId) =>
      _db.collection('shops').doc(shopId).collection('sales');

  Future<ReceiptSettings> getReceiptSettings(String shopId) async {
    final doc = await _db.collection('shops').doc(shopId).get();
    if (doc.exists && doc.data()?['receiptSettingsV2'] != null) {
      return ReceiptSettings.fromMap(
        Map<String, dynamic>.from(doc.data()!['receiptSettingsV2'] as Map),
      );
    }
    // Fallback: build default settings from shop basic info
    final data = doc.data() ?? {};
    return ReceiptSettings(
      businessName: data['name'] as String? ?? '',
      address: data['address'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }

  CollectionReference<Map<String, dynamic>> _categories(String shopId) =>
      _db.collection('shops').doc(shopId).collection('categories');

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  Future<void> insertProduct(String shopId, Product product) async {
    final docRef = _products(shopId).doc();
    final data = product.toMap();
    data.remove('id');
    await docRef.set(data);
  }

  Future<List<Product>> getProducts(String shopId, {String? search}) async {
    try {
      Query<Map<String, dynamic>> query = _products(shopId).orderBy('name');

      if (search != null && search.isNotEmpty) {
        // If it looks like a barcode (mostly digits), search by barcode exactly
        if (RegExp(r'^\d+$').hasMatch(search)) {
          final barcodeSnapshot = await _products(shopId)
              .where('barcode', isEqualTo: search)
              .get();
          if (barcodeSnapshot.docs.isNotEmpty) {
            return barcodeSnapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Product.fromMap(data);
            }).toList();
          }
        }

        // Fallback to name prefix search (case-sensitive by default in Firestore)
        query = query
            .where('name', isGreaterThanOrEqualTo: search)
            .where('name', isLessThanOrEqualTo: search + '\uf8ff');
      }

      final snapshot = await query.limit(100).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Product.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error fetching products: $e");
      // Return empty list so the UI doesn't hang in buffering state
      return [];
    }
  }

  Future<Product?> getProductByBarcode(String shopId, String barcode) async {
    final snapshot = await _products(shopId)
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    data['id'] = snapshot.docs.first.id;
    return Product.fromMap(data);
  }

  Future<Product?> getProductById(String shopId, String id) async {
    final doc = await _products(shopId).doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Product.fromMap(data);
  }

  Future<void> updateProduct(String shopId, Product product) async {
    if (product.id == null) return;
    final data = product.toMap();
    data.remove('id');
    await _products(shopId).doc(product.id).update(data);
  }

  Future<void> deleteProduct(String shopId, String id) async {
    await _products(shopId).doc(id).delete();
  }

  Future<void> updateStock(String shopId, String productId, num quantityChange) async {
    await _products(shopId).doc(productId).update({
      'stock': FieldValue.increment(quantityChange)
    });
  }

  Future<List<Product>> getLowStockProducts(String shopId, {int threshold = 10}) async {
    final snapshot = await _products(shopId)
        .where('stock', isLessThanOrEqualTo: threshold)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Product.fromMap(data);
    }).toList();
  }

  Future<int> getProductCount(String shopId) async {
    final snapshot = await _products(shopId).count().get();
    return snapshot.count ?? 0;
  }

  // ---------------------------------------------------------------------------
  // CUSTOMERS
  // ---------------------------------------------------------------------------

  Future<void> insertCustomer(String shopId, Customer customer) async {
    final docRef = _customers(shopId).doc();
    final data = customer.toMap();
    data.remove('id');
    await docRef.set(data);
  }

  Future<List<Customer>> getCustomers(String shopId, {String? search}) async {
    Query<Map<String, dynamic>> query = _customers(shopId).orderBy('name');

    if (search != null && search.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: search)
          .where('name', isLessThanOrEqualTo: search + '\uf8ff');
    }

    final snapshot = await query.limit(50).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Customer.fromMap(data);
    }).toList();
  }

  Future<void> updateCustomerBalance(String shopId, String customerId, double amount) async {
    await _customers(shopId).doc(customerId).update({'balance': amount});
  }

  Future<void> addToCustomerBalance(String shopId, String customerId, double amount) async {
    await _customers(shopId).doc(customerId).update({
      'balance': FieldValue.increment(amount)
    });
  }

  Future<int> getCustomerCount(String shopId) async {
    final snapshot = await _customers(shopId).where('balance', isGreaterThan: 0).count().get();
    return snapshot.count ?? 0;
  }

  Future<double> getTotalOutstanding(String shopId) async {
    final snapshot = await _customers(shopId).where('balance', isGreaterThan: 0).get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final bal = doc.data()['balance'] as num?;
      if (bal != null) total += bal.toDouble();
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // SALES
  // ---------------------------------------------------------------------------

  Future<void> insertSale(String shopId, Sale sale, List<SaleItem> items) async {
    final batch = _db.batch();

    // Create Sale Doc
    final saleRef = _sales(shopId).doc();
    final pNames = items.map((e) => e.productName).toList();
    final saleData = sale.copyWith(productNames: pNames).toMap();
    saleData.remove('id');
    batch.set(saleRef, saleData);

    // Create Sale Items Docs
    for (var item in items) {
      final itemRef = saleRef.collection('items').doc();
      final itemData = item.toMap();
      itemData.remove('id');
      itemData['saleId'] = saleRef.id;
      itemData['shopId'] = shopId; // Add shopId for collectionGroup queries
      batch.set(itemRef, itemData);

      // Deduct stock from scoped products subcollection
      if (item.productId.isNotEmpty) {
        final productRef = _products(shopId).doc(item.productId);
        batch.update(productRef, {'stock': FieldValue.increment(-item.quantity)});
      }
    }

    // Update customer balance if credit
    if (sale.paymentMethod == 'credit' && sale.customerId != null) {
      final customerRef = _customers(shopId).doc(sale.customerId);
      batch.update(customerRef, {
        'balance': FieldValue.increment(sale.totalAmount),
        'lastPurchase': DateTime.now().toIso8601String()
      });
    }

    await batch.commit();
  }

  Future<List<Sale>> getRecentSales(String shopId, {int limit = 10}) async {
    final snapshot = await _sales(shopId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Sale.fromMap(data);
    }).toList();
  }

  Future<List<SaleItem>> getSaleItems(String shopId, String saleId) async {
    final snapshot = await _sales(shopId).doc(saleId).collection('items').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return SaleItem.fromMap(data);
    }).toList();
  }

  Future<double> getTodaySales(String shopId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final snapshot = await _sales(shopId)
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .get();

    double total = 0;
    for (var doc in snapshot.docs) {
      final val = doc.data()['totalAmount'] as num?;
      if (val != null) total += val.toDouble();
    }
    return total;
  }

  Future<int> getSalesCount(String shopId) async {
    final snapshot = await _sales(shopId).count().get();
    return snapshot.count ?? 0;
  }

  Future<String> generateInvoiceNumber(String shopId) async {
    final count = await getSalesCount(shopId);
    return 'INV-${(count + 1).toString().padLeft(6, '0')}';
  }

  // ---------------------------------------------------------------------------
  // REPORTS / ANALYTICS
  // ---------------------------------------------------------------------------

  /// Fetch all sales within a date range (inclusive).
  /// Handles both local ISO strings ("2026-03-01T00:00:00.000") and
  /// UTC ISO strings with Z suffix ("2026-03-01T00:00:00.000Z").
  Future<List<Sale>> getSalesInRange(String shopId, DateTime start, DateTime end) async {
    // Use a range that covers both local and UTC formatted ISO strings.
    // Local: "2026-03-01T00:00:00.000"  UTC: "2026-03-01T00:00:00.000Z"
    // Appending 'Z' to end ensures UTC-formatted dates are included.
    final startStr = start.toIso8601String();
    final endStr = '${end.toIso8601String()}Z';

    final snapshot = await _sales(shopId)
        .where('createdAt', isGreaterThanOrEqualTo: startStr)
        .where('createdAt', isLessThanOrEqualTo: endStr)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Sale.fromMap(data);
    }).toList();
  }

  /// Fetch all sale items for a list of sale IDs in parallel for maximum speed.
  Future<List<SaleItem>> getSaleItemsForSales(String shopId, List<String> saleIds) async {
    final List<Future<List<SaleItem>>> futures = saleIds.map((saleId) async {
      final snapshot = await _sales(shopId).doc(saleId).collection('items').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return SaleItem.fromMap(data);
      }).toList();
    }).toList();

    final nestedResults = await Future.wait(futures);
    return nestedResults.expand((items) => items).toList();
  }

  /// Pharmacy: get products expiring within [days] from now.
  Future<List<Product>> getExpiringProducts(String shopId, {int days = 30}) async {
    final cutoff = DateTime.now().add(Duration(days: days)).toIso8601String();
    final snapshot = await _products(shopId)
        .where('expiryDate', isLessThanOrEqualTo: cutoff)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Product.fromMap(data);
    }).where((p) => p.expiryDate != null).toList();
  }

  /// Repair: count jobs grouped by status from sales in a date range.
  Future<Map<String, int>> getJobStatusCounts(String shopId, DateTime start, DateTime end) async {
    final sales = await getSalesInRange(shopId, start, end);
    final counts = <String, int>{'pending': 0, 'in-progress': 0, 'done': 0};
    for (final sale in sales) {
      final status = sale.jobStatus.isEmpty ? 'pending' : sale.jobStatus;
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------------------
  // CATEGORIES
  // ---------------------------------------------------------------------------

  Future<List<String>> getCategories(String shopId) async {
    final snapshot = await _categories(shopId).orderBy('name').get();
    return snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
  }

  Future<void> insertCategory(String shopId, String name) async {
    await _categories(shopId).add({'name': name});
  }

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _notifications(String shopId) =>
      _db.collection('shops').doc(shopId).collection('notifications');

  /// Default notification preferences — all enabled.
  static const _defaultNotificationPrefs = <String, dynamic>{
    'dailySalesSummary': true,
    'lowStockAlerts': true,
    'expiringMedicineAlert': true,
    'expiredStockAlert': true,
    'newProductReminder': true,
    'pendingJobsReminder': true,
    'overdueJobsAlert': true,
    'restockReminder': true,
    'dailyMenuReminder': true,
  };

  Future<Map<String, dynamic>> getNotificationPreferences(String shopId) async {
    final shop = await getShopDetails(shopId);
    final stored = shop?['notificationPreferences'] as Map<String, dynamic>?;
    if (stored != null) return {..._defaultNotificationPrefs, ...stored};
    return Map<String, dynamic>.from(_defaultNotificationPrefs);
  }

  Future<void> saveNotificationPreferences(
      String shopId, Map<String, dynamic> prefs) async {
    await updateShopDetails(shopId, {'notificationPreferences': prefs});
  }

  Future<void> createNotification(
      String shopId, AppNotification notification) async {
    await _notifications(shopId).add(notification.toMap());
  }

  Future<List<AppNotification>> getNotifications(String shopId,
      {int limit = 50}) async {
    final snapshot = await _notifications(shopId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return AppNotification.fromMap(data);
    }).toList();
  }

  Future<int> getUnreadNotificationCount(String shopId) async {
    final snapshot = await _notifications(shopId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> markNotificationRead(
      String shopId, String notificationId) async {
    await _notifications(shopId).doc(notificationId).update({'isRead': true});
  }

  Future<void> markAllNotificationsRead(String shopId) async {
    final snapshot = await _notifications(shopId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------

  /// Find a user by email address (for cashier PIN reset requests from login)
  Future<AppUser?> queryUserByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AppUser.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  /// Get all users in a shop
  Future<List<AppUser>> getShopUsers(String shopId) async {
    final snapshot = await _db
        .collection('users')
        .where('shopId', isEqualTo: shopId)
        .get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }
}
