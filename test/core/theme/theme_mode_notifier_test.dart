import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeNotifier', () {
    test('carrega valor persistido e salva alterações no SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final notifier = ThemeModeNotifier();

      // Aguarda leitura assíncrona inicial.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.state, ThemeMode.dark);

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');

      await notifier.setThemeMode(ThemeMode.system);
      expect(notifier.state, ThemeMode.system);
      expect(prefs.getString('theme_mode'), 'system');
    });

    test('usa ThemeMode.system quando não há preferência salva', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = ThemeModeNotifier();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(notifier.state, ThemeMode.system);
    });
  });
}
