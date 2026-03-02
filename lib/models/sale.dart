class Sale {
  final String? id;
  final String invoiceNumber;
  final double totalAmount;
  final double discount;
  final String paymentMethod; // 'cash', 'credit', 'advance'
  final String? customerId;
  final DateTime createdAt;
  final List<SaleItem> items;

  // ── Restaurant fields ──
  final String? tableNumber;
  final String orderType; // 'dine-in', 'takeaway', 'delivery', ''

  // ── Repair fields ──
  final String jobStatus;   // 'pending', 'in-progress', 'done', ''
  final String? deviceInfo; // IMEI / serial for this job
  final double advanceAmount;

  Sale({
    this.id,
    required this.invoiceNumber,
    required this.totalAmount,
    this.discount = 0,
    required this.paymentMethod,
    this.customerId,
    DateTime? createdAt,
    this.items = const [],
    this.tableNumber,
    this.orderType = '',
    this.jobStatus = '',
    this.deviceInfo,
    this.advanceAmount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'totalAmount': totalAmount,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'createdAt': createdAt.toIso8601String(),
      'tableNumber': tableNumber,
      'orderType': orderType,
      'jobStatus': jobStatus,
      'deviceInfo': deviceInfo,
      'advanceAmount': advanceAmount,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String?,
      invoiceNumber: map['invoiceNumber'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod'] as String,
      customerId: map['customerId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      tableNumber: map['tableNumber'] as String?,
      orderType: (map['orderType'] as String?) ?? '',
      jobStatus: (map['jobStatus'] as String?) ?? '',
      deviceInfo: map['deviceInfo'] as String?,
      advanceAmount: (map['advanceAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SaleItem {
  final String? id;
  final String saleId;
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double discount;

  // ── Restaurant: selected modifiers & variant for this cart line ──
  final List<Map<String, dynamic>> selectedModifiers; // [{name, price}]
  final String? selectedVariant;        // e.g. "Large"
  final double variantPriceAdjustment;  // extra cost from variant
  final String? notes;                  // special instructions

  SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.discount = 0,
    this.selectedModifiers = const [],
    this.selectedVariant,
    this.variantPriceAdjustment = 0,
    this.notes,
  });

  double get modifierTotal => selectedModifiers.fold(0.0, (s, m) => s + ((m['price'] as num?)?.toDouble() ?? 0));
  double get total => ((price + variantPriceAdjustment + modifierTotal) * quantity) - discount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'discount': discount,
      'selectedModifiers': selectedModifiers,
      'selectedVariant': selectedVariant,
      'variantPriceAdjustment': variantPriceAdjustment,
      'notes': notes,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String?,
      saleId: map['saleId'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      selectedModifiers: (map['selectedModifiers'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      selectedVariant: map['selectedVariant'] as String?,
      variantPriceAdjustment: (map['variantPriceAdjustment'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
    );
  }
}
