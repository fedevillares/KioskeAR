import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/permission.dart';
import '../models/product.dart';
import '../services/storage_service.dart';
import '../providers/theme_provider.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';
import 'sales_page.dart';
import 'profitability_page.dart';
import 'settings_page.dart';
import 'admin_panel_page.dart';
import 'login_page.dart';
import 'cash_closing_page.dart';
import 'customers_page.dart';

/// Pestaña "Más": accesos a las pantallas secundarias (Ventas, Rentabilidad,
/// Configuración) y acceso rápido al modo oscuro. Vive dentro del AppShell.
class MoreTab extends StatefulWidget {
  const MoreTab({Key? key}) : super(key: key);

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> with AutomaticKeepAliveClientMixin {
  List<Product> _products = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final kioscoId = context.read<SessionProvider>().kioscoId;
    if (kioscoId == null) return;
    final products = await StorageService.loadProducts(kioscoId);
    if (mounted) setState(() => _products = products);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final session = Provider.of<SessionProvider>(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          const Text('Más', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),

          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: SwitchListTile(
              title: const Text('Modo oscuro', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(themeProvider.isDarkMode ? 'Activado' : 'Desactivado'),
              secondary: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppConstants.primaryColor,
              ),
              value: themeProvider.isDarkMode,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 20),

          _MoreItem(
            icon: Icons.point_of_sale,
            color: AppConstants.warningColor,
            title: 'Cierre de caja diario',
            subtitle: 'Resumen del día y arqueo de caja',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CashClosingPage())),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.people_alt,
            color: AppConstants.secondaryColor,
            title: 'Clientes y Fiado',
            subtitle: 'Cuentas corrientes y cobros pendientes',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomersPage())),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.receipt_long,
            color: AppConstants.primaryColor,
            title: 'Historial de Ventas',
            subtitle: 'Registro completo de transacciones',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesPage())),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.trending_up,
            color: AppConstants.successColor,
            title: 'Rentabilidad',
            subtitle: 'Márgenes y ganancia potencial',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfitabilityPage(products: _products)),
            ),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.settings,
            color: AppConstants.primaryColor,
            title: 'Configuración',
            subtitle: 'Apariencia, inventario, backup y Mercado Pago',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
          ),
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.refresh,
            color: AppConstants.warningColor,
            title: 'Recargar Datos',
            subtitle: 'Vuelve a leer productos y ventas guardadas',
            onTap: _load,
          ),
          if (session.isAdmin || session.hasPermission(Permission.gestionarEmpleados)) ...[
            const SizedBox(height: 12),
            _MoreItem(
              icon: Icons.admin_panel_settings,
              color: AppConstants.secondaryColor,
              title: 'Panel de administración',
              subtitle: 'Crear y gestionar usuarios del kiosco',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelPage())),
            ),
          ],
          const SizedBox(height: 12),
          _MoreItem(
            icon: Icons.logout,
            color: AppConstants.errorColor,
            title: 'Cerrar sesión',
            subtitle: session.currentUser?.displayName ?? '',
            onTap: () async {
              await session.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
