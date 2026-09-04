import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/storage_service.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/app_navigation.dart';
import '../widgets/glass_container.dart';

/// Contenido del resumen diario. No incluye Scaffold/AppBar propios: se usa
/// embebido dentro de ReportsTab (dentro del AppShell).
class DashboardPage extends StatefulWidget {
  final List<Product> products;

  const DashboardPage({Key? key, required this.products}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Sale> _todaySales = [];
  bool _isLoading = true;
  bool _stockAlertsEnabled = true;
  int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAlertPrefs();
  }

  Future<void> _loadAlertPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stockAlertsEnabled = prefs.getBool('stock_alerts_enabled') ?? true;
      _lowStockThreshold = prefs.getInt('low_stock_threshold') ?? 5;
    });
  }

  Future<void> _loadData() async {
    final kioscoId = context.read<SessionProvider>().kioscoId;
    if (kioscoId == null) return;
    setState(() => _isLoading = true);
    final allSales = await StorageService.loadSales(kioscoId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (mounted) {
      setState(() {
        _todaySales = allSales.where((s) => s.timestamp.isAfter(today)).toList();
        _isLoading = false;
      });
    }
  }

  /// Un producto entra en alerta si está agotado, por debajo de su propio
  /// mínimo (minStock), o por debajo del umbral global configurado en
  /// Ajustes — lo que dispare primero.
  List<Product> _alertProducts() {
    return widget.products
        .where((p) => p.isOutOfStock || p.isLowStock || p.stock <= _lowStockThreshold)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));
  }

  @override
  Widget build(BuildContext context) {
    final totalSalesToday = _todaySales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final totalTransactions = _todaySales.length;
    final totalProducts = widget.products.length;
    final totalValue = widget.products.fold<double>(0, (sum, p) => sum + p.totalValue);
    final lowStock = widget.products.where((p) => p.isLowStock).length;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppConstants.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.today, color: AppConstants.successColor, size: 28),
                              ),
                              const SizedBox(width: 12),
                              const Text('Ventas de Hoy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _DashboardMetric('Total', Helpers.formatPrice(totalSalesToday), Icons.attach_money, AppConstants.successColor),
                              Container(width: 1, height: 60, color: context.colors.divider),
                              _DashboardMetric('Ventas', '$totalTransactions', Icons.receipt, AppConstants.primaryColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard('Productos', '$totalProducts', Icons.inventory_2, AppConstants.primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard('Valor Total', Helpers.formatPrice(totalValue), Icons.payments, AppConstants.successColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MetricCard('Stock Bajo', '$lowStock productos', Icons.warning_amber, lowStock > 0 ? AppConstants.warningColor : AppConstants.successColor),
                  const SizedBox(height: 20),

                  if (_stockAlertsEnabled && _alertProducts().isNotEmpty) ...[
                    _LowStockAlertBanner(products: _alertProducts()),
                    const SizedBox(height: 20),
                  ],

                  if (_todaySales.isNotEmpty) ...[
                    GlassContainer(
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.emoji_events, color: AppConstants.successColor),
                                SizedBox(width: 12),
                                Text('Más Vendidos Hoy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._getTopSoldProducts().take(5).map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppConstants.successColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${_getTopSoldProducts().toList().indexOf(entry) + 1}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text('${entry.value} vendidos', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (_todaySales.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GlassContainer(
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.history, color: AppConstants.primaryColor),
                                SizedBox(width: 12),
                                Text('Últimas Ventas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._todaySales.reversed.take(5).map((sale) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  const Icon(Icons.shopping_bag, color: AppConstants.successColor, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(sale.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        Text('${sale.quantity} x ${Helpers.formatPrice(sale.pricePerUnit)}', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(Helpers.formatPrice(sale.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.successColor)),
                                      Text(Helpers.formatDateTime(sale.timestamp).split(' ')[1], style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
            ),
          );
  }

  List<MapEntry<String, int>> _getTopSoldProducts() {
    final productCounts = <String, int>{};
    for (var sale in _todaySales) {
      productCounts[sale.productName] = (productCounts[sale.productName] ?? 0) + sale.quantity;
    }
    final sorted = productCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }
}

class _LowStockAlertBanner extends StatelessWidget {
  final List<Product> products;

  const _LowStockAlertBanner({required this.products});

  @override
  Widget build(BuildContext context) {
    final outOfStock = products.where((p) => p.isOutOfStock).length;
    final lowOnly = products.length - outOfStock;

    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => AppNavigation.goToTab(AppNavigation.inventario),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.errorColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: AppConstants.errorColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Alerta de stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          [
                            if (outOfStock > 0) '$outOfStock agotado${outOfStock == 1 ? '' : 's'}',
                            if (lowOnly > 0) '$lowOnly con stock bajo',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14),
                ],
              ),
              const SizedBox(height: 12),
              ...products.take(3).map((p) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.isOutOfStock ? AppConstants.errorColor : AppConstants.warningColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                        ),
                        Text(
                          p.isOutOfStock ? 'Sin stock' : '${p.stock} u.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: p.isOutOfStock ? AppConstants.errorColor : AppConstants.warningColor,
                          ),
                        ),
                      ],
                    ),
                  )),
              if (products.length > 3) ...[
                const SizedBox(height: 8),
                Text('+${products.length - 3} producto${products.length - 3 == 1 ? '' : 's'} más',
                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardMetric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}