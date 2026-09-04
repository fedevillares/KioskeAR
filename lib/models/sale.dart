/// Medio de pago de una venta, usado para el cierre de caja diario
/// (necesitamos saber cuánto entró en efectivo vs. digital para que el
/// arqueo de caja tenga sentido).
enum PaymentMethod { efectivo, tarjeta, mercadoPago, transferencia, fiado, otro }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.efectivo:
        return 'Efectivo';
      case PaymentMethod.tarjeta:
        return 'Tarjeta';
      case PaymentMethod.mercadoPago:
        return 'Mercado Pago';
      case PaymentMethod.transferencia:
        return 'Transferencia';
      case PaymentMethod.fiado:
        return 'Fiado';
      case PaymentMethod.otro:
        return 'Otro';
    }
  }

  static PaymentMethod fromName(String? name) {
    return PaymentMethod.values.firstWhere(
      (m) => m.name == name,
      orElse: () => PaymentMethod.efectivo,
    );
  }
}

class Sale {
  String id;
  String productId;
  String productName;
  int quantity;
  double pricePerUnit;
  double totalPrice;
  DateTime timestamp;
  // Quién hizo la venta y con qué medio de pago: necesario para el cierre
  // de caja diario (Fase 5) y para que la auditoría sepa "quién" además de
  // "qué" — antes una venta no quedaba atada a ningún usuario.
  String? soldByUserId;
  String? soldByUsername;
  PaymentMethod paymentMethod;
  // Si la venta se hizo con el producto en oferta, registramos el precio
  // original para que los reportes puedan mostrar cuánto se "regaló" en
  // descuentos sin tener que ir a buscar el historial del producto.
  double? originalPricePerUnit;
  // Si la venta se hizo fiada, queda atada al cliente para poder ver el
  // historial de fiado de cada uno desde su ficha.
  String? customerId;
  String? customerName;

  Sale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    required this.timestamp,
    this.soldByUserId,
    this.soldByUsername,
    this.paymentMethod = PaymentMethod.efectivo,
    this.originalPricePerUnit,
    this.customerId,
    this.customerName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        'totalPrice': totalPrice,
        'timestamp': timestamp.toIso8601String(),
        'soldByUserId': soldByUserId,
        'soldByUsername': soldByUsername,
        'paymentMethod': paymentMethod.name,
        'originalPricePerUnit': originalPricePerUnit,
        'customerId': customerId,
        'customerName': customerName,
      };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'],
        productId: json['productId'],
        productName: json['productName'],
        quantity: json['quantity'],
        pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
        totalPrice: (json['totalPrice'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        soldByUserId: json['soldByUserId'],
        soldByUsername: json['soldByUsername'],
        paymentMethod: PaymentMethodLabel.fromName(json['paymentMethod']),
        originalPricePerUnit: json['originalPricePerUnit'] != null
            ? (json['originalPricePerUnit'] as num).toDouble()
            : null,
        customerId: json['customerId'],
        customerName: json['customerName'],
      );
}