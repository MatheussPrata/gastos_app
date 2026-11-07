import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';
import 'package:gastos_app/features/transactions/ui/widgets/transaction_tile.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Ler cupom fiscal',
            onPressed: () => context.push(RouteNames.receiptScanner),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('Nenhuma transação cadastrada'));
          }
          return ListView.separated(
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionTile(
                transaction: transaction,
                onTap: () {
                  if (transaction.receiptId != null &&
                      transaction.receiptId!.isNotEmpty) {
                    context.push(
                      RouteNames.receiptDetail,
                      extra: {
                        'receiptId': transaction.receiptId,
                        'transactionId': transaction.id,
                      },
                    );
                  } else {
                    context.push(
                      RouteNames.transactionForm,
                      extra: {'id': transaction.id, 'isEditing': true},
                    );
                  }
                },
                onDelete: () => _confirmDelete(context, ref, transaction),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova transação',
        onPressed: () => context.push(
          RouteNames.transactionForm,
          extra: {'isEditing': false},
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transação'),
        content: Text('Deseja excluir "${transaction.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(transactionsRepositoryProvider)
          .deleteTransaction(transaction.id);
      ref.invalidate(transactionsListProvider);
      ref.invalidate(monthTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);

      // Deleting changes the real spending, so refresh planning and re-check
      // thresholds without blocking the list update.
      ref
        ..invalidate(monthPlanningProvider)
        ..invalidate(planningProgressProvider)
        ..invalidate(planningAlertsProvider)
        ..invalidate(unreadAlertsProvider)
        ..invalidate(monthlyIncomeProvider)
        ..invalidate(incomeAttributionProvider)
        ..invalidate(monthSpentTotalProvider);
      for (final scope in BudgetScope.values) {
        ref.read(planningRepositoryProvider).checkAndCreateAlertsInBackground(
              month: transaction.date,
              scope: scope,
            );
      }
    }
  }
}
