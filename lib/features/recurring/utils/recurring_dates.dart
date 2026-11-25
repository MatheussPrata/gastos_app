/// Utilitarios de datas e rotulos para transacoes recorrentes.
class RecurringDates {
  /// Proxima ocorrencia apos [start] conforme a frequencia.
  ///
  /// 'mensal' e 'anual' preservam [preferredDay] (ou o dia de [start]) quando
  /// possivel, ajustando ao ultimo dia do mes destino (ex.: 31/01 -> 28/02 -> 31/03).
  static DateTime nextDue(
    DateTime start,
    String frequency, {
    int? preferredDay,
  }) {
    final day = preferredDay ?? start.day;
    switch (frequency) {
      case 'daily':
        return start.add(const Duration(days: 1));
      case 'weekly':
        return start.add(const Duration(days: 7));
      case 'monthly':
        final totalMonths = start.month + 1; // 1..12 -> 2..13
        final year = start.year + (totalMonths - 1) ~/ 12;
        final month = (totalMonths - 1) % 12 + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(
          year,
          month,
          day > lastDay ? lastDay : day,
          start.hour,
          start.minute,
        );
      case 'yearly':
        final targetYear = start.year + 1;
        final lastDay = DateTime(targetYear, start.month + 1, 0).day;
        return DateTime(
          targetYear,
          start.month,
          day > lastDay ? lastDay : day,
          start.hour,
          start.minute,
        );
      default:
        return start.add(const Duration(days: 30));
    }
  }

  /// Rotulo amigavel da frequencia.
  static String frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Diaria';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensal';
      case 'yearly':
        return 'Anual';
      default:
        return frequency;
    }
  }
}
