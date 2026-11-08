import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/planning/ui/widgets/category_budget_dialog.dart';
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
  Map<String, double> _spentByCategory = {};

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpending();
      if (_draft.categories.isEmpty) {
        _autoLoadCategories();
      }
    });
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

  Future<void> _loadSpending() async {
    try {
      final repo = ref.read(planningRepositoryProvider);
      final spent =
          await repo.getSpentByCategory(_draft.month, scope: _draft.scope);
      if (mounted) {
        setState(() => _spentByCategory = spent);
      }
    } catch (_) {}
  }

  Future<void> _autoLoadCategories() async {
    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final allCategories = await categoriesRepo.getCategories();
      final expenseCategories =
          allCategories.where((c) => c.isExpenseDefault).toList();

      if (expenseCategories.isNotEmpty &&
          mounted &&
          _draft.categories.isEmpty) {
        setState(() {
          _draft = _draft.copyWith(
            categories: [
              for (var i = 0; i < expenseCategories.length; i++)
                CategoryBudget(
                  categoryId: expenseCategories[i].id,
                  categoryName: expenseCategories[i].name,
                  categoryColor: expenseCategories[i].color,
                  categoryIcon: expenseCategories[i].icon,
                  percentage: 0,
                  sortOrder: i,
                ),
            ],
          );
        });
      }
    } catch (_) {}
  }

  Future<void> _addCategoryDialog() async {
    try {
      final categoriesRepo = ref.read(categoriesRepositoryProvider);
      final allCategories = await categoriesRepo.getCategories();
      final expenseCategories =
          allCategories.where((c) => c.isExpenseDefault).toList();

      final existingIds = _draft.categories.map((c) => c.categoryId).toSet();
      final available =
          expenseCategories.where((c) => !existingIds.contains(c.id)).toList();

      if (!mounted) return;

      if (available.isEmpty) {
        _showError('Todas as suas categorias já foram adicionadas ao orçamento.');
        return;
      }

      final selected = await showDialog<Category>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Adicionar Categoria ao Orçamento'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (_, index) {
                final cat = available[index];
                final color =
                    cat.color == 0 ? Colors.grey : Color(cat.color);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.18),
                    child:
                        Icon(categoryIcon(cat.icon), color: color, size: 20),
                  ),
                  title: Text(cat.name),
                  onTap: () => Navigator.of(ctx).pop(cat),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          _draft = _draft.upsertCategory(
            CategoryBudget(
              categoryId: selected.id,
              categoryName: selected.name,
              categoryColor: selected.color,
              categoryIcon: selected.icon,
              percentage: 0,
              sortOrder: _draft.categories.length,
            ),
          );
        });
      }
    } catch (e) {
      _showError('Erro ao carregar categorias: $e');
    }
  }

  void _removeCategory(String categoryId) {
    setState(() {
      final updated = _draft.categories
          .where((c) => c.categoryId != categoryId)
          .toList();
      _draft = _draft.copyWith(categories: updated);
    });
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

  Future<void> _editCategory(CategoryBudget category) async {
    await showDialog<void>(
      context: context,
      builder: (_) => CategoryBudgetDialog(
        plan: _draft,
        category: category,
        onSave: (percentage) async {
          setState(() {
            _draft = _draft.upsertCategory(
              category.copyWith(percentage: percentage),
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.plan.scope == BudgetScope.couple
              ? 'Orçamento do casal'
              : 'Orçamento individual',
        ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _SectionLabel('Distribuição por categoria'),
                TextButton.icon(
                  onPressed: _addCategoryDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
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
                spentAmount: _spentByCategory[category.categoryId] ?? 0.0,
                onChanged: (value) => setState(() {
                  _draft = _draft.upsertCategory(
                    category.copyWith(percentage: value),
                  );
                }),
                onEdit: () => _editCategory(category),
                onDelete: () => _removeCategory(category.categoryId),
              ),
            if (_draft.categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhuma categoria no orçamento ainda. Toque em "Adicionar" acima para incluir categorias.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addCategoryDialog,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Categoria ao Orçamento'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _ActualIncomePreview extends ConsumerWidget {
  const _ActualIncomePreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(monthlyIncomeProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Renda calculada a partir dos seus lançamentos de entrada:',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  incomeAsync.isLoading
                      ? '...'
                      : CurrencyFormatter.format(incomeAsync.valueOrNull ?? 0),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
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
    required this.spentAmount,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryBudget category;
  final double monthlyBudget;
  final double maxPercentage;
  final double spentAmount;
  final ValueChanged<double> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(8),
            child: Row(
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
                Icon(Icons.edit_outlined, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  '${value.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.grey.shade400,
                  tooltip: 'Remover do orçamento',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: color,
                    inactiveTrackColor: color.withOpacity(0.18),
                    thumbColor: color,
                    overlayColor: color.withOpacity(0.12),
                    valueIndicatorColor: color,
                    valueIndicatorTextStyle:
                        const TextStyle(color: Colors.white),
                  ),
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
          if (spentAmount > 0)
            Padding(
              padding: const EdgeInsets.only(left: 38, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gasto atual no mês: ${CurrencyFormatter.format(spentAmount)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: spentAmount > amount && amount > 0
                          ? AppColors.expense
                          : Colors.grey.shade600,
                      fontWeight: spentAmount > amount && amount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (amount > 0)
                    Text(
                      spentAmount <= amount
                          ? 'Sobra ${CurrencyFormatter.format(amount - spentAmount)}'
                          : 'Excede ${CurrencyFormatter.format(spentAmount - amount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: spentAmount <= amount
                            ? AppColors.secondary
                            : AppColors.expense,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
