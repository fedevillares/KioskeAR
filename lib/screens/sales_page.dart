import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/sale.dart';
import '../services/storage_service.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({Key? key}) : super(key: key);

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<Sale> _allSales = [];
  List<Sale> _todaySales = [];
  bool _isLoading = true;
  String _selectedPeriod = 'Hoy';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final kioscoId = context.read<SessionProvider>().kioscoId;
    if (kioscoId == null) return;
    setState(() => _isLoading = true);
    final sales = await StorageService.loadSales(kioscoId);
    if (mounted) {
      setState(() {
        _allSales = sales;
        _filterSales();
        _isLoading = false;
      });
    }
  }

  void _filterSales() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedPeriod) {
      case 'Hoy':
        _todaySales = _allSales.where((s) => s.timestamp.isAfter(today)).toList();
        break;
      case 'Ayer':
        final yesterday = today.subtract(const Duration(days: 1));
        _todaySales = _allSales.where((s) {
          return s.timestamp.isAfter(yesterday) && s.timestamp.isBefore(today);
        }).toList();
        break;
      case 'Esta semana':
        final weekAgo = today.subtract(const Duration(days: 7));
        _todaySales = _allSales.where((s) => s.timestamp.isAfter(weekAgo)).toList();
        break;
      case 'Este mes':
        final monthStart = DateTime(now.year, now.month, 1);
        _todaySales = _allSales.where((s) => s.timestamp.isAfter(monthStart)).toList();
        break;
      default:
        _todaySales = _allSales;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSales = _todaySales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final totalTransactions = _todaySales.length;
    final averageTicket = totalTransactions > 0 ? totalSales / totalTransactions : 0.0;

    return GlassBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Registro de Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Hoy', 'Ayer', 'Esta semana', 'Este mes', 'Todo'].map((period) {
                      final isSelected = _selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(period),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPeriod = period;
                              _filterSales();
                            });
                          },
                          selectedColor: AppConstants.primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : context.colors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Tarjetas resumen
                GlassContainer(
                  borderRadius: BorderRadius.circular(20),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatCard('Ventas', Helpers.formatPrice(totalSales), Icons.attach_money, AppConstants.successColor),
                            _StatCard('Tickets', '$totalTransactions', Icons.receipt, AppConstants.primaryColor),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _StatCard('Promedio', Helpers.formatPrice(averageTicket), Icons.shopping_cart, AppConstants.secondaryColor),
                      ],
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de ventas
                if (_todaySales.isEmpty)
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(40),
                    child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: context.colors.textTertiary),
                            const SizedBox(height: 12),
                            Text('No hay ventas registradas', style: TextStyle(fontSize: 16, color: context.colors.textSecondary)),
                          ],
                        ),
                    ),
                  )
                else
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Historial de Ventas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          ..._todaySales.reversed.take(20).map((sale) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppConstants.successColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.shopping_bag, color: AppConstants.successColor, size: 20),
                                  ),
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
                                      Text(Helpers.formatPrice(sale.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.successColor, fontSize: 16)),
                                      Text(Helpers.formatDateTime(sale.timestamp), style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )),
                        ],
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}