import 'package:flutter_test/flutter_test.dart';

import 'package:gastos_app/features/planning/services/notification_service.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';
import 'package:gastos_app/features/transactions/utils/reminder_schedule.dart';

void main() {
  group('ReminderSchedule', () {
    test('aviso antecipado cai N dias antes as 09:00', () {
      final due = DateTime(2026, 11, 20);

      final advance = ReminderSchedule.advanceAt(due, 1);
      expect(advance.day, 19);
      expect(advance.hour, ReminderSchedule.notifyHour);
      expect(advance.minute, ReminderSchedule.notifyMinute);

      final three = ReminderSchedule.advanceAt(due, 3);
      expect(three.day, 17);
    });

    test('atravessa a fronteira do mes', () {
      final due = DateTime(2026, 12, 1);
      final advance = ReminderSchedule.advanceAt(due, 3);

      expect(advance.month, 11);
      expect(advance.day, 28);
    });

    test('gera aviso antecipado e do dia quando ambos sao futuros', () {
      final reminders = ReminderSchedule.forTransaction(
        dueDate: DateTime(2026, 11, 20),
        leadDays: 2,
        now: DateTime(2026, 11, 6, 12),
      );

      expect(reminders, hasLength(2));
      expect(
        reminders.map((r) => r.kind),
        containsAll([ReminderKind.advance, ReminderKind.dueDay]),
      );
      final advance =
          reminders.firstWhere((r) => r.kind == ReminderKind.advance);
      expect(advance.at.day, 18);
    });

    test('com 0 dias so existe o aviso do dia', () {
      final reminders = ReminderSchedule.forTransaction(
        dueDate: DateTime(2026, 11, 20),
        leadDays: 0,
        now: DateTime(2026, 11, 6, 12),
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.kind, ReminderKind.dueDay);
    });

    test('descarta avisos cujo horario ja passou', () {
      // Vencimento hoje as 09:00 mas ja sao 12:00: o aviso do dia nao serve.
      final reminders = ReminderSchedule.forTransaction(
        dueDate: DateTime(2026, 11, 6),
        leadDays: 1,
        now: DateTime(2026, 11, 6, 12),
      );

      expect(reminders, isEmpty);
    });

    test('conta que vence amanha so agenda o aviso do dia', () {
      final reminders = ReminderSchedule.forTransaction(
        dueDate: DateTime(2026, 11, 7),
        leadDays: 1,
        now: DateTime(2026, 11, 6, 12),
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.kind, ReminderKind.dueDay);
      expect(reminders.single.at.day, 7);
    });

    test('ids de notificacao sao distintos e estaveis', () {
      const id = 'tx-abc';
      final advance = ReminderSchedule.advanceNotificationId(id);
      final dueDay = ReminderSchedule.dueDayNotificationId(id);

      expect(advance, isNot(dueDay));
      expect(advance, ReminderSchedule.advanceNotificationId(id));
      expect(dueDay, ReminderSchedule.dueDayNotificationId(id));
    });

    test('resume a antecedencia para a interface', () {
      expect(ReminderSchedule.summarize(0), 'Aviso no dia');
      expect(ReminderSchedule.summarize(1), 'Aviso 1 dia antes e no dia');
      expect(ReminderSchedule.summarize(3), 'Aviso 3 dias antes e no dia');
      expect(ReminderSchedule.advanceDescription(1), 'Vence amanhã');
      expect(ReminderSchedule.advanceDescription(3), 'Vence em 3 dias');
    });
  });

  group('TransactionReminderService regras puras', () {
    test('ids de notificacao nao colidem entre transacoes, recorrentes, cartoes e orcamento', () {
      const id = 'same-uuid-123';
      final ids = {
        ReminderSchedule.advanceNotificationId(id),
        ReminderSchedule.dueDayNotificationId(id),
        TransactionReminderService.recurringAdvanceNotificationId(id),
        TransactionReminderService.recurringDueDayNotificationId(id),
        TransactionReminderService.creditCardAdvanceNotificationId(id),
        TransactionReminderService.creditCardDueDayNotificationId(id),
        NotificationService.budgetAlertNotificationId(id),
      };

      expect(ids, hasLength(7));
      for (final value in ids) {
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('resolveNextRecurringDueDate avanca ocorrencias passadas e respeita endDate', () {
      final now = DateTime(2026, 11, 25, 14, 0);
      final next = TransactionReminderService.resolveNextRecurringDueDate(
        nextDueDate: DateTime(2026, 9, 10),
        frequency: 'monthly',
        now: now,
      );
      expect(next, DateTime(2026, 12, 10));

      final expired = TransactionReminderService.resolveNextRecurringDueDate(
        nextDueDate: DateTime(2026, 11, 20),
        frequency: 'monthly',
        now: now,
        endDate: DateTime(2026, 12, 1),
      );
      expect(expired, isNull);
    });

    test('resolveNextCreditCardDueDate pula faturas pagas e ajusta fevereiro', () {
      // Antes das 09:00 no dia do vencimento: ainda agenda para este mes
      final earlyMorning = DateTime(2026, 11, 15, 8, 0);
      expect(
        TransactionReminderService.resolveNextCreditCardDueDate(
          dueDay: 15,
          now: earlyMorning,
        ),
        DateTime(2026, 11, 15),
      );

      // Se a fatura de novembro ja foi paga, agenda dezembro
      expect(
        TransactionReminderService.resolveNextCreditCardDueDate(
          dueDay: 15,
          now: earlyMorning,
          paidYearMonths: {'2026_11'},
        ),
        DateTime(2026, 12, 15),
      );

      // Cartao com vencimento dia 31 em fevereiro cai no dia 28
      expect(
        TransactionReminderService.resolveNextCreditCardDueDate(
          dueDay: 31,
          now: DateTime(2026, 2, 1, 10, 0),
        ),
        DateTime(2026, 2, 28),
      );
    });
  });
}
