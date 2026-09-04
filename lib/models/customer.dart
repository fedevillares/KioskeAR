/// Cliente del kiosco, usado principalmente para el sistema de fiado
/// (cuenta corriente): se le puede vender sin cobrar al momento y queda
/// un saldo pendiente (`creditBalance`) que se cobra después.
class Customer {
  final String id;
  String name;
  String phone;
  String email;
  double creditBalance; // Saldo que el cliente debe (fiado)
  double creditLimit; // 0 = sin límite definido
  double totalPurchases;
  int purchaseCount;
  DateTime createdAt;
  DateTime lastPurchase;
  String notes;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.creditBalance = 0.0,
    this.creditLimit = 0.0,
    this.totalPurchases = 0.0,
    this.purchaseCount = 0,
    DateTime? createdAt,
    DateTime? lastPurchase,
    this.notes = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        lastPurchase = lastPurchase ?? DateTime.now();

  /// Si tiene un límite definido (> 0) y sumar [amount] lo superaría.
  bool wouldExceedLimit(double amount) {
    if (creditLimit <= 0) return false;
    return (creditBalance + amount) > creditLimit;
  }

  bool get hasDebt => creditBalance > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'creditBalance': creditBalance,
        'creditLimit': creditLimit,
        'totalPurchases': totalPurchases,
        'purchaseCount': purchaseCount,
        'createdAt': createdAt.toIso8601String(),
        'lastPurchase': lastPurchase.toIso8601String(),
        'notes': notes,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'],
        name: json['name'],
        phone: json['phone'] ?? '',
        email: json['email'] ?? '',
        creditBalance: (json['creditBalance'] ?? 0).toDouble(),
        creditLimit: (json['creditLimit'] ?? 0).toDouble(),
        totalPurchases: (json['totalPurchases'] ?? 0).toDouble(),
        purchaseCount: json['purchaseCount'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
        lastPurchase: DateTime.parse(json['lastPurchase']),
        notes: json['notes'] ?? '',
      );
}

/// Un movimiento en la cuenta corriente de un cliente: o bien una venta
/// fiada (suma deuda) o un pago/cobro (resta deuda).
enum CustomerTransactionType { fiado, pago }

class CustomerTransaction {
  final String id;
  final String customerId;
  final CustomerTransactionType type;
  final double amount;
  final DateTime timestamp;
  final String? saleId; // si el movimiento vino de una venta fiada
  final String note;

  CustomerTransaction({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    DateTime? timestamp,
    this.saleId,
    this.note = '',
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'type': type.name,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
        'saleId': saleId,
        'note': note,
      };

  factory CustomerTransaction.fromJson(Map<String, dynamic> json) =>
      CustomerTransaction(
        id: json['id'],
        customerId: json['customerId'],
        type: CustomerTransactionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => CustomerTransactionType.fiado,
        ),
        amount: (json['amount'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp']),
        saleId: json['saleId'],
        note: json['note'] ?? '',
      );
}
