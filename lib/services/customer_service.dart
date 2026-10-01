import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';

/// Maneja los clientes y el sistema de fiado (cuenta corriente) de cada
/// kiosco. Mismo patrón de namespacing por kioscoId que StorageService y
/// CategoryService, para que los datos de un kiosco nunca se mezclen con
/// los de otro en el mismo dispositivo.
class CustomerService {
  static String _customersKey(String kioscoId) => 'customers_$kioscoId';
  static String _transactionsKey(String kioscoId) => 'customer_txns_$kioscoId';

  // --- Clientes ---

  static Future<List<Customer>> loadAll(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customersKey(kioscoId));
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((c) => Customer.fromJson(c)).toList();
    } catch (e) {
      print('Error cargando clientes: $e');
      return [];
    }
  }

  static Future<bool> _saveAll(String kioscoId, List<Customer> customers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(customers.map((c) => c.toJson()).toList());
      return await prefs.setString(_customersKey(kioscoId), raw);
    } catch (e) {
      print('Error guardando clientes: $e');
      return false;
    }
  }

  static Future<Customer> add(
    String kioscoId, {
    required String name,
    String phone = '',
    String email = '',
    double creditLimit = 0.0,
    String notes = '',
  }) async {
    final customers = await loadAll(kioscoId);
    final customer = Customer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      creditLimit: creditLimit,
      notes: notes.trim(),
    );
    customers.add(customer);
    await _saveAll(kioscoId, customers);
    return customer;
  }

  static Future<bool> update(String kioscoId, Customer updated) async {
    final customers = await loadAll(kioscoId);
    final index = customers.indexWhere((c) => c.id == updated.id);
    if (index == -1) return false;
    customers[index] = updated;
    return await _saveAll(kioscoId, customers);
  }

  static Future<bool> remove(String kioscoId, String customerId) async {
    final customers = await loadAll(kioscoId);
    customers.removeWhere((c) => c.id == customerId);
    final removed = await _saveAll(kioscoId, customers);

    final txns = await _loadTransactions(kioscoId);
    txns.removeWhere((t) => t.customerId == customerId);
    await _saveTransactions(kioscoId, txns);

    return removed;
  }

  // --- Transacciones de cuenta corriente ---

  static Future<List<CustomerTransaction>> _loadTransactions(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_transactionsKey(kioscoId));
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((t) => CustomerTransaction.fromJson(t)).toList();
    } catch (e) {
      print('Error cargando movimientos de clientes: $e');
      return [];
    }
  }

  static Future<bool> _saveTransactions(
    String kioscoId,
    List<CustomerTransaction> txns,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(txns.map((t) => t.toJson()).toList());
      return await prefs.setString(_transactionsKey(kioscoId), raw);
    } catch (e) {
      print('Error guardando movimientos de clientes: $e');
      return false;
    }
  }

  /// Historial de movimientos de un cliente, más reciente primero.
  static Future<List<CustomerTransaction>> historyFor(
    String kioscoId,
    String customerId,
  ) async {
    final txns = await _loadTransactions(kioscoId);
    final filtered = txns.where((t) => t.customerId == customerId).toList();
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  /// Registra una venta fiada: suma [amount] a la deuda del cliente y deja
  /// constancia del movimiento. Devuelve el cliente actualizado, o null si
  /// no se encontró.
  static Future<Customer?> registerFiado(
    String kioscoId, {
    required String customerId,
    required double amount,
    String? saleId,
    String note = '',
  }) async {
    final customers = await loadAll(kioscoId);
    final index = customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return null;

    final customer = customers[index];
    customer.creditBalance += amount;
    customer.totalPurchases += amount;
    customer.purchaseCount += 1;
    customer.lastPurchase = DateTime.now();
    await _saveAll(kioscoId, customers);

    final txns = await _loadTransactions(kioscoId);
    txns.add(CustomerTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: customerId,
      type: CustomerTransactionType.fiado,
      amount: amount,
      saleId: saleId,
      note: note,
    ));
    await _saveTransactions(kioscoId, txns);

    return customer;
  }

  /// Registra un pago/cobro: resta [amount] de la deuda del cliente
  /// (nunca queda en negativo) y deja constancia del movimiento.
  static Future<Customer?> registerPayment(
    String kioscoId, {
    required String customerId,
    required double amount,
    String note = '',
  }) async {
    final customers = await loadAll(kioscoId);
    final index = customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return null;

    final customer = customers[index];
    customer.creditBalance = (customer.creditBalance - amount).clamp(0, double.infinity);
    await _saveAll(kioscoId, customers);

    final txns = await _loadTransactions(kioscoId);
    txns.add(CustomerTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerId: customerId,
      type: CustomerTransactionType.pago,
      amount: amount,
      note: note,
    ));
    await _saveTransactions(kioscoId, txns);

    return customer;
  }

  /// Deuda total fiada entre todos los clientes del kiosco.
  static Future<double> totalDebt(String kioscoId) async {
    final customers = await loadAll(kioscoId);
    return customers.fold<double>(0, (sum, c) => sum + c.creditBalance);
  }
}
