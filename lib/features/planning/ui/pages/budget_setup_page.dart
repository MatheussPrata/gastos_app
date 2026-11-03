import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/ui/widgets/notification_settings_dialog.dart';

/// Full-screen editor for the monthly budget plan.
class BudgetSetupPage extends ConsumerStatefulWidget {
  const BudgetSetupPage({super.key, required this.plan});

  final BudgetPlan plan;

  @override
  ConsumerState<BudgetSetupPage> createState() => _BudgetSetupPageState();
}

class _BudgetSetupPageState extends ConsumerState<BudgetSetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _incomeController;
  late final TextEditingController _budgetController;

  late BudgetPlan _draft;
  late IncomeMode _incomeMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.plan;
    _incomeMode = widget.plan.incomeMode;
    _incomeController = TextEditingController(
      text: widget.plan.manualIncome > 0
          ? CurrencyFormatter.format(widget.plan.manualIncome)
          : '',
    );
    _budgetController = TextEditingController(
      text: widget.plan.monthlyBudget > 0
          ? CurrencyFormatter.format(widget.plan.monthlyBudget)
          : '',
    );
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  double get _allocatedPercentage => _draft.allocatedPercentage;

  double get _unallocatedPercentage {
    final remaining = 100 - _allocatedPercentage;
    return remaining < 0 ? 0 : remaining;
  }

  /// Maximum percentage a category can use without passing 100% in total.
  double _maxFor(CategoryBudget category) {
    final others = _allocatedPercentage - category.percentage;
    return (100 - others).clamp(0, 100).toDouble();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final monthlyBudget = FormHelper.parseBRL(_budgetController.text);
    if (monthlyBudget <= 0) {
      _showError('Informe um orçamento maior que zero.');
      return;
    }

    final income = FormHelper.parseBRL(_incomeController.text);
    final next = _draft.copyWith(
      incomeMode: _incomeMode,
      manualIncome: income,
      monthlyBudget: monthlyBudget,
    );

    if (!next.isValid) {
      _showError(
        'A soma dos percentuais passa de 100% '
        '(${next.allocatedPercentage.toStringAsFixed(0)}%).',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(monthPlanningProvider.notifier).applyPlan(next);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError('Erro ao salvar: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openNotificationSettings() async {
    final result = await showDialog<NotificationSettings>(
      context: context,
      builder: (_) =>
          NotificationSettingsDialog(settings: _draft.notifications),
    );
    if (result != null && mounted) {
      setState(() => _draft = _draft.copyWith(notifications: result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar orçamento'),
        actions: [
          IconButton(
            tooltip: 'Alertas de limite',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _openNotificationSettings,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _SectionLabel('Renda mensal'),
            SegmentedButton<IncomeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: IncomeMode.manual,
                  icon: Icon(Icons.edit_outlined),
                  label: Text('Manual'),
                ),
                ButtonSegment(
                  value: IncomeMode.actual,
                  icon: Icon(Icons.auto_graph),
                  label: Text('Automática'),
                ),
              ],
              selected: {_incomeMode},
              onSelectionChanged: (selection) {
                setState(() => _incomeMode = selection.first);
              },
            ),
            const SizedBox(height: 12),
            if (_incomeMode == IncomeMode.manual)
              TextFormField(
                controller: _incomeController,
                keyboardType: TextInputType.number,
                inputFormatters: [BRLTextInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Renda mensal esperada',
                  hintText: 'R\$ 0,00',
                ),
              )
            else
              const _ActualIncomePreview(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              inputFormatters: [BRLTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Orçamento total do mês',
                hintText: 'R\$ 0,00',
              ),
              validator: (value) {
                if (FormHelper.parseBRL(value ?? '') <= 0) {
                  return 'Informe um valor maior que zero';
                }
                return null;
              },
              onChanged: (value) => setState(() {
                _draft = _draft.copyWith(
                  monthlyBudget: FormHelper.parseBRL(value),
                );
              }),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Distribuição por categoria'),
            _DistributionSummary(
              allocatedPercentage: _allocatedPercentage,
              unallocatedPercentage: _unallocatedPercentage,
              reserveAmount:
                  _draft.monthlyBudget * _unallocatedPercentage / 100,
            ),
            const SizedBox(height: 8),
            for (final category in _draft.categories)
              _CategorySliderTile(
                key: ValueKey(category.categoryId),
                category: category,
                monthlyBudget: _draft.monthlyBudget,
                maxPercentage: _maxFor(category),
                onChanged: (value) => setState(() {
                  _draft = _draft.upsertCategory(
                    category.copyWith(percentage: value),
                  );
                }),
              ),
            if (_draft.categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhuma categoria de despesa encontrada. Cadastre categorias '
                  'em uma transação para distribuí-las aqui.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar planejamento'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ActualIncomePreview extends ConsumerWidget {
  const _ActualIncomePreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedPlanMonthProvider);
    final incomeAsync = ref.watch(
      actualIncomeForMonthProvider(DateTime(month.year, month.month)),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_graph, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receitas reais do mês',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  incomeAsync.when(
                    loading: () => 'Carregando...',
                    error: (_, __) => 'Não foi possível calcular',
                    data: CurrencyFormatter.format,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionSummary extends StatelessWidget {
  const _DistributionSummary({
    required this.allocatedPercentage,
    required this.unallocatedPercentage,
    required this.reserveAmount,
  });

  final double allocatedPercentage;
  final double unallocatedPercentage;
  final double reserveAmount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distribuído'),
                Text(
                  '${allocatedPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (allocatedPercentage / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reserva (${unallocatedPercentage.toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Text(
                  CurrencyFormatter.format(reserveAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySliderTile extends StatelessWidget {
  const _CategorySliderTile({
    super.key,
    required this.category,
    required this.monthlyBudget,
    required this.maxPercentage,
    required this.onChanged,
  });

  final CategoryBudget category;
  final double monthlyBudget;
  final double maxPercentage;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = category.categoryColor == 0
        ? Colors.grey
        : Color(category.categoryColor);
    final value = category.percentage.clamp(0, maxPercentage).toDouble();
    final amount = monthlyBudget * value / 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.16),
                child: Icon(
                  categoryIcon(category.categoryIcon),
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  max: maxPercentage <= 0 ? 1 : maxPercentage,
                  divisions: maxPercentage <= 0
                      ? null
                      : maxPercentage.round().clamp(1, 100),
                  label: '${value.toStringAsFixed(0)}%',
                  onChanged: maxPercentage <= 0 ? null : onChanged,
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  CurrencyFormatter.format(amount),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
