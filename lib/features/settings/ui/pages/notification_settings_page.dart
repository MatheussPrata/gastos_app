import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/notifications/notification_permission_service.dart';
import 'package:gastos_app/core/notifications/notification_permissions_provider.dart';
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
          const _PermissionsSection(),
          const SizedBox(height: 24),
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

/// Mostra o estado real das permissoes e oferece a acao adequada.
class _PermissionsSection extends ConsumerWidget {
  const _PermissionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(notificationPermissionsProvider);

    return permissions.when(
      loading: () => const Card(
        child: ListTile(
          leading: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Verificando permissões...'),
        ),
      ),
      error: (_, __) => _ErrorCard(
        onRetry: () => ref.invalidate(notificationPermissionsProvider),
      ),
      data: (status) => _PermissionCard(
        permissions: status,
        onRefresh: () => ref.invalidate(notificationPermissionsProvider),
      ),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard({
    required this.permissions,
    required this.onRefresh,
  });

  final NotificationPermissions permissions;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = permissions.canNotify;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              granted
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              color: granted ? Colors.green : Colors.orange,
            ),
            title: Text(
              granted
                  ? 'Notificações permitidas'
                  : 'Notificações bloqueadas',
            ),
            subtitle: Text(_statusText()),
          ),
          if (!granted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final result =
                            await NotificationPermissionService.instance
                                .request();
                        onRefresh();
                        if (!result.canNotify) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Permissão não concedida. Abra as '
                                'configurações do aparelho para ativar.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text('Permitir'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await NotificationPermissionService.instance
                          .openSystemSettings();
                      onRefresh();
                    },
                    child: const Text('Configurações'),
                  ),
                ],
              ),
            ),
          if (granted && !permissions.canScheduleExact)
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.orange),
              title: const Text('Alarme exato desativado'),
              subtitle: const Text(
                'Os avisos ainda chegam no dia, mas podem atrasar alguns '
                'minutos. Ative "Alarmes e lembretes" nas configurações.',
              ),
              trailing: TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await NotificationPermissionService.instance
                      .requestExactAlarms();
                  onRefresh();
                  if (!result.canScheduleExact) {
                    await NotificationPermissionService.instance
                        .openSystemSettings(exactAlarms: true);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Ative "Alarmes e lembretes" para este app.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Ativar'),
              ),
            ),
        ],
      ),
    );
  }

  String _statusText() {
    return switch (permissions.status) {
      NotificationPermissionStatus.granted => permissions.canScheduleExact
          ? 'Os lembretes chegam no horário definido.'
          : 'Os lembretes chegam no dia, com pequena tolerância.',
      NotificationPermissionStatus.notRequested =>
        'Toque em "Permitir" para receber os lembretes.',
      NotificationPermissionStatus.denied =>
        'Toque em "Permitir" e aceite o pedido do sistema.',
      NotificationPermissionStatus.permanentlyDenied =>
        'Bloqueadas nas configurações do aparelho. Abra as configurações '
            'do app para reativar.',
      NotificationPermissionStatus.unknown =>
        'Não foi possível verificar neste aparelho.',
    };
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.orange),
        title: const Text('Não foi possível verificar as permissões'),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('Tentar'),
        ),
      ),
    );
  }
}
