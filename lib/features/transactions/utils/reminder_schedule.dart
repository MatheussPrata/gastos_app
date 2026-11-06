/// Regras puras de agendamento dos lembretes de vencimento.
///
/// Separado do plugin de notificacoes para poder ser testado sem plataforma.
///
/// Modelo: cada transacao com lembrete gera dois avisos — um alguns dias
/// antes e outro no proprio dia do vencimento.
class ReminderSchedule {
  const ReminderSchedule._();

  /// Hora em que os avisos sao entregues.
  static const int notifyHour = 9;
  static const int notifyMinute = 0;

  /// Antecedencias oferecidas nas configuracoes, em dias.
  static const List<int> leadDayOptions = [0, 1, 2, 3, 5, 7];

  /// Valor usado quando o utilizador nunca mexeu nas configuracoes.
  static const int defaultLeadDays = 1;

  /// Ids de notificacao das duas variantes de uma transacao.
  ///
  /// Derivados do id da transacao, por isso reagendar substitui o aviso
  /// anterior em vez de acumular duplicados.
  static int advanceNotificationId(String transactionId) =>
      (transactionId.hashCode & 0x3FFFFFFF) | 0x40000000;

  static int dueDayNotificationId(String transactionId) =>
      (transactionId.hashCode & 0x3FFFFFFF) | 0x20000000;

  /// Momento do aviso antecipado: [leadDays] dias antes do vencimento.
  static DateTime advanceAt(DateTime dueDate, int leadDays) {
    final day = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final target = day.subtract(Duration(days: leadDays));
    return DateTime(
      target.year,
      target.month,
      target.day,
      notifyHour,
      notifyMinute,
    );
  }

  /// Momento do aviso no dia do vencimento.
  static DateTime dueDayAt(DateTime dueDate) => DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        notifyHour,
        notifyMinute,
      );

  /// Agendamentos que ainda fazem sentido para [dueDate].
  ///
  /// Avisos cujo horario ja passou sao omitidos: agendar no passado nunca
  /// dispara e so ocuparia espaco no sistema.
  static List<ScheduledReminder> forTransaction({
    required DateTime dueDate,
    required int leadDays,
    required DateTime now,
  }) {
    final result = <ScheduledReminder>[];

    final dueDay = dueDayAt(dueDate);
    if (dueDay.isAfter(now)) {
      result.add(ScheduledReminder(
        kind: ReminderKind.dueDay,
        at: dueDay,
      ));
    }

    // Com 0 dias de antecedencia o aviso antecipado seria o proprio dia.
    if (leadDays > 0) {
      final advance = advanceAt(dueDate, leadDays);
      if (advance.isAfter(now)) {
        result.add(ScheduledReminder(
          kind: ReminderKind.advance,
          at: advance,
        ));
      }
    }

    return result;
  }

  /// Texto do aviso antecipado, ex.: "Vence em 2 dias".
  static String advanceDescription(int leadDays) {
    if (leadDays <= 1) return 'Vence amanhã';
    return 'Vence em $leadDays dias';
  }

  /// Descricao curta do que esta configurado, para a lista de transacoes.
  static String summarize(int leadDays) {
    if (leadDays <= 0) return 'Aviso no dia';
    if (leadDays == 1) return 'Aviso 1 dia antes e no dia';
    return 'Aviso $leadDays dias antes e no dia';
  }
}

/// Variante de um aviso agendado.
enum ReminderKind { advance, dueDay }

/// Um aviso concreto a agendar no sistema operativo.
class ScheduledReminder {
  const ScheduledReminder({required this.kind, required this.at});

  final ReminderKind kind;
  final DateTime at;
}
