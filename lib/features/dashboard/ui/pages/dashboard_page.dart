import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_cards_page.dart';
import 'package:gastos_app/features/dashboard/ui/widgets/settings_drawer.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart'
    hide Category;
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

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedTab = 0; // 0: Transações, 1: Categorias

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.credit_card),
            tooltip: 'Cartões de Crédito',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditCardsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Ler cupom fiscal',
            onPressed: () => context.push(RouteNames.receiptScanner),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthSelector(context, selectedMonth),
          _buildSummaryAndCardImpact(context, transactionsAsync),
          _buildTabSelector(),
          Expanded(
            child: _selectedTab == 0
                ? _buildTransactionsList(context, transactionsAsync)
                : _buildCategoryBreakdownList(context, transactionsAsync),
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

  Widget _buildMonthSelector(BuildContext context, DateTime month) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
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
            onPressed: () => _changeMonth(1),
            tooltip: 'Próximo mês',
          ),
        ],
      ),
    );
  }

  void _changeMonth(int delta) {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta, 1);
  }

  String _monthLabel(DateTime month) =>
      '${_monthNames[month.month - 1]} ${month.year}';

  Widget _buildSummaryAndCardImpact(
    BuildContext context,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    return transactionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Erro ao carregar: $e'),
      ),
      data: (transactions) {
        var income = 0.0;
        var expense = 0.0;
        var cardSpent = 0.0;

        for (final transaction in transactions) {
          if (transaction.isExpense) {
            expense += transaction.amount;
            if (transaction.paymentMethod == 'Cartão de Crédito' ||
                (transaction.creditCardId != null &&
                    transaction.creditCardId!.isNotEmpty)) {
              cardSpent += transaction.amount;
            }
          } else {
            income += transaction.amount;
          }
        }
        final balance = income - expense;
        final percentOfIncome =
            income > 0 ? (cardSpent / income * 100) : 0.0;

        Color cardWarningColor;
        if (percentOfIncome > 50) {
          cardWarningColor = AppColors.expense;
        } else if (percentOfIncome > 30) {
          cardWarningColor = AppColors.warning;
        } else {
          cardWarningColor = AppColors.income;
        }

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                    const Divider(height: 24),
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
                            color: balance >= 0
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Card: Comprometimento da Renda no Cartão de Crédito
            if (cardSpent > 0 || income > 0)
              InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreditCardsPage()),
                ),
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.credit_card,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              income > 0
                                  ? '${percentOfIncome.toStringAsFixed(1)}% da renda gasta no cartão de crédito'
                                  : 'Gasto no cartão: ${CurrencyFormatter.format(cardSpent)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: income > 0
                                    ? cardWarningColor
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (income > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (percentOfIncome / 100).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                AlwaysStoppedAnimation(cardWarningColor),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cartão: ${CurrencyFormatter.format(cardSpent)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade700),
                            ),
                            Text(
                              'Renda: ${CurrencyFormatter.format(income)}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Toque para gerenciar faturas e limites dos cartões',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color) {
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

  Widget _summaryItem(String label, double value, Color color) =>
      _buildSummaryItem(label, value, color);

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Center(child: Text('Lançamentos')),
              selected: _selectedTab == 0,
              onSelected: (selected) {
                if (selected) setState(() => _selectedTab = 0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Center(child: Text('Por Categoria')),
              selected: _selectedTab == 1,
              onSelected: (selected) {
                if (selected) setState(() => _selectedTab = 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
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
              onDelete: () => _confirmDelete(context, transaction),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryBreakdownList(
    BuildContext context,
    AsyncValue<List<Transaction>> transactionsAsync,
  ) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return transactionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (transactions) {
        final expenseTransactions =
            transactions.where((t) => t.isExpense).toList();

        if (expenseTransactions.isEmpty) {
          return const Center(
            child: Text('Nenhum gasto registrado neste mês.'),
          );
        }

        final categoriesList =
            categoriesAsync.valueOrNull ?? const <Category>[];

        // Group total spent and credit card spent by category
        final categoryTotals = <String, double>{};
        final categoryCardSpent = <String, double>{};
        var totalExpenses = 0.0;

        for (final tx in expenseTransactions) {
          final catId = tx.categoryId ?? 'none';
          categoryTotals[catId] = (categoryTotals[catId] ?? 0.0) + tx.amount;
          totalExpenses += tx.amount;

          final isCard = tx.paymentMethod == 'Cartão de Crédito' ||
              (tx.creditCardId != null && tx.creditCardId!.isNotEmpty);
          if (isCard) {
            categoryCardSpent[catId] =
                (categoryCardSpent[catId] ?? 0.0) + tx.amount;
          }
        }

        final sortedCategories = categoryTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: sortedCategories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = sortedCategories[index];
            final catId = entry.key;
            final catTotal = entry.value;
            final cardSpent = categoryCardSpent[catId] ?? 0.0;
            final cardPercent =
                catTotal > 0 ? (cardSpent / catTotal * 100) : 0.0;
            final overallPercent =
                totalExpenses > 0 ? (catTotal / totalExpenses * 100) : 0.0;

            final cat = categoriesList.cast<Category?>().firstWhere(
                  (c) => c?.id == catId,
                  orElse: () => null,
                );
            final name = cat?.name ?? 'Outros';
            final iconData = categoryIcon(cat?.icon ?? 'category');
            final color = cat != null && cat.color != 0
                ? Color(cat.color)
                : AppColors.primary;

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(iconData, size: 20, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${overallPercent.toStringAsFixed(1)}% do total de gastos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(catTotal),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Barra com proporção Cartão vs Outros
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (cardPercent / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Destaque de % no cartão de crédito
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.credit_card,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              cardSpent > 0
                                  ? '${cardPercent.toStringAsFixed(0)}% no cartão (${CurrencyFormatter.format(cardSpent)})'
                                  : '0% no cartão',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cardSpent > 0
                                    ? AppColors.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (cardPercent < 100)
                          Text(
                            '${(100 - cardPercent).toStringAsFixed(0)}% outros (${CurrencyFormatter.format(catTotal - cardSpent)})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
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
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
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
