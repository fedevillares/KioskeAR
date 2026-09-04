/// Permisos granulares que un admin de kiosco puede otorgar a sus
/// empleados. Antes el sistema era binario (admin ve y hace todo, empleado
/// ve y hace todo menos el panel de administración) — esto permite, por
/// ejemplo, que un empleado pueda vender pero no aplicar descuentos, o que
/// pueda ver reportes pero no cerrar caja.
enum Permission {
  gestionarInventario,
  aplicarDescuentos,
  verReportes,
  cerrarCaja,
  gestionarEmpleados,
  eliminarVentas,
}

extension PermissionLabel on Permission {
  String get label {
    switch (this) {
      case Permission.gestionarInventario:
        return 'Agregar y editar productos';
      case Permission.aplicarDescuentos:
        return 'Aplicar ofertas y descuentos';
      case Permission.verReportes:
        return 'Ver reportes y estadísticas';
      case Permission.cerrarCaja:
        return 'Cerrar caja diaria';
      case Permission.gestionarEmpleados:
        return 'Gestionar otros empleados';
      case Permission.eliminarVentas:
        return 'Eliminar productos del inventario';
    }
  }

  String get description {
    switch (this) {
      case Permission.gestionarInventario:
        return 'Crear, editar y escanear productos en Inventario';
      case Permission.aplicarDescuentos:
        return 'Activar el modo oferta en los productos';
      case Permission.verReportes:
        return 'Acceder a la pestaña Reportes y ver el detalle de ventas';
      case Permission.cerrarCaja:
        return 'Confirmar el cierre de caja del día';
      case Permission.gestionarEmpleados:
        return 'Crear, editar permisos o eliminar otros empleados (no admins)';
      case Permission.eliminarVentas:
        return 'Borrar productos existentes del inventario';
    }
  }

  static Permission? fromName(String name) {
    for (final p in Permission.values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Set de permisos por defecto para un empleado recién creado: puede
/// vender y gestionar inventario básico, pero no tocar precios sensibles
/// ni gestionar a otros usuarios. El admin del kiosco puede ampliarlo o
/// restringirlo después desde el panel de administración.
const Map<Permission, bool> defaultEmployeePermissions = {
  Permission.gestionarInventario: true,
  Permission.aplicarDescuentos: false,
  Permission.verReportes: false,
  Permission.cerrarCaja: false,
  Permission.gestionarEmpleados: false,
  Permission.eliminarVentas: false,
};
