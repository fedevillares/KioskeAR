import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cash_closing.dart';
import '../models/permission.dart';
import '../models/sale.dart';
import '../providers/session_provider.dart';
import '../services/cash_closing_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';

/// Cierre de caja diario: muestra el resumen "en vivo" del día actual
/// (ventas por medio de pago, ganancia estimada) y permite confirmar el
/// cierre dejando un registro inmutable. También lista los cierres
/// anteriores para llevar un historial día por día.
class CashClosingPage extends StatefulWidget {
  const CashClosingPage({Key? key}) : super(key: key);

  @override
  State<CashClosingPage> createState() => _CashClosingPageState();
}

class _CashClosingPageState extends State<CashClosingPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  DailySummary? _todaySummary;
  CashClosing? _todayClosing;
  double _todayCost = 0;
  List<CashClosing> _history = [];

  String get _kioscoId => context.read<SessionProvider>().kioscoId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    final today = DateTime.now();
    final summary = await CashClosingService.getDailySummary(kioscoId, today);
    final closing = await CashClosingService.getClosingForDay(kioscoId, today);
    final products = await StorageService.loadProducts(kioscoId);
    final history = await CashClosingService.loadAll(kioscoId);

    final costByProduct = {for (final p in products) p.id: p.costPrice};
    final cost = summary.sales.fold<double>(
      0,
      (sum, s) => sum + ((costByProduct[s.productId] ?? 0) * s.quantity),
    );

    if (mounted) {
      setState(() {
        _todaySummary = summary;
        _todayClosing = closing;
        _todayCost = cost;
        _history = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCloseDialog() async {
    final session = context.read<SessionProvider>();
    if (!session.hasPermission(Permission.cerrarCaja)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tenés permiso para cerrar la caja. Pedile a un administrador que te lo habilite.'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      return;
    }

    final summary = _todaySummary;
    if (summary == null) return;

    final cashController = TextEditingController(
      text: summary.cashExpected > 0 ? summary.cashExpected.toStringAsFixed(0) : '',
    );
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.point_of_sale, color: AppConstants.primaryColor),
            SizedBox(width: 10),
            Text('Confirmar cierre'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vas a cerrar la caja del ${Helpers.formatDate(DateTime.now())}. '
              'Una vez confirmado, no se puede modificar.',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cashController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Efectivo contado en caja',
                prefixIcon: const Icon(Icons.payments_outlined),
                helperText: 'Esperado: ${Helpers.formatPrice(summary.cashExpected)}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observaciones (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final kioscoId = context.read<SessionProvider>().kioscoId;
    if (kioscoId == null) return;
    final user = context.read<SessionProvider>().currentUser;
    final cashCounted = double.tryParse(cashController.text.trim().replaceAll(',', '.'));

    try {
      await CashClosingService.closeDay(
        kioscoId: kioscoId,
        date: DateTime.now(),
        totalCost: _todayCost,
        closedByUserId: user?.uid,
        closedByUsername: user?.usuario,
        cashCounted: cashCounted,
        notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Caja cerrada correctamente'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppConstants.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Cierre de caja'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primaryColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: AppConstants.primaryColor,
          tabs: const [
            Tab(text: 'Hoy'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTodayTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }

  Widget _buildTodayTab() {
    final summary = _todaySummary!;
    final isClosed = _todayClosing != null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          if (isClosed) _buildClosedBanner(_todayClosing!),
          if (isClosed) const SizedBox(height: 16),
          _buildSummaryCard(
            totalSales: summary.totalSales,
            totalRevenue: summary.totalRevenue,
            totalCost: _todayCost,
            totalProfit: summary.totalRevenue - _todayCost,
            totalDiscount: summary.totalDiscountGiven,
          ),
          const SizedBox(height: 16),
          _buildPaymentBreakdown(summary.totalsByPaymentMethod, summary.salesCountByPaymentMethod),
          const SizedBox(height: 24),
          if (!isClosed)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: summary.totalSales == 0 ? null : _openCloseDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cerrar caja de hoy'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          if (!isClosed && summary.totalSales == 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Todavía no hay ventas registradas hoy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner(CashClosing closing) {
    final diff = closing.cashDifference;
    return GlassContainer(
      borderRadius: BorderRadius.circular(16),
      color: AppConstants.successColor.withOpacity(0.1),
      border: Border.all(color: AppConstants.successColor.withOpacity(0.4)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppConstants.successColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Caja cerrada · ${Helpers.formatDateTime(closing.closedAt)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (closing.closedByUsername != null)
                    Text('por ${closing.closedByUsername}', style: const TextStyle(fontSize: 12)),
                  if (diff != null && diff.abs() > 0.5)
                    Text(
                      diff > 0
                          ? 'Sobrante: ${Helpers.formatPrice(diff)}'
                          : 'Faltante: ${Helpers.formatPrice(diff.abs())}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: diff > 0 ? AppConstants.successColor : AppConstants.errorColor,
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

  Widget _buildSummaryCard({
    required int totalSales,
    required double totalRevenue,
    required double totalCost,
    required double totalProfit,
    required double totalDiscount,
  }) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(Helpers.formatDate(DateTime.now()), style: TextStyle(fontSize: 13, color: context.colors.textTertiary)),
                Text('$totalSales ${totalSales == 1 ? 'venta' : 'ventas'}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              Helpers.formatPrice(totalRevenue),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text('Total vendido', style: TextStyle(fontSize: 12, color: context.colors.textTertiary)),
            Divider(height: 28, color: context.colors.divider),
            Row(
              children: [
                Expanded(child: _MiniStat(label: 'Ganancia', value: Helpers.formatPrice(totalProfit), color: AppConstants.successColor)),
                Expanded(child: _MiniStat(label: 'Costo', value: Helpers.formatPrice(totalCost), color: context.colors.textTertiary)),
                if (totalDiscount > 0)
                  Expanded(child: _MiniStat(label: 'En descuentos', value: Helpers.formatPrice(totalDiscount), color: AppConstants.warningColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentBreakdown(Map<String, double> totals, Map<String, int> counts) {
    if (totals.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);

    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Por medio de pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final method = PaymentMethodLabel.fromName(e.key);
              final pct = grandTotal > 0 ? (e.value / grandTotal) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(_iconFor(method), size: 16, color: AppConstants.primaryColor),
                            const SizedBox(width: 6),
                            Text('${method.label} (${counts[e.key] ?? 0})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        Text(Helpers.formatPrice(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        color: AppConstants.primaryColor,
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

  IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.efectivo:
        return Icons.payments_outlined;
      case PaymentMethod.tarjeta:
        return Icons.credit_card;
      case PaymentMethod.mercadoPago:
        return Icons.qr_code;
      case PaymentMethod.transferencia:
        return Icons.swap_horiz;
      case PaymentMethod.fiado:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethod.otro:
        return Icons.more_horiz;
    }
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 56, color: context.colors.textTertiary),
              const SizedBox(height: 12),
              Text('Todavía no hay cierres registrados', style: TextStyle(color: context.colors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final c = _history[index];
          final diff = c.cashDifference;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(16),
              enableBlur: false,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today, color: AppConstants.primaryColor, size: 18),
                ),
                title: Text(Helpers.formatDate(c.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '${c.totalSales} ventas · ${Helpers.formatPrice(c.totalRevenue)}'
                  '${diff != null && diff.abs() > 0.5 ? (diff > 0 ? ' · sobrante' : ' · faltante') : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  Helpers.formatPrice(c.totalProfit),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.successColor),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.textTertiary)),
      ],
    );
  }
}
