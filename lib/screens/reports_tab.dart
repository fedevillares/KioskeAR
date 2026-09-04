import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/storage_service.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';
import 'dashboard_page.dart';
import 'statistics_page.dart';
import 'comparison_report_page.dart';

/// Pestaña "Reportes": combina el resumen diario (Dashboard), las
/// estadísticas (Statistics) y la comparativa mensual/rentabilidad en
/// sub-pestañas internas, dentro del AppShell.
class ReportsTab extends StatefulWidget {
  const ReportsTab({Key? key}) : super(key: key);

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  List<Product> _products = [];
  List<Sale> _sales = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final kioscoId = context.read<SessionProvider>().kioscoId;
    if (kioscoId == null) return;
    setState(() => _isLoading = true);
    final products = await StorageService.loadProducts(kioscoId);
    final sales = await StorageService.loadSales(kioscoId);
    if (mounted) {
      setState(() {
        _products = products;
        _sales = sales;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Reportes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: AppConstants.primaryColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(4),
              blur: 12,
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                  ),
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: 'Resumen'),
                  Tab(text: 'Estadísticas'),
                  Tab(text: 'Comparativa'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      DashboardPage(products: _products),
                      StatisticsPage(products: _products),
                      ComparisonReportPage(products: _products, sales: _sales),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
