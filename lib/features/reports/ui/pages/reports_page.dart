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
/// top categorias e comparativo mensal.
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

    final filteredStats = _continuousStats(
        monthlyStatsAsync.valueOrNull ?? const [], period, selectedMonth);
    final filteredCatStats = _continuousCatStats(
        monthlyCatStatsAsync.valueOrNull ?? const [], period, selectedMonth);

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
            ..invalidate(categoryExpensesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const _PeriodSelector(),
            if (period == ReportPeriod.month) const _MonthSelector(),
            _SummaryCard(
              period: period,
              selectedMonth: selectedMonth,
              monthTransactions: monthTransactions,
              stats: filteredStats,
              allStats: monthlyStatsAsync.valueOrNull ?? const [],
              statsLoading: monthlyStatsAsync.isLoading,
            ),
            const _SectionTitle('Saldo ao longo do tempo'),
            _BalanceLineChart(stats: filteredStats),
            const _SectionTitle('Gastos por categoria'),
            _CategoryChart(categoriesAsync: categoryExpenses),
            const _SectionTitle('Top categorias'),
            _TopCategoriesChart(categoriesAsync: categoryExpenses),
            const _SectionTitle('Gastos por cartão'),
            const _CardsChart(),
            const _SectionTitle('Comparativo mensal'),
            _MonthlyChart(stats: filteredCatStats),
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
  DateTime selectedMonth,
) {
  switch (period) {
    case ReportPeriod.month:
      return (
        start: DateTime(selectedMonth.year, selectedMonth.month, 1),
        end: DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59),
      );
    case ReportPeriod.quarter:
      return (
        start: DateTime(selectedMonth.year, selectedMonth.month - 2, 1),
        end: DateTime(selectedMonth.year, selectedMonth.month + 1, 0, 23, 59, 59),
      );
    case ReportPeriod.year:
      return (
        start: DateTime(selectedMonth.year, 1, 1),
        end: DateTime(selectedMonth.year, 12, 31, 23, 59, 59),
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

/// Meses do período, do início ao fim, sem buracos (inclusive futuros vazios).
List<String> _monthRange(
  ReportPeriod period,
  DateTime selectedMonth, {
  String? firstDataKey,
  String? lastDataKey,
}) {
  DateTime start;
  DateTime end;

  if (period == ReportPeriod.all) {
    if (firstDataKey == null || lastDataKey == null) return const [];
    start = _parseMonthKey(firstDataKey);
    end = _parseMonthKey(lastDataKey);
  } else {
    final range = _rangeFor(period, selectedMonth);
    start = DateTime(range.start.year, range.start.month, 1);
    end = DateTime(range.end.year, range.end.month, 1);
    // Não desenha meses que ainda não chegaram.
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    if (end.isAfter(currentMonth)) end = currentMonth;
  }

  if (start.isAfter(end)) return const [];

  final months = <String>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    months.add(_monthKey(cursor));
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  return months;
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

List<MonthlyCategoryStats> _continuousCatStats(
  List<MonthlyCategoryStats> stats,
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
          now.day > 0) {
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
  const _BalanceLineChart({required this.stats});

  final List<MonthlyStats> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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

    final spots = <FlSpot>[
      for (var i = 0; i < stats.length; i++)
        FlSpot(i.toDouble(), stats[i].balance),
    ];

    final values = spots.map((s) => s.y);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final span = (highest - lowest).abs();
    final pad = span == 0 ? math.max(highest.abs() * 0.1, 1.0) : span * 0.2;
    final minY = lowest - pad;
    final maxY = highest + pad;
    final interval = (maxY - minY) / 4;
    final labelStep = _labelStep(stats.length);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
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
                    getTitlesWidget: (value, meta) => Text(
                      _compactValue(value),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= stats.length) {
                        return const SizedBox.shrink();
                      }
                      if (index % labelStep != 0 && index != stats.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _shortMonth(stats[index].month),
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
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final index = spot.x.toInt();
                    if (index < 0 || index >= stats.length) {
                      return null;
                    }
                    return LineTooltipItem(
                      '${_shortMonth(stats[index].month)}\n'
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
                  curveSmoothness: 0.3,
                  barWidth: 3,
                  color: scheme.primary,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: scheme.primary,
                      strokeWidth: 2,
                      strokeColor: scheme.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withOpacity(0.22),
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
      ),
    );
  }

  int _labelStep(int length) {
    if (length <= 6) return 1;
    return (length / 6).ceil();
  }
}

class _TopCategoriesChart extends StatelessWidget {
  const _TopCategoriesChart({required this.categoriesAsync});

  final AsyncValue<List<CategoryExpense>> categoriesAsync;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: categoriesAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => const SizedBox(
            height: 100,
            child: Center(child: Text('Erro ao carregar categorias')),
          ),
          data: (categories) {
            final visible = categories.where((c) => c.total > 0).toList();
            if (visible.isEmpty) {
              return const EmptyState(
                icon: Icons.leaderboard_outlined,
                title: 'Nenhum gasto no período',
                height: 150,
              );
            }

            final ranked = visible.take(6).toList();
            final colorMap = _resolveCategoryColors(visible);
            final maxTotal = ranked.first.total;

            return Column(
              children: [
                for (final category in ranked)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: colorMap[category.categoryId] ??
                                    _categoryColor(category),
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
                              CurrencyFormatter.format(category.total),
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
                            value: maxTotal == 0
                                ? 0
                                : (category.total / maxTotal).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: (colorMap[category.categoryId] ??
                                    _categoryColor(category))
                                .withOpacity(0.14),
                            color: colorMap[category.categoryId] ??
                                _categoryColor(category),
                          ),
                        ),
                      ],
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
                message: 'Nenhum gasto registrado neste período.',
              );
            }

            final total = visible.fold<double>(0, (sum, c) => sum + c.total);
            final highlighted = visible.take(5).toList();
            final colorMap = _resolveCategoryColors(visible);

            // Filtra fatias menores que 0.5% apenas para o desenho do gráfico circular.
            final chartSlices = visible
                .where((c) => total > 0 && (c.total / total) >= 0.005)
                .toList();
            final renderSlices = chartSlices.isEmpty ? visible : chartSlices;

            return Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 52,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final section = response?.touchedSection;
                          if (section == null) return;
                          final index = section.touchedSectionIndex;
                          if (index < 0 || index >= renderSlices.length) return;
                          final category = renderSlices[index];
                          if (!context.mounted) return;
                          context.push(
                            RouteNames.transactions,
                            extra: {
                              'categoryId': category.categoryId,
                              'categoryName': category.categoryName,
                            },
                          );
                        },
                      ),
                      sections: [
                        for (final category in renderSlices)
                          () {
                            final percent = total > 0
                                ? (category.total / total * 100)
                                : 0.0;
                            final showTitle = percent >= 5.0;
                            final color = colorMap[category.categoryId] ??
                                _categoryColor(category);

                            return PieChartSectionData(
                              value: category.total,
                              color: color,
                              radius: 46,
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
                ),
                const SizedBox(height: 16),
                for (final category in highlighted)
                  _CategoryLegendItem(
                    category: category,
                    total: total,
                    color: colorMap[category.categoryId] ??
                        _categoryColor(category),
                  ),
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
  const _CategoryLegendItem({
    required this.category,
    required this.total,
    required this.color,
  });

  final CategoryExpense category;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : category.total / total * 100;
    final percentText = percent == 0
        ? '0%'
        : percent < 1
            ? '< 1%'
            : '${percent.toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
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
                percentText,
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
  const _MonthlyChart({required this.stats});

  final List<MonthlyCategoryStats> stats;

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

    final visible =
        stats.length > 6 ? stats.sublist(stats.length - 6) : stats;
    final highest = visible.fold<double>(
      0,
      (value, stat) => math.max(value, math.max(stat.income, stat.expense)),
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
    final monthlyColorMap = _resolveCategoryColors(legendCategories);

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
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= visible.length) {
                      return null;
                    }
                    final label =
                        rodIndex == 0 ? 'Entradas' : 'Saídas';
                    return BarTooltipItem(
                      '${_shortMonth(visible[groupIndex].month)}\n'
                      '$label: ${CurrencyFormatter.format(rod.toY)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                      _expenseRod(visible[index], monthlyColorMap),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Expense bar stacked by category colors. Falls back to a solid red bar
  /// when the month has no categorized expenses.
  BarChartRodData _expenseRod(
    MonthlyCategoryStats stat,
    Map<String, Color> colorMap,
  ) {
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
    return EmptyState(icon: icon, title: message, height: 160);
  }
}

const List<Color> _chartPalette = [
  Color(0xFFFF6B6B), // Coral Red
  Color(0xFF4ECDC4), // Turquoise / Teal
  Color(0xFFFFB347), // Warm Orange
  Color(0xFF6BCB77), // Emerald Green
  Color(0xFF7E57C2), // Deep Purple
  Color(0xFF29B6F6), // Sky Blue
  Color(0xFFFFD93D), // Bright Gold / Yellow
  Color(0xFFEC407A), // Pink / Rose
  Color(0xFFFF7043), // Tangerine
  Color(0xFF26A69A), // Mint / Cyan
  Color(0xFF9CCC65), // Lime
  Color(0xFF5C6BC0), // Indigo
  Color(0xFF8D6E63), // Brown / Wood
  Color(0xFF00ACC1), // Ocean Cyan
  Color(0xFFD81B60), // Berry Red
  Color(0xFF3949AB), // Royal Blue
  Color(0xFF78909C), // Slate
];

/// Mapeia cada categoria para uma cor única e bem contrastada no gráfico.
/// Evita que categorias diferentes compartilhem a mesma cor (mesmo que salvas assim no banco).
@visibleForTesting
Map<String, Color> resolveCategoryColorsForTesting(
  List<CategoryExpense> categories,
) =>
    _resolveCategoryColors(categories);

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

  // Pass 1: Categorias válidas com cor distinta pré-existente
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

  // Pass 2: Categorias colididas, sem cor ou especiais
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

/// Gastos por cartão no mês selecionado (barra fatura vs limite).
class _CardsChart extends ConsumerWidget {
  const _CardsChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final cardsAsync = ref.watch(
      cardsWithSpentProvider(DateTime(month.year, month.month)),
    );

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
            final maxValue = visible
                .map((c) => c.card.limitAmount > 0
                    ? c.card.limitAmount
                    : c.spent)
                .reduce(math.max);

            return Column(
              children: [
                for (final c in visible)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.credit_card,
                              size: 14,
                              color: c.card.cardColor,
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
                            value: maxValue <= 0
                                ? 0
                                : (c.spent / maxValue).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor:
                                c.card.cardColor.withOpacity(0.15),
                            color: c.card.cardColor,
                          ),
                        ),
                        if (c.card.limitAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Limite: ${CurrencyFormatter.format(c.card.limitAmount)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        if (c.invoiceTotal > 0)
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
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
