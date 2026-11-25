import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/notifications/notification_permission_service.dart';
import 'package:gastos_app/core/notifications/notification_permissions_provider.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/planning/services/notification_service.dart';
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

  /// Grava a nova antecedencia e reagenda transacoes, recorrencias e faturas.
  Future<void> setLeadDays(int days) async {
    state = days;
    await TransactionReminderService.instance.setLeadDays(days);
    await TransactionReminderService.instance
        .syncAllFromDatabase(db.AppDatabase());
  }
}

final reminderLeadDaysProvider =
    StateNotifierProvider<ReminderLeadDaysNotifier, int>(
  (ref) => ReminderLeadDaysNotifier(),
);

/// Configuracoes das notificacoes do app.
class NotificationSettingsPage extends ConsumerStatefulWidget {
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
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage>
    with WidgetsBindingObserver {
  bool _sendingTest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(notificationPermissionsProvider);
      unawaited(
        TransactionReminderService.instance
            .syncAllFromDatabase(db.AppDatabase()),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    if (_sendingTest) return;
    setState(() => _sendingTest = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      var permissions = await NotificationPermissionService.instance.check();
      if (!permissions.canNotify) {
        permissions = await NotificationPermissionService.instance.request();
        if (mounted) {
          ref.invalidate(notificationPermissionsProvider);
        }
      }

      if (!permissions.canNotify) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Permita as notificações nas configurações do aparelho para testar.',
            ),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () {
                NotificationPermissionService.instance.openSystemSettings();
              },
            ),
          ),
        );
        return;
      }

      final sent = await NotificationService.instance.showTestNotification();
      unawaited(
        TransactionReminderService.instance
            .syncAllFromDatabase(db.AppDatabase()),
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            sent
                ? 'Notificação de teste enviada! Verifique a barra do aparelho.'
                : 'Não foi possível enviar a notificação neste aparelho.',
          ),
          backgroundColor: sent ? AppColors.income : AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadDays = ref.watch(reminderLeadDaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PermissionsSection(),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.notifications_active,
                color: AppColors.primary,
              ),
              title: const Text('Testar notificações'),
              subtitle: const Text(
                'Envia um aviso imediato para confirmar que o aparelho está exibindo notificações.',
              ),
              trailing: FilledButton.tonal(
                onPressed: _sendingTest ? null : _sendTestNotification,
                child: _sendingTest
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Testar'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Lembretes de vencimento',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Valem para transações marcadas com "Lembrar de pagar", contas '
            'recorrentes ativas e faturas de cartão em aberto. '
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
                    title: Text(
                      NotificationSettingsPage._labels[days] ??
                          '$days dias antes',
                    ),
                    onChanged: (value) async {
                      if (value == null || value == leadDays) return;
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(reminderLeadDaysProvider.notifier)
                          .setLeadDays(value);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Lembretes atualizados: ${NotificationSettingsPage._labels[value]}',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(
                Icons.schedule_outlined,
                color: AppColors.primary,
              ),
              title: Text('Horário dos avisos'),
              subtitle: Text(
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
                        if (result.canNotify) {
                          unawaited(
                            TransactionReminderService.instance
                                .syncAllFromDatabase(db.AppDatabase()),
                          );
                        } else {
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
        ],
      ),
    );
  }

  String _statusText() {
    return switch (permissions.status) {
      NotificationPermissionStatus.granted =>
        'Os lembretes chegam no dia, no horário aproximado definido.',
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
