import 'package:flutter/material.dart';

class AppConstants {
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color secondaryColor = Color(0xFF8B5CF6);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color backgroundColor = Color(0xFFF9FAFB);

  // --- Fondos de degradado para el efecto "liquid glass" ---
  static const List<Color> backgroundGradientLight = [
    Color(0xFFEEF0FF),
    Color(0xFFF8F9FF),
    Color(0xFFE9F4FF),
  ];

  static const List<Color> backgroundGradientDark = [
    Color(0xFF0B0B14),
    Color(0xFF121022),
    Color(0xFF0E1420),
  ];

  // --- Superficies de vidrio (glassmorphism) ---
  static Color glassFillLight = Colors.white.withOpacity(0.55);
  static Color glassFillDark = Colors.white.withOpacity(0.06);

  static Color glassBorderLight = Colors.white.withOpacity(0.7);
  static Color glassBorderDark = Colors.white.withOpacity(0.12);

  static Color glassShadowLight = const Color(0xFF6366F1).withOpacity(0.10);
  static Color glassShadowDark = Colors.black.withOpacity(0.45);

  static const double glassBlur = 18.0;
  static const double glassBlurStrong = 26.0;

  static const List<String> categories = [
    'Todos',
    'Bebidas',
    'Golosinas',
    'Snacks',
    'Cigarrillos',
    'Librería',
    'Otros',
  ];

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Bebidas':
        return Icons.local_drink;
      case 'Golosinas':
        return Icons.cake;
      case 'Snacks':
        return Icons.fastfood;
      case 'Cigarrillos':
        return Icons.smoking_rooms;
      case 'Librería':
        return Icons.book;
      case 'Otros':
        return Icons.shopping_bag;
      default:
        return Icons.inventory_2;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'Bebidas':
        return const Color(0xFF3B82F6);
      case 'Golosinas':
        return const Color(0xFFEC4899);
      case 'Snacks':
        return const Color(0xFFF59E0B);
      case 'Cigarrillos':
        return const Color(0xFF6B7280);
      case 'Librería':
        return const Color(0xFF8B5CF6);
      case 'Otros':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
  }

  static const double cardElevation = 2.0;
  static const double padding = 16.0;
  static const double spacing = 8.0;

  // --- Escala fija de radios de borde ---
  // Antes convivían valores sueltos (8, 10, 12, 14, 16, 18, 20...) elegidos
  // ad hoc por cada widget. Esta escala de 3 tamaños cubre todos los casos:
  // radiusSmall para elementos chicos dentro de una tarjeta (chips, botones
  // internos, badges), radiusMedium para tarjetas de contenido (filas,
  // tarjetas de producto/cliente), radiusLarge para contenedores grandes
  // (paneles, diálogos, la barra de navegación).
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 20.0;

  // Alias para no romper código existente que ya usa borderRadius.
  static const double borderRadius = radiusSmall;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration slowAnimation = Duration(milliseconds: 600);

  // --- Texto secundario/terciario adaptativo ---
  // Antes había Colors.grey[600] hardcodeado repetido en decenas de
  // lugares: se ve igual en claro y oscuro, así que en modo oscuro queda
  // plano y sin contraste sobre el fondo glass oscuro. Estos dos tonos
  // reemplazan ese patrón y sí responden al modo actual.
  static const Color textSecondaryLight = Color(0xFF5B6472);
  static const Color textSecondaryDark = Color(0xFFB8BFCC);
  static const Color textTertiaryLight = Color(0xFF8B93A1);
  static const Color textTertiaryDark = Color(0xFF7D8494);
  static const Color dividerLight = Color(0xFFE2E5EC);
  static const Color dividerDark = Color(0xFF2C2A3D);
}

/// Acceso corto a los colores que dependen del Brightness actual, para no
/// repetir "Theme.of(context).brightness == Brightness.dark ? x : y" en
/// cada pantalla. Uso: context.colors.textSecondary
extension AppColorsContext on BuildContext {
  _AppColors get colors => _AppColors(Theme.of(this).brightness == Brightness.dark);
}

class _AppColors {
  final bool isDark;
  const _AppColors(this.isDark);

  Color get textSecondary => isDark ? AppConstants.textSecondaryDark : AppConstants.textSecondaryLight;
  Color get textTertiary => isDark ? AppConstants.textTertiaryDark : AppConstants.textTertiaryLight;
  Color get divider => isDark ? AppConstants.dividerDark : AppConstants.dividerLight;
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF1A1D23);
}