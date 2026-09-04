import 'sale.dart';

/// Snapshot de un cierre de caja diario: una vez que el kiosquero confirma
/// el cierre, estos números quedan congelados (no se recalculan después,
/// aunque se sigan cargando ventas viejas o se edite algo retroactivamente)
/// para que el cierre sea un registro contable confiable, no un valor
/// "vivo" que cambia solo.
class CashClosing {
  String id;
  String kioscoId;
  // Fecha del día que se cierra (medianoche local), no el instante en que
  // se hizo el cierre — permite cerrar "ayer" si alguien se olvidó.
  DateTime date;
  DateTime closedAt;
  String? closedByUserId;
  String? closedByUsername;

  int totalSales;
  double totalRevenue;
  double totalCost;
  double totalProfit;
  double totalDiscountGiven;

  // Desglose por medio de pago: clave = PaymentMethod.name
  Map<String, double> totalsByPaymentMethod;
  Map<String, int> salesCountByPaymentMethod;

  // Efectivo esperado en caja según lo vendido en efectivo, vs. lo que el
  // kiosquero contó físicamente al cerrar. La diferencia (sobrante/faltante)
  // es el dato más útil de un arqueo de caja real.
  double? cashCounted;
  String? notes;

  List<String> saleIds;

  CashClosing({
    required this.id,
    required this.kioscoId,
    required this.date,
    required this.closedAt,
    this.closedByUserId,
    this.closedByUsername,
    required this.totalSales,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.totalDiscountGiven,
    required this.totalsByPaymentMethod,
    required this.salesCountByPaymentMethod,
    this.cashCounted,
    this.notes,
    required this.saleIds,
  });

  double get cashExpected => totalsByPaymentMethod[PaymentMethod.efectivo.name] ?? 0;

  /// Diferencia entre lo contado físicamente y lo que debería haber según
  /// las ventas en efectivo. Positivo = sobrante, negativo = faltante.
  double? get cashDifference => cashCounted == null ? null : cashCounted! - cashExpected;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kioscoId': kioscoId,
        'date': date.toIso8601String(),
        'closedAt': closedAt.toIso8601String(),
        'closedByUserId': closedByUserId,
        'closedByUsername': closedByUsername,
        'totalSales': totalSales,
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'totalProfit': totalProfit,
        'totalDiscountGiven': totalDiscountGiven,
        'totalsByPaymentMethod': totalsByPaymentMethod,
        'salesCountByPaymentMethod': salesCountByPaymentMethod,
        'cashCounted': cashCounted,
        'notes': notes,
        'saleIds': saleIds,
      };

  factory CashClosing.fromJson(Map<String, dynamic> json) => CashClosing(
        id: json['id'],
        kioscoId: json['kioscoId'],
        date: DateTime.parse(json['date']),
        closedAt: DateTime.parse(json['closedAt']),
        closedByUserId: json['closedByUserId'],
        closedByUsername: json['closedByUsername'],
        totalSales: json['totalSales'] ?? 0,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0,
        totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
        totalDiscountGiven: (json['totalDiscountGiven'] as num?)?.toDouble() ?? 0,
        totalsByPaymentMethod: Map<String, double>.from(
          (json['totalsByPaymentMethod'] as Map?)?.map(
                (k, v) => MapEntry(k as String, (v as num).toDouble()),
              ) ??
              {},
        ),
        salesCountByPaymentMethod: Map<String, int>.from(
          (json['salesCountByPaymentMethod'] as Map?)?.map(
                (k, v) => MapEntry(k as String, v as int),
              ) ??
              {},
        ),
        cashCounted: (json['cashCounted'] as num?)?.toDouble(),
        notes: json['notes'],
        saleIds: List<String>.from(json['saleIds'] ?? []),
      );
}

/// Resumen "en vivo" (no cerrado todavía) de un día, calculado al vuelo a
/// partir de las ventas. Se usa para mostrar el día actual antes de
/// confirmarlo, y comparte forma con CashClosing pero sin persistir nada.
class DailySummary {
  final DateTime date;
  final List<Sale> sales;

  DailySummary({required this.date, required this.sales});

  int get totalSales => sales.length;
  double get totalRevenue => sales.fold(0.0, (sum, s) => sum + s.totalPrice);
  double get totalDiscountGiven => sales.fold(0.0, (sum, s) {
        if (s.originalPricePerUnit == null) return sum;
        return sum + ((s.originalPricePerUnit! - s.pricePerUnit) * s.quantity);
      });

  Map<String, double> get totalsByPaymentMethod {
    final map = <String, double>{};
    for (final s in sales) {
      map[s.paymentMethod.name] = (map[s.paymentMethod.name] ?? 0) + s.totalPrice;
    }
    return map;
  }

  Map<String, int> get salesCountByPaymentMethod {
    final map = <String, int>{};
    for (final s in sales) {
      map[s.paymentMethod.name] = (map[s.paymentMethod.name] ?? 0) + 1;
    }
    return map;
  }

  double get cashExpected => totalsByPaymentMethod[PaymentMethod.efectivo.name] ?? 0;
}
