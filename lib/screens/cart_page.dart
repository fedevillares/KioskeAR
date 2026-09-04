import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../services/storage_service.dart';
import '../services/mercadopago_service.dart';
import '../services/category_service.dart';
import '../services/customer_service.dart';
import '../providers/cart_provider.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';
import 'mercadopago_qr_page.dart';
import 'barcode_scanner_page.dart';
import '../widgets/add_product_dialog.dart';

class CartPage extends StatefulWidget {
  final List<Product> products;
  final Product? initialProduct;

  const CartPage({
    Key? key,
    required this.products,
    this.initialProduct,
  }) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Product> _filteredProducts = [];
  List<String> _categories = AppConstants.categories;
  Map<String, String> _categoryEmojis = {};

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products.where((p) => p.stock > 0).toList();
    _loadCategories();

    // Agregar producto inicial si existe
    if (widget.initialProduct != null && widget.initialProduct!.stock > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<CartProvider>(context, listen: false).addToCart(widget.initialProduct!);
      });
    }
  }

  Future<void> _loadCategories() async {
    final kioscoId = context.read<SessionProvider>().kioscoId;
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

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = widget.products
          .where((p) => p.stock > 0 && p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );

    if (code == null || code.isEmpty || !mounted) return;

    final match = widget.products.where((p) => p.barcode == code).toList();

    if (match.isEmpty) {
      _offerToCreateProduct(code);
      return;
    }

    final product = match.first;
    if (product.stock <= 0) {
      _showMessage('${product.name} no tiene stock disponible', isError: true);
      return;
    }

    Provider.of<CartProvider>(context, listen: false).addToCart(product);
    _showMessage('✓ ${product.name} agregado');
  }

  void _offerToCreateProduct(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Producto no encontrado'),
        content: Text('No hay ningún producto con el código $code. ¿Querés crearlo ahora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _createProductWithBarcode(code);
            },
            child: const Text('Crear producto'),
          ),
        ],
      ),
    );
  }

  void _createProductWithBarcode(String code) {
    showDialog(
      context: context,
      builder: (context) => AddProductDialog(
        initialBarcode: code,
        existingProducts: widget.products,
        categories: _categories,
        categoryEmojis: _categoryEmojis,
        onSave: (product) async {
          final kioscoId = context.read<SessionProvider>().kioscoId;
          widget.products.add(product);
          if (kioscoId != null) await StorageService.saveProducts(kioscoId, widget.products);
          if (mounted) {
            setState(() {
              _filteredProducts = widget.products.where((p) => p.stock > 0).toList();
            });
            _showMessage('✓ ${product.name} creado');
          }
        },
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppConstants.errorColor : AppConstants.successColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _processPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    if (cartProvider.items.isEmpty) {
      _showMessage('El carrito está vacío', isError: true);
      return;
    }

    // Validar stock
    for (var item in cartProvider.items) {
      final product = widget.products.firstWhere((p) => p.id == item.productId);
      if (product.stock < item.quantity) {
        _showMessage('Stock insuficiente para ${item.productName}', isError: true);
        return;
      }
    }

    final mpEnabled = await MercadoPagoService.isEnabled();
    
    final paymentMethod = await showDialog<String>(
      context: context,
      builder: (context) => _PaymentMethodDialog(mpEnabled: mpEnabled),
    );

    if (paymentMethod == null) return;

    if (paymentMethod == 'cash') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _CashPaymentDialog(total: cartProvider.total),
      );
      if (confirmed == true) {
        await _completeSale(paymentMethod: PaymentMethod.efectivo);
      }
    } else if (paymentMethod == 'mercadopago') {
      await _processMercadoPagoPayment();
    } else if (paymentMethod == 'fiado') {
      await _processFiadoPayment();
    }
  }

  Future<void> _processFiadoPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final kioscoId = context.read<SessionProvider>().kioscoId;
    if (kioscoId == null) return;

    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => _SelectCustomerDialog(kioscoId: kioscoId, amount: cartProvider.total),
    );
    if (customer == null || !mounted) return;

    await _completeSale(paymentMethod: PaymentMethod.fiado, customer: customer);
  }

  Future<void> _processMercadoPagoPayment() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final result = await MercadoPagoService.createPaymentQR(
      items: cartProvider.items,
      total: cartProvider.total,
    );

    if (mounted) Navigator.pop(context);

    if (result == null) {
      _showMessage('Error al generar código QR. Verifica tu configuración.', isError: true);
      return;
    }

    if (mounted) {
      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => MercadoPagoQRPage(
            qrData: result['qr_data'],
            total: cartProvider.total,
            preferenceId: result['preference_id'],
          ),
        ),
      );

      if (paid == true) {
        await _completeSale(paymentMethod: PaymentMethod.mercadoPago);
      }
    }
  }

  Future<void> _completeSale({
    PaymentMethod paymentMethod = PaymentMethod.efectivo,
    Customer? customer,
  }) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final session = context.read<SessionProvider>();
    final kioscoId = session.kioscoId;
    if (kioscoId == null) return;
    final user = session.currentUser;
    final now = DateTime.now();
    final saleIds = <String>[];

    for (var item in cartProvider.items) {
      final product = widget.products.firstWhere((p) => p.id == item.productId);
      product.stock -= item.quantity;
      product.lastUpdated = now;

      final saleId = '${now.millisecondsSinceEpoch}_${item.productId}';
      final sale = Sale(
        id: saleId,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        pricePerUnit: item.price,
        totalPrice: item.total,
        timestamp: now,
        soldByUserId: user?.uid,
        soldByUsername: user?.usuario,
        paymentMethod: paymentMethod,
        originalPricePerUnit: product.hasActiveDiscount ? product.price : null,
        customerId: customer?.id,
        customerName: customer?.name,
      );
      await StorageService.registerSale(kioscoId, sale);
      saleIds.add(saleId);
    }

    await StorageService.saveProducts(kioscoId, widget.products);

    if (paymentMethod == PaymentMethod.fiado && customer != null) {
      await CustomerService.registerFiado(
        kioscoId,
        customerId: customer.id,
        amount: cartProvider.total,
        saleId: saleIds.isNotEmpty ? saleIds.first : null,
      );
    }

    if (mounted) {
      _showMessage('✓ Venta completada: ${Helpers.formatPrice(cartProvider.total)}');
      cartProvider.clearCart();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return GlassBackground(
          child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Carrito de Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (cartProvider.items.isNotEmpty)
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart),
                      onPressed: () {},
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppConstants.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${cartProvider.itemCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              if (cartProvider.items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () {
                    cartProvider.clearCart();
                    _showMessage('Carrito vaciado');
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        blur: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar producto...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterProducts('');
                                    },
                                  )
                                : null,
                            filled: false,
                            border: InputBorder.none,
                          ),
                          onChanged: _filterProducts,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      blur: 12,
                      padding: EdgeInsets.zero,
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppConstants.primaryColor),
                        tooltip: 'Escanear código de barras',
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ],
                ),
              ),

              if (_searchController.text.isNotEmpty)
                Container(
                  height: 150,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _filteredProducts.isEmpty
                      ? const Center(child: Text('No se encontraron productos'))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GlassContainer(
                                borderRadius: BorderRadius.circular(16),
                                width: 140,
                                enableBlur: false,
                                padding: EdgeInsets.zero,
                                child: InkWell(
                                  onTap: () {
                                    cartProvider.addToCart(product);
                                    _showMessage('✓ ${product.name} agregado');
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(AppConstants.getCategoryIcon(product.category), color: AppConstants.getCategoryColor(product.category), size: 32),
                                        const SizedBox(height: 8),
                                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(Helpers.formatPrice(product.price), style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
                                        Text('Stock: ${product.stock}', style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

              const Divider(height: 1),

              Expanded(
                child: cartProvider.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 80, color: context.colors.textTertiary),
                            const SizedBox(height: 16),
                            Text('Carrito vacío', style: TextStyle(fontSize: 20, color: context.colors.textSecondary, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            Text('Busca productos arriba', style: TextStyle(fontSize: 14, color: context.colors.textTertiary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cartProvider.items.length,
                        itemBuilder: (context, index) {
                          final item = cartProvider.items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassContainer(
                              borderRadius: BorderRadius.circular(16),
                              enableBlur: false,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text(Helpers.formatPrice(item.price), style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => cartProvider.updateQuantity(item.productId, -1),
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: AppConstants.errorColor,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      ),
                                      IconButton(
                                        onPressed: () => cartProvider.updateQuantity(item.productId, 1),
                                        icon: const Icon(Icons.add_circle_outline),
                                        color: AppConstants.successColor,
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      Helpers.formatPrice(item.total),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppConstants.primaryColor),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => cartProvider.removeFromCart(item.productId),
                                    icon: const Icon(Icons.delete_outline),
                                    color: AppConstants.errorColor,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              if (cartProvider.items.isNotEmpty)
                GlassContainer(
                  borderRadius: BorderRadius.zero,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(16),
                  blur: 20,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total (${cartProvider.itemCount} items)', style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
                            const SizedBox(height: 4),
                            Text(Helpers.formatPrice(cartProvider.total), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppConstants.successColor)),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: _processPayment,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppConstants.successColor,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.payment, size: 24),
                          label: const Text('Cobrar', style: TextStyle(fontSize: 18)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}

class _PaymentMethodDialog extends StatelessWidget {
  final bool mpEnabled;

  const _PaymentMethodDialog({required this.mpEnabled});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.payment, color: AppConstants.primaryColor),
          SizedBox(width: 12),
          Text('Método de Pago'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.money, color: AppConstants.successColor, size: 32),
            title: const Text('Efectivo', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Pago en efectivo'),
            onTap: () => Navigator.pop(context, 'cash'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppConstants.backgroundColor,
          ),
          if (mpEnabled) ...[
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.qr_code_2, color: Color(0xFF009EE3), size: 32),
              title: const Text('Mercado Pago', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pago con QR'),
              onTap: () => Navigator.pop(context, 'mercadopago'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF009EE3).withOpacity(0.1),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.handshake, color: AppConstants.warningColor, size: 32),
            title: const Text('Fiado', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Queda en la cuenta corriente del cliente'),
            onTap: () => Navigator.pop(context, 'fiado'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: AppConstants.warningColor.withOpacity(0.1),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Elegir (o crear al vuelo) el cliente al que se le va a fiar la venta.
/// Si el cliente tiene límite de fiado configurado y esta venta lo
/// superaría, se avisa y se pide confirmación antes de continuar.
class _SelectCustomerDialog extends StatefulWidget {
  final String kioscoId;
  final double amount;
  const _SelectCustomerDialog({required this.kioscoId, required this.amount});

  @override
  State<_SelectCustomerDialog> createState() => _SelectCustomerDialogState();
}

class _SelectCustomerDialogState extends State<_SelectCustomerDialog> {
  List<Customer> _customers = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final customers = await CustomerService.loadAll(widget.kioscoId);
    customers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) {
      setState(() {
        _customers = customers;
        _loading = false;
      });
    }
  }

  List<Customer> get _filtered {
    if (_query.trim().isEmpty) return _customers;
    final q = _query.toLowerCase();
    return _customers.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _pick(Customer customer) async {
    if (customer.wouldExceedLimit(widget.amount)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supera el límite de fiado'),
          content: Text(
            '${customer.name} tiene un límite de ${Helpers.formatPrice(customer.creditLimit)} '
            'y ya debe ${Helpers.formatPrice(customer.creditBalance)}. '
            'Esta venta lo dejaría en ${Helpers.formatPrice(customer.creditBalance + widget.amount)}. '
            '¿Fiar igual?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppConstants.errorColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Fiar igual'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    if (mounted) Navigator.pop(context, customer);
  }

  Future<void> _createAndPick() async {
    final controller = TextEditingController(text: _query);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo cliente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final customer = await CustomerService.add(widget.kioscoId, name: name);
    if (mounted) Navigator.pop(context, customer);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('¿A quién le fiás?'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('Sin clientes', style: TextStyle(color: context.colors.textTertiary)),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final customer = _filtered[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(customer.name),
                              subtitle: customer.creditBalance > 0
                                  ? Text('Debe ${Helpers.formatPrice(customer.creditBalance)}')
                                  : null,
                              onTap: () => _pick(customer),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        TextButton.icon(
          onPressed: _createAndPick,
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Nuevo cliente'),
        ),
      ],
    );
  }
}

class _CashPaymentDialog extends StatefulWidget {
  final double total;
  const _CashPaymentDialog({required this.total});

  @override
  State<_CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<_CashPaymentDialog> {
  final TextEditingController _receivedController = TextEditingController();
  double _change = 0;

  void _calculateChange() {
    final received = double.tryParse(_receivedController.text) ?? 0;
    setState(() => _change = received - widget.total);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.money, color: AppConstants.successColor),
          SizedBox(width: 12),
          Text('Pago en Efectivo'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total a cobrar:', style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text(Helpers.formatPrice(widget.total), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
          const SizedBox(height: 24),
          TextField(
            controller: _receivedController,
            decoration: InputDecoration(
              labelText: 'Monto recibido',
              prefixText: '\$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
            onChanged: (_) => _calculateChange(),
          ),
          if (_change != 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _change >= 0 ? AppConstants.successColor.withOpacity(0.1) : AppConstants.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_change >= 0 ? 'Cambio:' : 'Falta:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _change >= 0 ? AppConstants.successColor : AppConstants.errorColor)),
                  Text(Helpers.formatPrice(_change.abs()), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _change >= 0 ? AppConstants.successColor : AppConstants.errorColor)),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _change >= 0 ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(backgroundColor: AppConstants.successColor),
          icon: const Icon(Icons.check),
          label: const Text('Confirmar'),
        ),
      ],
    );
  }
}