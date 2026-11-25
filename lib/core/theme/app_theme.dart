import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App color palette - matching the Kotlin app colors
class AppColors {
  // Primary colors (modernized)
  static const Color primary = Color(0xFF2563EB); // Blue
  static const Color primaryVariant = Color(0xFF1D4ED8);
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

/// Design tokens do Kuanto v2 — superfícies e acento menta.
abstract final class KuantoColors {
  static const Color mint = Color(0xFF2EC4B6);
  static const Color deepBlue = Color(0xFF0B2545);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color darkBackground = Color(0xFF0A1220);
  static const Color darkSurface = Color(0xFF121B2B);
}

/// Aplica números tabulares (valores de R$ alinhados em coluna).
TextTheme _withTabularFigures(TextTheme t) {
  TextStyle? f(TextStyle? s) =>
      s?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  return t.copyWith(
    displayLarge: f(t.displayLarge),
    displayMedium: f(t.displayMedium),
    displaySmall: f(t.displaySmall),
    headlineLarge: f(t.headlineLarge),
    headlineMedium: f(t.headlineMedium),
    headlineSmall: f(t.headlineSmall),
    titleLarge: f(t.titleLarge),
    titleMedium: f(t.titleMedium),
    titleSmall: f(t.titleSmall),
    bodyLarge: f(t.bodyLarge),
    bodyMedium: f(t.bodyMedium),
    bodySmall: f(t.bodySmall),
    labelLarge: f(t.labelLarge),
    labelMedium: f(t.labelMedium),
    labelSmall: f(t.labelSmall),
  );
}

/// Light theme
ThemeData buildLightTheme(Color seedColor) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ).copyWith(
    primary: seedColor,
    secondary: KuantoColors.mint,
    tertiary: AppColors.tertiary,
    error: AppColors.expense,
    surface: KuantoColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: KuantoColors.background,
    textTheme:
        _withTabularFigures(ThemeData(brightness: Brightness.light).textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: KuantoColors.background,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: scheme.surface,
      shadowColor: Colors.black.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primary.withOpacity(0.08),
      selectedColor: scheme.primary.withOpacity(0.18),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    dialogTheme: const DialogTheme(
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
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ).copyWith(
    primary: seedColor,
    secondary: KuantoColors.mint,
    tertiary: AppColors.tertiary,
    error: AppColors.expense,
    surface: KuantoColors.darkSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: KuantoColors.darkBackground,
    textTheme:
        _withTabularFigures(ThemeData(brightness: Brightness.dark).textTheme),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: KuantoColors.darkBackground,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: scheme.surface,
      shadowColor: Colors.black.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primary.withOpacity(0.12),
      selectedColor: scheme.primary.withOpacity(0.24),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    dialogTheme: DialogTheme(
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

/// Persists and exposes the selected theme mode (`system`, `light`, `dark`).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  static const _prefsKey = 'theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {}
  }
}

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
    (ref) => ThemeModeNotifier());

/// Default themes (blue seed) kept for callers that do not customize colors.
ThemeData get lightTheme => buildLightTheme(AppColors.primary);
ThemeData get darkTheme => buildDarkTheme(AppColors.primary);

/// Colors available for the primary color customization.
const List<Color> kThemeSeedColors = [
  Color(0xFF2563EB), // Azul
  Color(0xFF2EC4B6), // Menta
  Color(0xFF7C3AED), // Violeta
  Color(0xFFF97316), // Laranja
  Color(0xFFDB2777), // Rosa
  Color(0xFF0D9488), // Teal
  Color(0xFF4F46E5), // Índigo
  Color(0xFF78716C), // Pedra
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
