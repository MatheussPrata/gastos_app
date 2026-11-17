import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/core/widgets/empty_state.dart';
import 'package:gastos_app/features/goals/provider/goals_provider.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro ao carregar metas: $error')),
        data: (goals) {
          if (goals.isEmpty) {
            return const EmptyState(
              icon: Icons.flag_outlined,
              title: 'Nenhuma meta ainda',
              message: 'Toque em + para criar sua primeira meta.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) => _GoalCard(goal: goals[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova meta',
        onPressed: () => _showGoalForm(context, goal: null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final db.Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = goal.targetAmount <= 0 ? 1.0 : goal.targetAmount;
    final ratio = (goal.savedAmount / target).clamp(0.0, 1.0);
    final color = Color(goal.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.flag, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    goal.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showGoalForm(context, goal: goal);
                    } else if (value == 'delete') {
                      ref.read(goalsProvider.notifier).delete(goal.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.15),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${CurrencyFormatter.format(goal.savedAmount)} de '
                  '${CurrencyFormatter.format(goal.targetAmount)}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  '${(ratio * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
            if (goal.targetDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Prazo: ${_formatDate(goal.targetDate!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

Future<void> _showGoalForm(BuildContext context, {db.Goal? goal}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _GoalForm(goal: goal),
    ),
  );
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({this.goal});

  final db.Goal? goal;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _name = TextEditingController(text: goal?.name ?? '');
    _target = TextEditingController(
      text: goal == null ? '' : goal.targetAmount.toStringAsFixed(2),
    );
    _saved = TextEditingController(
      text: goal == null ? '' : goal.savedAmount.toStringAsFixed(2),
    );
    _targetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  double _parse(String text) =>
      double.tryParse(text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = _parse(_target.text);
    if (name.isEmpty || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome e um valor alvo.')),
      );
      return;
    }
    setState(() => _saving = true);
    await ref.read(goalsProvider.notifier).save(
          id: widget.goal?.id,
          name: name,
          targetAmount: target,
          savedAmount: _parse(_saved.text),
          targetDate: _targetDate,
          color: widget.goal?.color ?? AppColors.secondary.value,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.goal == null ? 'Nova meta' : 'Editar meta',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome da meta'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _target,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Valor alvo (R\$)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _saved,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Já guardado (R\$)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                _targetDate == null
                    ? 'Definir prazo (opcional)'
                    : '${_targetDate!.day.toString().padLeft(2, '0')}/'
                        '${_targetDate!.month.toString().padLeft(2, '0')}/'
                        '${_targetDate!.year}',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar meta'),
            ),
          ],
        ),
      ),
    );
  }
}
