import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/sale.dart';

/// SEGURIDAD: productos y ventas se guardan en SharedPreferences con clave
/// namespaceada por kioscoId (mismo patrón que CategoryService). Antes las
/// claves eran fijas ('products', 'sales'), así que si alguna vez dos
/// kioscos compartían el mismo dispositivo físico (o se reusaba el
/// dispositivo para un kiosco distinto sin desinstalar la app), el stock y
/// las ventas de uno se mezclaban o pisaban con las del otro — un riesgo
/// real de integridad de datos, no solo cosmético.
///
/// Todas las llamadas ahora requieren kioscoId explícito. Esto es una
/// breaking change intencional: preferimos que el compilador detecte cada
/// lugar que faltaba namespacear, en vez de namespacear "a medias" y dejar
/// agujeros silenciosos.
class StorageService {
  static String _productsKey(String kioscoId) => 'products_$kioscoId';
  static String _salesKey(String kioscoId) => 'sales_$kioscoId';
  static const int _maxSalesHistory = 5000;

  static Future<bool> saveProducts(String kioscoId, List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = json.encode(
        products.map((p) => p.toJson()).toList(),
      );
      return await prefs.setString(_productsKey(kioscoId), productsJson);
    } catch (e) {
      print('Error guardando productos: $e');
      return false;
    }
  }

  static Future<List<Product>> loadProducts(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = prefs.getString(_productsKey(kioscoId));

      if (productsJson != null && productsJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(productsJson);
        return decoded.map((p) => Product.fromJson(p)).toList();
      }

      // Migración desde la clave vieja sin namespacear (instalaciones
      // previas a este cambio), para no perder datos existentes.
      final legacyJson = prefs.getString('products');
      if (legacyJson != null && legacyJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(legacyJson);
        final migrated = decoded.map((p) => Product.fromJson(p)).toList();
        await saveProducts(kioscoId, migrated);
        await prefs.remove('products');
        return migrated;
      }

      // Solo el primer kiosco que arranca sin datos recibe el catálogo de
      // ejemplo, para no contaminar instalaciones nuevas vacías a propósito.
      return [];
    } catch (e) {
      print('Error cargando productos: $e');
      return [];
    }
  }

  static Future<bool> saveSales(String kioscoId, List<Sale> sales) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final limitedSales = sales.length > _maxSalesHistory
          ? sales.sublist(sales.length - _maxSalesHistory)
          : sales;

      final salesJson = json.encode(
        limitedSales.map((s) => s.toJson()).toList(),
      );
      return await prefs.setString(_salesKey(kioscoId), salesJson);
    } catch (e) {
      print('Error guardando ventas: $e');
      return false;
    }
  }

  static Future<List<Sale>> loadSales(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salesJson = prefs.getString(_salesKey(kioscoId));

      if (salesJson != null && salesJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(salesJson);
        return decoded.map((s) => Sale.fromJson(s)).toList();
      }

      // Migración desde la clave vieja.
      final legacyJson = prefs.getString('sales');
      if (legacyJson != null && legacyJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(legacyJson);
        final migrated = decoded.map((s) => Sale.fromJson(s)).toList();
        await saveSales(kioscoId, migrated);
        await prefs.remove('sales');
        return migrated;
      }

      return [];
    } catch (e) {
      print('Error cargando ventas: $e');
      return [];
    }
  }

  static Future<bool> registerSale(String kioscoId, Sale sale) async {
    try {
      final sales = await loadSales(kioscoId);
      sales.add(sale);
      return await saveSales(kioscoId, sales);
    } catch (e) {
      print('Error registrando venta: $e');
      return false;
    }
  }

  static Future<bool> clearKioscoData(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_productsKey(kioscoId));
      await prefs.remove(_salesKey(kioscoId));
      return true;
    } catch (e) {
      print('Error limpiando datos: $e');
      return false;
    }
  }

  static Future<String> exportData(String kioscoId) async {
    try {
      final products = await loadProducts(kioscoId);
      final sales = await loadSales(kioscoId);
      return json.encode({
        'kioscoId': kioscoId,
        'products': products.map((p) => p.toJson()).toList(),
        'sales': sales.map((s) => s.toJson()).toList(),
        'exportDate': DateTime.now().toIso8601String(),
        'version': '2.0.0',
      });
    } catch (e) {
      print('Error exportando datos: $e');
      return '{}';
    }
  }

  /// Catálogo de ejemplo, solo para que el usuario lo cargue manualmente
  /// desde Ajustes si quiere arrancar con datos de muestra (no se aplica
  /// automáticamente para no contaminar kioscos nuevos).
  static List<Product> getSampleProducts() {
    return [
      Product(id: '1', name: 'Coca Cola 500ml', category: 'Bebidas', stock: 24, price: 500, costPrice: 300, minStock: 10),
      Product(id: '2', name: 'Agua Mineral 1L', category: 'Bebidas', stock: 18, price: 300, costPrice: 180, minStock: 10),
      Product(id: '3', name: 'Fanta 500ml', category: 'Bebidas', stock: 15, price: 500, costPrice: 300, minStock: 10),
      Product(id: '4', name: 'Chocolatina', category: 'Golosinas', stock: 45, price: 200, costPrice: 120, minStock: 20),
      Product(id: '5', name: 'Caramelos', category: 'Golosinas', stock: 60, price: 50, costPrice: 30, minStock: 30),
      Product(id: '6', name: 'Chicles', category: 'Golosinas', stock: 40, price: 100, costPrice: 60, minStock: 20),
      Product(id: '7', name: 'Papas Fritas', category: 'Snacks', stock: 12, price: 350, costPrice: 200, minStock: 8),
      Product(id: '8', name: 'Palitos Salados', category: 'Snacks', stock: 20, price: 250, costPrice: 150, minStock: 10),
      Product(id: '9', name: 'Marlboro Box', category: 'Cigarrillos', stock: 8, price: 1200, costPrice: 900, minStock: 5),
      Product(id: '10', name: 'Lucky Strike', category: 'Cigarrillos', stock: 6, price: 1100, costPrice: 850, minStock: 5),
      Product(id: '11', name: 'Lapicera BIC', category: 'Librería', stock: 30, price: 150, costPrice: 80, minStock: 15),
      Product(id: '12', name: 'Cuaderno Éxito', category: 'Librería', stock: 10, price: 800, costPrice: 500, minStock: 5),
    ];
  }
}
