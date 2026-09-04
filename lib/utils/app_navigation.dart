import 'package:flutter/foundation.dart';

/// Permite que cualquier tab (ej. el banner de stock bajo en el Dashboard)
/// pida saltar a otra pestaña del AppShell sin tener una referencia directa
/// a su State. AppShell escucha este notifier y actualiza su índice actual.
class AppNavigation {
  static final ValueNotifier<int?> requestedTabIndex = ValueNotifier<int?>(null);

  static const int inicio = 0;
  static const int inventario = 1;
  static const int reportes = 2;
  static const int mas = 3;

  static void goToTab(int index) {
    requestedTabIndex.value = index;
  }
}
