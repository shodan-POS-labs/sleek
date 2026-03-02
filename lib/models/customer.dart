class Customer {
  final String? id;
  final String name;
  final String phone;
  final double balance;
  final String? lastPurchase;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.balance = 0,
    this.lastPurchase,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'balance': balance,
      'lastPurchase': lastPurchase,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      balance: (map['balance'] as num).toDouble(),
      lastPurchase: map['lastPurchase'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    double? balance,
    String? lastPurchase,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      balance: balance ?? this.balance,
      lastPurchase: lastPurchase ?? this.lastPurchase,
      createdAt: createdAt,
    );
  }
}
