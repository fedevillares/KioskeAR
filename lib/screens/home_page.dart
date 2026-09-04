import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/product_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/metric_card.dart';
import '../widgets/glass_container.dart';
import '../providers/cart_provider.dart';
import '../providers/session_provider.dart';
import 'cart_page.dart';

/// Pestaña "Inicio": resumen rápido, búsqueda y listado de productos.
/// Vive dentro del AppShell (IndexedStack), por lo que no define su propio
/// Scaffold con barra de navegación: la barra inferior la provee el shell.
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = AppConstants.categories;
  Map<String, String> _categoryEmojis = {};
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  bool _isLoading = true;
  int _lowStockCount = 0;
  int _outOfStockCount = 0;
  int _expiringCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
  }

  String? get _kioscoId => context.read<SessionProvider>().kioscoId;

  /// Saludo cálido según la hora, con el nombre del usuario si está
  /// disponible. Reemplaza el subtítulo fijo "Gestión de Stock": darle
  /// algo de identidad al header es parte de lo que hace que la app se
  /// sienta terminada en vez de una plantilla genérica.
  String _greeting() {
    final hour = DateTime.now().hour;
    final momento = hour < 12 ? 'Buen día' : (hour < 20 ? 'Buenas tardes' : 'Buenas noches');
    final user = context.read<SessionProvider>().currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : user?.usuario;
    return name != null && name.isNotEmpty ? '$momento, $name' : momento;
  }

  Future<void> _loadCategories() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    final categories = await CategoryService.loadAll(kioscoId);
    final emojis = await CategoryService.loadEmojis(kioscoId);
    if (mounted) {
      setState(() {
        _categories = categories;
        _categoryEmojis = emojis;
      });
    }
  }

  /// Emojis sugeridos para categorías de kiosco. El usuario puede elegir
  /// uno o dejarla sin emoji (usa el ícono Material genérico).
  static const List<String> _emojiOptions = [
    '🥤', '🍫', '🍪', '🍿', '🚬', '📚', '🛍️', '🍞', '🥛', '🧃',
    '🍬', '🍩', '🧴', '🧻', '🔋', '💊', '🧊', '🍺', '🥫', '🧀',
  ];

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    String? selectedEmoji;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nueva categoría'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Ej: Lácteos',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Emoji (opcional)',
                  style: TextStyle(fontSize: 13, color: dialogContext.colors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojiOptions.map((emoji) {
                    final isPicked = selectedEmoji == emoji;
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        selectedEmoji = isPicked ? null : emoji;
                      }),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isPicked ? AppConstants.primaryColor.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPicked ? AppConstants.primaryColor : dialogContext.colors.divider,
                            width: isPicked ? 2 : 1,
                          ),
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final kioscoId = _kioscoId;
                if (kioscoId == null) return;
                final added = await CategoryService.add(kioscoId, controller.text, emoji: selectedEmoji);
                if (!mounted) return;
                Navigator.pop(dialogContext);
                if (added) {
                  await _loadCategories();
                  _showSnackBar('✓ Categoría agregada');
                } else {
                  _showSnackBar('Esa categoría ya existe o no es válida', isError: true);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Eliminar "$category"? Los productos que ya la tienen asignada no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final kioscoId = _kioscoId;
              if (kioscoId == null) return;
              await CategoryService.remove(kioscoId, category);
              if (!mounted) return;
              Navigator.pop(context);
              if (_selectedCategory == category) {
                setState(() {
                  _selectedCategory = 'Todos';
                  _filterProducts();
                });
              }
              await _loadCategories();
              _showSnackBar('✓ Categoría eliminada');
            },
            style: FilledButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProducts() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    setState(() => _isLoading = true);
    final products = await StorageService.loadProducts(kioscoId);
    if (mounted) {
      setState(() {
        _allProducts = products;
        _filterProducts();
        _updateStockAlerts();
        _isLoading = false;
      });
    }
  }

  void _updateStockAlerts() {
    _lowStockCount = _allProducts.where((p) => p.isLowStock && !p.isOutOfStock).length;
    _outOfStockCount = _allProducts.where((p) => p.isOutOfStock).length;
    _expiringCount = _allProducts.where((p) => p.isExpiringSoon()).length;
  }

  void _filterProducts() {
    _filteredProducts = _allProducts.where((product) {
      final matchesCategory = _selectedCategory == 'Todos' || product.category == _selectedCategory;
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _saveProducts() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    await StorageService.saveProducts(kioscoId, _allProducts);
  }

  void _updateStock(Product product, int change) {
    final index = _allProducts.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      setState(() {
        _allProducts[index].stock += change;
        if (_allProducts[index].stock < 0) _allProducts[index].stock = 0;
        _allProducts[index].lastUpdated = DateTime.now();
        _filterProducts();
        _updateStockAlerts();
      });
      _saveProducts();

      if (change < 0) {
        _registerSale(product, change.abs());
      }
    }
  }

  Future<void> _registerSale(Product product, int quantity) async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    final user = context.read<SessionProvider>().currentUser;
    final effectivePrice = product.hasActiveDiscount ? product.discountedPrice : product.price;
    final sale = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      pricePerUnit: effectivePrice,
      totalPrice: effectivePrice * quantity,
      timestamp: DateTime.now(),
      soldByUserId: user?.uid,
      soldByUsername: user?.usuario,
      originalPricePerUnit: product.hasActiveDiscount ? product.price : null,
    );
    await StorageService.registerSale(kioscoId, sale);
  }

  void _showQuickSaleDialog(Product product) {
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.point_of_sale, color: AppConstants.successColor),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Venta Rápida')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Precio: \$${product.price.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, color: context.colors.textSecondary)),
            Text('Stock: ${product.stock}', style: TextStyle(fontSize: 14, color: context.colors.textTertiary)),
            const SizedBox(height: 20),
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.shopping_cart),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0 && quantity <= product.stock) {
                _updateStock(product, -quantity);
                Navigator.pop(context);
                _showSnackBar('✓ Venta: ${product.name} x$quantity');
              } else {
                _showSnackBar('Cantidad inválida', isError: true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppConstants.successColor),
            icon: const Icon(Icons.check),
            label: const Text('Vender'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog([Product? product]) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        product: product,
        existingProducts: _allProducts,
        categories: _categories,
        categoryEmojis: _categoryEmojis,
        onSave: (newProduct) {
          setState(() {
            if (product != null) {
              final index = _allProducts.indexWhere((p) => p.id == product.id);
              if (index != -1) _allProducts[index] = newProduct;
            } else {
              _allProducts.add(newProduct);
            }
            _filterProducts();
            _updateStockAlerts();
          });
          _saveProducts();
          _showSnackBar(product != null ? '✓ Producto actualizado' : '✓ Producto agregado');
        },
      ),
    );
  }

  void _deleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppConstants.errorColor),
            SizedBox(width: 12),
            Text('Eliminar producto'),
          ],
        ),
        content: Text('¿Estás seguro de eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _allProducts.removeWhere((p) => p.id == product.id);
                _filterProducts();
                _updateStockAlerts();
              });
              _saveProducts();
              Navigator.pop(context);
              _showSnackBar('✓ ${product.name} eliminado');
            },
            style: FilledButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showProductOptions(Product product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: context.colors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: AppConstants.primaryColor),
              title: const Text('Agregar al carrito'),
              onTap: () {
                Navigator.pop(context);
                Provider.of<CartProvider>(context, listen: false).addToCart(product);
                _showSnackBar('✓ ${product.name} agregado al carrito');
              },
            ),
            ListTile(
              leading: const Icon(Icons.point_of_sale, color: AppConstants.successColor),
              title: const Text('Venta rápida'),
              onTap: () {
                Navigator.pop(context);
                _showQuickSaleDialog(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppConstants.primaryColor),
              title: const Text('Editar'),
              onTap: () {
                Navigator.pop(context);
                _showAddProductDialog(product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppConstants.errorColor),
              title: const Text('Eliminar'),
              onTap: () {
                Navigator.pop(context);
                _deleteProduct(product);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                  ).createShader(bounds),
                  child: const Text(
                    'Kioske.AR',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              // Notificaciones
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: AppConstants.primaryColor),
                    onPressed: () {
                      if (_lowStockCount > 0 || _outOfStockCount > 0 || _expiringCount > 0) {
                        showDialog(
                          context: context,
                          builder: (context) => _StockAlertsDialog(
                            products: _allProducts.where((p) => p.isLowStock).toList(),
                            expiringProducts: _allProducts.where((p) => p.isExpiringSoon()).toList(),
                          ),
                        );
                      }
                    },
                  ),
                  if (_lowStockCount > 0 || _outOfStockCount > 0 || _expiringCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppConstants.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${_lowStockCount + _outOfStockCount + _expiringCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              // Carrito
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined, color: AppConstants.primaryColor),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CartPage(products: _allProducts)),
                      );
                      if (result == true) _loadProducts();
                    },
                  ),
                  if (cartProvider.itemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppConstants.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${cartProvider.itemCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Compensa la altura real del AppBar: como extendBodyBehindAppBar
                // es true (para que el blur se vea sobre el fondo glass), el body
                // arranca en y=0 y SafeArea solo cubre el status bar/notch, no el
                // AppBar en sí. Sin este espacio, las métricas, el buscador y la
                // cinta de categorías quedan tapados detrás del título "Kioske.AR".
                SizedBox(height: kToolbarHeight + 8),

                // Tarjeta de métricas superior (glass)
                GlassContainer(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      MetricCard(
                        icon: Icons.inventory_2,
                        label: 'Total Productos',
                        value: '${_allProducts.length}',
                      ),
                      MetricCard(
                        icon: Icons.warning_amber_rounded,
                        label: 'Stock Bajo',
                        value: '$_lowStockCount',
                        isWarning: true,
                      ),
                      MetricCard(
                        icon: Icons.event_busy,
                        label: 'Por vencer',
                        value: '$_expiringCount',
                        isWarning: _expiringCount > 0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Búsqueda mejorada (glass)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    blur: 12,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
                        prefixIcon: const Icon(Icons.search, color: AppConstants.primaryColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() {
                                  _searchQuery = '';
                                  _filterProducts();
                                }),
                              )
                            : null,
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) => setState(() {
                        _searchQuery = value;
                        _filterProducts();
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Filtros por categoría (base del kiosco + personalizadas).
                // El chip "+" al final permite crear categorías propias;
                // mantener presionado un chip personalizado la elimina.
                SizedBox(
                  height: 45,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == _categories.length) {
                        return ActionChip(
                          avatar: const Icon(Icons.add, size: 18, color: AppConstants.primaryColor),
                          label: const Text('Categoría'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: context.colors.divider, width: 1.5),
                          ),
                          backgroundColor: Colors.transparent,
                          onPressed: _showAddCategoryDialog,
                        );
                      }

                      final category = _categories[index];
                      return GestureDetector(
                        onLongPress: CategoryService.isCustom(category)
                            ? () => _confirmDeleteCategory(category)
                            : null,
                        child: CategoryChip(
                          category: category,
                          isSelected: _selectedCategory == category,
                          emoji: _categoryEmojis[category],
                          onTap: () => setState(() {
                            _selectedCategory = category;
                            _filterProducts();
                          }),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de productos
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: context.colors.textTertiary),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'No se encontraron productos' : 'No hay productos',
                                    style: TextStyle(
                                        fontSize: 16, color: context.colors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Agregá tu primer producto desde la pestaña Inventario',
                                      style: TextStyle(fontSize: 13, color: context.colors.textTertiary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                              itemCount: _filteredProducts.length,
                              cacheExtent: 1000,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                return RepaintBoundary(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ProductCard(
                                      key: ValueKey(product.id),
                                      product: product,
                                      onTap: () => _showProductOptions(product),
                                      onStockChange: (change) => _updateStock(product, change),
                                      onAddToCart: () {
                                        Provider.of<CartProvider>(context, listen: false).addToCart(product);
                                        _showSnackBar('✓ ${product.name} agregado al carrito');
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          // El botón de agregar producto vive en la pestaña Inventario
          // (gestión real de productos), no en Inicio.
        );
      },
    );
  }
}

class _StockAlertsDialog extends StatelessWidget {
  final List<Product> products;
  final List<Product> expiringProducts;

  const _StockAlertsDialog({required this.products, this.expiringProducts = const []});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber, color: AppConstants.warningColor),
          SizedBox(width: 12),
          Text('Alertas'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (products.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textSecondary)),
              ),
              ...products.map((product) => ListTile(
                    dense: true,
                    leading: Icon(
                      product.isOutOfStock ? Icons.error : Icons.warning,
                      color: product.isOutOfStock ? AppConstants.errorColor : AppConstants.warningColor,
                    ),
                    title: Text(product.name),
                    subtitle: Text(product.isOutOfStock ? 'AGOTADO' : 'Stock: ${product.stock} (mín: ${product.minStock})'),
                    trailing: product.isOutOfStock
                        ? null
                        : Text('${product.stock}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
            ],
            if (expiringProducts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text('Vencimientos', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textSecondary)),
              ),
              ...expiringProducts.map((product) {
                final days = product.daysUntilExpiration ?? 0;
                final expired = days < 0;
                return ListTile(
                  dense: true,
                  leading: Icon(
                    expired ? Icons.event_busy : Icons.schedule,
                    color: expired ? AppConstants.errorColor : AppConstants.warningColor,
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    expired
                        ? 'Vencido el ${Helpers.formatDate(product.expirationDate!)}'
                        : 'Vence en $days día${days == 1 ? '' : 's'} (${Helpers.formatDate(product.expirationDate!)})',
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
