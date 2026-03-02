/// Business Config Engine
/// Maps each BusinessType to a set of feature flags that drive the UI.

enum BusinessType {
  retail,
  restaurant,
  repairShop,
  pharmacy,
}

class BusinessConfig {
  final BusinessType type;
  final String label;
  final String emoji;
  final String salesItemLabel;    // "Product", "Menu Item", "Service", "Medicine"
  final String addItemLabel;      // "Add Product", "Add Menu Item", etc.
  final String salesScreenTitle;  // "New Sale", "New Order", "New Job", etc.
  final String itemNameHint;      // Placeholder for item name field
  final String categoryHint;      // Placeholder for category field
  final String searchHint;        // Placeholder for search bar

  // Feature flags
  final bool hasBarcode;
  final bool hasModifiers;          // Restaurant: toppings, extras
  final bool hasVariants;           // Restaurant: size (S/M/L)
  final bool hasTableManagement;
  final bool hasDineInTakeaway;
  final bool hasJobCards;           // Repair: job status tracking
  final bool hasDeviceTracking;     // Repair: IMEI / Serial
  final bool hasServiceCharge;
  final bool hasAdvancePayment;
  final bool hasExpiryTracking;     // Pharmacy: expiry dates
  final bool hasBatchTracking;      // Pharmacy: batch numbers
  final bool hasWholesalePrice;
  final bool hasWeightBasedPricing; // Retail: kg, liter
  final bool hasStockManagement;

  const BusinessConfig({
    required this.type,
    required this.label,
    required this.emoji,
    required this.salesItemLabel,
    required this.addItemLabel,
    required this.salesScreenTitle,
    required this.itemNameHint,
    required this.categoryHint,
    required this.searchHint,
    this.hasBarcode = false,
    this.hasModifiers = false,
    this.hasVariants = false,
    this.hasTableManagement = false,
    this.hasDineInTakeaway = false,
    this.hasJobCards = false,
    this.hasDeviceTracking = false,
    this.hasServiceCharge = false,
    this.hasAdvancePayment = false,
    this.hasExpiryTracking = false,
    this.hasBatchTracking = false,
    this.hasWholesalePrice = false,
    this.hasWeightBasedPricing = false,
    this.hasStockManagement = true,
  });

  /// Factory: get config for a given type
  static BusinessConfig forType(BusinessType type) {
    switch (type) {
      case BusinessType.retail:
        return _retail;
      case BusinessType.restaurant:
        return _restaurant;
      case BusinessType.repairShop:
        return _repairShop;
      case BusinessType.pharmacy:
        return _pharmacy;
    }
  }

  /// Parse from Firestore string, defaults to retail
  static BusinessType parseType(String? value) {
    switch (value) {
      case 'restaurant':
        return BusinessType.restaurant;
      case 'repairShop':
        return BusinessType.repairShop;
      case 'pharmacy':
        return BusinessType.pharmacy;
      default:
        return BusinessType.retail;
    }
  }

  /// All available types (for the setup screen selector)
  static List<BusinessConfig> get allTypes => [
    _retail,
    _restaurant,
    _repairShop,
    _pharmacy,
  ];

  // ─── Predefined Configs ──────────────────────────────────

  static const _retail = BusinessConfig(
    type: BusinessType.retail,
    label: 'Retail / Grocery',
    emoji: '🛒',
    salesItemLabel: 'Product',
    addItemLabel: 'Add Product',
    salesScreenTitle: 'New Sale',
    itemNameHint: 'e.g. Coca-Cola 500ml',
    categoryHint: 'e.g. Beverages, Dairy, Snacks',
    searchHint: 'Search products...',
    hasBarcode: true,
    hasWholesalePrice: true,
    hasWeightBasedPricing: true,
    hasStockManagement: true,
  );

  static const _restaurant = BusinessConfig(
    type: BusinessType.restaurant,
    label: 'Restaurant / Café',
    emoji: '🍕',
    salesItemLabel: 'Menu Item',
    addItemLabel: 'Add Menu Item',
    salesScreenTitle: 'New Order',
    itemNameHint: 'e.g. Margherita Pizza',
    categoryHint: 'e.g. Pizza, Drinks, Starters',
    searchHint: 'Search menu items...',
    hasModifiers: true,
    hasVariants: true,
    hasTableManagement: true,
    hasDineInTakeaway: true,
    hasStockManagement: false, // Restaurants track ingredients, not item stock
  );

  static const _repairShop = BusinessConfig(
    type: BusinessType.repairShop,
    label: 'Repair Shop',
    emoji: '🔧',
    salesItemLabel: 'Service',
    addItemLabel: 'Add Service',
    salesScreenTitle: 'New Job Card',
    itemNameHint: 'e.g. Screen Replacement',
    categoryHint: 'e.g. Mobile, Laptop, Accessories',
    searchHint: 'Search services...',
    hasJobCards: true,
    hasDeviceTracking: true,
    hasServiceCharge: true,
    hasAdvancePayment: true,
    hasStockManagement: false,
  );

  static const _pharmacy = BusinessConfig(
    type: BusinessType.pharmacy,
    label: 'Pharmacy',
    emoji: '💊',
    salesItemLabel: 'Medicine',
    addItemLabel: 'Add Medicine',
    salesScreenTitle: 'New Sale',
    itemNameHint: 'e.g. Paracetamol 500mg',
    categoryHint: 'e.g. Antibiotics, Vitamins, OTC',
    searchHint: 'Search medicines...',
    hasBarcode: true,
    hasExpiryTracking: true,
    hasBatchTracking: true,
    hasWholesalePrice: true,
    hasStockManagement: true,
  );
}
