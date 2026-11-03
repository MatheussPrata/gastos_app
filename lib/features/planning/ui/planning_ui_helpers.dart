import 'package:flutter/material.dart';

import 'package:gastos_app/core/theme/app_theme.dart';

/// Month names used by the planning screens (pt-BR).
const List<String> planningMonthNames = [
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

/// "Novembro 2026" for the given month.
String planningMonthLabel(DateTime month) =>
    '${planningMonthNames[month.month - 1]} ${month.year}';

/// Color used for budget progress according to how much was consumed.
Color planningStatusColor(double percent) {
  if (percent >= 100) return AppColors.expense;
  if (percent >= 90) return const Color(0xFFFB8C00);
  if (percent >= 80) return AppColors.warning;
  return AppColors.secondary;
}
