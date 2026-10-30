import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/api/api_providers.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// App entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dio client
  DioClient().init(baseUrl: ApiEndpoints.baseUrl);

  // Initialize database (optional - can be lazy)
  // AppDatabase(); // Singleton, will initialize on first access

  runApp(const ProviderScope(child: GastosApp()));
}

/// Main app widget
class GastosApp extends ConsumerWidget {
  const GastosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Gastos',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final textScaler = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.2,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      },
    );
  }
}