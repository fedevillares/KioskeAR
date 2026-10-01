import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/permission.dart';
import '../models/product.dart';
import '../services/storage_service.dart';
import '../services/category_service.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/add_product_dialog.dart';
import '../widgets/glass_container.dart';
import 'barcode_scanner_page.dart';

enum _SortBy { name, stockAsc, stockDesc, value }

/// Pestaña "Inventario": listado completo de productos en formato tabla,
/// pensado para gestión rápida (editar, eliminar, ordenar, buscar por
/// código de barras) más que para venta. Vive dentro del AppShell.
class InventoryTab extends StatefulWidget {
  const InventoryTab({Key? key}) : super(key: key);

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> with AutomaticKeepAliveClientMixin {
  List<Product> _products = [];
  List<String> _categories = AppConstants.categories;
  Map<String, String> _categoryEmojis = {};
  bool _isLoading = true;
  _SortBy _sortBy = _SortBy.name;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? get _kioscoId => context.read<SessionProvider>().kioscoId;

  Future<void> _load() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    setState(() => _isLoading = true);
    final products = await StorageService.loadProducts(kioscoId);
    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
    }
  }

  List<Product> get _visibleProducts {
    final q = _query.trim().toLowerCase();
    var list = _products.where((p) {
      if (q.isEmpty) return true;
      final matchesName = p.name.toLowerCase().contains(q);
      final matchesBarcode = (p.barcode ?? '').toLowerCase().contains(q);
      return matchesName || matchesBarcode;
    }).toList();
    switch (_sortBy) {
      case _SortBy.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case _SortBy.stockAsc:
        list.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case _SortBy.stockDesc:
        list.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case _SortBy.value:
        list.sort((a, b) => b.totalValue.compareTo(a.totalValue));
        break;
    }
    return list;
  }

  Future<void> _saveProducts() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    await StorageService.saveProducts(kioscoId, _products);
  }

  void _editProduct(Product product) {
    final session = context.read<SessionProvider>();
    if (!session.hasPermission(Permission.gestionarInventario)) {
      _denyPermission('No tenés permiso para editar productos. Pedile a un administrador que te lo habilite.');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        product: product,
        existingProducts: _products,
        categories: _categories,
        categoryEmojis: _categoryEmojis,
        onSave: (newProduct) {
          setState(() {
            final index = _products.indexWhere((p) => p.id == product.id);
            if (index != -1) _products[index] = newProduct;
          });
          _saveProducts();
        },
      ),
    );
  }

  void _addProduct({String? initialBarcode}) {
    final session = context.read<SessionProvider>();
    if (!session.hasPermission(Permission.gestionarInventario)) {
      _denyPermission('No tenés permiso para agregar productos. Pedile a un administrador que te lo habilite.');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        initialBarcode: initialBarcode,
        existingProducts: _products,
        categories: _categories,
        categoryEmojis: _categoryEmojis,
        onSave: (newProduct) {
          setState(() => _products.add(newProduct));
          _saveProducts();
        },
      ),
    );
  }

  void _denyPermission(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.errorColor,
      ),
    );
  }

  void _deleteProduct(Product product) {
    final session = context.read<SessionProvider>();
    if (!session.hasPermission(Permission.eliminarVentas)) {
      _denyPermission('No tenés permiso para eliminar productos. Pedile a un administrador que te lo habilite.');
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${product.name}" del inventario?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppConstants.errorColor),
            onPressed: () {
              setState(() => _products.removeWhere((p) => p.id == product.id));
              _saveProducts();
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  /// Abre la cámara para escanear y usa el resultado como filtro de
  /// búsqueda. Si ningún producto tiene ese código, ofrece crear uno nuevo
  /// directamente con el código ya completado.
  Future<void> _scanToSearch() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    if (code == null || code.isEmpty || !mounted) return;

    final match = _products.where((p) => p.barcode == code).toList();
    if (match.isNotEmpty) {
      setState(() {
        _query = code;
        _searchController.text = code;
      });
      _showSnackBar('✓ Encontrado: ${match.first.name}');
    } else {
      _showNotFoundDialog(code);
    }
  }

  void _showNotFoundDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Código no encontrado'),
        content: Text('Ningún producto tiene el código "$code". ¿Querés crear uno nuevo con este código?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _addProduct(initialBarcode: code);
            },
            child: const Text('Crear producto'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final products = _visibleProducts;
    final totalValue = _products.fold<double>(0, (sum, p) => sum + p.totalValue);
    final offersCount = _products.where((p) => p.hasActiveDiscount).length;

    // Altura real de la barra de navegación glass de AppShell (ver
    // _GlassBottomBar en app_shell.dart): icono 22 + spacing 3 + texto ~14
    // + padding vertical del item 20 + padding del GlassContainer 16 = 75,
    // más el margen exterior (12 arriba incluido en el Padding fromLTRB,
    // 12 abajo) y el inset de gestos/home-indicator del dispositivo, que
    // varía por equipo y por eso se lee de MediaQuery en vez de fijarlo.
    // AppShell usa extendBody: true, así que InventoryTab (al no tener su
    // propia bottomNavigationBar) ocupa toda la pantalla por detrás de esa
    // barra glass, y el FAB necesita este margen para no quedar tapado.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final navBarHeight = 75 + 12 + 12 + bottomInset;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: navBarHeight),
        child: FloatingActionButton.extended(
          onPressed: () => _addProduct(),
          backgroundColor: AppConstants.primaryColor,
          icon: const Icon(Icons.add),
          label: const Text('Producto'),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Inventario', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: AppConstants.primaryColor),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.payments, size: 18, color: AppConstants.successColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Valor en stock', style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
                                Text(Helpers.formatPrice(totalValue),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.successColor, fontSize: 15)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (offersCount > 0) ...[
                    const SizedBox(width: 8),
                    GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, size: 18, color: AppConstants.warningColor),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('En oferta', style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
                              Text('$offersCount',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.warningColor, fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassContainer(
                borderRadius: BorderRadius.circular(14),
                blur: 12,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código...',
                    prefixIcon: const Icon(Icons.search, color: AppConstants.primaryColor),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: AppConstants.primaryColor),
                      tooltip: 'Buscar por código de barras',
                      onPressed: _scanToSearch,
                    ),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _SortChip(label: 'Nombre', selected: _sortBy == _SortBy.name, onTap: () => setState(() => _sortBy = _SortBy.name)),
                  const SizedBox(width: 8),
                  _SortChip(label: 'Stock ↑', selected: _sortBy == _SortBy.stockAsc, onTap: () => setState(() => _sortBy = _SortBy.stockAsc)),
                  const SizedBox(width: 8),
                  _SortChip(label: 'Stock ↓', selected: _sortBy == _SortBy.stockDesc, onTap: () => setState(() => _sortBy = _SortBy.stockDesc)),
                  const SizedBox(width: 8),
                  _SortChip(label: 'Valor', selected: _sortBy == _SortBy.value, onTap: () => setState(() => _sortBy = _SortBy.value)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? _EmptyState(hasQuery: _query.isNotEmpty, onAdd: () => _addProduct())
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ProductRow(
                                product: p,
                                onEdit: () => _editProduct(p),
                                onDelete: () => _deleteProduct(p),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRow({required this.product, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final statusColor = p.isOutOfStock
        ? AppConstants.errorColor
        : p.isLowStock
            ? AppConstants.warningColor
            : AppConstants.successColor;

    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      blur: 10,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppConstants.getCategoryColor(p.category).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppConstants.getCategoryIcon(p.category),
                    color: AppConstants.getCategoryColor(p.category)),
              ),
              if (p.hasActiveDiscount)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppConstants.warningColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_offer, size: 11, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (p.hasActiveDiscount) ...[
                      Text(Helpers.formatPrice(p.price),
                          style: TextStyle(fontSize: 12, color: context.colors.textTertiary, decoration: TextDecoration.lineThrough)),
                      const SizedBox(width: 6),
                      Text(Helpers.formatPrice(p.discountedPrice),
                          style: const TextStyle(fontSize: 12, color: AppConstants.warningColor, fontWeight: FontWeight.bold)),
                    ] else
                      Text(Helpers.formatPrice(p.price), style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                    Text(' · ${p.category}', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
                if (p.barcode != null && p.barcode!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.qr_code, size: 11, color: context.colors.textTertiary),
                      const SizedBox(width: 3),
                      Text(p.barcode!, style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
                    ],
                  ),
                ],
                if (p.isExpiringSoon()) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        p.isExpired ? Icons.event_busy : Icons.schedule,
                        size: 11,
                        color: p.isExpired ? AppConstants.errorColor : AppConstants.warningColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        p.isExpired
                            ? 'Vencido'
                            : 'Vence en ${p.daysUntilExpiration} día${p.daysUntilExpiration == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.isExpired ? AppConstants.errorColor : AppConstants.warningColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${p.stock}',
                style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final VoidCallback onAdd;

  const _EmptyState({required this.hasQuery, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.inventory_2_outlined,
              size: 56,
              color: context.colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'Sin resultados' : 'Tu inventario está vacío',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Probá buscar por otro nombre o escaneá el código de barras.'
                  : 'Agregá tu primer producto para empezar a controlar tu stock.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Agregar producto'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: AppConstants.fastAnimation,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppConstants.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppConstants.primaryColor : Colors.grey.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.colors.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
