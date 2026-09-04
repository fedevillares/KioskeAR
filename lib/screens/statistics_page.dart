import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';

/// Contenido de estadísticas. No incluye Scaffold/AppBar propios: se usa
/// embebido dentro de ReportsTab (dentro del AppShell).
class StatisticsPage extends StatefulWidget {
  final List<Product> products;

  const StatisticsPage({Key? key, required this.products}) : super(key: key);

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalProducts = widget.products.length;
    final totalStock = widget.products.fold<int>(0, (sum, p) => sum + p.stock);
    final totalValue = widget.products.fold<double>(0, (sum, p) => sum + p.totalValue);
    final lowStockProducts = widget.products.where((p) => p.isLowStock && !p.isOutOfStock).length;
    final outOfStockProducts = widget.products.where((p) => p.isOutOfStock).length;

    final Map<String, int> categoryCounts = {};
    final Map<String, double> categoryValues = {};
    
    for (var product in widget.products) {
      categoryCounts[product.category] = (categoryCounts[product.category] ?? 0) + product.stock;
      categoryValues[product.category] = (categoryValues[product.category] ?? 0) + product.totalValue;
    }

    return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _buildSummaryCard(
                'Resumen General',
                [
                  _StatItem('Total de productos', totalProducts.toString(), Icons.inventory_2, AppConstants.primaryColor),
                  _StatItem('Total en stock', totalStock.toString(), Icons.inventory, AppConstants.successColor),
                  _StatItem('Valor total', Helpers.formatPrice(totalValue), Icons.attach_money, AppConstants.primaryColor),
                  _StatItem('Stock bajo', lowStockProducts.toString(), Icons.warning_amber, AppConstants.warningColor),
                  _StatItem('Agotados', outOfStockProducts.toString(), Icons.error_outline, AppConstants.errorColor),
                ],
              ),
              const SizedBox(height: 20),

              if (categoryCounts.isNotEmpty) ...[
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.8 + (0.2 * value),
                        child: child,
                      ),
                    );
                  },
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.pie_chart, color: AppConstants.primaryColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text('Stock por Categoría', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 60,
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        _touchedIndex = -1;
                                        return;
                                      }
                                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                sections: _buildPieChartSections(categoryCounts),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ..._buildCategoryLegend(categoryCounts),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (categoryValues.isNotEmpty) ...[
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: child,
                    );
                  },
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppConstants.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.bar_chart, color: AppConstants.successColor, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text('Valor por Categoría', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 200,
                            child: _buildValueBarChart(categoryValues),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.emoji_events, color: AppConstants.successColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text('Top 5 por Valor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._buildTopProducts(widget.products),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSummaryCard(String title, List<_StatItem> items) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics, color: AppConstants.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 400 + (index * 100)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(-20 * (1 - value), 0),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(item.icon, color: item.color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.label, style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
                      ),
                      Text(item.value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: item.color)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, int> data) {
    final total = data.values.fold<int>(0, (sum, val) => sum + val);
    
    return data.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final mapEntry = entry.value;
      final percentage = (mapEntry.value / total * 100);
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 90.0 : 80.0;
      
      return PieChartSectionData(
        value: mapEntry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        color: AppConstants.getCategoryColor(mapEntry.key),
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildValueBarChart(Map<String, double> categoryValues) {
    final maxValue = categoryValues.values.reduce((a, b) => a > b ? a : b);
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxValue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final category = categoryValues.keys.toList()[group.x.toInt()];
              return BarTooltipItem(
                '$category\n${Helpers.formatPrice(rod.toY)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final categories = categoryValues.keys.toList();
                if (value.toInt() >= categories.length) return const Text('');
                final category = categories[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(
                    AppConstants.getCategoryIcon(category),
                    size: 20,
                    color: AppConstants.getCategoryColor(category),
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: categoryValues.entries.toList().asMap().entries.map((entry) {
          final index = entry.key;
          final mapEntry = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: mapEntry.value,
                color: AppConstants.getCategoryColor(mapEntry.key),
                width: 30,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppConstants.getCategoryColor(mapEntry.key).withOpacity(0.6),
                    AppConstants.getCategoryColor(mapEntry.key),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildCategoryLegend(Map<String, int> data) {
    return data.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final mapEntry = entry.value;
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppConstants.getCategoryColor(mapEntry.key),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppConstants.getCategoryIcon(mapEntry.key), size: 16, color: AppConstants.getCategoryColor(mapEntry.key)),
              const SizedBox(width: 8),
              Expanded(child: Text(mapEntry.key, style: const TextStyle(fontSize: 14))),
              Text('${mapEntry.value} unidades', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildTopProducts(List<Product> products) {
    final sortedProducts = List<Product>.from(products)..sort((a, b) => b.totalValue.compareTo(a.totalValue));
    final top5 = sortedProducts.take(5).toList();

    return top5.asMap().entries.map((entry) {
      final index = entry.key;
      final product = entry.value;
      
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(30 * (1 - value), 0),
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppConstants.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: index < 3 ? Border.all(color: AppConstants.primaryColor.withOpacity(0.3), width: 2) : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: index < 3
                        ? [AppConstants.primaryColor, AppConstants.secondaryColor]
                        : [context.colors.textTertiary, context.colors.divider],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (index < 3 ? AppConstants.primaryColor : Colors.grey).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Icon(AppConstants.getCategoryIcon(product.category), size: 20, color: AppConstants.getCategoryColor(product.category)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${product.stock} unidades × ${Helpers.formatPrice(product.price)}', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                  ],
                ),
              ),
              Text(Helpers.formatPrice(product.totalValue), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.successColor)),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}