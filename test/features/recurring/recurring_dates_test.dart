import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/recurring/utils/recurring_dates.dart';

void main() {
  group('RecurringDates.nextDue', () {
    test('diaria adiciona 1 dia', () {
      final start = DateTime(2026, 11, 3, 12, 30);
      expect(RecurringDates.nextDue(start, 'daily'),
          DateTime(2026, 11, 4, 12, 30));
    });

    test('semanal adiciona 7 dias', () {
      final start = DateTime(2026, 11, 3);
      expect(RecurringDates.nextDue(start, 'weekly'), DateTime(2026, 11, 10));
    });

    test('mensal preserva o dia do mes', () {
      final start = DateTime(2026, 11, 15);
      expect(RecurringDates.nextDue(start, 'monthly'), DateTime(2026, 12, 15));
    });

    test('mensal vira o ano em dezembro', () {
      final start = DateTime(2026, 12, 15);
      expect(RecurringDates.nextDue(start, 'monthly'), DateTime(2027, 1, 15));
    });

    test('mensal ajusta dia 31 para o ultimo dia do mes', () {
      expect(
        RecurringDates.nextDue(DateTime(2026, 1, 31), 'monthly'),
        DateTime(2026, 2, 28),
      );
      // 2028 e bissexto.
      expect(
        RecurringDates.nextDue(DateTime(2028, 1, 31), 'monthly'),
        DateTime(2028, 2, 29),
      );
    });

    test('anual adiciona 1 ano', () {
      final start = DateTime(2026, 11, 3);
      expect(RecurringDates.nextDue(start, 'yearly'), DateTime(2027, 11, 3));
    });
  });

  group('RecurringDates.frequencyLabel', () {
    test('mapeia as frequencias conhecidas', () {
      expect(RecurringDates.frequencyLabel('daily'), 'Diaria');
      expect(RecurringDates.frequencyLabel('weekly'), 'Semanal');
      expect(RecurringDates.frequencyLabel('monthly'), 'Mensal');
      expect(RecurringDates.frequencyLabel('yearly'), 'Anual');
    });

    test('mantem valores desconhecidos', () {
      expect(RecurringDates.frequencyLabel('bimonthly'), 'bimonthly');
    });
  });
}
