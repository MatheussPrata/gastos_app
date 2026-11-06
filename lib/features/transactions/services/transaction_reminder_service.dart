import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:gastos_app/features/transactions/utils/reminder_schedule.dart';

/// Lembretes de vencimento agendados no proprio aparelho.
///
/// Cada transacao com lembrete gera dois avisos: um [leadDays] dias antes do
/// vencimento e outro no proprio dia. A antecedencia e uma preferencia global
/// (ver [leadDays] / [setLeadDays]).
class TransactionReminderService {
  TransactionReminderService._();

  static final TransactionReminderService instance =
      TransactionReminderService._();

  static const _channelId = 'transaction_reminders';
  static const _channelName = 'Lembretes de vencimento';
  static const _channelDescription =
      'Avisos antes e no dia do vencimento de uma transacao.';

  static const _leadDaysKey = 'reminder_lead_days';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _timezoneReady = false;
  int _leadDays = ReminderSchedule.defaultLeadDays;

  /// Antecedencia configurada, em dias.
  int get leadDays => _leadDays;

  /// Configura o plugin, o fuso horario, pede permissao e carrega a
  /// preferencia de antecedencia.
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

    await _loadPreferences();
    await _ensureTimezone();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_leadDaysKey);
      if (stored != null && ReminderSchedule.leadDayOptions.contains(stored)) {
        _leadDays = stored;
      }
    } catch (_) {
      // Sem preferencia guardada: mantem o padrao.
    }
  }

  /// Grava a antecedencia escolhida nas configuracoes.
  Future<void> setLeadDays(int days) async {
    _leadDays = days;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_leadDaysKey, days);
    } catch (_) {}
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    try {
      tz_data.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      _timezoneReady = true;
    } catch (_) {
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

  /// Agenda os avisos de uma transacao conforme a antecedencia atual.
  Future<void> schedule({
    required String transactionId,
    required String description,
    required double amount,
    required bool isExpense,
    required DateTime dueDate,
    required bool enabled,
    required DateTime now,
  }) async {
    await initialize();
    if (!_initialized) return;

    await cancel(transactionId);
    if (!enabled) return;

    final reminders = ReminderSchedule.forTransaction(
      dueDate: dueDate,
      leadDays: _leadDays,
      now: now,
    );

    for (final reminder in reminders) {
      final isDueDay = reminder.kind == ReminderKind.dueDay;
      await _show(
        id: isDueDay
            ? ReminderSchedule.dueDayNotificationId(transactionId)
            : ReminderSchedule.advanceNotificationId(transactionId),
        at: reminder.at,
        title: isDueDay
            ? (isExpense ? 'Vence hoje' : 'Recebimento hoje')
            : (isExpense
                ? ReminderSchedule.advanceDescription(_leadDays)
                : 'Recebimento ${ReminderSchedule.advanceDescription(_leadDays).toLowerCase()}'),
        body: '$description • ${_formatAmount(amount)}',
        payload: transactionId,
      );
    }
  }

  /// Remove os avisos agendados de [transactionId].
  Future<void> cancel(String transactionId) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(ReminderSchedule.advanceNotificationId(transactionId));
      await _plugin.cancel(ReminderSchedule.dueDayNotificationId(transactionId));
    } catch (_) {}
  }

  /// Reagenda todas as transacoes que tem lembrete ligado.
  ///
  /// Usado quando o utilizador muda a antecedencia nas configuracoes.
  Future<void> rescheduleAll(
    Iterable<({String id, String description, double amount, bool isExpense, DateTime dueDate})> transactions,
  ) async {
    final now = DateTime.now();
    for (final item in transactions) {
      await schedule(
        transactionId: item.id,
        description: item.description,
        amount: item.amount,
        isExpense: item.isExpense,
        dueDate: item.dueDate,
        enabled: true,
        now: now,
      );
    }
  }

  Future<void> _show({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    final when = tz.TZDateTime.from(at, tz.local);

    // Alarme exato entrega na hora escolhida, mas o Android 14 pode negar a
    // permissao. Nesse caso cai para o modo inexato, que ainda entrega no dia.
    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details(),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        return;
      } catch (_) {
        // Tenta o proximo modo; se todos falharem, nao bloqueia o fluxo.
      }
    }
    debugPrint('Nao foi possivel agendar o lembrete $id');
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
