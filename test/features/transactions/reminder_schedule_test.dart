import 'package:flutter_test/flutter_test.dart';

import 'package:gastos_app/features/transactions/utils/reminder_schedule.dart';

void main() {
  group('ReminderSchedule', () {
    test('usa 09:00 do dia do vencimento como sugestao', () {
      final due = DateTime(2026, 11, 20, 18, 45);
      final reminder = ReminderSchedule.atDefaultTime(due);

      expect(reminder.year, 2026);
      expect(reminder.month, 11);
      expect(reminder.day, 20);
      expect(reminder.hour, 9);
      expect(reminder.minute, 0);
    });

    test('so agenda datas futuras', () {
      final now = DateTime(2026, 11, 6, 12);

      expect(ReminderSchedule.isSchedulable(null, now), isFalse);
      expect(
        ReminderSchedule.isSchedulable(DateTime(2026, 11, 6, 11, 59), now),
        isFalse,
      );
      expect(
        ReminderSchedule.isSchedulable(DateTime(2026, 11, 6, 12, 1), now),
        isTrue,
      );
      expect(
        ReminderSchedule.isSchedulable(DateTime(2026, 11, 20, 9), now),
        isTrue,
      );
    });

    test('descreve a data com dois digitos', () {
      expect(
        ReminderSchedule.describe(DateTime(2026, 11, 20, 9, 5)),
        '20/11/2026 as 09:05',
      );
      expect(
        ReminderSchedule.describe(DateTime(2027, 1, 2, 14, 30)),
        '02/01/2027 as 14:30',
      );
    });
  });
}
