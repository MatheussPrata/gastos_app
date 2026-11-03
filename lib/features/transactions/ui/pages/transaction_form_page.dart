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
import 'package:gastos_app/features/recurring/utils/recurring_dates.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart'
    hide Category, RecurringTransaction;
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

const List<int> _newCategoryColors = [
  0xFFFF6B6B,
  0xFF4ECDC4,
  0xFFFFB347,
  0xFF6BCB77,
  0xFFFF8E8E,
  0xFFA8E6CF,
  0xFFB8B8B8,
];

class TransactionFormPage extends ConsumerStatefulWidget {
  final String? transactionId;
  final bool isEditing;

  const TransactionFormPage({
    super.key,
    this.transactionId,
    required this.isEditing,
  });

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isExpense = true;
  String? _categoryId;
  String _paymentMethod = PaymentMethods.all.first;
  DateTime _date = DateTime.now();
  bool _isInstallment = false;
  int _installments = 2;
  bool _isRecurring = false;
  String _frequency = 'monthly';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.transactionId != null) {
      _loadTransaction();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTransaction() async {
    final repository = ref.read(transactionsRepositoryProvider);
    final transaction =
        await repository.getTransactionById(widget.transactionId!);
    if (transaction == null || !mounted) return;

    setState(() {
      _isExpense = transaction.isExpense;
      _descriptionController.text = transaction.description;
      _amountController.text = FormHelper.formatBRL(transaction.amount);
      _categoryId = transaction.categoryId;
      _paymentMethod = transaction.paymentMethod.isEmpty
          ? PaymentMethods.all.first
          : transaction.paymentMethod;
      _date = transaction.date;
      _notesController.text = transaction.notes ?? '';
      if (transaction.isInstallment && transaction.totalInstallments > 1) {
        _isInstallment = true;
        _installments = transaction.totalInstallments;
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

    final isInstallment = _isExpense && _isInstallment;
    final installments = isInstallment ? _installments : 1;
    final notes = _notesController.text.trim();
    final now = DateTime.now();
    final repository = ref.read(transactionsRepositoryProvider);

    setState(() => _isSaving = true);

    try {
      if (widget.isEditing && widget.transactionId != null) {
        final existing =
            await repository.getTransactionById(widget.transactionId!);
        if (existing == null) throw Exception('Transação não encontrada');

        await repository.updateTransaction(existing.copyWith(
          description: _descriptionController.text.trim(),
          amount: amount,
          date: _date,
          categoryId: _categoryId,
          paymentMethod: _paymentMethod,
          isExpense: _isExpense,
          isInstallment: isInstallment,
          installmentNumber: isInstallment ? existing.installmentNumber : 1,
          totalInstallments: installments,
          notes: notes.isEmpty ? null : notes,
        ));
      } else {
        final userId = ref.read(currentUserProvider)?.id ?? 'guest';
        final transaction = Transaction(
          id: const Uuid().v4(),
          userId: userId,
          amount: amount,
          description: _descriptionController.text.trim(),
          date: _date,
          categoryId: _categoryId,
          paymentMethod: _paymentMethod,
          isExpense: _isExpense,
          isInstallment: isInstallment,
          installmentNumber: 1,
          totalInstallments: installments,
          notes: notes.isEmpty ? null : notes,
          createdAt: now,
          updatedAt: now,
        );
        await repository.createTransaction(transaction);

        if (_isRecurring) {
          final recurring = RecurringTransaction(
            id: const Uuid().v4(),
            userId: userId,
            description: transaction.description,
            amount: transaction.amount,
            type: _isExpense ? 'expense' : 'income',
            categoryId: _categoryId,
            frequency: _frequency,
            dayOfMonth: _date.day,
            startDate: _date,
            isActive: true,
            nextDueDate: RecurringDates.nextDue(_date, _frequency),
            createdAt: now,
          );
          await ref
              .read(recurringRepositoryProvider)
              .createRecurring(recurring);
        }
      }

      ref.invalidate(monthTransactionsProvider);
      ref.invalidate(transactionsListProvider);
      ref.invalidate(monthlyStatsProvider);
      ref.invalidate(recurringListProvider);

      // Planning: refresh percentages/alerts and check thresholds in the
      // background so the dialog can close immediately.
      final container = ProviderScope.containerOf(context, listen: false);
      ref
        ..invalidate(monthPlanningProvider)
        ..invalidate(planningProgressProvider)
        ..invalidate(planningAlertsProvider)
        ..invalidate(unreadAlertsProvider);
      container
          .read(planningRepositoryProvider)
          .checkAndCreateAlertsInBackground(
            month: _date,
            onAlerts: (_) {
              container
                ..invalidate(planningAlertsProvider)
                ..invalidate(unreadAlertsProvider)
                ..invalidate(planningProgressProvider);
            },
          );

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

  Future<void> _showNewCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nova Categoria'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome da categoria'),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty || !mounted) return;

    final categories =
        ref.read(categoriesListProvider).value ?? const <Category>[];
    final existingIndex = categories
        .indexWhere((c) => c.name.toLowerCase() == name.toLowerCase());

    if (existingIndex >= 0) {
      setState(() => _categoryId = categories[existingIndex].id);
      return;
    }

    final color =
        _newCategoryColors[categories.length % _newCategoryColors.length];
    final category = Category(
      id: const Uuid().v4(),
      name: name,
      color: color,
      icon: 'category',
      isDefault: false,
      isExpenseDefault: _isExpense,
      sortOrder: categories.length,
    );

    try {
      await ref.read(categoriesListProvider.notifier).createCategory(category);
      if (mounted) setState(() => _categoryId = category.id);
    } catch (e) {
      if (mounted) _showError('Erro ao salvar categoria: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Transação' : 'Nova Transação'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTypeToggle(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Supermercado',
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
              value: _paymentMethod,
              decoration:
                  const InputDecoration(labelText: 'Método de Pagamento'),
              items: [
                for (final method in PaymentMethods.all)
                  DropdownMenuItem(value: method, child: Text(method)),
              ],
              onChanged: (value) =>
                  setState(() => _paymentMethod = value ?? _paymentMethod),
            ),
            const SizedBox(height: 16),
            _buildDateField(),
            if (_isExpense) ...[
              const SizedBox(height: 8),
              _buildInstallmentSection(),
            ],
            if (!widget.isEditing) ...[
              const SizedBox(height: 8),
              _buildRecurringSection(),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Opcional',
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
                  : Text(widget.isEditing ? 'Salvar Alterações' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle() {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: true,
          icon: Icon(Icons.arrow_downward, color: AppColors.expense),
          label: Text('Gasto'),
        ),
        ButtonSegment(
          value: false,
          icon: Icon(Icons.arrow_upward, color: AppColors.income),
          label: Text('Entrada'),
        ),
      ],
      selected: {_isExpense},
      onSelectionChanged: (selection) {
        setState(() {
          _isExpense = selection.first;
          if (!_isExpense) _isInstallment = false;
        });
      },
    );
  }

  Widget _buildCategoryDropdown(AsyncValue<List<Category>> categoriesAsync) {
    return categoriesAsync.when(
      loading: () => DropdownButtonFormField<String>(
        items: const [],
        onChanged: (_) {},
        decoration: const InputDecoration(
          labelText: 'Categoria',
          hintText: 'Carregando...',
        ),
      ),
      error: (error, _) => DropdownButtonFormField<String>(
        items: const [],
        decoration: const InputDecoration(
          labelText: 'Categoria',
          hintText: 'Erro ao carregar categorias',
        ),
        onChanged: (_) {},
      ),
      data: (categories) {
        return DropdownButtonFormField<String>(
          value: _categoryId,
          decoration: const InputDecoration(labelText: 'Categoria'),
          hint: const Text('Selecione a categoria'),
          items: [
            for (final category in categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(category.name),
              ),
            const DropdownMenuItem(
              value: '__new__',
              child: Text('+ Nova Categoria'),
            ),
          ],
          onChanged: (value) {
            if (value == '__new__') {
              _showNewCategoryDialog();
            } else {
              setState(() => _categoryId = value);
            }
          },
        );
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Data',
          suffixIcon: Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormatter.formatDayMonthYear(_date)),
      ),
    );
  }

  Widget _buildInstallmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: _isInstallment,
          onChanged: (value) => setState(() => _isInstallment = value ?? false),
          title: const Text('Parcelado'),
          subtitle: const Text('Dividir em parcelas mensais'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_isInstallment)
          DropdownButtonFormField<int>(
            value: _installments,
            decoration: const InputDecoration(labelText: 'Número de Parcelas'),
            items: [
              for (var i = 2; i <= 36; i++)
                DropdownMenuItem(value: i, child: Text('${i}x')),
            ],
            onChanged: (value) => setState(() => _installments = value ?? 2),
          ),
      ],
    );
  }

  Widget _buildRecurringSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: _isRecurring,
          onChanged: _isInstallment
              ? null
              : (value) => setState(() => _isRecurring = value ?? false),
          title: const Text('Transação recorrente'),
          subtitle: const Text(
            'Repete automaticamente (contas fixas, salário, assinaturas...)',
          ),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_isRecurring)
          DropdownButtonFormField<String>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Repetir a cada'),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Dia')),
              DropdownMenuItem(value: 'weekly', child: Text('Semana')),
              DropdownMenuItem(value: 'monthly', child: Text('Mês')),
              DropdownMenuItem(value: 'yearly', child: Text('Ano')),
            ],
            onChanged: (value) =>
                setState(() => _frequency = value ?? 'monthly'),
          ),
      ],
    );
  }
}
