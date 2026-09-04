import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';

class ProfitabilityPage extends StatelessWidget {
  final List<Product> products;

  const ProfitabilityPage({Key? key, required this.products}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalInvestment = products.fold<double>(0, (sum, p) => sum + (p.stock * p.costPrice));
    final totalValue = products.fold<double>(0, (sum, p) => sum + p.totalValue);
    final totalProfit = products.fold<double>(0, (sum, p) => sum + p.totalProfit);
    final profitMargin = totalInvestment > 0 ? (totalProfit / totalInvestment) * 100 : 0;

    final profitableProducts = products.where((p) => p.costPrice > 0 && p.profit > 0).toList()
      ..sort((a, b) => b.profitMargin.compareTo(a.profitMargin));

    return GlassBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Análisis de Rentabilidad', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(20),
            gradient: LinearGradient(
              colors: [AppConstants.successColor, AppConstants.successColor.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
                children: [
                  const Icon(Icons.trending_up, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text('Ganancia Potencial', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(Helpers.formatPrice(totalProfit), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Margen: ${profitMargin.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70, fontSize: 18)),
                ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _MetricCard('Inversión', Helpers.formatPrice(totalInvestment), Icons.shopping_bag, AppConstants.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard('Valor de Venta', Helpers.formatPrice(totalValue), Icons.attach_money, AppConstants.successColor)),
            ],
          ),
          const SizedBox(height: 20),

          GlassContainer(
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star, color: AppConstants.warningColor),
                      SizedBox(width: 12),
                      Text('Productos Más Rentables', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (profitableProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, size: 48, color: context.colors.textTertiary),
                            const SizedBox(height: 12),
                            Text('Agrega el precio de costo a tus productos', style: TextStyle(color: context.colors.textSecondary), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  else
                    ...profitableProducts.take(10).map((product) {
                      final index = profitableProducts.indexOf(product);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: index < 3 ? Border.all(color: AppConstants.successColor.withOpacity(0.3), width: 2) : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: index < 3
                                      ? [AppConstants.successColor, AppConstants.primaryColor]
                                      : [context.colors.textTertiary, context.colors.divider],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('Costo: ${Helpers.formatPrice(product.costPrice)} → Venta: ${Helpers.formatPrice(product.price)}', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppConstants.successColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('${product.profitMargin.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.successColor, fontSize: 14)),
                                ),
                                const SizedBox(height: 4),
                                Text(Helpers.formatPrice(product.totalProfit), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
            ),
          ),
          const SizedBox(height: 20),

          if (profitableProducts.isNotEmpty)
            GlassContainer(
              borderRadius: BorderRadius.circular(20),
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pie_chart, color: AppConstants.primaryColor),
                        SizedBox(width: 12),
                        Text('Distribución de Márgenes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildMarginDistribution(context, profitableProducts),
                  ],
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildMarginDistribution(BuildContext context, List<Product> products) {
    final ranges = {
      'Alto (>50%)': products.where((p) => p.profitMargin > 50).length,
      'Medio (20-50%)': products.where((p) => p.profitMargin >= 20 && p.profitMargin <= 50).length,
      'Bajo (<20%)': products.where((p) => p.profitMargin < 20).length,
    };

    return Column(
      children: ranges.entries.map((entry) {
        final percentage = products.isEmpty ? 0.0 : (entry.value / products.length) * 100;
        Color color;
        if (entry.key.contains('Alto')) {
          color = AppConstants.successColor;
        } else if (entry.key.contains('Medio')) {
          color = AppConstants.warningColor;
        } else {
          color = AppConstants.errorColor;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${entry.value} productos (${percentage.toStringAsFixed(0)}%)', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: context.colors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
      child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
      ),
    );
  }
}