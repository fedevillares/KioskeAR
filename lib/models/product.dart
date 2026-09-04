class Product {
  String id;
  String name;
  String category;
  int stock;
  double price;
  double costPrice;
  int minStock;
  String? barcode;
  String? imagePath;
  DateTime createdAt;
  DateTime? lastUpdated;

  // --- Modo oferta / descuento ---
  // Un producto puede tener un porcentaje de descuento activo, con fecha
  // de vencimiento opcional. Si discountExpiresAt es null, la oferta no
  // vence sola y queda activa hasta que se desactive manualmente.
  double? discountPercent; // 0-100
  DateTime? discountExpiresAt;

  // Fecha de vencimiento del producto (opcional). Relevante para lácteos,
  // fiambres, golosinas y bebidas, donde vender stock vencido es un riesgo
  // real para el kiosco, no solo una pérdida de plata.
  DateTime? expirationDate;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.stock,
    required this.price,
    this.costPrice = 0,
    this.minStock = 5,
    this.barcode,
    this.imagePath,
    DateTime? createdAt,
    this.lastUpdated,
    this.discountPercent,
    this.discountExpiresAt,
    this.expirationDate,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isLowStock => stock <= minStock;
  bool get isOutOfStock => stock == 0;
  double get totalValue => stock * price;
  double get profit => price - costPrice;
  double get profitMargin => costPrice > 0 ? ((price - costPrice) / costPrice) * 100 : 0;
  double get totalProfit => stock * profit;

  /// Días que faltan para vencer (negativo si ya venció). Null si el
  /// producto no tiene fecha de vencimiento configurada.
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expDate = DateTime(expirationDate!.year, expirationDate!.month, expirationDate!.day);
    return expDate.difference(todayDate).inDays;
  }

  bool get isExpired {
    final days = daysUntilExpiration;
    return days != null && days < 0;
  }

  /// Vence dentro de los próximos [withinDays] días (por defecto 7),
  /// incluyendo lo que ya venció.
  bool isExpiringSoon({int withinDays = 7}) {
    final days = daysUntilExpiration;
    if (days == null) return false;
    return days <= withinDays;
  }

  /// Si hay un % de descuento configurado y, en caso de tener vencimiento,
  /// todavía no pasó, la oferta está activa.
  bool get hasActiveDiscount {
    if (discountPercent == null || discountPercent! <= 0) return false;
    if (discountExpiresAt != null && DateTime.now().isAfter(discountExpiresAt!)) {
      return false;
    }
    return true;
  }

  /// Precio final a cobrar, ya con el descuento aplicado si corresponde.
  double get discountedPrice {
    if (!hasActiveDiscount) return price;
    return price * (1 - discountPercent! / 100);
  }

  double get discountAmount => hasActiveDiscount ? price - discountedPrice : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'stock': stock,
    'price': price,
    'costPrice': costPrice,
    'minStock': minStock,
    'barcode': barcode,
    'imagePath': imagePath,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated?.toIso8601String(),
    'discountPercent': discountPercent,
    'discountExpiresAt': discountExpiresAt?.toIso8601String(),
    'expirationDate': expirationDate?.toIso8601String(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    category: json['category'],
    stock: json['stock'],
    price: (json['price'] as num).toDouble(),
    costPrice: json['costPrice'] != null ? (json['costPrice'] as num).toDouble() : 0,
    minStock: json['minStock'] ?? 5,
    barcode: json['barcode'],
    imagePath: json['imagePath'],
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    lastUpdated: json['lastUpdated'] != null
        ? DateTime.parse(json['lastUpdated'])
        : null,
    discountPercent: json['discountPercent'] != null
        ? (json['discountPercent'] as num).toDouble()
        : null,
    discountExpiresAt: json['discountExpiresAt'] != null
        ? DateTime.parse(json['discountExpiresAt'])
        : null,
    expirationDate: json['expirationDate'] != null
        ? DateTime.parse(json['expirationDate'])
        : null,
  );

  Product copyWith({
    String? id,
    String? name,
    String? category,
    int? stock,
    double? price,
    double? costPrice,
    int? minStock,
    String? barcode,
    String? imagePath,
    DateTime? createdAt,
    DateTime? lastUpdated,
    double? discountPercent,
    bool clearDiscount = false,
    DateTime? discountExpiresAt,
    bool clearDiscountExpiry = false,
    DateTime? expirationDate,
    bool clearExpirationDate = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      stock: stock ?? this.stock,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      minStock: minStock ?? this.minStock,
      barcode: barcode ?? this.barcode,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      discountPercent: clearDiscount ? null : (discountPercent ?? this.discountPercent),
      discountExpiresAt: clearDiscountExpiry ? null : (discountExpiresAt ?? this.discountExpiresAt),
      expirationDate: clearExpirationDate ? null : (expirationDate ?? this.expirationDate),
    );
  }
}
