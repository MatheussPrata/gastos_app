import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/recurring/models/recurring_models.dart';
import 'package:gastos_app/features/recurring/provider/recurring_provider.dart';
import 'package:gastos_app/features/recurring/repository/recurring_repository.dart';
import 'package:gastos_app/features/recurring/utils/recurring_dates.dart';

/// Formulario de transacao recorrente (criar/editar).
class RecurringFormPage extends ConsumerStatefulWidget {
  final String? recurringId;
  final bool isEditing;

  const RecurringFormPage({
    super.key,
    this.recurringId,
    required this.isEditing,
  });

  @override
  ConsumerState<RecurringFormPage> createState() => _RecurringFormPageState();
}

class _RecurringFormPageState extends ConsumerState<RecurringFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isExpense = true;
  String? _categoryId;
  String _frequency = 'monthly';
  DateTime _date = DateTime.now();
  bool _isActive = true;
  bool _isSaving = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.recurringId != null) {
      _load();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final existing = await ref
        .read(recurringRepositoryProvider)
        .getRecurringById(widget.recurringId!);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (existing != null) {
        _isExpense = existing.type == 'expense';
        _descriptionController.text = existing.description;
        _amountController.text = FormHelper.formatBRL(existing.amount);
        _categoryId = existing.categoryId;
        _frequency = existing.frequency;
        _date = existing.startDate;
        _isActive = existing.isActive;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = FormHelper.parseBRL(_amountController.text);
    if (amount <= 0) {
      _showError('Informe um valor maior que zero.');
      return;
    }

    setState(() => _isSaving = true);
    final description = _descriptionController.text.trim();
    final type = _isExpense ? 'expense' : 'income';
    final now = DateTime.now();

    try {
      if (widget.isEditing && widget.recurringId != null) {
        final existing = await ref
            .read(recurringRepositoryProvider)
            .getRecurringById(widget.recurringId!);
        if (existing == null) throw Exception('Recorrência não encontrada');

        await ref.read(recurringListProvider.notifier).updateRecurring(
              existing.copyWith(
                description: description,
                amount: amount,
                type: type,
                categoryId: _categoryId,
                frequency: _frequency,
                dayOfMonth: _date.day,
                startDate: _date,
                isActive: _isActive,
                nextDueDate: RecurringDates.nextDue(_date, _frequency),
              ),
            );
      } else {
        final userId = ref.read(currentUserProvider)?.id ?? 'guest';
        final recurring = RecurringTransaction(
          id: const Uuid().v4(),
          userId: userId,
          description: description,
          amount: amount,
          type: type,
          categoryId: _categoryId,
          frequency: _frequency,
          dayOfMonth: _date.day,
          startDate: _date,
          isActive: _isActive,
          nextDueDate: RecurringDates.nextDue(_date, _frequency),
          createdAt: now,
        );
        await ref
            .read(recurringListProvider.notifier)
            .createRecurring(recurring);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showError('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEditing ? 'Editar Recorrência' : 'Nova Recorrência'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Gasto')),
                ButtonSegment(value: false, label: Text('Entrada')),
              ],
              selected: {_isExpense},
              onSelectionChanged: (selection) =>
                  setState(() => _isExpense = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Aluguel, Academia, Salário',
              ),
              validator: Validators.required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [BRLTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Valor',
                hintText: 'R\$ 0,00',
              ),
              validator: (value) {
                if (FormHelper.parseBRL(value ?? '') <= 0) {
                  return 'Informe um valor maior que zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(categoriesAsync),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequência'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Diária')),
                DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
                DropdownMenuItem(value: 'yearly', child: Text('Anual')),
              ],
              onChanged: (value) =>
                  setState(() => _frequency = value ?? 'monthly'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Início'),
              subtitle: Text(DateFormatter.formatDayMonthYear(_date)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativa'),
              subtitle: const Text('Desative para pausar sem excluir'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Salvar Alterações' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(AsyncValue<List<Category>> categoriesAsync) {
    final categories = categoriesAsync.value ?? const <Category>[];
    final current = _categoryId;
    return DropdownButtonFormField<String?>(
      value: current,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Categoria'),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Sem categoria'),
        ),
        for (final category in categories)
          DropdownMenuItem<String?>(
            value: category.id,
            child: Text(category.name),
          ),
        if (current != null && !categories.any((c) => c.id == current))
          DropdownMenuItem<String?>(
            value: current,
            child: Text('Categoria removida'),
          ),
      ],
      onChanged: (value) => setState(() => _categoryId = value),
    );
  }
}
