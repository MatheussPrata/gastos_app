import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/dashboard/ui/widgets/settings_drawer.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';
import 'package:gastos_app/features/transactions/ui/widgets/transaction_tile.dart';

const List<String> _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final transactionsAsync = ref.watch(monthTransactionsProvider);

    return Scaffold(
      drawer: const SettingsDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text('Olá, ${user?.username ?? 'Usuário'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Ler cupom fiscal',
            onPressed: () => context.push(RouteNames.receiptScanner),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(context, ref, selectedMonth),
          _buildSummary(context, transactionsAsync),
          Expanded(
            child: _buildTransactionsList(context, ref, transactionsAsync),
          ),
        ],
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

  Widget _buildMonthSelector(
    BuildContext context,
    WidgetRef ref,
    DateTime month,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(ref, -1),
            tooltip: 'Mês anterior',
          ),
          Expanded(
            child: Center(
              child: Text(
                _monthLabel(month),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(ref, 1),
            tooltip: 'Próximo mês',
          ),
        ],
      ),
    );
  }

  void _changeMonth(WidgetRef ref, int delta) {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta, 1);
  }

  String _monthLabel(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  Widget _buildSummary(
    BuildContext context,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Erro ao carregar: $e'),
      ),
      data: (transactions) {
        var income = 0.0;
        var expense = 0.0;
        for (final transaction in transactions) {
          if (transaction.isExpense) {
            expense += transaction.amount;
          } else {
            income += transaction.amount;
          }
        }
        final balance = income - expense;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('Entradas', income, AppColors.income),
                    _summaryItem('Saídas', expense, AppColors.expense),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saldo do mês',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      CurrencyFormatter.format(balance),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            balance >= 0 ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    return transactionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (transactions) {
        if (transactions.isEmpty) {
          return const Center(child: Text('Nenhum lançamento neste mês'));
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
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
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

    if (confirmed != true) return;

    await ref
        .read(transactionsRepositoryProvider)
        .deleteTransaction(transaction.id);

    ref
      ..invalidate(transactionsListProvider)
      ..invalidate(monthTransactionsProvider)
      ..invalidate(monthlyStatsProvider)
      ..invalidate(monthPlanningProvider)
      ..invalidate(planningProgressProvider)
      ..invalidate(planningAlertsProvider)
      ..invalidate(unreadAlertsProvider)
      ..invalidate(monthlyIncomeProvider)
      ..invalidate(incomeAttributionProvider)
      ..invalidate(monthSpentTotalProvider)
      ..invalidate(cardsWithSpentProvider)
      ..invalidate(cardCategorySpendingProvider)
      ..invalidate(cardForecastProvider);

    for (final scope in BudgetScope.values) {
      ref.read(planningRepositoryProvider).checkAndCreateAlertsInBackground(
            month: transaction.date,
            scope: scope,
          );
    }
  }
}
