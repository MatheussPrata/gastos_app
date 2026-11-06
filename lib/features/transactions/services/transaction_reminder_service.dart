import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Lembretes de pagamento agendados no proprio aparelho.
///
/// Uma notificacao e agendada por transacao que tenha [reminderAt] no futuro.
/// O agendamento vive no sistema operativo, por isso chega mesmo com o app
/// fechado; se o aparelho reiniciar, o plugin reagenda a partir do estado
/// guardado no manifesto.
class TransactionReminderService {
  TransactionReminderService._();

  static final TransactionReminderService instance =
      TransactionReminderService._();

  static const _channelId = 'transaction_reminders';
  static const _channelName = 'Lembretes de pagamento';
  static const _channelDescription =
      'Avisos na data escolhida para pagar uma transacao.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;

  /// Configura o plugin, o fuso horario e pede permissao (Android 13+).
  Future<void> initialize() async {
    if (!_initialized) {
      const android = AndroidInitializationSettings('ic_stat_budget');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      try {
        await _plugin.initialize(settings);
        _initialized = true;
        await _requestPermissions();
      } catch (_) {
        _initialized = false;
        return;
      }
    }

    await _ensureTimezone();
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _timezoneReady = true;
    } catch (_) {
      // Sem fuso resolvido, usa o padrao do pacote (UTC) em vez de falhar.
      try {
        tz_data.initializeTimeZones();
      } catch (_) {}
      _timezoneReady = false;
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // Android 12+ pede permissao separada para alarmes exatos.
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Versoes antigas do Android nao precisam destas permissoes.
    }
  }

  /// Id estavel da notificacao de um lembrete.
  ///
  /// Usa o id da transacao para que reagendar substitua o anterior em vez de
  /// duplicar avisos.
  int notificationIdFor(String transactionId) =>
      transactionId.hashCode & 0x7FFFFFFF;

  /// Agenda (ou reagenda) o lembrete de uma transacao.
  ///
  /// [reminderAt] nulo cancela qualquer lembrete existente.
  Future<void> schedule({
    required String transactionId,
    required String description,
    required double amount,
    required bool isExpense,
    DateTime? reminderAt,
  }) async {
    await initialize();
    if (!_initialized) return;

    await cancel(transactionId);

    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) return;

    final title = isExpense ? 'Hora de pagar' : 'Entrada prevista';
    final body = isExpense
        ? '$description • ${_formatAmount(amount)}'
        : '$description • ${_formatAmount(amount)}';

    final when = tz.TZDateTime.from(reminderAt, tz.local);

    // Alarme exato entrega na hora escolhida, mas o Android 14 pode negar a
    // permissao. Nesse caso cai para o modo inexato, que ainda entrega no dia.
    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          notificationIdFor(transactionId),
          title,
          body,
          when,
          _details(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: transactionId,
        );
        return;
      } catch (_) {
        // Tenta o proximo modo; se todos falharem, nao bloqueia a gravacao.
      }
    }
    debugPrint('Nao foi possivel agendar o lembrete de $transactionId');
  }

  /// Remove o lembrete agendado de [transactionId].
  Future<void> cancel(String transactionId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(notificationIdFor(transactionId));
    } catch (_) {}
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_budget',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

  String _formatAmount(double amount) {
    final value = amount.toStringAsFixed(2).replaceAll('.', ',');
    final parts = value.split(',');
    final reais = parts.first;
    final buffer = StringBuffer();
    for (var i = 0; i < reais.length; i++) {
      if (i > 0 && (reais.length - i) % 3 == 0) buffer.write('.');
      buffer.write(reais[i]);
    }
    return 'R\$ $buffer,${parts.last}';
  }
}
