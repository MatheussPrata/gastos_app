import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

/// Mini gráfico (sparkline) da evolução do saldo nos últimos meses.
class BalanceSparkline extends StatelessWidget {
  const BalanceSparkline({super.key, required this.stats});

  final List<MonthlyStats> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.length < 2) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final spots = <FlSpot>[
      for (var i = 0; i < stats.length; i++)
        FlSpot(i.toDouble(), stats[i].balance),
    ];
    final values = spots.map((s) => s.y);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final span = (highest - lowest).abs();
    final pad = span == 0 ? math.max(highest.abs() * 0.1, 1.0) : span * 0.15;

    return SizedBox(
      height: 56,
      child: LineChart(
        LineChartData(
          minY: lowest - pad,
          maxY: highest + pad,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              barWidth: 2.5,
              color: scheme.primary,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withOpacity(0.18),
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
    );
  }
}
