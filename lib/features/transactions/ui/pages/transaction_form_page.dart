import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/ui/category_icons.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart'
    hide Category;
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

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

    // Guard against a category from the opposite type being persisted.
    final expectedType =
        _isExpense ? CategoryType.expense : CategoryType.income;
    final categories =
        ref.read(categoriesListProvider).valueOrNull ?? const <Category>[];
    Category? selectedCategory;
    for (final category in categories) {
      if (category.id == _categoryId) {
        selectedCategory = category;
        break;
      }
    }
    final categoryId =
        selectedCategory?.type == expectedType ? selectedCategory!.id : null;

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
          categoryId: categoryId,
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
          categoryId: categoryId,
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
      }

      ref.invalidate(monthTransactionsProvider);
      ref.invalidate(transactionsListProvider);
      ref.invalidate(monthlyStatsProvider);

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
          label: Text('Saída'),
        ),
        ButtonSegment(
          value: false,
          icon: Icon(Icons.arrow_upward, color: AppColors.income),
          label: Text('Entrada'),
        ),
      ],
      selected: {_isExpense},
      onSelectionChanged: (selection) {
        final newIsExpense = selection.first;
        setState(() {
          // Categories are type-specific: clear the selection when switching.
          if (_isExpense != newIsExpense) _categoryId = null;
          _isExpense = newIsExpense;
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
        final type = _isExpense ? CategoryType.expense : CategoryType.income;
        final filtered = categories
            .where((category) => category.type == type)
            .toList(growable: false);
        final hasSelected =
            filtered.any((category) => category.id == _categoryId);
        final selected = hasSelected ? _categoryId : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria'),
              hint: Text(
                filtered.isEmpty
                    ? 'Nenhuma categoria cadastrada'
                    : 'Selecione a categoria',
              ),
              items: [
                for (final category in filtered)
                  DropdownMenuItem(
                    value: category.id,
                    child: Row(
                      children: [
                        Icon(
                          CategoryIcons.resolve(category.icon),
                          size: 20,
                          color: Color(category.color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onChanged: filtered.isEmpty
                  ? null
                  : (value) => setState(() => _categoryId = value),
            ),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  'Cadastre categorias em Configurações > Gerenciar Categorias.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
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
}
