import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Cliente centralizado para `flutter_local_notifications`.
///
/// Garante uma única instância do plugin inicializada em todo o app, registra
/// explicitamente os canais de alta prioridade no Android 8+ e prepara o fuso
/// horário local com fallback seguro para `America/Sao_Paulo`.
class LocalNotificationsClient {
  LocalNotificationsClient._();

  static final LocalNotificationsClient instance = LocalNotificationsClient._();

  static const String smallIcon = 'ic_stat_budget';

  static const String budgetChannelId = 'budget_alerts';
  static const String budgetChannelName = 'Alertas de orçamento';
  static const String budgetChannelDescription =
      'Avisos quando uma categoria atinge o limite definido no planejamento.';

  static const String remindersChannelId = 'transaction_reminders';
  static const String remindersChannelName = 'Lembretes de vencimento';
  static const String remindersChannelDescription =
      'Avisos antes e no dia do vencimento de contas, recorrências e faturas.';

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;
  Future<bool>? _initializing;

  bool get isInitialized => _initialized;

  AndroidFlutterLocalNotificationsPlugin? get android =>
      plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Inicializa o plugin, cria os canais Android e configura o timezone.
  Future<bool> ensureInitialized() {
    if (_initialized) {
      return ensureTimezone().then((_) => true);
    }
    final running = _initializing;
    if (running != null) return running;

    final future = _doInitialize();
    _initializing = future;
    return future.whenComplete(() => _initializing = null);
  }

  Future<bool> _doInitialize() async {
    if (kIsWeb) return false;

    const androidSettings = AndroidInitializationSettings(smallIcon);
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      await plugin.initialize(settings);
      _initialized = true;
    } catch (error) {
      debugPrint('Falha ao inicializar notificacoes locais: $error');
      _initialized = false;
      return false;
    }

    await _registerAndroidChannels();
    await ensureTimezone();
    return true;
  }

  Future<void> _registerAndroidChannels() async {
    try {
      final androidPlugin = android;
      if (androidPlugin == null) return;

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          remindersChannelId,
          remindersChannelName,
          description: remindersChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          budgetChannelId,
          budgetChannelName,
          description: budgetChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (error) {
      debugPrint('Falha ao registrar canais de notificacao: $error');
    }
  }

  /// Garante que o banco de fusos horários e `tz.local` estejam prontos.
  Future<void> ensureTimezone() async {
    if (_timezoneReady) return;
    try {
      tz_data.initializeTimeZones();
    } catch (_) {}

    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _timezoneReady = true;
      return;
    } catch (error) {
      debugPrint('Fallback de fuso horario para America/Sao_Paulo: $error');
    }

    try {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      _timezoneReady = true;
    } catch (_) {
      _timezoneReady = false;
    }
  }
}
