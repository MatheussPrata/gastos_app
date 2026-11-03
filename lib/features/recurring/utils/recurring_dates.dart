/// Utilitarios de datas e rotulos para transacoes recorrentes.
class RecurringDates {
  /// Proxima ocorrencia apos [start] conforme a frequencia.
  ///
  /// 'mensal' preserva o dia do mes quando possivel (31/01 -> 28/02 ou 29/02).
  static DateTime nextDue(DateTime start, String frequency) {
    final day = start.day;
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
        return DateTime(start.year + 1, start.month, day);
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
