class CartItem {
  final int productId;
  final String name;
  final double price;
  int quantity;
  final int stock;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.stock,
  });

  double get total => price * quantity;
}
