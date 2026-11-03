import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/recurring/models/recurring_models.dart';
import 'package:gastos_app/features/recurring/provider/recurring_provider.dart';
import 'package:gastos_app/features/recurring/utils/recurring_dates.dart';

/// Lista de transacoes recorrentes (contas fixas, assinaturas, salario...).
class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorrentes'),
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro ao carregar: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(recurringListProvider.notifier)
                    .loadRecurring(forceRefresh: true),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
        data: (recurring) {
          if (recurring.isEmpty) {
            return const _EmptyView();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: recurring.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = recurring[index];
              return _RecurringTile(
                item: item,
                onToggleActive: (value) => ref
                    .read(recurringListProvider.notifier)
                    .updateRecurring(item.copyWith(isActive: value)),
                onEdit: () => context.push(
                  RouteNames.recurringForm,
                  extra: {'id': item.id, 'isEditing': true},
                ),
                onDelete: () => _confirmDelete(context, ref, item),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova recorrência',
        onPressed: () => context.push(
          RouteNames.recurringForm,
          extra: {'isEditing': false},
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir recorrência?'),
        content: Text('"${item.description}" deixará de se repetir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(recurringListProvider.notifier).deleteRecurring(item.id);
    }
  }
}

class _RecurringTile extends StatelessWidget {
  const _RecurringTile({
    required this.item,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final RecurringTransaction item;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == 'expense';
    final color = isExpense ? AppColors.expense : AppColors.income;
    final sign = isExpense ? '-' : '+';

    final subtitle = [
      RecurringDates.frequencyLabel(item.frequency),
      'próxima: ${DateFormatter.formatDayMonthYear(item.nextDueDate)}',
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(38),
          child: Icon(Icons.repeat, color: color),
        ),
        title: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: item.isActive
              ? null
              : TextStyle(
                  color: Theme.of(context).disabledColor,
                  decoration: TextDecoration.lineThrough,
                ),
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sign ${CurrencyFormatter.format(item.amount)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            Switch(
              value: item.isActive,
              onChanged: onToggleActive,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.repeat_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma transação recorrente',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Contas fixas, assinaturas e salário aparecem aqui. '
              'Você também pode marcar "Transação recorrente" ao adicionar '
              'um lançamento.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
