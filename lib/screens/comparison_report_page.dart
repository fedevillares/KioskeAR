import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';

/// Reportes comparativos: mes actual vs. mes anterior, proyección de
/// agotamiento de stock según ritmo de venta reciente, y ranking de
/// productos por rentabilidad (no solo por volumen vendido — un producto
/// puede vender mucho y dejar poco margen, o vender poco y ser muy
/// rentable por unidad).
///
/// La rentabilidad histórica se aproxima usando el costPrice ACTUAL del
/// producto contra el pricePerUnit registrado en cada venta, porque Sale
/// no guarda una foto del costo al momento de vender. Es una aproximación
/// razonable mientras el costo no cambie mucho de un mes a otro, pero vale
/// aclararlo: si el costo de un producto cambió hace poco, la rentabilidad
/// de ventas viejas se recalcula con el costo de hoy, no con el real de
/// ese momento.
class ComparisonReportPage extends StatelessWidget {
  final List<Product> products;
  final List<Sale> sales;

  const ComparisonReportPage({Key? key, required this.products, required this.sales})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final previousMonthStart = DateTime(now.year, now.month - 1, 1);

    final currentMonthSales = sales.where((s) => !s.timestamp.isBefore(currentMonthStart)).toList();
    final previousMonthSales = sales
        .where((s) => !s.timestamp.isBefore(previousMonthStart) && s.timestamp.isBefore(currentMonthStart))
        .toList();

    final productsById = {for (final p in products) p.id: p};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _MonthComparisonCard(
          currentSales: currentMonthSales,
          previousSales: previousMonthSales,
        ),
        const SizedBox(height: 20),
        _DepletionProjectionCard(products: products, sales: sales),
        const SizedBox(height: 20),
        _ProfitabilityRankingCard(sales: currentMonthSales, productsById: productsById),
      ],
    );
  }
}

class _MonthComparisonCard extends StatelessWidget {
  final List<Sale> currentSales;
  final List<Sale> previousSales;

  const _MonthComparisonCard({required this.currentSales, required this.previousSales});

  @override
  Widget build(BuildContext context) {
    final currentTotal = currentSales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final previousTotal = previousSales.fold<double>(0, (sum, s) => sum + s.totalPrice);
    final currentCount = currentSales.length;
    final previousCount = previousSales.length;

    final diffPercent = previousTotal > 0
        ? ((currentTotal - previousTotal) / previousTotal) * 100
        : (currentTotal > 0 ? 100.0 : 0.0);
    final isUp = diffPercent >= 0;

    final now = DateTime.now();
    final monthNames = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final currentMonthName = monthNames[now.month - 1];
    final prevMonthIndex = (now.month - 2) % 12;
    final previousMonthName = monthNames[prevMonthIndex < 0 ? prevMonthIndex + 12 : prevMonthIndex];

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month, color: AppConstants.primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Este mes vs. mes anterior', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MonthColumn(
                    label: previousMonthName[0].toUpperCase() + previousMonthName.substring(1),
                    total: previousTotal,
                    count: previousCount,
                    muted: true,
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: _MonthColumn(
                    label: currentMonthName[0].toUpperCase() + currentMonthName.substring(1),
                    total: currentTotal,
                    count: currentCount,
                    muted: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (isUp ? AppConstants.successColor : AppConstants.errorColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isUp ? Icons.trending_up : Icons.trending_down,
                    color: isUp ? AppConstants.successColor : AppConstants.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isUp ? '+' : ''}${diffPercent.toStringAsFixed(1)}% en ventas respecto al mes anterior',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isUp ? AppConstants.successColor : AppConstants.errorColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthColumn extends StatelessWidget {
  final String label;
  final double total;
  final int count;
  final bool muted;

  const _MonthColumn({required this.label, required this.total, required this.count, required this.muted});

  @override
  Widget build(BuildContext context) {
    final color = muted ? context.colors.textSecondary : AppConstants.primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: context.colors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(Helpers.formatPrice(total), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text('$count ventas', style: TextStyle(fontSize: 11.5, color: context.colors.textTertiary)),
      ],
    );
  }
}

class _DepletionProjectionCard extends StatelessWidget {
  final List<Product> products;
  final List<Sale> sales;

