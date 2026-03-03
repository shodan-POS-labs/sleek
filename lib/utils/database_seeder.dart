import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore_for_file: unused_local_variable

/// ──────────────────────────────────────────────────────────────────────────
/// DATABASE SEEDER — Comprehensive test data for ShopFlow POS
///
/// Creates 3 shops, each with a different business type, admin + cashier
/// accounts, products, categories, customers, sales (with items),
/// and notifications.
///
/// Usage:  await DatabaseSeeder.seed();
///         (call from a dev button or debug screen)
/// ──────────────────────────────────────────────────────────────────────────

class DatabaseSeeder {
  static final _db = FirebaseFirestore.instance;
  static final _rng = Random();

  static String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  // ─── MAIN ENTRY POINT ──────────────────────────────────────────────────

  static Future<String> seed() async {
    final log = StringBuffer();
    log.writeln('═══ ShopFlow Database Seeder ═══\n');

    try {
      // ────────── SHOP 1: Pharmacy ──────────
      log.writeln('▸ Creating Pharmacy shop...');
      final pharmacy = await _createShop(
        shopName: 'MediCare Pharmacy',
        businessType: 'pharmacy',
        adminName: 'Somapala Galagagedara',
        adminEmail: 'somapalagalagedara@gmail.com',
        adminPassword: 'Test@1234',
        adminPin: '123456',
        cashierName: 'Nimal Perera',
        cashierEmail: 'nimal.pharmacy@test.com',
        cashierPassword: 'Test@1234',
        cashierPin: '654321',
      );
      await _seedPharmacyData(pharmacy['shopId']!, pharmacy['customerIds']!);
      log.writeln('  ✓ Pharmacy seeded (${pharmacy['shopId']})');

      // ────────── SHOP 2: Restaurant ──────────
      log.writeln('▸ Creating Restaurant shop...');
      final restaurant = await _createShop(
        shopName: 'Spice Garden Restaurant',
        businessType: 'restaurant',
        adminName: 'Dingiribanda Senanayake',
        adminEmail: 'dingiribanda125@gmail.com',
        adminPassword: 'Test@1234',
        adminPin: '123456',
        cashierName: 'Sunil Silva',
        cashierEmail: 'sunil.restaurant@test.com',
        cashierPassword: 'Test@1234',
        cashierPin: '654321',
      );
      await _seedRestaurantData(
          restaurant['shopId']!, restaurant['customerIds']!);
      log.writeln('  ✓ Restaurant seeded (${restaurant['shopId']})');

      // ────────── SHOP 3: Retail ──────────
      log.writeln('▸ Creating Retail shop...');
      final retail = await _createShop(
        shopName: 'FreshMart Grocery',
        businessType: 'retail',
        adminName: 'Pabasara Fernando',
        adminEmail: 'pabasaraf79@gmail.com',
        adminPassword: 'Test@1234',
        adminPin: '123456',
        cashierName: 'Kamal Jayasuriya',
        cashierEmail: 'kamal.retail@test.com',
        cashierPassword: 'Test@1234',
        cashierPin: '654321',
      );
      await _seedRetailData(retail['shopId']!, retail['customerIds']!);
      log.writeln('  ✓ Retail seeded (${retail['shopId']})');

      log.writeln('\n═══ SEEDING COMPLETE ═══');
      log.writeln('\nLogin credentials (all PINs: 123456 admin / 654321 cashier):');
      log.writeln('  Pharmacy  → somapalagalagedara@gmail.com / Test@1234');
      log.writeln('  Restaurant→ dingiribanda125@gmail.com    / Test@1234');
      log.writeln('  Retail    → pabasaraf79@gmail.com        / Test@1234');
    } catch (e, st) {
      log.writeln('\n✗ ERROR: $e');
      log.writeln(st.toString().split('\n').take(5).join('\n'));
    }

    return log.toString();
  }

  // ─── SHOP + USER CREATION ──────────────────────────────────────────────

