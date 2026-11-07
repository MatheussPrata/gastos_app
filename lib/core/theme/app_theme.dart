import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App color palette - matching the Kotlin app colors
class AppColors {
  // Primary colors from Kotlin app
  static const Color primary = Color(0xFF1E88E5); // Blue
  static const Color primaryVariant = Color(0xFF1565C0);
  static const Color secondary = Color(0xFF43A047); // Green
  static const Color secondaryVariant = Color(0xFF2E7D32);
  static const Color tertiary = Color(0xFF6750A4); // Purple
  static const Color tertiaryVariant = Color(0xFF4F378B);

  // Semantic colors
  static const Color income = Color(0xFF43A047); // Green for income
  static const Color expense = Color(0xFFE53935); // Red for expense
  static const Color warning = Color(0xFFFFB300); // Amber for warnings
  static const Color info = Color(0xFF1E88E5); // Blue for info

  // Category colors (matching Kotlin app)
  static const List<Color> categoryColors = [
    Color(0xFFFF6B6B), // Alimentação
    Color(0xFF4ECDC4), // Transporte
    Color(0xFFFFD93D), // Compras
    Color(0xFF6BCB77), // Lazer
    Color(0xFFFF8E8E), // Saúde
    Color(0xFFA8E6CF), // Educação
    Color(0xFFFFB347), // Contas
    Color(0xFFB8B8B8), // Outros
  ];
}

/// Light theme
ThemeData buildLightTheme(Color seedColor) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      primary: seedColor,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.expense,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: seedColor, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.expense),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: seedColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: seedColor),
        foregroundColor: seedColor,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: seedColor,
      unselectedItemColor: Colors.grey,
      elevation: 8,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 3,
      backgroundColor: Colors.white,
      indicatorColor: seedColor.withAlpha(38),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected ? seedColor : Colors.grey.shade600,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? seedColor : Colors.grey.shade600,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seedColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade300,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      contentTextStyle: TextStyle(fontSize: 16, color: Colors.black87),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      backgroundColor: Colors.white,
    ),
  );
}

/// Dark theme
ThemeData buildDarkTheme(Color seedColor) {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      primary: seedColor,
      secondary: AppColors.secondary,
      tertiary: AppColors.tertiary,
      error: AppColors.expense,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade900,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: seedColor, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.expense),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: seedColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: seedColor),
        foregroundColor: seedColor,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: seedColor,
      unselectedItemColor: Colors.grey.shade400,
      elevation: 8,
      backgroundColor: Colors.grey.shade900,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 3,
      backgroundColor: Colors.grey.shade900,
      indicatorColor: seedColor.withAlpha(51),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected ? seedColor : Colors.grey.shade400,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? seedColor : Colors.grey.shade400,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seedColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade700,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      contentTextStyle: const TextStyle(fontSize: 16, color: Colors.white70),
      backgroundColor: Colors.grey[850],
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      backgroundColor: Colors.grey[850],
    ),
  );
}

/// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Default themes (blue seed) kept for callers that do not customize colors.
ThemeData get lightTheme => buildLightTheme(AppColors.primary);
ThemeData get darkTheme => buildDarkTheme(AppColors.primary);

/// Colors available for the primary color customization.
const List<Color> kThemeSeedColors = [
  Color(0xFF1E88E5), // Azul
  Color(0xFF43A047), // Verde
  Color(0xFF6750A4), // Roxo
  Color(0xFFFB8C00), // Laranja
  Color(0xFFD81B60), // Rosa
  Color(0xFF00897B), // Teal
  Color(0xFF3949AB), // Índigo
  Color(0xFF6D4C41), // Marrom
];

/// Persists the chosen primary color for the app theme.
class ThemeColorNotifier extends StateNotifier<Color> {
  ThemeColorNotifier() : super(AppColors.primary) {
    _load();
  }

  static const _prefsKey = 'theme_primary_color';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(_prefsKey);
      if (value != null) state = Color(value);
    } catch (_) {}
  }

  Future<void> setColor(Color color) async {
    state = color;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, color.value);
    } catch (_) {}
  }
}

final themeColorProvider = StateNotifierProvider<ThemeColorNotifier, Color>(
    (ref) => ThemeColorNotifier());
