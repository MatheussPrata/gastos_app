/// Regras puras de agendamento dos lembretes de pagamento.
///
/// Separado do plugin de notificacoes para poder ser testado sem plataforma.
class ReminderSchedule {
  const ReminderSchedule._();

  /// Hora padrao do lembrete quando o utilizador nao escolhe uma.
  static const int defaultHour = 9;
  static const int defaultMinute = 0;

  /// Combina [dueDate] com a hora escolhida, mantendo o dia do vencimento.
  static DateTime atDefaultTime(DateTime dueDate) => DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        defaultHour,
        defaultMinute,
      );

  /// Verdadeiro quando [reminderAt] e futuro e portanto pode ser agendado.
  ///
  /// Notificacoes para horas passadas nunca disparam, por isso sao ignoradas.
  static bool isSchedulable(DateTime? reminderAt, DateTime now) {
    if (reminderAt == null) return false;
    return reminderAt.isAfter(now);
  }

  /// Texto mostrado no formulario e nas listas.
  static String describe(DateTime reminderAt) => '${_twoDigits(reminderAt.day)}'
      '/${_twoDigits(reminderAt.month)}/${reminderAt.year} as '
      '${_twoDigits(reminderAt.hour)}:${_twoDigits(reminderAt.minute)}';

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
