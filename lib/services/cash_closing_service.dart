import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cash_closing.dart';
import '../models/sale.dart';
import '../utils/helpers.dart';
import 'storage_service.dart';

/// Persistencia de los cierres de caja diarios, namespaceada por kiosco
/// (mismo patrón que StorageService/CategoryService). Un cierre, una vez
/// creado, es prácticamente inmutable: solo se permite anularlo
/// explícitamente para corregir un error, nunca "recalcularlo en silencio".
class CashClosingService {
  static String _key(String kioscoId) => 'cash_closings_$kioscoId';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Future<List<CashClosing>> loadAll(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(kioscoId));
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = json.decode(raw);
      final list = decoded.map((c) => CashClosing.fromJson(c)).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      print('Error cargando cierres de caja: $e');
      return [];
    }
  }

  static Future<bool> _saveAll(String kioscoId, List<CashClosing> closings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(closings.map((c) => c.toJson()).toList());
      return await prefs.setString(_key(kioscoId), raw);
    } catch (e) {
      print('Error guardando cierres de caja: $e');
      return false;
    }
  }

  /// Si ya existe un cierre confirmado para esa fecha (comparando solo
  /// año/mes/día, ignorando la hora), lo devuelve.
  static Future<CashClosing?> getClosingForDay(String kioscoId, DateTime date) async {
    final all = await loadAll(kioscoId);
    final day = _dayOnly(date);
    for (final c in all) {
      if (_dayOnly(c.date) == day) return c;
    }
    return null;
  }

  static Future<bool> isDayClosed(String kioscoId, DateTime date) async {
    return await getClosingForDay(kioscoId, date) != null;
  }

  /// Trae las ventas de un día calendario específico (00:00 a 23:59:59),
  /// para armar el resumen en vivo antes de cerrar, o para mostrar el
  /// detalle de un cierre ya hecho.
  static Future<List<Sale>> salesForDay(String kioscoId, DateTime date) async {
    final allSales = await StorageService.loadSales(kioscoId);
    final day = _dayOnly(date);
    return allSales.where((s) => _dayOnly(s.timestamp) == day).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<DailySummary> getDailySummary(String kioscoId, DateTime date) async {
    final sales = await salesForDay(kioscoId, date);
    return DailySummary(date: _dayOnly(date), sales: sales);
  }

  /// Costo total de las ventas del día: lo necesitamos para la ganancia del
  /// cierre, pero Sale no guarda el costPrice (puede cambiar con el tiempo),
  /// así que se recibe ya calculado desde afuera usando el catálogo actual
  /// de productos. Si el producto fue borrado, simplemente no suma costo
  /// para esa venta (mejor estimar de menos que reventar el cierre).
  static Future<CashClosing> closeDay({
    required String kioscoId,
    required DateTime date,
    required double totalCost,
    String? closedByUserId,
    String? closedByUsername,
    double? cashCounted,
    String? notes,
  }) async {
    final existing = await getClosingForDay(kioscoId, date);
    if (existing != null) {
      throw StateError('El día ${Helpers.formatDate(date)} ya tiene un cierre registrado.');
    }

    final summary = await getDailySummary(kioscoId, date);

    final closing = CashClosing(
      id: '${kioscoId}_${_dayOnly(date).toIso8601String()}',
      kioscoId: kioscoId,
      date: _dayOnly(date),
      closedAt: DateTime.now(),
      closedByUserId: closedByUserId,
      closedByUsername: closedByUsername,
      totalSales: summary.totalSales,
      totalRevenue: summary.totalRevenue,
      totalCost: totalCost,
      totalProfit: summary.totalRevenue - totalCost,
      totalDiscountGiven: summary.totalDiscountGiven,
      totalsByPaymentMethod: summary.totalsByPaymentMethod,
      salesCountByPaymentMethod: summary.salesCountByPaymentMethod,
      cashCounted: cashCounted,
      notes: notes,
      saleIds: summary.sales.map((s) => s.id).toList(),
    );

    final all = await loadAll(kioscoId);
    all.add(closing);
    await _saveAll(kioscoId, all);
    return closing;
  }

  /// Anula un cierre ya hecho (por ejemplo, si se cerró por error). No
  /// borra las ventas, solo libera la fecha para que se pueda volver a
  /// cerrar más tarde con los números correctos.
  static Future<bool> deleteClosing(String kioscoId, String closingId) async {
    final all = await loadAll(kioscoId);
    all.removeWhere((c) => c.id == closingId);
    return await _saveAll(kioscoId, all);
  }
}
