import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../services/customer_service.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';

/// Lista de clientes del kiosco con su saldo de cuenta corriente (fiado).
/// Desde aquí se puede dar de alta un cliente nuevo, ver el detalle de cada
/// uno (historial de movimientos) y registrar un pago que reduce su deuda.
class CustomersPage extends StatefulWidget {
  const CustomersPage({Key? key}) : super(key: key);

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  List<Customer> _customers = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _kioscoId => context.read<SessionProvider>().kioscoId;

  Future<void> _load() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    final customers = await CustomerService.loadAll(kioscoId);
    customers.sort((a, b) => b.creditBalance.compareTo(a.creditBalance));
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
    return _customers.where((c) =>
        c.name.toLowerCase().contains(q) || c.phone.contains(q)).toList();
  }

  double get _totalDebt => _customers.fold<double>(0, (sum, c) => sum + c.creditBalance);

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

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo cliente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Límite de fiado (opcional)',
                  prefixText: '\$ ',
                  helperText: 'Dejalo vacío para no poner límite',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await CustomerService.add(
                kioscoId,
                name: name,
                phone: phoneController.text.trim(),
                creditLimit: double.tryParse(limitController.text) ?? 0.0,
              );
              if (!mounted) return;
              Navigator.pop(dialogContext);
              await _load();
              _showMessage('✓ Cliente agregado');
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _openDetail(Customer customer) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => CustomerDetailPage(customer: customer)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Clientes y Fiado', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddCustomerDialog,
          backgroundColor: AppConstants.primaryColor,
          child: const Icon(Icons.person_add, color: Colors.white),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deuda total fiada', style: TextStyle(fontSize: 13, color: context.colors.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  Helpers.formatPrice(_totalDebt),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _totalDebt > 0 ? AppConstants.errorColor : AppConstants.successColor,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.account_balance_wallet, size: 36, color: AppConstants.primaryColor.withOpacity(0.6)),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(14),
                        blur: 12,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Buscar cliente...',
                            prefixIcon: Icon(Icons.search),
                            filled: false,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 72, color: context.colors.textTertiary),
                                  const SizedBox(height: 12),
                                  Text(
                                    _customers.isEmpty ? 'Todavía no hay clientes' : 'Sin resultados',
                                    style: TextStyle(color: context.colors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final customer = _filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GlassContainer(
                                    borderRadius: BorderRadius.circular(16),
                                    enableBlur: false,
                                    child: ListTile(
                                      onTap: () => _openDetail(customer),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      leading: CircleAvatar(
                                        backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                                        child: Text(
                                          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                          style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: customer.phone.isNotEmpty ? Text(customer.phone) : null,
                                      trailing: Text(
                                        Helpers.formatPrice(customer.creditBalance),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: customer.creditBalance > 0 ? AppConstants.errorColor : context.colors.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Detalle de un cliente: saldo, datos de contacto y el historial completo
/// de movimientos (fiados y pagos), con acción para registrar un cobro.
class CustomerDetailPage extends StatefulWidget {
  final Customer customer;
  const CustomerDetailPage({Key? key, required this.customer}) : super(key: key);

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late Customer _customer;
  List<CustomerTransaction> _history = [];
  bool _loading = true;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _load();
  }

  String? get _kioscoId => context.read<SessionProvider>().kioscoId;

  Future<void> _load() async {
    final kioscoId = _kioscoId;
    if (kioscoId == null) return;
    final customers = await CustomerService.loadAll(kioscoId);
    final updated = customers.where((c) => c.id == _customer.id).toList();
    final history = await CustomerService.historyFor(kioscoId, _customer.id);
    if (mounted) {
      setState(() {
        if (updated.isNotEmpty) _customer = updated.first;
        _history = history;
        _loading = false;
      });
    }
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

  void _showRegisterPaymentDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Registrar pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo actual: ${Helpers.formatPrice(_customer.creditBalance)}',
                style: TextStyle(color: context.colors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Monto a cobrar',
                prefixText: '\$ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount <= 0) return;
              final kioscoId = _kioscoId;
              if (kioscoId == null) return;
              await CustomerService.registerPayment(
                kioscoId,
                customerId: _customer.id,
                amount: amount,
              );
              if (!mounted) return;
              Navigator.pop(dialogContext);
              _changed = true;
              await _load();
              _showMessage('✓ Pago registrado');
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: GlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(_customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context, _changed),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    children: [
                      GlassContainer(
                        borderRadius: BorderRadius.circular(18),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text('Saldo (fiado)', style: TextStyle(fontSize: 14, color: context.colors.textSecondary)),
                            const SizedBox(height: 6),
                            Text(
                              Helpers.formatPrice(_customer.creditBalance),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _customer.creditBalance > 0 ? AppConstants.errorColor : AppConstants.successColor,
                              ),
                            ),
                            if (_customer.creditLimit > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Límite: ${Helpers.formatPrice(_customer.creditLimit)}',
                                style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _customer.creditBalance > 0 ? _showRegisterPaymentDialog : null,
                              style: FilledButton.styleFrom(backgroundColor: AppConstants.successColor),
                              icon: const Icon(Icons.payments),
                              label: const Text('Registrar pago'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_customer.phone.isNotEmpty)
                        GlassContainer(
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            leading: const Icon(Icons.phone, color: AppConstants.primaryColor),
                            title: Text(_customer.phone),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text('Historial de movimientos', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
                      const SizedBox(height: 8),
                      if (_history.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Sin movimientos todavía', style: TextStyle(color: context.colors.textTertiary)),
                          ),
                        )
                      else
                        ..._history.map((t) {
                          final isFiado = t.type == CustomerTransactionType.fiado;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassContainer(
                              borderRadius: BorderRadius.circular(14),
                              enableBlur: false,
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  isFiado ? Icons.arrow_upward : Icons.arrow_downward,
                                  color: isFiado ? AppConstants.errorColor : AppConstants.successColor,
                                ),
                                title: Text(isFiado ? 'Compra fiada' : 'Pago recibido'),
                                subtitle: Text(Helpers.formatDateTime(t.timestamp)),
                                trailing: Text(
                                  '${isFiado ? '+' : '-'}${Helpers.formatPrice(t.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isFiado ? AppConstants.errorColor : AppConstants.successColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
