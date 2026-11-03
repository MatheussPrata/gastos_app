import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';

/// List of active budget alerts with read/dismiss actions.
class PlanningAlertsPage extends ConsumerWidget {
  const PlanningAlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(planningAlertsProvider);
    final unreadCount = ref.watch(unreadAlertCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de orçamento'),
        actions: [
          IconButton(
            tooltip: 'Marcar todos como lidos',
            icon: const Icon(Icons.done_all),
            onPressed: unreadCount == 0
                ? null
                : () => ref.read(planningAlertsProvider.notifier).markAllRead(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(planningAlertsProvider.notifier).load(),
        child: alertsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Icon(Icons.error_outline, size: 56, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Center(child: Text('Erro ao carregar alertas: $error')),
            ],
          ),
          data: (alerts) {
            if (alerts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Nenhum alerta ativo.\nVocê está dentro dos limites.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _AlertTile(
                  alert: alert,
                  onRead: () => ref
                      .read(planningAlertsProvider.notifier)
                      .markRead(alert.id),
                  onDismiss: () => ref
                      .read(planningAlertsProvider.notifier)
                      .dismiss(alert.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.onRead,
    required this.onDismiss,
  });

  final BudgetAlert alert;
  final VoidCallback onRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = _alertColor(alert.threshold);

    return ListTile(
      onTap: alert.read ? null : onRead,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.14),
        child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${alert.categoryName} atingiu ${alert.threshold}%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: alert.read ? FontWeight.w400 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (!alert.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Text(
        '${CurrencyFormatter.format(alert.spentAmount)} de '
        '${CurrencyFormatter.format(alert.allocatedAmount)} • '
        '${DateFormatter.formatDateTime(alert.triggeredAt)}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        tooltip: 'Dispensar',
        icon: const Icon(Icons.close, size: 18),
        onPressed: onDismiss,
      ),
    );
  }

  Color _alertColor(int threshold) {
    if (threshold >= 100) return AppColors.expense;
    if (threshold >= 90) return const Color(0xFFFB8C00);
    return AppColors.warning;
  }
}
