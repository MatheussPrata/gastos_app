import 'package:drift/drift.dart' show Variable;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/notifications/local_notifications_client.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';
import 'package:gastos_app/features/recurring/utils/recurring_dates.dart';
import 'package:gastos_app/features/transactions/utils/reminder_schedule.dart';

/// Lembretes de vencimento agendados no proprio aparelho.
///
/// Gerencia avisos para:
/// 1. Transacoes com "Lembrar de pagar" ativado
/// 2. Transacoes recorrentes ativas
/// 3. Faturas de cartoes de credito ativos (ainda nao marcadas como pagas)
///
/// A antecedencia e uma preferencia global (ver [leadDays] / [setLeadDays]).
class TransactionReminderService {
  TransactionReminderService._();

  static final TransactionReminderService instance =
      TransactionReminderService._();

  static const _leadDaysKey = 'reminder_lead_days';

  LocalNotificationsClient get _client => LocalNotificationsClient.instance;

  int _leadDays = ReminderSchedule.defaultLeadDays;
  bool _preferencesLoaded = false;

  /// Antecedencia configurada, em dias.
  int get leadDays => _leadDays;

  // --------------------------------------------------- deterministic IDs
  // Bits 30..29 = 00 garantem zero colisao com ReminderSchedule (0x40000000 / 0x20000000).
  static int recurringAdvanceNotificationId(String recurringId) =>
      (recurringId.hashCode & 0x03FFFFFF) | 0x04000000;

  static int recurringDueDayNotificationId(String recurringId) =>
      (recurringId.hashCode & 0x03FFFFFF) | 0x08000000;

  static int creditCardAdvanceNotificationId(String cardId) =>
      (cardId.hashCode & 0x03FFFFFF) | 0x0C000000;

  static int creditCardDueDayNotificationId(String cardId) =>
      (cardId.hashCode & 0x03FFFFFF) | 0x10000000;

