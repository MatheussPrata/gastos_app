import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/core/widgets/empty_state.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
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

/// Período de análise dos relatórios.
enum ReportPeriod { month, quarter, year, all }

final reportPeriodProvider = StateProvider<ReportPeriod>(
  (_) => ReportPeriod.month,
);

/// Reports tab: resumo, saldo ao longo do tempo, gastos por categoria,
/// formas de pagamento, cartões e comparativo mensal.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);
    final monthTransactions = ref.watch(monthTransactionsProvider);
    final monthlyStatsAsync = period == ReportPeriod.all
        ? ref.watch(monthlyStatsAllProvider)
        : ref.watch(monthlyStatsProvider);
    final monthlyCatStatsAsync = period == ReportPeriod.all
        ? ref.watch(monthlyCategoryStatsAllProvider)
        : ref.watch(monthlyCategoryStatsProvider);

    final range = _rangeFor(period, selectedMonth);
    final categoryExpenses = ref.watch(
      categoryExpensesProvider((start: range.start, end: range.end)),
    );
    final paymentMethodExpenses = ref.watch(
      paymentMethodExpensesProvider((start: range.start, end: range.end)),
    );

    final filteredStats = _continuousStats(
      monthlyStatsAsync.valueOrNull ?? const [],
      period,
      selectedMonth,
    );
    final comparisonStats = buildMonthlyComparisonSeries(
      monthlyCatStatsAsync.valueOrNull ?? const [],
      period,
      selectedMonth,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(monthTransactionsProvider)
            ..invalidate(monthlyStatsProvider)
            ..invalidate(recentMonthlyStatsProvider)
            ..invalidate(monthlyCategoryStatsProvider)
            ..invalidate(monthlyStatsAllProvider)
            ..invalidate(monthlyCategoryStatsAllProvider)
            ..invalidate(categoryExpensesProvider)
            ..invalidate(paymentMethodExpensesProvider)
            ..invalidate(cardsWithSpentProvider)
            ..invalidate(cardsRangeSpentProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const _PeriodSelector(),
            if (period == ReportPeriod.month || period == ReportPeriod.quarter)
              _MonthSelector(isQuarter: period == ReportPeriod.quarter),
            if (period == ReportPeriod.year) const _YearSelector(),
            _SummaryCard(
              period: period,
              selectedMonth: selectedMonth,
              monthTransactions: monthTransactions,
              stats: filteredStats,
              allStats: monthlyStatsAsync.valueOrNull ?? const [],
              statsLoading: monthlyStatsAsync.isLoading,
            ),
            const _SectionTitle('Saldo ao longo do tempo'),
            _BalanceLineChart(
              period: period,
              selectedMonth: selectedMonth,
              monthTransactions: monthTransactions,
              stats: filteredStats,
            ),
            const _SectionTitle('Gastos por categoria'),
            _CategoryChart(categoriesAsync: categoryExpenses),
            const _SectionTitle('Gastos por forma de pagamento'),
            _PaymentMethodsChart(methodsAsync: paymentMethodExpenses),
            const _SectionTitle('Gastos por cartão'),
            _CardsChart(
              period: period,
              selectedMonth: selectedMonth,
              range: range,
            ),
            const _SectionTitle('Comparativo mensal'),
            _MonthlyChart(
              stats: comparisonStats,
              highlightedMonthKey:
                  period == ReportPeriod.month ? _monthKey(selectedMonth) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ helpers

String _monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

({DateTime start, DateTime end}) _rangeFor(
  ReportPeriod period,
  DateTime selectedMonth, {
  DateTime? now,
}) {
  final refNow = now ?? DateTime.now();
  switch (period) {
    case ReportPeriod.month:
      return (
        start: DateTime(selectedMonth.year, selectedMonth.month, 1),
        end: DateTime(
          selectedMonth.year,
          selectedMonth.month + 1,
          0,
          23,
          59,
          59,
        ),
      );
    case ReportPeriod.quarter:
      return (
        start: DateTime(selectedMonth.year, selectedMonth.month - 2, 1),
        end: DateTime(
          selectedMonth.year,
          selectedMonth.month + 1,
          0,
          23,
          59,
          59,
        ),
      );
    case ReportPeriod.year:
      final endMonth = selectedMonth.year == refNow.year ? refNow.month : 12;
      return (
        start: DateTime(selectedMonth.year, 1, 1),
        end: DateTime(selectedMonth.year, endMonth + 1, 0, 23, 59, 59),
      );
    case ReportPeriod.all:
      return (start: DateTime(2000, 1, 1), end: DateTime(2100, 1, 1));
  }
}

DateTime _parseMonthKey(String key) {
  final parts = key.split('-');
  final year = int.tryParse(parts.first) ?? DateTime.now().year;
  final month = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  return DateTime(year, month, 1);
}

List<String> _buildMonthsBetween(DateTime start, DateTime end) {
  if (start.isAfter(end)) return const [];
  final months = <String>[];
  var cursor = DateTime(start.year, start.month, 1);
  final limit = DateTime(end.year, end.month, 1);
  while (!cursor.isAfter(limit)) {
    months.add(_monthKey(cursor));
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  return months;
}

/// Meses do período, do início ao fim, sem buracos.
List<String> _monthRange(
  ReportPeriod period,
  DateTime selectedMonth, {
  String? firstDataKey,
  String? lastDataKey,
  DateTime? now,
}) {
  if (period == ReportPeriod.all) {
    if (firstDataKey == null || lastDataKey == null) return const [];
    return _buildMonthsBetween(
      _parseMonthKey(firstDataKey),
      _parseMonthKey(lastDataKey),
    );
  }

  final range = _rangeFor(period, selectedMonth, now: now);
  final start = DateTime(range.start.year, range.start.month, 1);
  final end = DateTime(range.end.year, range.end.month, 1);
  return _buildMonthsBetween(start, end);
}

/// Série mensal contínua: meses sem lançamento entram com zero.
List<MonthlyStats> _continuousStats(
  List<MonthlyStats> stats,
  ReportPeriod period,
  DateTime selectedMonth,
) {
  final byMonth = {for (final s in stats) s.month: s};
  final sorted = [...stats]..sort((a, b) => a.month.compareTo(b.month));
  final months = _monthRange(
    period,
    selectedMonth,
    firstDataKey: sorted.isEmpty ? null : sorted.first.month,
    lastDataKey: sorted.isEmpty ? null : sorted.last.month,
  );

  return [
    for (final key in months)
      byMonth[key] ??
          MonthlyStats(month: key, income: 0, expense: 0, balance: 0),
  ];
}

/// Formata valores do eixo Y com suporte correto a negativos e precisão < 10k.
@visibleForTesting
String formatCompactCurrencyAxis(double value) {
  if (value.abs() < 0.5) return '0';
  final sign = value < 0 ? '-' : '';
  final abs = value.abs();

  if (abs >= 1000000) {
    final formatted =
        (abs / 1000000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
    return '$sign${formatted}M';
  }
  if (abs >= 10000) {
    return '$sign${(abs / 1000).toStringAsFixed(0)}k';
  }
  if (abs >= 1000) {
    final formatted =
        (abs / 1000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',');
    return '$sign${formatted}k';
  }
  return '$sign${abs.toStringAsFixed(0)}';
}

/// Constrói a evolução acumulada dia a dia do saldo dentro de [selectedMonth].
List<({int day, double balance})> buildDailyCumulativeBalancePoints(
  List<Transaction> transactions,
  DateTime selectedMonth, {
  DateTime? now,
}) {
  if (transactions.isEmpty) return const [];

  final refNow = now ?? DateTime.now();
  final daysInMonth =
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

  final dailyDelta = <int, double>{};
  var maxTxDay = 1;
  for (final t in transactions) {
    if (t.date.year != selectedMonth.year ||
        t.date.month != selectedMonth.month) {
      continue;
    }
    final day = t.date.day;
    if (day > maxTxDay) maxTxDay = day;
    dailyDelta[day] =
        (dailyDelta[day] ?? 0.0) + (t.isExpense ? -t.amount : t.amount);
  }

  if (dailyDelta.isEmpty) return const [];

  final isCurrentMonth = selectedMonth.year == refNow.year &&
      selectedMonth.month == refNow.month;
  final lastDay = isCurrentMonth
      ? math.min(daysInMonth, math.max(refNow.day, maxTxDay))
      : daysInMonth;

  final points = <({int day, double balance})>[];
  var running = 0.0;
  for (var day = 1; day <= lastDay; day++) {
    running += dailyDelta[day] ?? 0.0;
    points.add((day: day, balance: running));
  }
  return points;
}

/// Série usada no Comparativo Mensal conforme o período selecionado:
/// - Mês: 6 meses contínuos encerrando em [selectedMonth]
/// - 3 meses: 3 meses contínuos encerrando em [selectedMonth]
/// - Ano: todos os meses do ano de [selectedMonth] (até 12 meses)
/// - Tudo: até os últimos 12 meses contínuos com histórico
List<MonthlyCategoryStats> buildMonthlyComparisonSeries(
  List<MonthlyCategoryStats> stats,
  ReportPeriod period,
  DateTime selectedMonth, {
  DateTime? now,
}) {
  final refNow = now ?? DateTime.now();
  final byMonth = {for (final s in stats) s.month: s};
  final sorted = [...stats]..sort((a, b) => a.month.compareTo(b.month));

  final List<String> months;
  switch (period) {
    case ReportPeriod.month:
      final start = DateTime(selectedMonth.year, selectedMonth.month - 5, 1);
      final end = DateTime(selectedMonth.year, selectedMonth.month, 1);
      months = _buildMonthsBetween(start, end);
      break;
    case ReportPeriod.quarter:
      final start = DateTime(selectedMonth.year, selectedMonth.month - 2, 1);
      final end = DateTime(selectedMonth.year, selectedMonth.month, 1);
      months = _buildMonthsBetween(start, end);
      break;
    case ReportPeriod.year:
      final year = selectedMonth.year;
      final yearStart = DateTime(year, 1, 1);
      final lastMonth = year == refNow.year ? refNow.month : 12;
      months = _buildMonthsBetween(yearStart, DateTime(year, lastMonth, 1));
      break;
    case ReportPeriod.all:
      if (sorted.isEmpty) {
        months = const [];
      } else {
        final full = _buildMonthsBetween(
          _parseMonthKey(sorted.first.month),
          _parseMonthKey(sorted.last.month),
        );
        months =
            full.length > 12 ? full.sublist(full.length - 12) : full;
      }
      break;
  }

  return [
    for (final key in months)
      byMonth[key] ??
          MonthlyCategoryStats(
            month: key,
            income: 0,
            expense: 0,
            categories: const [],
          ),
  ];
}

// ------------------------------------------------------------------ widgets

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<ReportPeriod>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ReportPeriod.month, label: Text('Mês')),
          ButtonSegment(value: ReportPeriod.quarter, label: Text('3 meses')),
          ButtonSegment(value: ReportPeriod.year, label: Text('Ano')),
          ButtonSegment(value: ReportPeriod.all, label: Text('Tudo')),
        ],
        selected: {period},
        onSelectionChanged: (selection) {
          ref.read(reportPeriodProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector({this.isQuarter = false});

  final bool isQuarter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final quarterStart = DateTime(month.year, month.month - 2, 1);
    final label = isQuarter
        ? '${_shortMonthNames[quarterStart.month - 1]} – '
            '${_shortMonthNames[month.month - 1]} ${month.year}'
        : '${_monthNames[month.month - 1]} ${month.year}';

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
                label,
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

class _YearSelector extends ConsumerWidget {
  const _YearSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedMonthProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftYear(ref, -1),
            tooltip: 'Ano anterior',
          ),
          Expanded(
            child: Center(
              child: Text(
                '${selected.year}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftYear(ref, 1),
            tooltip: 'Próximo ano',
          ),
        ],
      ),
    );
  }

  void _shiftYear(WidgetRef ref, int delta) {
    final current = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state =
        DateTime(current.year + delta, current.month, 1);
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
  const _SummaryCard({
    required this.period,
    required this.selectedMonth,
    required this.monthTransactions,
    required this.stats,
    required this.allStats,
    required this.statsLoading,
  });

  final ReportPeriod period;
  final DateTime selectedMonth;
  final AsyncValue<List<Transaction>> monthTransactions;
  final List<MonthlyStats> stats;
  final List<MonthlyStats> allStats;
  final bool statsLoading;

  @override
  Widget build(BuildContext context) {
    var income = 0.0;
    var expense = 0.0;
    var loading = false;

    if (period == ReportPeriod.month) {
      final snapshot = monthTransactions;
      if (snapshot.isLoading) {
        loading = true;
      } else {
        for (final t in snapshot.valueOrNull ?? const <Transaction>[]) {
          if (t.isExpense) {
            expense += t.amount;
          } else {
            income += t.amount;
          }
        }
      }
    } else if (statsLoading) {
      loading = true;
    } else {
      for (final s in stats) {
        income += s.income;
        expense += s.expense;
      }
    }

    final balance = income - expense;

    double? previousExpense;
    if (period == ReportPeriod.month) {
      final prevKey =
          _monthKey(DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
      final matches = allStats.where((s) => s.month == prevKey);
      if (matches.isNotEmpty) {
        previousExpense = matches.first.expense;
      }
    }

    double? projectedExpense;
    if (period == ReportPeriod.month) {
      final now = DateTime.now();
      if (selectedMonth.year == now.year &&
          selectedMonth.month == now.month &&
          now.day >= 2 &&
          expense > 0) {
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        projectedExpense = expense / now.day * daysInMonth;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? const SizedBox(
                height: 132,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
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
                          deltaPercent: previousExpense != null &&
                                  previousExpense > 0
                              ? (expense - previousExpense) /
                                  previousExpense *
                                  100
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Saldo do período',
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
                  if (income > 0) ...[
                    const SizedBox(height: 8),
                    _SavingsRateRow(
                      income: income,
                      expense: expense,
                      balance: balance,
                    ),
                  ],
                  if (projectedExpense != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Projeção de saídas no mês',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(projectedExpense),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SavingsRateRow extends StatelessWidget {
  const _SavingsRateRow({
    required this.income,
    required this.expense,
    required this.balance,
  });

  final double income;
  final double expense;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final color = isPositive ? AppColors.income : AppColors.expense;
    final pct = isPositive
        ? (balance / income * 100).toStringAsFixed(0)
        : ((expense - income) / income * 100).toStringAsFixed(0);
    final label = isPositive
        ? 'Economia de $pct% das entradas'
        : 'Saídas $pct% acima das entradas';

    return Row(
      children: [
        Icon(
          isPositive ? Icons.savings_outlined : Icons.warning_amber_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.deltaPercent,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final double? deltaPercent;

  @override
  Widget build(BuildContext context) {
    final delta = deltaPercent;
    final deltaColor = delta == null
        ? Colors.grey
        : (delta > 0 ? AppColors.expense : AppColors.income);

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
        if (delta != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                delta > 0 ? Icons.trending_up : Icons.trending_down,
                size: 14,
                color: deltaColor,
              ),
              const SizedBox(width: 3),
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: deltaColor,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BalanceLineChart extends StatelessWidget {
  const _BalanceLineChart({
    required this.period,
    required this.selectedMonth,
    required this.monthTransactions,
    required this.stats,
  });

  final ReportPeriod period;
  final DateTime selectedMonth;
  final AsyncValue<List<Transaction>> monthTransactions;
  final List<MonthlyStats> stats;

  @override
  Widget build(BuildContext context) {
    if (period == ReportPeriod.month) {
      if (monthTransactions.isLoading) {
        return const Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }
      final dailyPoints = buildDailyCumulativeBalancePoints(
        monthTransactions.valueOrNull ?? const [],
        selectedMonth,
      );
      if (dailyPoints.isEmpty) {
        return const Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: EmptyState(
            icon: Icons.show_chart,
            title: 'Sem dados suficientes',
            message: 'Registre lançamentos no mês para ver a evolução diária.',
          ),
        );
      }

      return _buildChartCard(
        context,
        subtitle: 'Saldo acumulado dia a dia no mês',
        spots: [
          for (var i = 0; i < dailyPoints.length; i++)
            FlSpot(i.toDouble(), dailyPoints[i].balance),
        ],
        bottomLabel: (index) {
          if (index < 0 || index >= dailyPoints.length) return '';
          return '${dailyPoints[index].day}';
        },
        tooltipLabel: (index) {
          if (index < 0 || index >= dailyPoints.length) return '';
          final day = dailyPoints[index].day;
          final shortMonth = _shortMonthNames[selectedMonth.month - 1];
          return 'Dia $day/$shortMonth';
        },
      );
    }

    if (stats.isEmpty) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: EmptyState(
          icon: Icons.show_chart,
          title: 'Sem dados suficientes',
          message: 'Registre lançamentos para ver a evolução do saldo.',
        ),
      );
    }

    return _buildChartCard(
      context,
      subtitle: 'Saldo líquido mês a mês',
      spots: [
        for (var i = 0; i < stats.length; i++)
          FlSpot(i.toDouble(), stats[i].balance),
      ],
      bottomLabel: (index) {
        if (index < 0 || index >= stats.length) return '';
        return _shortMonth(stats[index].month);
      },
      tooltipLabel: (index) {
        if (index < 0 || index >= stats.length) return '';
        return _shortMonthWithYear(stats[index].month);
      },
    );
  }

  Widget _buildChartCard(
    BuildContext context, {
    required String subtitle,
    required List<FlSpot> spots,
    required String Function(int index) bottomLabel,
    required String Function(int index) tooltipLabel,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final values = spots.map((s) => s.y);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final span = (highest - lowest).abs();
    final pad = span == 0 ? math.max(highest.abs() * 0.15, 10.0) : span * 0.2;
    final minY = lowest - pad;
    final maxY = highest + pad;
    final interval = math.max((maxY - minY) / 4, 1.0);
    final labelStep = _labelStep(spots.length);
    final showZeroLine = minY <= 0 && maxY >= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: spots.length == 1 ? -0.5 : 0,
                  maxX: spots.length == 1 ? 0.5 : (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.18),
                      strokeWidth: 1,
                    ),
                  ),
                  extraLinesData: showZeroLine
                      ? ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 0,
                              color: Colors.grey.withOpacity(0.5),
                              strokeWidth: 1,
                              dashArray: const [4, 4],
                            ),
                          ],
                        )
                      : null,
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
                        reservedSize: 52,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if ((value - meta.max).abs() < interval * 0.12) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            formatCompactCurrencyAxis(value),
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
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if ((value - value.roundToDouble()).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          final index = value.round();
                          if (index < 0 || index >= spots.length) {
                            return const SizedBox.shrink();
                          }
                          if (index % labelStep != 0 &&
                              index != spots.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              bottomLabel(index),
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
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItems: (touchedSpots) =>
                          touchedSpots.map((spot) {
                        final index = spot.x.round();
                        if (index < 0 || index >= spots.length) {
                          return null;
                        }
                        return LineTooltipItem(
                          '${tooltipLabel(index)}\n'
                          '${CurrencyFormatter.format(spot.y)}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      barWidth: 3,
                      color: scheme.primary,
                      dotData: FlDotData(
                        show: spots.length <= 16,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: spot.y >= 0
                              ? AppColors.income
                              : AppColors.expense,
                          strokeWidth: 1.5,
                          strokeColor: scheme.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withOpacity(0.20),
                            scheme.primary.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _labelStep(int length) {
    if (length <= 6) return 1;
    return (length / 6).ceil();
  }
}

class _CategoryChart extends StatefulWidget {
  const _CategoryChart({required this.categoriesAsync});

  final AsyncValue<List<CategoryExpense>> categoriesAsync;

  @override
  State<_CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<_CategoryChart> {
  bool _expanded = false;

  void _openCategory(BuildContext context, CategoryExpense category) {
    if (!context.mounted) return;
    context.push(
      RouteNames.transactions,
      extra: {
        'categoryId': category.categoryId,
        'categoryName': category.categoryName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: widget.categoriesAsync.when(
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
                message: 'Nenhum gasto registrado neste período.',
              );
            }

            final total = visible.fold<double>(0, (sum, c) => sum + c.total);
            final colorMap = _resolveCategoryColors(visible);
            final hasMore = visible.length > 6;
            final listItems =
                _expanded || !hasMore ? visible : visible.take(6).toList();

            // Filtra fatias menores que 0.5% apenas para o desenho do donut.
            final chartSlices = visible
                .where((c) => total > 0 && (c.total / total) >= 0.005)
                .toList();
            final renderSlices = chartSlices.isEmpty ? visible : chartSlices;

            return Column(
              children: [
                SizedBox(
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 56,
                          startDegreeOffset: -90,
                          pieTouchData: PieTouchData(
                            enabled: true,
                            touchCallback: (event, response) {
                              if (event is! FlTapUpEvent) return;
                              final section = response?.touchedSection;
                              if (section == null) return;
                              final index = section.touchedSectionIndex;
                              if (index < 0 || index >= renderSlices.length) {
                                return;
                              }
                              _openCategory(context, renderSlices[index]);
                            },
                          ),
                          sections: [
                            for (final category in renderSlices)
                              () {
                                final percent = total > 0
                                    ? (category.total / total * 100)
                                    : 0.0;
                                final showTitle = percent >= 6.0;
                                final color = colorMap[category.categoryId] ??
                                    _categoryColor(category);

                                return PieChartSectionData(
                                  value: category.total,
                                  color: color,
                                  radius: 44,
                                  showTitle: showTitle,
                                  title: showTitle
                                      ? '${percent.toStringAsFixed(0)}%'
                                      : '',
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                );
                              }(),
                          ],
                        ),
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: 96,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  CurrencyFormatter.format(total),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final category in listItems)
                  _CategoryLegendItem(
                    category: category,
                    total: total,
                    color: colorMap[category.categoryId] ??
                        _categoryColor(category),
                    onTap: () => _openCategory(context, category),
                  ),
                if (hasMore) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                      label: Text(
                        _expanded
                            ? 'Mostrar menos'
                            : 'Ver todas (${visible.length})',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryLegendItem extends StatelessWidget {
  const _CategoryLegendItem({
    required this.category,
    required this.total,
    required this.color,
    required this.onTap,
  });

  final CategoryExpense category;
  final double total;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (category.total / total).clamp(0.0, 1.0);
    final percent = total == 0 ? 0.0 : category.total / total * 100;
    final percentText = percent == 0
        ? '0%'
        : percent < 1
            ? '< 1%'
            : '${percent.toStringAsFixed(0)}%';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
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
                Text(
                  '${CurrencyFormatter.format(category.total)} • $percentText',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: color.withOpacity(0.14),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodsChart extends StatelessWidget {
  const _PaymentMethodsChart({required this.methodsAsync});

  final AsyncValue<List<PaymentMethodExpense>> methodsAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: methodsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox(
            height: 100,
            child: Center(
              child: Text('Erro ao carregar formas de pagamento'),
            ),
          ),
          data: (methods) {
            final visible = methods.where((m) => m.total > 0).toList();
            if (visible.isEmpty) {
              return const EmptyState(
                icon: Icons.payments_outlined,
                title: 'Sem gastos neste período',
                height: 140,
              );
            }

            final total = visible.fold<double>(0, (sum, m) => sum + m.total);

            return Column(
              children: [
                if (total > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          for (final item in visible)
                            () {
                              final flex = math.max(
                                ((item.total / total) * 1000).round(),
                                1,
                              );
                              return Expanded(
                                flex: flex,
                                child: Container(
                                  color: _paymentMethodColor(item.method),
                                ),
                              );
                            }(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                for (final item in visible)
                  () {
                    final color = _paymentMethodColor(item.method);
                    final percent = total > 0 ? item.total / total * 100 : 0.0;
                    final percentText = percent < 1
                        ? '< 1%'
                        : '${percent.toStringAsFixed(0)}%';
                    final countLabel = item.count == 1
                        ? '1 lançamento'
                        : '${item.count} lançamentos';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: color.withOpacity(0.14),
                            child: Icon(
                              _paymentMethodIcon(item.method),
                              size: 16,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.method,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  countLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(item.total),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                percentText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }(),
              ],
            );
          },
        ),
      ),
    );
  }
}

Color _paymentMethodColor(String method) {
  switch (method) {
    case PaymentMethods.pix:
      return const Color(0xFF00BFA5);
    case PaymentMethods.creditCard:
      return const Color(0xFF7E57C2);
    case PaymentMethods.debitCard:
      return const Color(0xFF29B6F6);
    case PaymentMethods.money:
      return const Color(0xFF6BCB77);
    case PaymentMethods.boleto:
      return const Color(0xFFFFB347);
    default:
      return const Color(0xFF78909C);
  }
}

IconData _paymentMethodIcon(String method) {
  switch (method) {
    case PaymentMethods.pix:
      return Icons.pix;
    case PaymentMethods.creditCard:
      return Icons.credit_card;
    case PaymentMethods.debitCard:
      return Icons.payment;
    case PaymentMethods.money:
      return Icons.attach_money;
    case PaymentMethods.boleto:
      return Icons.qr_code_2;
    default:
      return Icons.wallet_outlined;
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({
    required this.stats,
    this.highlightedMonthKey,
  });

  final List<MonthlyCategoryStats> stats;
  final String? highlightedMonthKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: _buildChart(context),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    if (stats.isEmpty) {
      return const _EmptyChart(
        icon: Icons.bar_chart,
        message: 'Sem histórico de lançamentos.',
      );
    }

    final visible = stats;
    final highest = visible.fold<double>(
      0,
      (value, stat) => math.max(value, math.max(stat.income, stat.expense)),
    );
    final maxY = highest <= 0 ? 100.0 : highest * 1.2;
    final interval = math.max(maxY / 4, 1.0);
    final rodWidth = visible.length <= 6 ? 9.0 : 5.5;
    final barsSpace = visible.length <= 6 ? 4.0 : 2.0;
    final scheme = Theme.of(context).colorScheme;

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
    final monthlyColorMap = _resolveCategoryColors(legendCategories);

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
                  color: monthlyColorMap[category.categoryId] ??
                      _categoryColor(category),
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
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= visible.length) {
                      return null;
                    }
                    final stat = visible[groupIndex];
                    final label = rodIndex == 0 ? 'Entradas' : 'Saídas';
                    final balance = stat.income - stat.expense;
                    final lines = <String>[
                      _shortMonthWithYear(stat.month),
                      '$label: ${CurrencyFormatter.format(rod.toY)}',
                      'Saldo: ${CurrencyFormatter.format(balance)}',
                    ];
                    if (rodIndex == 1 && stat.categories.isNotEmpty) {
                      for (final cat in stat.categories.take(3)) {
                        if (cat.total <= 0) continue;
                        lines.add(
                          '• ${cat.categoryName}: '
                          '${CurrencyFormatter.format(cat.total)}',
                        );
                      }
                    }
                    return BarTooltipItem(
                      lines.join('\n'),
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
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
                    reservedSize: 50,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value <= 0 ||
                          (value - meta.max).abs() < interval * 0.12) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        formatCompactCurrencyAxis(value),
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
                      final key = visible[index].month;
                      final isHighlighted = key == highlightedMonthKey;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _shortMonth(key),
                          style: TextStyle(
                            fontSize: visible.length <= 6 ? 10 : 9.5,
                            fontWeight: isHighlighted
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isHighlighted
                                ? scheme.primary
                                : Colors.grey.shade500,
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
                    barsSpace: barsSpace,
                    barRods: [
                      BarChartRodData(
                        toY: visible[index].income,
                        color: AppColors.income,
                        width: rodWidth,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      _expenseRod(
                        visible[index],
                        monthlyColorMap,
                        width: rodWidth,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BarChartRodData _expenseRod(
    MonthlyCategoryStats stat,
    Map<String, Color> colorMap, {
    required double width,
  }) {
    final stack = <BarChartRodStackItem>[];
    var start = 0.0;
    for (final category in stat.categories) {
      if (category.total <= 0) continue;
      final end = start + category.total;
      stack.add(
        BarChartRodStackItem(
          start,
          end,
          colorMap[category.categoryId] ?? _categoryColor(category),
        ),
      );
      start = end;
    }

    if (stack.isEmpty) {
      return BarChartRodData(
        toY: stat.expense,
        color: AppColors.expense,
        width: width,
        borderRadius: BorderRadius.circular(4),
      );
    }

    return BarChartRodData(
      toY: stat.expense,
      color: AppColors.expense,
      rodStackItems: stack,
      width: width,
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
    return EmptyState(icon: icon, title: message, height: 160);
  }
}

const List<Color> _chartPalette = [
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFB347),
  Color(0xFF6BCB77),
  Color(0xFF7E57C2),
  Color(0xFF29B6F6),
  Color(0xFFFFD93D),
  Color(0xFFEC407A),
  Color(0xFFFF7043),
  Color(0xFF26A69A),
  Color(0xFF9CCC65),
  Color(0xFF5C6BC0),
  Color(0xFF8D6E63),
  Color(0xFF00ACC1),
  Color(0xFFD81B60),
  Color(0xFF3949AB),
  Color(0xFF78909C),
];

/// Mapeia cada categoria para uma cor única e bem contrastada no gráfico.
Map<String, Color> resolveCategoryChartColors(
  List<CategoryExpense> categories,
) =>
    _resolveCategoryColors(categories);

/// Mapeia cada categoria para uma cor única e bem contrastada no gráfico.
@visibleForTesting
Map<String, Color> resolveCategoryColorsForTesting(
  List<CategoryExpense> categories,
) =>
    resolveCategoryChartColors(categories);

Map<String, Color> _resolveCategoryColors(List<CategoryExpense> categories) {
  final result = <String, Color>{};
  final usedRgb = <int>{};

  bool isSimilar(Color c1, Color c2) {
    if (c1.value == c2.value) return true;
    final r = (c1.red - c2.red).abs();
    final g = (c1.green - c2.green).abs();
    final b = (c1.blue - c2.blue).abs();
    return (r * r + g * g + b * b) < 1400;
  }

  for (final cat in categories) {
    if (cat.categoryId == 'none' ||
        cat.categoryName.toLowerCase().contains('sem categoria') ||
        cat.categoryColor == 0 ||
        cat.categoryColor == 0xFFB8B8B8) {
      continue;
    }

    final catColor = Color(cat.categoryColor);
    final collides = usedRgb.any((rgb) => isSimilar(Color(rgb), catColor));
    if (!collides) {
      result[cat.categoryId] = catColor;
      usedRgb.add(catColor.value);
    }
  }

  var paletteIndex = 0;
  for (final cat in categories) {
    if (result.containsKey(cat.categoryId)) continue;

    if (cat.categoryId == 'none' ||
        cat.categoryName.toLowerCase().contains('sem categoria')) {
      const greyColor = Color(0xFF9E9E9E);
      if (!usedRgb.any((rgb) => isSimilar(Color(rgb), greyColor))) {
        result[cat.categoryId] = greyColor;
        usedRgb.add(greyColor.value);
        continue;
      }
    }

    Color? chosen;
    while (paletteIndex < _chartPalette.length) {
      final candidate = _chartPalette[paletteIndex++];
      if (!usedRgb.any((rgb) => isSimilar(Color(rgb), candidate))) {
        chosen = candidate;
        break;
      }
    }

    chosen ??= () {
      final hue = (categories.indexOf(cat) * 137.5) % 360.0;
      return HSLColor.fromAHSL(1.0, hue, 0.75, 0.55).toColor();
    }();

    result[cat.categoryId] = chosen;
    usedRgb.add(chosen.value);
  }

  return result;
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

String _shortMonthWithYear(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return key;
  return '${_shortMonthNames[month - 1]}/${parts[0]}';
}

/// Gastos por cartão:
/// - No modo Mês, calcula % de uso sobre o limite individual de cada cartão.
/// - Nos demais períodos, mostra os gastos acumulados no período selecionado.
class _CardsChart extends ConsumerWidget {
  const _CardsChart({
    required this.period,
    required this.selectedMonth,
    required this.range,
  });

  final ReportPeriod period;
  final DateTime selectedMonth;
  final ({DateTime start, DateTime end}) range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (period == ReportPeriod.month) {
      final cardsAsync = ref.watch(
        cardsWithSpentProvider(DateTime(selectedMonth.year, selectedMonth.month)),
      );
      return _buildMonthlyCards(cardsAsync);
    }

    final rangeCardsAsync = ref.watch(cardsRangeSpentProvider(range));
    return _buildRangeCards(rangeCardsAsync);
  }

  Widget _buildMonthlyCards(AsyncValue<List<CardWithSpent>> cardsAsync) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: cardsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox(
            height: 100,
            child: Center(child: Text('Erro ao carregar cartões')),
          ),
          data: (cards) {
            if (cards.isEmpty) {
              return const EmptyState(
                icon: Icons.credit_card,
                title: 'Nenhum cartão cadastrado',
                height: 140,
              );
            }
            final visible = cards
                .where((c) => c.spent > 0 || c.invoiceTotal > 0)
                .toList();
            if (visible.isEmpty) {
              return const EmptyState(
                icon: Icons.credit_card_off,
                title: 'Sem gastos em cartões neste mês',
                height: 140,
              );
            }

            final totalCardsSpent = visible.fold<double>(
              0.0,
              (sum, c) => sum + math.max(c.spent, c.invoiceTotal),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fatura do mês selecionado (% sobre o limite do cartão)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                for (final c in visible)
                  () {
                    final used = math.max(c.spent, c.invoiceTotal);
                    final hasLimit = c.card.limitAmount > 0;
                    final ratio = hasLimit
                        ? used / c.card.limitAmount
                        : (totalCardsSpent > 0
                            ? used / totalCardsSpent
                            : 0.0);
                    final barColor = hasLimit && ratio >= 1.0
                        ? AppColors.expense
                        : (hasLimit && ratio >= 0.8
                            ? const Color(0xFFFFA000)
                            : c.card.cardColor);
                    final subtitle = hasLimit
                        ? '${(ratio * 100).toStringAsFixed(0)}% do limite '
                            '(${CurrencyFormatter.format(c.card.limitAmount)})'
                        : '${(ratio * 100).toStringAsFixed(0)}% dos gastos em cartão';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 15,
                                color: barColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.card.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              if (c.isPaid) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.income.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Paga',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                CurrencyFormatter.format(c.spent),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: barColor.withOpacity(0.15),
                              color: barColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasLimit && ratio >= 0.8
                                  ? barColor
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (c.invoiceTotal > 0 && c.invoiceTotal != c.spent)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Fatura informada: ${CurrencyFormatter.format(c.invoiceTotal)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRangeCards(AsyncValue<List<CardRangeSpent>> cardsAsync) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: cardsAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox(
            height: 100,
            child: Center(child: Text('Erro ao carregar cartões')),
          ),
          data: (visible) {
            if (visible.isEmpty) {
              return const EmptyState(
                icon: Icons.credit_card_off,
                title: 'Sem gastos em cartões neste período',
                height: 140,
              );
            }

            final totalSpent =
                visible.fold<double>(0.0, (sum, c) => sum + c.spent);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total gasto por cartão no período selecionado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                for (final item in visible)
                  () {
                    final ratio =
                        totalSpent > 0 ? item.spent / totalSpent : 0.0;
                    final color = item.card.cardColor;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.credit_card, size: 15, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.card.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(item.spent),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: color.withOpacity(0.15),
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(ratio * 100).toStringAsFixed(0)}% do total em cartões no período',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
              ],
            );
          },
        ),
      ),
    );
  }
}
