import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/home_widgets/models/home_widget_models.dart';
import 'package:gastos_app/features/home_widgets/services/home_widget_payload_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ponte entre o Flutter e os AppWidgets nativos do Android.
class HomeWidgetService {
  HomeWidgetService._();

  /// Instância global compartilhada pelo app.
  static final HomeWidgetService instance = HomeWidgetService._();

  static const MethodChannel _channel = MethodChannel(
    'com.kuanto.gastos/widgets',
  );

  final StreamController<WidgetLaunchAction> _actionsController =
      StreamController<WidgetLaunchAction>.broadcast();

  Timer? _debounce;
  bool _initialized = false;
  bool _syncInFlight = false;
  bool _syncQueued = false;
  bool _allowNonAndroidForTesting = false;

  /// Stream de ações recebidas quando o usuário toca em um widget com o app aberto.
  Stream<WidgetLaunchAction> get actions => _actionsController.stream;

  bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || _allowNonAndroidForTesting);

  /// Permite simular plataforma Android em testes unitários/de widget no Linux.
  @visibleForTesting
  void setAllowNonAndroidForTesting({required bool enabled}) {
    _allowNonAndroidForTesting = enabled;
    if (!enabled) {
      _debounce?.cancel();
      _debounce = null;
    }
  }

  /// Registra o handler do `MethodChannel` para receber cliques dos widgets.
  Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAction' && call.arguments is Map) {
        final action = WidgetLaunchAction.fromMap(
          call.arguments as Map<Object?, Object?>,
        );
        _actionsController.add(action);
      }
      return null;
    });
  }

  /// Consome a ação de abertura enviada pelo widget no cold start.
  Future<WidgetLaunchAction?> consumeInitialAction() async {
    if (!_isSupported) return null;
    try {
      final raw = await _channel.invokeMethod<dynamic>('consumeInitialAction');
      if (raw is Map) {
        return WidgetLaunchAction.fromMap(raw);
      }
    } catch (_) {}
    return null;
  }

  /// Agenda atualização debounced (300 ms) dos widgets Android.
  ///
  /// Fora do Android (ex.: suíte `flutter test` no Linux), retorna de imediato
  /// sem criar timers pendentes.
  void scheduleSync({
    ThemeMode? themeMode,
    Color? primaryColor,
    bool authenticated = true,
  }) {
    if (!_isSupported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        syncNow(
          themeMode: themeMode,
          primaryColor: primaryColor,
          authenticated: authenticated,
        ),
      );
    });
  }

  /// Recalcula imediatamente o snapshot dos widgets e atualiza a tela inicial.
  Future<void> syncNow({
    ThemeMode? themeMode,
    Color? primaryColor,
    bool authenticated = true,
  }) async {
    if (!_isSupported) return;
    if (_syncInFlight) {
      _syncQueued = true;
      return;
    }

    _syncInFlight = true;
    try {
      final appearance = await _resolveAppearance(
        themeMode: themeMode,
        primaryColor: primaryColor,
      );
      final payload = authenticated
          ? await HomeWidgetPayloadBuilder(database: db.AppDatabase()).build(
              themeMode: appearance.themeMode,
              primaryColor: appearance.primaryColor,
            )
          : HomeWidgetPayloadBuilder.unauthenticatedPayload(
              themeMode: appearance.themeMode,
              primaryColor: appearance.primaryColor,
            );
      await _channel.invokeMethod<bool>(
        'updateWidgetData',
        {'payload': payload},
      );
    } catch (_) {
      // Nunca interrompe o fluxo do app se o launcher/canal estiver indisponível.
    } finally {
      _syncInFlight = false;
      if (_syncQueued) {
        _syncQueued = false;
        unawaited(
          syncNow(
            themeMode: themeMode,
            primaryColor: primaryColor,
            authenticated: authenticated,
          ),
        );
      }
    }
  }

  /// Limpa dados financeiros dos widgets ao sair ou excluir a conta.
  Future<void> clearOnLogout() async {
    if (!_isSupported) return;
    _debounce?.cancel();
    await syncNow(authenticated: false);
  }

  /// Retorna se o usuário escolheu ocultar os valores monetários nos widgets.
  Future<bool> getHideValues() async {
    if (!_isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('getHideValues');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Define se os valores monetários devem ser ocultados nos widgets.
  Future<void> setHideValues({required bool hide}) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>('setHideValues', {'hide': hide});
    } catch (_) {}
  }

  /// Lista os widgets de gráfico ativos atualmente na tela inicial.
  Future<List<ActiveChartWidgetConfig>> getActiveChartWidgets() async {
    if (!_isSupported) return const [];
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('getActiveChartWidgets');
      if (raw == null) return const [];
      final result = <ActiveChartWidgetConfig>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final id = item['widgetId'] as int?;
        if (id == null) continue;
        result.add(
          ActiveChartWidgetConfig(
            widgetId: id,
            chartType: HomeWidgetChartType.fromKey(item['chartType'] as String?),
            period: HomeWidgetPeriod.fromKey(item['period'] as String?),
          ),
        );
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  /// Atualiza a configuração (tipo de gráfico e período) de um widget existente.
  Future<void> configureChartWidget({
    required int widgetId,
    required HomeWidgetChartType chartType,
    required HomeWidgetPeriod period,
  }) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<bool>(
        'configureChartWidget',
        {
          'widgetId': widgetId,
          'chartType': chartType.key,
          'period': period.key,
        },
      );
    } catch (_) {}
  }

  /// Indica se o launcher suporta fixação programática de widgets (Android 8+).
  Future<bool> isPinWidgetSupported() async {
    if (!_isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isPinWidgetSupported');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Solicita ao sistema operacional fixar um widget do tipo [kind].
  Future<bool> requestPinWidget(HomeWidgetKind kind) async {
    if (!_isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestPinWidget',
        {'kind': kind.key},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<({ThemeMode themeMode, Color primaryColor})> _resolveAppearance({
    ThemeMode? themeMode,
    Color? primaryColor,
  }) async {
    if (themeMode != null && primaryColor != null) {
      return (themeMode: themeMode, primaryColor: primaryColor);
    }
    var resolvedMode = themeMode ?? ThemeMode.system;
    var resolvedColor = primaryColor ?? AppColors.primary;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (themeMode == null) {
        resolvedMode = switch (prefs.getString('theme_mode')) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
      }
      if (primaryColor == null) {
        final rawColor = prefs.getInt('theme_primary_color');
        if (rawColor != null) resolvedColor = Color(rawColor);
      }
    } catch (_) {}
    return (themeMode: resolvedMode, primaryColor: resolvedColor);
  }
}
