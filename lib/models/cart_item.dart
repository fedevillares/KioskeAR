class CartItem {
  String productId;
  String productName;
  double price;
  int quantity;
  int? discountPercent;
  String? notes;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.discountPercent,
    this.notes,
  });

  double get subtotal => price * quantity;

  double get priceWithDiscount {
    if (discountPercent == null || discountPercent == 0) return price;
    return price * (1 - (discountPercent! / 100));
  }

  double get total => priceWithDiscount * quantity;
  double get savedAmount => (price * quantity) - total;

  void applyDiscount(int percent) {
    if (percent > 0 && percent <= 100) {
      discountPercent = percent;
    }
  }

  String getFormattedPrice() => '\$${price.toStringAsFixed(2)}';
  String getFormattedTotal() => '\$${total.toStringAsFixed(2)}';
  String getFormattedDiscount() => discountPercent != null ? '-${discountPercent}%' : 'Sin descuento';

  String getDescription() {
    String desc = '$productName x$quantity';
    if (discountPercent != null && discountPercent! > 0) desc += ' (${getFormattedDiscount()})';
    if (notes != null && notes!.isNotEmpty) desc += ' - $notes';
    return desc;
  }

  void incrementQuantity() => quantity++;

  void decrementQuantity() {
    if (quantity > 0) quantity--;
  }

  bool isValid() => productId.isNotEmpty && productName.isNotEmpty && price >= 0 && quantity > 0;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'price': price,
    'quantity': quantity,
    'discountPercent': discountPercent,
    'notes': notes,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['productId'],
    productName: json['productName'],
    price: (json['price'] as num).toDouble(),
    quantity: json['quantity'],
    discountPercent: json['discountPercent'],
    notes: json['notes'],
  );

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is CartItem && runtimeType == other.runtimeType && productId == other.productId;

  @override
  int get hashCode => productId.hashCode;
}
