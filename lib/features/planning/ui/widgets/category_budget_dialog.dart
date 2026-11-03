import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';

enum _EntryMode { percentage, currency }

/// Dialog to adjust the percentage of a single category.
///
/// When [onSave] is provided the value is handed back to the caller instead of
/// being persisted (used by the setup screen's draft).
class CategoryBudgetDialog extends ConsumerStatefulWidget {
  const CategoryBudgetDialog({
    super.key,
    required this.plan,
    required this.category,
    this.onSave,
  });

  final BudgetPlan plan;
  final CategoryBudget category;
  final Future<void> Function(double percentage)? onSave;

  @override
  ConsumerState<CategoryBudgetDialog> createState() =>
      _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends ConsumerState<CategoryBudgetDialog> {
  late double _percentage;
  late final TextEditingController _valueController;
  _EntryMode _entryMode = _EntryMode.percentage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _percentage = widget.category.percentage.clamp(0, _maxAllowed).toDouble();
    _valueController = TextEditingController(
      text: _percentage.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  /// Maximum percentage this category can use without exceeding 100% total.
  double get _maxAllowed {
    final others = widget.plan.allocatedPercentage - widget.category.percentage;
    final available = 100 - others;
    return available.clamp(0, 100).toDouble();
  }

  double get _amount => widget.plan.monthlyBudget * _percentage / 100;

  double get _maxAmount => widget.plan.monthlyBudget * _maxAllowed / 100;

  Color get _color => widget.category.categoryColor == 0
      ? Colors.grey
      : Color(widget.category.categoryColor);

  void _syncValueText() {
    final text = _entryMode == _EntryMode.percentage
        ? _percentage.toStringAsFixed(0)
        : CurrencyFormatter.format(_amount);
    _valueController.text = text;
    _valueController.selection = TextSelection.collapsed(offset: text.length);
  }

  void _onTyped(String raw) {
    double percentage;
    if (_entryMode == _EntryMode.percentage) {
      percentage = double.tryParse(raw.replaceAll(',', '.')) ?? _percentage;
    } else {
      final amount = FormHelper.parseBRL(raw);
      percentage = widget.plan.monthlyBudget <= 0
          ? 0
          : amount / widget.plan.monthlyBudget * 100;
    }
    setState(() {
      _percentage = percentage.clamp(0, _maxAllowed).toDouble();
    });
  }

  void _setEntryMode(_EntryMode mode) {
    setState(() {
      _entryMode = mode;
      _syncValueText();
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      if (widget.onSave != null) {
        await widget.onSave!(_percentage);
      } else {
        await ref.read(monthPlanningProvider.notifier).updateCategoryPercentage(
              widget.category.categoryId,
              _percentage,
            );
      }
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
    final isPercentage = _entryMode == _EntryMode.percentage;

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _color.withOpacity(0.16),
            child: Icon(
              categoryIcon(widget.category.categoryIcon),
              size: 18,
              color: _color,
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orçamento do mês: '
              '${CurrencyFormatter.format(widget.plan.monthlyBudget)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            SegmentedButton<_EntryMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              segments: const [
                ButtonSegment(
                  value: _EntryMode.percentage,
                  label: Text('%'),
                ),
                ButtonSegment(
                  value: _EntryMode.currency,
                  label: Text('R\$'),
                ),
              ],
              selected: {_entryMode},
              onSelectionChanged: (selection) => _setEntryMode(selection.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _valueController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: isPercentage
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
                  : [BRLTextInputFormatter()],
              decoration: InputDecoration(
                labelText: isPercentage ? 'Percentual' : 'Valor',
                suffixText: isPercentage ? '%' : null,
                helperText: isPercentage
                    ? 'Máximo ${_maxAllowed.toStringAsFixed(0)}%'
                    : 'Máximo ${CurrencyFormatter.format(_maxAmount)}',
              ),
              onChanged: _onTyped,
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _color,
                inactiveTrackColor: _color.withOpacity(0.18),
                thumbColor: _color,
                overlayColor: _color.withOpacity(0.12),
                valueIndicatorColor: _color,
                valueIndicatorTextStyle: const TextStyle(color: Colors.white),
              ),
              child: Slider(
                value: _percentage.clamp(0, _maxAllowed).toDouble(),
                max: _maxAllowed <= 0 ? 1 : _maxAllowed,
                divisions:
                    _maxAllowed <= 0 ? null : _maxAllowed.round().clamp(1, 100),
                label: '${_percentage.toStringAsFixed(0)}%',
                onChanged: _maxAllowed <= 0
                    ? null
                    : (value) {
                        setState(() => _percentage = value);
                        _syncValueText();
                      },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _color,
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
          ],
        ),
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