  const _DepletionProjectionCard({required this.products, required this.sales});

  /// Velocidad de venta diaria promedio de los últimos 14 días, por
  /// producto. Con eso se proyecta en cuántos días se agota el stock
  /// actual si el ritmo de venta se mantiene.
  Map<String, double> _dailyVelocity() {
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    final recent = sales.where((s) => s.timestamp.isAfter(cutoff)).toList();
    final totals = <String, int>{};
    for (final s in recent) {
      totals[s.productId] = (totals[s.productId] ?? 0) + s.quantity;
    }
    return totals.map((id, qty) => MapEntry(id, qty / 14));
  }

  @override
  Widget build(BuildContext context) {
    final velocity = _dailyVelocity();

    final projections = products
        .where((p) => !p.isOutOfStock && (velocity[p.id] ?? 0) > 0)
        .map((p) {
          final daysLeft = p.stock / velocity[p.id]!;
          return (product: p, daysLeft: daysLeft);
        })
        .where((entry) => entry.daysLeft <= 30)
        .toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.timeline, color: AppConstants.warningColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Proyección de agotamiento (30 días)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Según el ritmo de venta de los últimos 14 días',
              style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (projections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Ningún producto se agotaría en los próximos 30 días al ritmo actual.',
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                ),
              )
            else
              ...projections.take(8).map((entry) {
                final p = entry.product;
                final days = entry.daysLeft;
                final urgent = days <= 7;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: urgent ? AppConstants.errorColor : AppConstants.warningColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        days < 1 ? '<1 día' : '${days.round()} días',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: urgent ? AppConstants.errorColor : AppConstants.warningColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ProfitabilityRankingCard extends StatelessWidget {
  final List<Sale> sales;
  final Map<String, Product> productsById;

  const _ProfitabilityRankingCard({required this.sales, required this.productsById});

  @override
  Widget build(BuildContext context) {
    final volumeByProduct = <String, int>{};
    final profitByProduct = <String, double>{};

    for (final s in sales) {
      volumeByProduct[s.productId] = (volumeByProduct[s.productId] ?? 0) + s.quantity;
      final product = productsById[s.productId];
      if (product != null) {
        final profitPerUnit = s.pricePerUnit - product.costPrice;
        profitByProduct[s.productId] = (profitByProduct[s.productId] ?? 0) + (profitPerUnit * s.quantity);
      }
    }

    final byProfit = profitByProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final byVolume = volumeByProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final topVolumeIds = byVolume.take(5).map((e) => e.key).toSet();
    final topProfitIds = byProfit.take(5).map((e) => e.key).toSet();
    final mismatch = topVolumeIds.difference(topProfitIds).isNotEmpty ||
        topProfitIds.difference(topVolumeIds).isNotEmpty;

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.workspace_premium, color: AppConstants.successColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Más rentables del mes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (byProfit.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Todavía no hay ventas este mes para calcular rentabilidad.',
                    style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
              )
            else ...[
              ...byProfit.take(5).toList().asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final productId = entry.value.key;
                final profit = entry.value.value;
                final product = productsById[productId];
                final volume = volumeByProduct[productId] ?? 0;
                if (product == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.successColor.withOpacity(0.15),
                        ),
                        child: Center(
                          child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.successColor)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            Text('$volume vendidos', style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        Helpers.formatPrice(profit),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppConstants.successColor),
                      ),
                    ],
                  ),
                );
              }),
              if (mismatch) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppConstants.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El ranking de más vendidos no coincide del todo con el de más rentables: hay productos que venden mucho pero dejan poco margen, y viceversa.',
                          style: TextStyle(fontSize: 11.5, color: context.colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
