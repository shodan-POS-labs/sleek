class Product {
  final String? id;
  final String name;
  final String barcode;
  final double retailPrice;
  final double wholesalePrice;
  final double stock;
  final String category;
  final String? imagePath;
  final double? profitPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Restaurant fields ──
  final List<Map<String, dynamic>> modifiers;   // [{name: "Extra Cheese", price: 150}]
  final List<Map<String, dynamic>> variants;    // [{label: "Large", price: 800}]

  // ── Pharmacy fields ──
  final DateTime? expiryDate;
  final String? batchNumber;

  // ── Repair fields ──
  final double serviceCharge;
  final String? deviceInfo;    // IMEI / Serial number

  // ── Retail fields ──
  final String unitType;       // "piece", "kg", "liter", "meter"
  final bool isWeighable;
  final double weightQuantity;

  Product({
    this.id,
    required this.name,
    this.barcode = '',
    required this.retailPrice,
    this.wholesalePrice = 0,
    this.stock = 0.0,
    required this.category,
    this.imagePath,
    this.profitPercentage,
    this.modifiers = const [],
    this.variants = const [],
    this.expiryDate,
    this.batchNumber,
    this.serviceCharge = 0,
    this.deviceInfo,
    this.unitType = 'piece',
    this.isWeighable = false,
    this.weightQuantity = 1.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'retailPrice': retailPrice,
      'wholesalePrice': wholesalePrice,
      'stock': stock,
      'category': category,
      'imagePath': imagePath,
      'profitPercentage': profitPercentage,
      'modifiers': modifiers,
      'variants': variants,
      'expiryDate': expiryDate?.toIso8601String(),
      'batchNumber': batchNumber,
      'serviceCharge': serviceCharge,
      'deviceInfo': deviceInfo,
      'unitType': unitType,
      'isWeighable': isWeighable,
      'weightQuantity': weightQuantity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String?,
      name: map['name'] as String,
      barcode: (map['barcode'] as String?) ?? '',
      retailPrice: (map['retailPrice'] as num).toDouble(),
      wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble() ?? 0,
      stock: (map['stock'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String,
      imagePath: map['imagePath'] as String?,
      profitPercentage: (map['profitPercentage'] as num?)?.toDouble(),
      modifiers: (map['modifiers'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      variants: (map['variants'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [],
      expiryDate: map['expiryDate'] != null ? DateTime.parse(map['expiryDate'] as String) : null,
      batchNumber: map['batchNumber'] as String?,
      serviceCharge: (map['serviceCharge'] as num?)?.toDouble() ?? 0,
      deviceInfo: map['deviceInfo'] as String?,
      unitType: (map['unitType'] as String?) ?? 'piece',
      isWeighable: (map['isWeighable'] as bool?) ?? false,
      weightQuantity: (map['weightQuantity'] as num?)?.toDouble() ?? 1.0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : DateTime.now(),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : DateTime.now(),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? retailPrice,
    double? wholesalePrice,
    double? stock,
    String? category,
    String? imagePath,
    double? profitPercentage,
    List<Map<String, dynamic>>? modifiers,
    List<Map<String, dynamic>>? variants,
    DateTime? expiryDate,
    String? batchNumber,
    double? serviceCharge,
    String? deviceInfo,
    String? unitType,
    bool? isWeighable,
    double? weightQuantity,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      retailPrice: retailPrice ?? this.retailPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      profitPercentage: profitPercentage ?? this.profitPercentage,
      modifiers: modifiers ?? this.modifiers,
      variants: variants ?? this.variants,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
      serviceCharge: serviceCharge ?? this.serviceCharge,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      unitType: unitType ?? this.unitType,
      isWeighable: isWeighable ?? this.isWeighable,
      weightQuantity: weightQuantity ?? this.weightQuantity,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
