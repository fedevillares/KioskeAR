import 'package:intl/intl.dart';

class Helpers {
  static String formatPrice(double price) {
    final formatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  static double getStockPercentage(int current, int min) {
    if (min == 0) return 100;
    return (current / (min * 3)) * 100;
  }

  static String getStockStatusMessage(int current, int min) {
    if (current == 0) return 'Agotado';
    if (current <= min) return 'Stock bajo';
    if (current <= min * 2) return 'Stock moderado';
    return 'Stock bueno';
  }

  static String? validateProductName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre es requerido';
    }
    if (value.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }
    return null;
  }

  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'El precio es requerido';
    }
    final price = double.tryParse(value);
    if (price == null || price <= 0) {
      return 'Ingrese un precio válido';
    }
    return null;
  }

  static String? validateCostPrice(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final cost = double.tryParse(value.trim());
    if (cost == null || cost < 0) {
      return 'Ingrese un costo válido';
    }
    return null;
  }

  static String? validateStock(String? value) {
    if (value == null || value.isEmpty) {
      return 'El stock es requerido';
    }
    final stock = int.tryParse(value);
    if (stock == null || stock < 0) {
      return 'Ingrese un stock válido';
    }
    return null;
  }

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}