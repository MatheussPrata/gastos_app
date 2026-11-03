import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';

/// Dialog to adjust the percentage of a single category.
class CategoryBudgetDialog extends ConsumerStatefulWidget {
  const CategoryBudgetDialog({
    super.key,
    required this.plan,
    required this.category,
  });

  final BudgetPlan plan;
  final CategoryBudget category;

  @override
  ConsumerState<CategoryBudgetDialog> createState() =>
      _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends ConsumerState<CategoryBudgetDialog> {
  late double _percentage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _percentage = widget.category.percentage.clamp(0, _maxAllowed).toDouble();
  }

  /// Maximum percentage this category can use without exceeding 100% total.
  double get _maxAllowed {
    final others = widget.plan.allocatedPercentage - widget.category.percentage;
    final available = 100 - others;
    return available.clamp(0, 100).toDouble();
  }

  double get _amount => widget.plan.monthlyBudget * _percentage / 100;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(monthPlanningProvider.notifier).updateCategoryPercentage(
            widget.category.categoryId,
            _percentage,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = widget.category.categoryColor == 0
        ? Colors.grey
        : Color(widget.category.categoryColor);

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: categoryColor.withOpacity(0.16),
            child: Icon(
              categoryIcon(widget.category.categoryIcon),
              size: 18,
              color: categoryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.category.categoryName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Orçamento do mês: '
            '${CurrencyFormatter.format(widget.plan.monthlyBudget)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                CurrencyFormatter.format(_amount),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: _percentage.clamp(0, _maxAllowed).toDouble(),
            max: _maxAllowed <= 0 ? 1 : _maxAllowed,
            divisions:
                _maxAllowed <= 0 ? null : _maxAllowed.round().clamp(1, 100),
            label: '${_percentage.toStringAsFixed(0)}%',
            onChanged: _maxAllowed <= 0
                ? null
                : (value) => setState(() => _percentage = value),
          ),
          Text(
            'Até ${_maxAllowed.toStringAsFixed(0)}% disponível para esta '
            'categoria (respeitando o limite de 100%).',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
