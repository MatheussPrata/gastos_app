import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';
import 'package:gastos_app/features/transactions/utils/reminder_schedule.dart';

/// Preferencia de antecedencia dos lembretes de vencimento.
class ReminderLeadDaysNotifier extends StateNotifier<int> {
  ReminderLeadDaysNotifier() : super(ReminderSchedule.defaultLeadDays) {
    _load();
  }

  Future<void> _load() async {
    await TransactionReminderService.instance.initialize();
    state = TransactionReminderService.instance.leadDays;
  }

  /// Grava a nova antecedencia e reagenda as transacoes que ja tem lembrete.
  Future<void> setLeadDays(int days) async {
    state = days;
    await TransactionReminderService.instance.setLeadDays(days);

    final database = db.AppDatabase();
    final rows = await (database.select(database.transactions)
          ..where((t) => t.reminderEnabled.equals(true)))
        .get();

    await TransactionReminderService.instance.rescheduleAll(
      rows.map((row) => (
            id: row.id,
            description: row.description,
            amount: row.amount,
            isExpense: row.isExpense,
            dueDate: row.date,
          )),
    );
  }
}

final reminderLeadDaysProvider =
    StateNotifierProvider<ReminderLeadDaysNotifier, int>(
  (ref) => ReminderLeadDaysNotifier(),
);

/// Configuracoes das notificacoes do app.
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  static const _labels = {
    0: 'Só no dia do vencimento',
    1: '1 dia antes e no dia',
    2: '2 dias antes e no dia',
    3: '3 dias antes e no dia',
    5: '5 dias antes e no dia',
    7: '7 dias antes e no dia',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadDays = ref.watch(reminderLeadDaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Lembretes de vencimento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Valem para toda transação marcada com "Lembrar de pagar". '
            'Ao mudar, os lembretes já agendados são atualizados.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (final days in ReminderSchedule.leadDayOptions)
                  RadioListTile<int>(
                    value: days,
                    groupValue: leadDays,
                    title: Text(_labels[days] ?? '$days dias antes'),
                    onChanged: (value) async {
                      if (value == null || value == leadDays) return;
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(reminderLeadDaysProvider.notifier)
                          .setLeadDays(value);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Lembretes atualizados: ${_labels[value]}',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined,
                  color: AppColors.primary),
              title: const Text('Horário dos avisos'),
              subtitle: const Text(
                'Os lembretes chegam às 09:00, no fuso do aparelho.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Se o aparelho estiver sem rede ou desligado no horário do aviso, '
            'a notificação aparece assim que ele voltar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
