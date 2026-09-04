import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  double _fontSize = 1.0;
  static const String _themeKey = 'isDarkMode';
  static const String _fontSizeKey = 'fontSize';

  bool get isDarkMode => _isDarkMode;
  double get fontSize => _fontSize;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 1.0;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black87,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppConstants.glassFillLight,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(color: AppConstants.glassBorderLight, width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white.withOpacity(0.92),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFFAFAFE),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: BorderSide.none,
          ),
        ),
        textTheme: _getTextTheme(Brightness.light),
      );

  ThemeData get darkTheme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppConstants.glassFillDark,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            side: BorderSide(color: AppConstants.glassBorderDark, width: 1),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF181626).withOpacity(0.96),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF15131F),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            borderSide: BorderSide.none,
          ),
        ),
        textTheme: _getTextTheme(Brightness.dark),
      );

  TextTheme _getTextTheme(Brightness brightness) {
    final baseTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(fontSize: 57 * _fontSize),
      displayMedium: baseTheme.displayMedium?.copyWith(fontSize: 45 * _fontSize),
      displaySmall: baseTheme.displaySmall?.copyWith(fontSize: 36 * _fontSize),
      headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 32 * _fontSize),
      headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 28 * _fontSize),
      headlineSmall: baseTheme.headlineSmall?.copyWith(fontSize: 24 * _fontSize),
      titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 22 * _fontSize),
      titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 16 * _fontSize),
      titleSmall: baseTheme.titleSmall?.copyWith(fontSize: 14 * _fontSize),
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: 16 * _fontSize),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: 14 * _fontSize),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: 12 * _fontSize),
      labelLarge: baseTheme.labelLarge?.copyWith(fontSize: 14 * _fontSize),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: 12 * _fontSize),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: 11 * _fontSize),
    );
  }
}