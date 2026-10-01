import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart_item.dart';
import '../models/product.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];
  bool _isLoading = false;

  List<CartItem> get items => _items;
  int get itemCount => _items.length;
  double get total => _items.fold(0, (sum, item) => sum + item.total);
  bool get isLoading => _isLoading;

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      _isLoading = true;
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');

      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> decoded = json.decode(cartJson);
        _items.clear();
        _items.addAll(decoded.map((item) => CartItem.fromJson(item)).toList());
        print('✓ Carrito cargado: ${_items.length} items');
      }
    } catch (e) {
      print('Error cargando carrito: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = json.encode(_items.map((item) => item.toJson()).toList());
      await prefs.setString('cart_items', cartJson);
      print('✓ Carrito guardado: ${_items.length} items');
    } catch (e) {
      print('Error guardando carrito: $e');
    }
  }

  void addToCart(Product product) {
    final existingIndex = _items.indexWhere((item) => item.productId == product.id);

    if (existingIndex >= 0) {
      final currentQuantity = _items[existingIndex].quantity;
      if (currentQuantity < product.stock) {
        _items[existingIndex].quantity++;
        _saveCart();
        notifyListeners();
      }
    } else {
      if (product.stock > 0) {
        _items.add(CartItem(
          productId: product.id,
          productName: product.name,
          price: product.price,
          quantity: 1,
        ));
        _saveCart();
        notifyListeners();
      }
    }
  }

  void removeFromCart(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(String productId, int change) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      _items[index].quantity += change;
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      _saveCart();
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _items.clear();
    await _saveCart();
    notifyListeners();
  }

  bool hasProduct(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  int getProductQuantity(String productId) {
    final item = _items.firstWhere(
      (item) => item.productId == productId,
      orElse: () => CartItem(productId: '', productName: '', price: 0, quantity: 0),
    );
    return item.quantity;
  }
}