  /// Creates a shop, admin user, cashier user, base categories, customers,
  /// and notification preferences. Returns shopId + list of customerIds.
  static Future<Map<String, dynamic>> _createShop({
    required String shopName,
    required String businessType,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String adminPin,
    required String cashierName,
    required String cashierEmail,
    required String cashierPassword,
    required String cashierPin,
  }) async {
    // 1 — Create admin in Firebase Auth
    final adminUid =
        await _createAuthUser(adminEmail, adminPassword);

    // 2 — Create shop doc
    final shopRef = await _db.collection('shops').add({
      'name': shopName,
      'businessType': businessType,
      'createdAt': FieldValue.serverTimestamp(),
      'receiptSettings': {
        'shopName': shopName,
        'phone': '+94 ${70 + _rng.nextInt(9)}${_rng.nextInt(10000000).toString().padLeft(7, '0')}',
        'address': '${_rng.nextInt(300) + 1}, Main Street, Colombo ${_rng.nextInt(15) + 1}',
        'footer': 'Thank you for your purchase!',
      },
      'notificationPreferences': {
        'dailySalesSummary': true,
        'lowStockAlerts': true,
        'expiringMedicineAlert': true,
        'expiredStockAlert': true,
        'newProductReminder': true,
        'pendingJobsReminder': true,
        'overdueJobsAlert': true,
        'restockReminder': true,
        'dailyMenuReminder': true,
      },
    });
    final shopId = shopRef.id;

    // 3 — Create admin user doc
    await _db.collection('users').doc(adminUid).set({
      'shopId': shopId,
      'name': adminName,
      'pinHash': _hashPin(adminPin),
      'role': 'admin',
      'email': adminEmail,
      'biometricEnabled': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    // 4 — Create cashier in Firebase Auth via secondary app
    final cashierUid =
        await _createAuthUser(cashierEmail, cashierPassword);

    await _db.collection('users').doc(cashierUid).set({
      'shopId': shopId,
      'name': cashierName,
      'pinHash': _hashPin(cashierPin),
      'role': 'cashier',
      'email': cashierEmail,
      'biometricEnabled': false,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    // 5 — Categories (business-specific)
    final cats = _categoriesFor(businessType);
    for (final cat in cats) {
      await _db
          .collection('shops')
          .doc(shopId)
          .collection('categories')
          .add({'name': cat});
    }

    // 6 — Customers (shared pattern, 8 per shop)
    final customerIds = <String>[];
    final customers = _generateCustomers();
    for (final c in customers) {
      final ref = await _db
          .collection('shops')
          .doc(shopId)
          .collection('customers')
          .add(c);
      customerIds.add(ref.id);
    }

    return {'shopId': shopId, 'customerIds': customerIds};
  }

  /// Creates a Firebase Auth user. Uses a secondary Firebase App to avoid
  /// signing out the current user.
  static Future<String> _createAuthUser(String email, String password) async {
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = Firebase.app('seeder_temp');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'seeder_temp',
        options: Firebase.app().options,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await secondaryAuth.signOut();
      return cred.user!.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // User exists — sign in to get UID
        final cred = await secondaryAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await secondaryAuth.signOut();
        return cred.user!.uid;
      }
      rethrow;
    }
  }

  // ─── CATEGORIES ────────────────────────────────────────────────────────

  static List<String> _categoriesFor(String type) {
    switch (type) {
      case 'pharmacy':
        return [
          'Antibiotics',
          'Pain Relief',
          'Vitamins & Supplements',
          'Cough & Cold',
          'Skin Care',
          'First Aid',
          'Diabetes',
          'Baby Care',
        ];
      case 'restaurant':
        return [
          'Rice & Curry',
          'Kottu & Noodles',
          'Starters',
          'Desserts',
          'Hot Beverages',
          'Cold Beverages',
          'Short Eats',
          'Specials',
        ];
      case 'retail':
        return [
          'Beverages',
          'Dairy',
          'Snacks',
          'Rice & Grains',
          'Cleaning',
          'Personal Care',
          'Canned Food',
          'Frozen',
        ];
      default:
        return ['General'];
    }
  }

  // ─── CUSTOMERS (8 per shop) ────────────────────────────────────────────

  static List<Map<String, dynamic>> _generateCustomers() {
    final now = DateTime.now();
    final names = [
      ['Ruwan Bandara', '0771234567'],
      ['Anoma Dissanayake', '0712345678'],
      ['Chaminda Vaas', '0761234567'],
      ['Dilini Perera', '0781234567'],
      ['Eshan Gunawardena', '0751234567'],
      ['Fathima Nazar', '0741234567'],
      ['Gamini de Silva', '0701234567'],
      ['Hashini Ratnayake', '0721234567'],
    ];

    return names.asMap().entries.map((entry) {
      final i = entry.key;
      final n = entry.value;
      final createdDaysAgo = 60 - (i * 7);
      final balance = i < 3 ? (500.0 + i * 350) : 0.0; // First 3 have credit
      return {
        'name': n[0],
        'phone': n[1],
        'balance': balance,
        'lastPurchase': i < 5
            ? now.subtract(Duration(days: i * 3)).toIso8601String()
            : null,
        'createdAt':
            now.subtract(Duration(days: createdDaysAgo)).toIso8601String(),
      };
    }).toList();
  }

  // ─── PHARMACY SEED DATA ────────────────────────────────────────────────

  static Future<void> _seedPharmacyData(
      String shopId, List<dynamic> customerIds) async {
    final now = DateTime.now();
    final products = _pharmacyProducts(now);
    final productIds = <String>[];

    // Insert products
    for (final p in products) {
      final ref = await _db
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .add(p);
      productIds.add(ref.id);
    }

    // Insert sales spanning the last 60 days
    await _seedSales(
      shopId: shopId,
      productIds: productIds,
      productData: products,
      customerIds: customerIds.cast<String>(),
      businessType: 'pharmacy',
      days: 60,
      salesPerDay: 5,
    );

    // Notifications
    await _seedNotifications(shopId, 'pharmacy', now);
  }

  static List<Map<String, dynamic>> _pharmacyProducts(DateTime now) {
    final categories = [
      'Antibiotics',
      'Pain Relief',
      'Vitamins & Supplements',
      'Cough & Cold',
      'Skin Care',
      'First Aid',
      'Diabetes',
      'Baby Care',
    ];

    return [
      _product('Paracetamol 500mg', 'Pain Relief', 15.0, stock: 200, wholesale: 10.0,
          barcode: '8901234560011', batch: 'B2024-001',
          expiry: now.add(const Duration(days: 365))),
      _product('Amoxicillin 250mg', 'Antibiotics', 45.0, stock: 80, wholesale: 30.0,
          barcode: '8901234560028', batch: 'B2024-002',
          expiry: now.add(const Duration(days: 180))),
      _product('Cough Syrup 100ml', 'Cough & Cold', 250.0, stock: 50, wholesale: 180.0,
          barcode: '8901234560035', batch: 'B2024-003',
          expiry: now.add(const Duration(days: 240))),
      _product('Vitamin C 1000mg', 'Vitamins & Supplements', 120.0, stock: 150, wholesale: 80.0,
          barcode: '8901234560042', batch: 'B2024-004',
          expiry: now.add(const Duration(days: 540))),
      _product('Cetirizine 10mg', 'Cough & Cold', 8.0, stock: 300, wholesale: 5.0,
          barcode: '8901234560059', batch: 'B2024-005',
          expiry: now.add(const Duration(days: 300))),
      _product('Metformin 500mg', 'Diabetes', 25.0, stock: 120, wholesale: 15.0,
          barcode: '8901234560066', batch: 'B2024-006',
          expiry: now.add(const Duration(days: 400))),
      _product('Ibuprofen 400mg', 'Pain Relief', 20.0, stock: 180, wholesale: 12.0,
          barcode: '8901234560073', batch: 'B2024-007',
          expiry: now.add(const Duration(days: 450))),
      _product('ORS Powder', 'First Aid', 35.0, stock: 100, wholesale: 22.0,
          barcode: '8901234560080', batch: 'B2024-008',
          expiry: now.add(const Duration(days: 500))),
      _product('Calamine Lotion 100ml', 'Skin Care', 180.0, stock: 40, wholesale: 120.0,
          barcode: '8901234560097', batch: 'B2024-009',
          expiry: now.add(const Duration(days: 350))),
      _product('Baby Gripe Water', 'Baby Care', 320.0, stock: 60, wholesale: 220.0,
          barcode: '8901234560103', batch: 'B2024-010',
          expiry: now.add(const Duration(days: 200))),
      _product('Multivitamin Tablets', 'Vitamins & Supplements', 550.0, stock: 90, wholesale: 380.0,
          barcode: '8901234560110', batch: 'B2024-011',
          expiry: now.add(const Duration(days: 600))),
      _product('Antacid Syrup 170ml', 'Cough & Cold', 210.0, stock: 65, wholesale: 140.0,
          barcode: '8901234560127', batch: 'B2024-012',
          expiry: now.add(const Duration(days: 270))),
      _product('Bandage Roll 5cm', 'First Aid', 85.0, stock: 150, wholesale: 50.0,
          barcode: '8901234560134', batch: 'B2024-013',
          expiry: now.add(const Duration(days: 730))),
      _product('Insulin Pen Needle', 'Diabetes', 750.0, stock: 3, wholesale: 500.0,
          barcode: '8901234560141', batch: 'B2024-014',
          expiry: now.add(const Duration(days: 90))),  // Low stock + expiring soon
      _product('Expired Cough Drops', 'Cough & Cold', 55.0, stock: 20, wholesale: 35.0,
          barcode: '8901234560158', batch: 'B2023-099',
          expiry: now.subtract(const Duration(days: 15))), // Already expired!
      _product('Diaper Cream 50g', 'Baby Care', 420.0, stock: 8, wholesale: 280.0,
          barcode: '8901234560165', batch: 'B2024-015',
          expiry: now.add(const Duration(days: 20))),  // Expiring within 30 days!
    ];
  }

  // ─── RESTAURANT SEED DATA ─────────────────────────────────────────────

  static Future<void> _seedRestaurantData(
      String shopId, List<dynamic> customerIds) async {
    final now = DateTime.now();
    final products = _restaurantProducts();
    final productIds = <String>[];

    for (final p in products) {
      final ref = await _db
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .add(p);
      productIds.add(ref.id);
    }

    await _seedSales(
      shopId: shopId,
      productIds: productIds,
      productData: products,
      customerIds: customerIds.cast<String>(),
      businessType: 'restaurant',
      days: 60,
      salesPerDay: 8,
    );

    await _seedNotifications(shopId, 'restaurant', now);
  }

  static List<Map<String, dynamic>> _restaurantProducts() {
    return [
      _menuItem('Chicken Fried Rice', 'Rice & Curry', 650.0,
          modifiers: [
            {'name': 'Extra Egg', 'price': 80},
            {'name': 'Extra Chicken', 'price': 150},
            {'name': 'Spicy Level +', 'price': 0},
          ],
          variants: [
            {'label': 'Regular', 'price': 650},
            {'label': 'Large', 'price': 850},
          ]),
      _menuItem('Special Kottu', 'Kottu & Noodles', 750.0,
          modifiers: [
            {'name': 'Cheese Topping', 'price': 120},
            {'name': 'Extra Meat', 'price': 200},
          ],
          variants: [
            {'label': 'Regular', 'price': 750},
            {'label': 'Large', 'price': 950},
          ]),
      _menuItem('Fish Curry Rice & Curry', 'Rice & Curry', 580.0,
          modifiers: [
            {'name': 'Extra Curry', 'price': 100},
            {'name': 'Papadum', 'price': 40},
          ]),
      _menuItem('Chicken Devilled', 'Rice & Curry', 450.0,
          modifiers: [
            {'name': 'Extra Spicy', 'price': 0},
          ]),
      _menuItem('Vegetable Spring Rolls (4pc)', 'Starters', 320.0),
      _menuItem('Chicken Wings (6pc)', 'Starters', 580.0,
          modifiers: [
            {'name': 'BBQ Sauce', 'price': 50},
            {'name': 'Hot Sauce', 'price': 0},
          ]),
      _menuItem('Watalappam', 'Desserts', 250.0),
      _menuItem('Ice Cream Sundae', 'Desserts', 380.0,
          variants: [
            {'label': 'Single Scoop', 'price': 280},
            {'label': 'Double Scoop', 'price': 380},
            {'label': 'Triple Scoop', 'price': 480},
          ]),
      _menuItem('Plain Tea', 'Hot Beverages', 80.0),
      _menuItem('Coffee', 'Hot Beverages', 120.0,
          variants: [
            {'label': 'Regular', 'price': 120},
            {'label': 'Large', 'price': 180},
          ]),
      _menuItem('Fresh Lime Juice', 'Cold Beverages', 200.0),
      _menuItem('Mango Smoothie', 'Cold Beverages', 350.0,
          variants: [
            {'label': 'Regular', 'price': 350},
            {'label': 'Large', 'price': 450},
          ]),
      _menuItem('Fish Bun', 'Short Eats', 80.0),
      _menuItem('Egg Roti', 'Short Eats', 100.0),
      _menuItem("Chef's Special Biryani", 'Specials', 1200.0,
          modifiers: [
            {'name': 'Raita', 'price': 80},
            {'name': 'Extra Chicken Leg', 'price': 250},
          ],
          variants: [
            {'label': 'Regular', 'price': 1200},
            {'label': 'Family Size', 'price': 2200},
          ]),
      _menuItem('Noodles Soup', 'Kottu & Noodles', 480.0,
          modifiers: [
            {'name': 'Add Prawns', 'price': 300},
            {'name': 'Extra Veggies', 'price': 50},
          ]),
    ];
  }

  // ─── RETAIL SEED DATA ─────────────────────────────────────────────────

  static Future<void> _seedRetailData(
      String shopId, List<dynamic> customerIds) async {
    final now = DateTime.now();
    final products = _retailProducts();
    final productIds = <String>[];

    for (final p in products) {
      final ref = await _db
          .collection('shops')
          .doc(shopId)
          .collection('products')
          .add(p);
      productIds.add(ref.id);
    }

    await _seedSales(
      shopId: shopId,
      productIds: productIds,
      productData: products,
      customerIds: customerIds.cast<String>(),
      businessType: 'retail',
      days: 60,
      salesPerDay: 6,
    );

    await _seedNotifications(shopId, 'retail', now);
  }

  static List<Map<String, dynamic>> _retailProducts() {
    return [
      _product('Coca-Cola 500ml', 'Beverages', 200.0, stock: 120, wholesale: 150.0,
          barcode: '5449000000996', unit: 'piece'),
      _product('Anchor Milk 1L', 'Dairy', 520.0, stock: 45, wholesale: 440.0,
          barcode: '5411188019190', unit: 'piece'),
      _product('Munchee Lemon Puff', 'Snacks', 180.0, stock: 80, wholesale: 140.0,
          barcode: '4796002000177', unit: 'piece'),
      _product('Basmati Rice 5kg', 'Rice & Grains', 2800.0, stock: 30, wholesale: 2400.0,
          barcode: '8901234567890', unit: 'kg'),
      _product('Sunlight Washing Powder 1kg', 'Cleaning', 650.0, stock: 60, wholesale: 520.0,
          barcode: '8901030582134', unit: 'piece'),
      _product('Signal Toothpaste 120g', 'Personal Care', 350.0, stock: 70, wholesale: 270.0,
          barcode: '8901030715044', unit: 'piece'),
      _product('Sardines Canned 425g', 'Canned Food', 480.0, stock: 50, wholesale: 360.0,
          barcode: '8990099213145', unit: 'piece'),
      _product('Elephant House Ice Cream 1L', 'Frozen', 950.0, stock: 15, wholesale: 750.0,
          barcode: '4796004000100', unit: 'piece'),
      _product('Red Onions 1kg', 'Rice & Grains', 450.0, stock: 40, wholesale: 350.0,
          barcode: '', unit: 'kg'),
      _product('Sugar 1kg', 'Rice & Grains', 290.0, stock: 55, wholesale: 240.0,
          barcode: '8901234000111', unit: 'kg'),
      _product('Dettol Soap 120g', 'Personal Care', 220.0, stock: 90, wholesale: 170.0,
          barcode: '8901030000222', unit: 'piece'),
      _product('Maggi Noodles 5-pack', 'Snacks', 500.0, stock: 42, wholesale: 380.0,
          barcode: '8901030000333', unit: 'piece'),
      _product('Fresh Coconut Oil 500ml', 'Rice & Grains', 680.0, stock: 25, wholesale: 520.0,
          barcode: '4796005000444', unit: 'liter'),
      _product('Atlas Exercise Book 200pg', 'Snacks', 120.0, stock: 5, wholesale: 85.0,
          barcode: '4796006000555', unit: 'piece'), // Low stock
      _product('Astra Margarine 250g', 'Dairy', 320.0, stock: 2, wholesale: 240.0,
          barcode: '4796007000666', unit: 'piece'), // Very low stock
      _product('Royal Cashew 200g', 'Snacks', 890.0, stock: 18, wholesale: 680.0,
          barcode: '4796008000777', unit: 'piece'),
    ];
  }

  // ─── PRODUCT HELPERS ───────────────────────────────────────────────────

  static Map<String, dynamic> _product(
    String name,
    String category,
    double price, {
    int stock = 0,
    double wholesale = 0,
    String barcode = '',
    String? batch,
    DateTime? expiry,
    String unit = 'piece',
  }) {
    final now = DateTime.now();
    return {
      'name': name,
      'barcode': barcode,
      'retailPrice': price,
      'wholesalePrice': wholesale,
      'stock': stock,
      'category': category,
      'imagePath': null,
      'profitPercentage': wholesale > 0
          ? ((price - wholesale) / wholesale * 100).roundToDouble()
          : null,
      'modifiers': <Map<String, dynamic>>[],
      'variants': <Map<String, dynamic>>[],
      'expiryDate': expiry?.toIso8601String(),
      'batchNumber': batch,
      'serviceCharge': 0.0,
      'deviceInfo': null,
      'unitType': unit,
      'createdAt': now.subtract(Duration(days: 30 + _rng.nextInt(30))).toIso8601String(),
      'updatedAt': now.subtract(Duration(days: _rng.nextInt(10))).toIso8601String(),
    };
  }

  static Map<String, dynamic> _menuItem(
    String name,
    String category,
    double price, {
    List<Map<String, dynamic>>? modifiers,
    List<Map<String, dynamic>>? variants,
  }) {
    final now = DateTime.now();
    return {
      'name': name,
      'barcode': '',
      'retailPrice': price,
      'wholesalePrice': 0.0,
      'stock': 0,
      'category': category,
      'imagePath': null,
      'profitPercentage': null,
      'modifiers': modifiers ?? <Map<String, dynamic>>[],
      'variants': variants ?? <Map<String, dynamic>>[],
      'expiryDate': null,
      'batchNumber': null,
      'serviceCharge': 0.0,
      'deviceInfo': null,
      'unitType': 'piece',
      'createdAt': now.subtract(Duration(days: 30 + _rng.nextInt(30))).toIso8601String(),
      'updatedAt': now.subtract(Duration(days: _rng.nextInt(10))).toIso8601String(),
    };
  }

  // ─── SALES SEEDER ─────────────────────────────────────────────────────

  static Future<void> _seedSales({
    required String shopId,
    required List<String> productIds,
    required List<Map<String, dynamic>> productData,
    required List<String> customerIds,
    required String businessType,
    required int days,
    required int salesPerDay,
  }) async {
    final now = DateTime.now();
    int invoiceCounter = 1000;
    final paymentMethods = ['cash', 'cash', 'cash', 'credit']; // 75% cash

    for (int d = days; d >= 0; d--) {
      final dayDate = DateTime(now.year, now.month, now.day - d);
      final todaySales = salesPerDay + _rng.nextInt(3) - 1; // ±1 variance

      for (int s = 0; s < todaySales; s++) {
        invoiceCounter++;
        final saleTime = dayDate.add(Duration(
          hours: 8 + _rng.nextInt(12), // 8AM – 8PM
          minutes: _rng.nextInt(60),
        ));

        // Pick 1-4 random products for this sale
        final itemCount = 1 + _rng.nextInt(4);
        final pickedIndices = <int>{};
        while (pickedIndices.length < itemCount &&
            pickedIndices.length < productIds.length) {
          pickedIndices.add(_rng.nextInt(productIds.length));
        }

        double totalAmount = 0;
        final saleItems = <Map<String, dynamic>>[];

        for (final idx in pickedIndices) {
          final prod = productData[idx];
          final qty = 1 + _rng.nextInt(3);
          final price = (prod['retailPrice'] as num).toDouble();
          final discount = _rng.nextInt(5) == 0 ? (price * 0.1).roundToDouble() : 0.0;

          // Restaurant: sometimes include modifiers/variants
          List<Map<String, dynamic>> selectedModifiers = [];
          String? selectedVariant;
          double variantAdj = 0;

          if (businessType == 'restaurant') {
            final mods = prod['modifiers'] as List<dynamic>;
            if (mods.isNotEmpty && _rng.nextBool()) {
              selectedModifiers = [Map<String, dynamic>.from(mods[_rng.nextInt(mods.length)] as Map)];
            }
            final vars = prod['variants'] as List<dynamic>;
            if (vars.isNotEmpty && _rng.nextBool()) {
              final v = Map<String, dynamic>.from(vars[_rng.nextInt(vars.length)] as Map);
              selectedVariant = v['label'] as String;
              variantAdj = (v['price'] as num).toDouble() - price;
            }
          }

          final modTotal = selectedModifiers.fold<double>(
              0, (s, m) => s + ((m['price'] as num?)?.toDouble() ?? 0));
          final lineTotal =
              ((price + variantAdj + modTotal) * qty) - discount;
          totalAmount += lineTotal;

          saleItems.add({
            'saleId': '', // Will be set after sale doc creation
            'productId': productIds[idx],
            'productName': prod['name'] as String,
            'price': price,
            'quantity': qty,
            'discount': discount,
            'selectedModifiers': selectedModifiers,
            'selectedVariant': selectedVariant,
            'variantPriceAdjustment': variantAdj,
            'notes': _rng.nextInt(10) == 0
                ? 'Special request from customer'
                : null,
          });
        }

        final payment = paymentMethods[_rng.nextInt(paymentMethods.length)];
        final hasCustomer = payment == 'credit' || _rng.nextInt(4) == 0;
        final customerId = hasCustomer
            ? customerIds[_rng.nextInt(customerIds.length)]
            : null;

        // Build sale map
        final saleDiscount =
            _rng.nextInt(8) == 0 ? (totalAmount * 0.05).roundToDouble() : 0.0;
        final saleMap = <String, dynamic>{
          'invoiceNumber': 'INV-$invoiceCounter',
          'totalAmount': totalAmount - saleDiscount,
          'discount': saleDiscount,
          'paymentMethod': payment,
          'customerId': customerId,
          'createdAt': saleTime.toIso8601String(),
          'tableNumber': null,
          'orderType': '',
          'jobStatus': '',
          'deviceInfo': null,
          'advanceAmount': 0.0,
        };

        // Business-specific fields
        if (businessType == 'restaurant') {
          final tables = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'];
          final orders = ['dine-in', 'dine-in', 'takeaway', 'delivery'];
          saleMap['tableNumber'] = tables[_rng.nextInt(tables.length)];
          saleMap['orderType'] = orders[_rng.nextInt(orders.length)];
        }

        // Write sale doc
        final saleRef = await _db
            .collection('shops')
            .doc(shopId)
            .collection('sales')
            .add(saleMap);

        // Write sale items
        for (final item in saleItems) {
          item['saleId'] = saleRef.id;
          await saleRef.collection('items').add(item);
        }
      }
    }
  }

  // ─── NOTIFICATIONS ─────────────────────────────────────────────────────

  static Future<void> _seedNotifications(
      String shopId, String businessType, DateTime now) async {
    final notifs = <Map<String, dynamic>>[];

    // Universal: daily summary
    notifs.add({
      'type': 'daily_summary',
      'title': "Yesterday's Sales Summary",
      'body': '12 order(s) totalling Rs. 8,450.',
      'createdAt': now.subtract(const Duration(hours: 6)).toIso8601String(),
      'isRead': false,
    });
    notifs.add({
      'type': 'daily_summary',
      'title': "Yesterday's Sales Summary",
      'body': '9 order(s) totalling Rs. 6,200.',
      'createdAt': now.subtract(const Duration(days: 1, hours: 6)).toIso8601String(),
      'isRead': true,
    });

    if (businessType == 'pharmacy') {
      notifs.addAll([
        {
          'type': 'low_stock',
          'title': 'Low Stock Alert',
          'body': '3 medicine(s) running low, 1 out of stock. Review your inventory.',
          'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
          'isRead': false,
        },
        {
          'type': 'expiring_stock',
          'title': 'Expiring Medicine Alert',
          'body': '2 medicine(s) expiring within 30 days.',
          'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
          'isRead': false,
        },
        {
          'type': 'expired_stock',
          'title': 'Expired Stock Found',
          'body': '1 medicine(s) have already expired. Remove them from your inventory immediately.',
          'createdAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
          'isRead': false,
        },
        {
          'type': 'new_product_reminder',
          'title': 'New Medicine Reminder',
          'body': "Have you received any new medicines this week? Don't forget to add them to your inventory.",
          'createdAt': now.subtract(const Duration(days: 2)).toIso8601String(),
          'isRead': true,
        },
      ]);
    }

    if (businessType == 'retail') {
      notifs.addAll([
        {
          'type': 'low_stock',
          'title': 'Low Stock Alert',
          'body': '2 product(s) running low. Review your inventory.',
          'createdAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
          'isRead': false,
        },
        {
          'type': 'restock_reminder',
          'title': 'Weekly Restock Reminder',
          'body': "It's Monday! Review your inventory and reorder products that are running low.",
          'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
          'isRead': true,
        },
      ]);
    }

    if (businessType == 'restaurant') {
      notifs.addAll([
        {
          'type': 'daily_menu_reminder',
          'title': 'Daily Menu Reminder',
          'body': "Good morning! Have you updated today's specials or marked any unavailable items?",
          'createdAt': now.subtract(const Duration(hours: 4)).toIso8601String(),
          'isRead': false,
        },
        {
          'type': 'daily_menu_reminder',
          'title': 'Daily Menu Reminder',
          'body': "Good morning! Have you updated today's specials or marked any unavailable items?",
          'createdAt': now.subtract(const Duration(days: 1, hours: 4)).toIso8601String(),
          'isRead': true,
        },
      ]);
    }

    // Write them all
    for (final n in notifs) {
      await _db
          .collection('shops')
          .doc(shopId)
          .collection('notifications')
          .add(n);
    }
  }
}
