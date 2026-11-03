import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

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

const List<String> _shortMonthNames = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

/// Reports tab: monthly summary, expenses by category and monthly evolution.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthTransactions = ref.watch(monthTransactionsProvider);
    final monthlyStats = ref.watch(monthlyCategoryStatsProvider);

    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final end = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
      23,
      59,
      59,
    );
    final categoryExpenses = ref.watch(
      categoryExpensesProvider((start: start, end: end)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(monthTransactionsProvider)
            ..invalidate(monthlyStatsProvider)
            ..invalidate(categoryExpensesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _MonthSelector(),
            _SummaryCard(transactionsAsync: monthTransactions),
            const _SectionTitle('Gastos por categoria'),
            _CategoryChart(categoriesAsync: categoryExpenses),
            const _SectionTitle('Evolução mensal'),
            _MonthlyChart(statsAsync: monthlyStats),
          ],
        ),
      ),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(ref, -1),
            tooltip: 'Mês anterior',
          ),
          Expanded(
            child: Center(
              child: Text(
                '${_monthNames[month.month - 1]} ${month.year}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftMonth(ref, 1),
            tooltip: 'Próximo mês',
          ),
        ],
      ),
    );
  }

  void _shiftMonth(WidgetRef ref, int delta) {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta, 1);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.transactionsAsync});

  final AsyncValue<List<Transaction>> transactionsAsync;

  @override
  Widget build(BuildContext context) {
    return transactionsAsync.when(
      loading: () => const SizedBox(
        height: 148,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Não foi possível carregar o resumo.'),
        ),
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
                  children: [
                    Expanded(
                      child: _SummaryItem(
                        label: 'Entradas',
                        value: income,
                        color: AppColors.income,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Theme.of(context).dividerColor,
                    ),
                    Expanded(
                      child: _SummaryItem(
                        label: 'Saídas',
                        value: expense,
                        color: AppColors.expense,
                        icon: Icons.arrow_downward,
                      ),
                    ),
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
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({required this.categoriesAsync});

  final AsyncValue<List<CategoryExpense>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: categoriesAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox(
            height: 120,
            child: Center(child: Text('Erro ao carregar categorias')),
          ),
          data: (categories) {
            final visible = categories.where((c) => c.total > 0).toList();
            if (visible.isEmpty) {
              return const _EmptyChart(
                icon: Icons.pie_chart_outline,
                message: 'Nenhum gasto registrado neste mês.',
              );
            }

            final total = visible.fold<double>(0, (sum, c) => sum + c.total);
            final highlighted = visible.take(5).toList();

            return Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      startDegreeOffset: -90,
                      sections: [
                        for (final category in visible)
                          PieChartSectionData(
                            value: category.total,
                            color: _categoryColor(category),
                            radius: 46,
                            title:
                                '${(category.total / total * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final category in highlighted)
                  _CategoryLegendItem(category: category, total: total),
                if (visible.length > highlighted.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+ ${visible.length - highlighted.length} categorias',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryLegendItem extends StatelessWidget {
  const _CategoryLegendItem({required this.category, required this.total});

  final CategoryExpense category;
  final double total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : category.total / total * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _categoryColor(category),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              category.categoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(category.total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.statsAsync});

  final AsyncValue<List<MonthlyCategoryStats>> statsAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: statsAsync.when(
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox(
            height: 120,
            child: Center(child: Text('Erro ao carregar histórico')),
          ),
          data: (stats) {
            if (stats.isEmpty) {
              return const _EmptyChart(
                icon: Icons.bar_chart,
                message: 'Sem histórico de lançamentos.',
              );
            }

            final visible =
                stats.length > 6 ? stats.sublist(stats.length - 6) : stats;
            final highest = visible.fold<double>(
              0,
              (value, stat) =>
                  math.max(value, math.max(stat.income, stat.expense)),
            );
            final maxY = highest <= 0 ? 100.0 : highest * 1.2;
            final interval = maxY / 4;

            // Categories aggregated across the visible months, used both in
            // the legend and in the stacked expense bars.
            final totals = <String, CategoryExpense>{};
            for (final stat in visible) {
              for (final category in stat.categories) {
                final existing = totals[category.categoryId];
                totals[category.categoryId] = existing == null
                    ? category
                    : existing.copyWith(
                        total: existing.total + category.total,
                      );
              }
            }
            final legendCategories = totals.values.toList()
              ..sort((a, b) => b.total.compareTo(a.total));

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    _ChartLegendDot(color: AppColors.income, label: 'Entradas'),
                    SizedBox(width: 16),
                    _ChartLegendDot(color: AppColors.expense, label: 'Saídas'),
                  ],
                ),
                if (legendCategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final category in legendCategories.take(6))
                        _ChartLegendDot(
                          color: _categoryColor(category),
                          label: category.categoryName,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withOpacity(0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            interval: interval,
                            getTitlesWidget: (value, meta) {
                              if (value <= 0) return const SizedBox.shrink();
                              return Text(
                                _compactValue(value),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= visible.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _shortMonth(visible[index].month),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var index = 0; index < visible.length; index++)
                          BarChartGroupData(
                            x: index,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: visible[index].income,
                                color: AppColors.income,
                                width: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              _expenseRod(visible[index]),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Expense bar stacked by category colors. Falls back to a solid red bar
  /// when the month has no categorized expenses.
  BarChartRodData _expenseRod(MonthlyCategoryStats stat) {
    final stack = <BarChartRodStackItem>[];
    var start = 0.0;
    for (final category in stat.categories) {
      if (category.total <= 0) continue;
      final end = start + category.total;
      stack.add(
        BarChartRodStackItem(start, end, _categoryColor(category)),
      );
      start = end;
    }

    if (stack.isEmpty) {
      return BarChartRodData(
        toY: stat.expense,
        color: AppColors.expense,
        width: 8,
        borderRadius: BorderRadius.circular(4),
      );
    }

    return BarChartRodData(
      toY: stat.expense,
      color: AppColors.expense,
      rodStackItems: stack,
      width: 8,
      borderRadius: BorderRadius.circular(4),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

Color _categoryColor(CategoryExpense category) {
  return category.categoryColor == 0
      ? Colors.grey
      : Color(category.categoryColor);
}

String _shortMonth(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return key;
  return _shortMonthNames[month - 1];
}

String _compactValue(double value) {
  if (value >= 1000000) {
    final millions = (value / 1000000).toStringAsFixed(1).replaceAll('.', ',');
    return '${millions}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}k';
  }
  return value.toStringAsFixed(0);
}