  /// Calcula a proxima ocorrencia util de uma recorrencia a partir de [now].
  static DateTime? resolveNextRecurringDueDate({
    required DateTime nextDueDate,
    required String frequency,
    required DateTime now,
    DateTime? endDate,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    var candidate = DateTime(
      nextDueDate.year,
      nextDueDate.month,
      nextDueDate.day,
    );

    var safety = 0;
    while (candidate.isBefore(today) && safety < 500) {
      candidate = RecurringDates.nextDue(candidate, frequency);
      candidate = DateTime(candidate.year, candidate.month, candidate.day);
      safety++;
    }

    // Se e hoje mas o horario das 09:00 ja passou, aponta para o proximo ciclo.
    if (!ReminderSchedule.dueDayAt(candidate).isAfter(now)) {
      final next = RecurringDates.nextDue(candidate, frequency);
      candidate = DateTime(next.year, next.month, next.day);
    }

    if (endDate != null) {
      final endDay = DateTime(endDate.year, endDate.month, endDate.day);
      if (candidate.isAfter(endDay)) return null;
    }

    return candidate;
  }

  /// Calcula o proximo dia de vencimento de fatura nao paga para um cartao.
  static DateTime? resolveNextCreditCardDueDate({
    required int dueDay,
    required DateTime now,
    Set<String> paidYearMonths = const {},
  }) {
    final safeDay = dueDay.clamp(1, 31);
    for (var monthOffset = 0; monthOffset < 3; monthOffset++) {
      final targetMonth = DateTime(now.year, now.month + monthOffset, 1);
      final key = '${targetMonth.year}_${targetMonth.month}';
      if (paidYearMonths.contains(key)) continue;

      final maxDays =
          DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
      final effectiveDay = safeDay > maxDays ? maxDays : safeDay;
      final candidate =
          DateTime(targetMonth.year, targetMonth.month, effectiveDay);

      if (ReminderSchedule.dueDayAt(candidate).isAfter(now)) {
        return candidate;
      }
    }
    return null;
  }

  /// Configura o plugin, o fuso horario e carrega a preferencia de antecedencia.
  Future<void> initialize() async {
    await _loadPreferences();
    await _client.ensureInitialized();
  }

  Future<void> _loadPreferences() async {
    if (_preferencesLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(_leadDaysKey);
      if (stored != null && ReminderSchedule.leadDayOptions.contains(stored)) {
        _leadDays = stored;
      }
      _preferencesLoaded = true;
    } catch (_) {
      // Sem preferencia guardada: mantem o padrao.
    }
  }

  /// Grava a antecedencia escolhida nas configuracoes.
  Future<void> setLeadDays(int days) async {
    _leadDays = days;
    _preferencesLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_leadDaysKey, days);
    } catch (_) {}
  }

  /// Pede as permissoes necessarias para os lembretes chegarem.
  Future<void> requestPermissions() async {
    try {
      await _client.ensureInitialized();
      final android = _client.android;
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Versoes antigas do Android nao precisam destas permissoes.
    }
  }

  /// Agenda os avisos de uma transacao conforme a antecedencia atual.
  ///
  /// Quando [allowSameDayFallback] e verdadeiro (gravacao direta pelo
  /// utilizador) e a conta vence hoje depois das 09:00, agenda um lembrete
  /// para dali a 1 minuto em vez de descartar silenciosamente.
  Future<void> schedule({
    required String transactionId,
    required String description,
    required double amount,
    required bool isExpense,
    required DateTime dueDate,
    required bool enabled,
    required DateTime now,
    bool allowSameDayFallback = false,
  }) async {
    await initialize();
    if (!_client.isInitialized) return;

    await cancel(transactionId);
    if (!enabled) return;

    var reminders = ReminderSchedule.forTransaction(
      dueDate: dueDate,
      leadDays: _leadDays,
      now: now,
    );

    if (reminders.isEmpty &&
        allowSameDayFallback &&
        dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day) {
      reminders = [
        ScheduledReminder(
          kind: ReminderKind.dueDay,
          at: now.add(const Duration(minutes: 1)),
        ),
      ];
    }

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
        payload: 'transaction:$transactionId',
      );
    }
  }

  /// Remove os avisos agendados de [transactionId].
  Future<void> cancel(String transactionId) async {
    if (!_client.isInitialized) {
      await _client.ensureInitialized();
      if (!_client.isInitialized) return;
    }
    try {
      await _client.plugin
          .cancel(ReminderSchedule.advanceNotificationId(transactionId));
      await _client.plugin
          .cancel(ReminderSchedule.dueDayNotificationId(transactionId));
    } catch (_) {}
  }

  /// Agenda avisos para uma transacao recorrente ativa.
  Future<void> scheduleRecurring({
    required String recurringId,
    required String description,
    required double amount,
    required bool isExpense,
    required String frequency,
    required DateTime nextDueDate,
    DateTime? endDate,
    required bool isActive,
    DateTime? now,
  }) async {
    await initialize();
    if (!_client.isInitialized) return;

    await cancelRecurring(recurringId);
    if (!isActive) return;

    final currentNow = now ?? DateTime.now();
    final effectiveDue = resolveNextRecurringDueDate(
      nextDueDate: nextDueDate,
      frequency: frequency,
      now: currentNow,
      endDate: endDate,
    );
    if (effectiveDue == null) return;

    final reminders = ReminderSchedule.forTransaction(
      dueDate: effectiveDue,
      leadDays: _leadDays,
      now: currentNow,
    );

    for (final reminder in reminders) {
      final isDueDay = reminder.kind == ReminderKind.dueDay;
      await _show(
        id: isDueDay
            ? recurringDueDayNotificationId(recurringId)
            : recurringAdvanceNotificationId(recurringId),
        at: reminder.at,
        title: isDueDay
            ? (isExpense
                ? 'Conta recorrente vence hoje'
                : 'Recebimento recorrente hoje')
            : (isExpense
                ? 'Conta recorrente • ${ReminderSchedule.advanceDescription(_leadDays).toLowerCase()}'
                : 'Recebimento recorrente • ${ReminderSchedule.advanceDescription(_leadDays).toLowerCase()}'),
        body: '$description • ${_formatAmount(amount)}',
        payload: 'recurring:$recurringId',
      );
    }
  }

  /// Remove os avisos agendados de [recurringId].
  Future<void> cancelRecurring(String recurringId) async {
    if (!_client.isInitialized) {
      await _client.ensureInitialized();
      if (!_client.isInitialized) return;
    }
    try {
      await _client.plugin
          .cancel(recurringAdvanceNotificationId(recurringId));
      await _client.plugin
          .cancel(recurringDueDayNotificationId(recurringId));
    } catch (_) {}
  }

  /// Agenda avisos para o proximo vencimento da fatura de um cartao ativo.
  Future<void> scheduleCreditCard({
    required String cardId,
    required String cardName,
    required int dueDay,
    required bool isActive,
    double invoiceAmount = 0,
    Set<String> paidYearMonths = const {},
    DateTime? now,
  }) async {
    await initialize();
    if (!_client.isInitialized) return;

    await cancelCreditCard(cardId);
    if (!isActive) return;

    final currentNow = now ?? DateTime.now();
    final dueDate = resolveNextCreditCardDueDate(
      dueDay: dueDay,
      now: currentNow,
      paidYearMonths: paidYearMonths,
    );
    if (dueDate == null) return;

    final reminders = ReminderSchedule.forTransaction(
      dueDate: dueDate,
      leadDays: _leadDays,
      now: currentNow,
    );

    final dayLabel =
        '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}';
    final body = invoiceAmount > 0
        ? 'Fatura de ${_formatAmount(invoiceAmount)} • Vencimento $dayLabel'
        : 'Fatura do cartão $cardName • Vencimento $dayLabel';

    for (final reminder in reminders) {
      final isDueDay = reminder.kind == ReminderKind.dueDay;
      await _show(
        id: isDueDay
            ? creditCardDueDayNotificationId(cardId)
            : creditCardAdvanceNotificationId(cardId),
        at: reminder.at,
        title: isDueDay
            ? 'Fatura $cardName vence hoje'
            : 'Fatura $cardName • ${ReminderSchedule.advanceDescription(_leadDays).toLowerCase()}',
        body: body,
        payload: 'credit_card:$cardId',
      );
    }
  }

  /// Remove os avisos agendados de [cardId].
  Future<void> cancelCreditCard(String cardId) async {
    if (!_client.isInitialized) {
      await _client.ensureInitialized();
      if (!_client.isInitialized) return;
    }
    try {
      await _client.plugin.cancel(creditCardAdvanceNotificationId(cardId));
      await _client.plugin.cancel(creditCardDueDayNotificationId(cardId));
    } catch (_) {}
  }

  /// Reagenda todas as transacoes que tem lembrete ligado.
  Future<void> rescheduleAll(
    Iterable<
            ({
              String id,
              String description,
              double amount,
              bool isExpense,
              DateTime dueDate
            })>
        transactions,
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

  /// Sincroniza com o sistema operativo todos os lembretes ativos do banco:
  /// transacoes marcadas, recorrencias ativas e faturas de cartao em aberto.
  Future<void> syncAllFromDatabase(db.AppDatabase database) async {
    await initialize();
    if (!_client.isInitialized) return;

    final now = DateTime.now();

    try {
      final txRows = await (database.select(database.transactions)
            ..where((t) => t.reminderEnabled.equals(true)))
          .get();
      for (final row in txRows) {
        await schedule(
          transactionId: row.id,
          description: row.description,
          amount: row.amount,
          isExpense: row.isExpense,
          dueDate: row.date,
          enabled: row.isExpense && row.reminderEnabled,
          now: now,
        );
      }
    } catch (error) {
      debugPrint('Falha ao sincronizar lembretes de transacoes: $error');
    }

    try {
      final recurringRows =
          await database.select(database.recurringTransactions).get();
      for (final row in recurringRows) {
        await scheduleRecurring(
          recurringId: row.id,
          description: row.description,
          amount: row.amount,
          isExpense: row.type == 'expense',
          frequency: row.frequency,
          nextDueDate: row.nextDueDate,
          endDate: row.endDate,
          isActive: row.isActive,
          now: now,
        );
      }
    } catch (error) {
      debugPrint('Falha ao sincronizar lembretes recorrentes: $error');
    }

    try {
      final cards = await database.select(database.creditCards).get();
      final settings = await database.select(database.appSettings).get();
      final settingsMap = {for (final s in settings) s.key: s.value};

      for (final card in cards) {
        if (!card.isActive) {
          await cancelCreditCard(card.id);
          continue;
        }

        final paidPrefix = 'card_invoice_paid_${card.id}_';
        final paidMonths = <String>{
          for (final entry in settingsMap.entries)
            if (entry.key.startsWith(paidPrefix) && entry.value == 'true')
              entry.key.substring(paidPrefix.length),
        };

        final nextDue = resolveNextCreditCardDueDate(
          dueDay: card.dueDay,
          now: now,
          paidYearMonths: paidMonths,
        );

        var invoiceAmount = 0.0;
        if (nextDue != null) {
          final manualKey =
              'card_invoice_${card.id}_${nextDue.year}_${nextDue.month}';
          final manualAmount =
              double.tryParse(settingsMap[manualKey] ?? '') ?? 0.0;
          if (manualAmount > 0) {
            invoiceAmount = manualAmount;
          } else {
            final range = CreditCardCycleHelper.invoiceDateRange(
              invoiceMonth: DateTime(nextDue.year, nextDue.month, 1),
              closingDay: card.closingDay,
            );
            final sumRow = await database
                .customSelect(
                  'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions '
                  'WHERE credit_card_id = ? AND is_expense = 1 '
                  'AND date >= ? AND date <= ?',
                  variables: [
                    Variable.withString(card.id),
                    Variable.withDateTime(range.start),
                    Variable.withDateTime(range.end),
                  ],
                  readsFrom: {database.transactions},
                )
                .getSingleOrNull();
            invoiceAmount = sumRow?.read<double>('total') ?? 0.0;
          }
        }

        await scheduleCreditCard(
          cardId: card.id,
          cardName: card.name,
          dueDay: card.dueDay,
          isActive: card.isActive,
          invoiceAmount: invoiceAmount,
          paidYearMonths: paidMonths,
          now: now,
        );
      }
    } catch (error) {
      debugPrint('Falha ao sincronizar lembretes de cartoes: $error');
    }
  }

  Future<void> _show({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _client.ensureTimezone();
    final when = tz.TZDateTime.from(at, tz.local);

    // Alarme exato entrega na hora escolhida, mas o Android 14+ pode negar a
    // permissao. Nesse caso cai para o modo inexato, que ainda entrega no dia.
    for (final mode in const [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _client.plugin.zonedSchedule(
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
          LocalNotificationsClient.remindersChannelId,
          LocalNotificationsClient.remindersChannelName,
          channelDescription:
              LocalNotificationsClient.remindersChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: LocalNotificationsClient.smallIcon,
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
