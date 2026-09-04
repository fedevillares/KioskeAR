import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/app_navigation.dart';
import '../widgets/glass_container.dart';
import 'home_page.dart';
import 'inventory_tab.dart';
import 'reports_tab.dart';
import 'more_tab.dart';

/// Shell principal de la app: mantiene una barra de navegación inferior
/// fija (estilo "liquid glass") mientras conmuta entre las secciones
/// principales usando IndexedStack, para que cada pestaña preserve su
/// estado al cambiar de pantalla.
class AppShell extends StatefulWidget {
  const AppShell({Key? key}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomePage(),
    InventoryTab(),
    ReportsTab(),
    MoreTab(),
  ];

  final List<_NavItem> _items = const [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.inventory_2_rounded, label: 'Inventario'),
    _NavItem(icon: Icons.bar_chart_rounded, label: 'Reportes'),
    _NavItem(icon: Icons.more_horiz_rounded, label: 'Más'),
  ];

  @override
  void initState() {
    super.initState();
    AppNavigation.requestedTabIndex.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    AppNavigation.requestedTabIndex.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final requested = AppNavigation.requestedTabIndex.value;
    if (requested != null && mounted) {
      setState(() => _currentIndex = requested);
      AppNavigation.requestedTabIndex.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: _GlassBottomBar(
          currentIndex: _currentIndex,
          items: _items,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _GlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _GlassBottomBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassContainer(
          blur: AppConstants.glassBlur,
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: AppConstants.fastAnimation,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppConstants.primaryColor.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black54),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
