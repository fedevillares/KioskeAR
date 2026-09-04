import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

/// Maneja las categorías propias de cada kiosco, sumadas a las categorías
/// base de la app (Bebidas, Golosinas, Snacks, etc.). Se guardan en
/// SharedPreferences con una clave namespaceada por kioscoId, para que si
/// el mismo dispositivo alguna vez aloja más de un kiosco, no se mezclen.
class CategoryService {
  static String _keyFor(String kioscoId) => 'custom_categories_$kioscoId';
  static String _emojiKeyFor(String kioscoId) => 'custom_category_emojis_$kioscoId';

  /// Categorías personalizadas guardadas para este kiosco (sin incluir
  /// "Todos" ni las categorías base, que siempre están disponibles).
  static Future<List<String>> loadCustom(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_keyFor(kioscoId)) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Emoji elegido para cada categoría personalizada (nombre -> emoji).
  /// Las categorías sin emoji asignado no aparecen en este mapa y caen
  /// al ícono Material por defecto.
  static Future<Map<String, String>> loadEmojis(String kioscoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_emojiKeyFor(kioscoId)) ?? [];
      final map = <String, String>{};
      for (final entry in raw) {
        final sep = entry.indexOf('|');
        if (sep <= 0 || sep == entry.length - 1) continue;
        map[entry.substring(0, sep)] = entry.substring(sep + 1);
      }
      return map;
    } catch (e) {
      return {};
    }
  }

  static Future<void> _saveEmojis(String kioscoId, Map<String, String> emojis) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = emojis.entries.map((e) => '${e.key}|${e.value}').toList();
    await prefs.setStringList(_emojiKeyFor(kioscoId), raw);
  }

  /// Lista completa para mostrar en la UI: "Todos" + base + custom,
  /// sin duplicados y respetando el orden de creación de las custom.
  static Future<List<String>> loadAll(String kioscoId) async {
    final custom = await loadCustom(kioscoId);
    final base = AppConstants.categories; // incluye 'Todos'
    final seen = base.toSet();
    final merged = [...base, ...custom.where((c) => seen.add(c))];
    return merged;
  }

  /// Agrega una categoría nueva para este kiosco. Devuelve false si ya
  /// existe (entre las base o las custom) o si el nombre es inválido.
  /// Si se pasa [emoji], queda asociado a la categoría para mostrarse
  /// en chips y dropdowns en vez del ícono Material genérico.
  static Future<bool> add(String kioscoId, String category, {String? emoji}) async {
    final name = category.trim();
    if (name.isEmpty || name.toLowerCase() == 'todos') return false;

    final existingAll = await loadAll(kioscoId);
    if (existingAll.any((c) => c.toLowerCase() == name.toLowerCase())) {
      return false;
    }

    final custom = await loadCustom(kioscoId);
    custom.add(name);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFor(kioscoId), custom);

    if (emoji != null && emoji.trim().isNotEmpty) {
      final emojis = await loadEmojis(kioscoId);
      emojis[name] = emoji.trim();
      await _saveEmojis(kioscoId, emojis);
    }
    return true;
  }

  /// Quita una categoría personalizada (no se pueden borrar las base).
  static Future<void> remove(String kioscoId, String category) async {
    final custom = await loadCustom(kioscoId);
    custom.removeWhere((c) => c.toLowerCase() == category.trim().toLowerCase());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFor(kioscoId), custom);

    final emojis = await loadEmojis(kioscoId);
    emojis.removeWhere((k, _) => k.toLowerCase() == category.trim().toLowerCase());
    await _saveEmojis(kioscoId, emojis);
  }

  /// Indica si una categoría es personalizada (y por lo tanto se puede
  /// borrar) versus una de las categorías base de la app.
  static bool isCustom(String category) {
    return !AppConstants.categories.contains(category);
  }
}
