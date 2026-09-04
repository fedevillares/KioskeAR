import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

/// Sincroniza productos en la nube, separados por kiosco (empresa).
/// Todos los dispositivos vinculados al mismo kioscoId comparten stock.
class FirestoreService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _productsRef(String kioscoId) =>
      _db.collection('kioscos').doc(kioscoId).collection('products');

  Future<void> saveProduct(String kioscoId, Product product) {
    return _productsRef(kioscoId).doc(product.id).set(product.toJson());
  }

  Future<void> deleteProduct(String kioscoId, String productId) {
    return _productsRef(kioscoId).doc(productId).delete();
  }

  Stream<List<Product>> watchProducts(String kioscoId) {
    return _productsRef(kioscoId).snapshots().map(
          (s) => s.docs.map((d) => Product.fromJson(d.data())).toList(),
        );
  }

  Future<List<Product>> loadProducts(String kioscoId) async {
    final snap = await _productsRef(kioscoId).get();
    return snap.docs.map((d) => Product.fromJson(d.data())).toList();
  }
}
