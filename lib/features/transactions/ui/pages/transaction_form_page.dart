import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class TransactionFormPage extends ConsumerStatefulWidget {
  final String? transactionId;
  final bool isEditing;

  const TransactionFormPage({
    super.key,
    this.transactionId,
    required this.isEditing,
  });

  @override
  ConsumerState<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _valueFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  bool _isExpense = true;
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isSaving = false;
  List<Category> _categories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _valueController.addListener(_formatValue);
  }

  @override
  void dispose() {
    _valueController.removeListener(_formatValue);
    _valueController.dispose();
    _descriptionController.dispose();
    _valueFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _formatValue() {
    final text = _valueController.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      _valueController.value = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }

    final value = int.parse(digitsOnly);
    final formatted = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    ).format(value / 100);

    if (text != formatted) {
      _valueController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final repository = ref.read(categoriesRepositoryProvider);
      final categories = await repository.getCategories();
      if (mounted) {
        setState(() {
          _categories = categories.where((c) => c.isExpenseDefault == _isExpense).toList();
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }

  void _onTypeChanged(bool isExpense) {
    setState(() {
      _isExpense = isExpense;
      _selectedCategory = null;
      _loadCategories();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showAddCategoryModal() {
    final nameController = TextEditingController();
    int selectedColor = AppColors.categoryColors.first;
    String selectedIcon = 'category';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nova Categoria',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                hintText: 'Ex: Alimentação, Transporte, Lazer',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o nome da categoria';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Cor', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppColors.categoryColors.map((color) {
                final isSelected = color == selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: Color(color).withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Ícone', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'category', 'restaurant', 'directions_bus', 'shopping_cart',
                'movie', 'local_hospital', 'school', 'receipt',
                'payments', 'work', 'trending_up', 'pets',
                'fitness_center', 'flight', 'hotel', 'games',
              ].map((iconName) {
                final isSelected = iconName == selectedIcon;
                final iconData = _getIconData(iconName);
                return GestureDetector(
                  onTap: () => setState(() => selectedIcon = iconName),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      iconData,
                      color: isSelected ? AppColors.primary : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                
                final repository = ref.read(categoriesRepositoryProvider);
                final newCategory = Category(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  color: selectedColor,
                  icon: selectedIcon,
                  isDefault: false,
                  isExpenseDefault: _isExpense,
                  sortOrder: _categories.length,
                );
                
                await repository.createCategory(newCategory);
                if (mounted) {
                  Navigator.pop(context);
                  await _loadCategories();
                  setState(() => _selectedCategory = _categories.firstWhere(
                    (c) => c.id == newCategory.id,
                    orElse: () => _categories.first,
                  ));
                }
              },
              child: const Text('Criar Categoria'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  final _formKey = GlobalKey<FormState>();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    final valueText = _valueController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (valueText.isEmpty || int.parse(valueText) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor maior que zero')),
      );
      return;
    }

    final value = int.parse(valueText) / 100;

    setState(() => _isSaving = true);

    try {
      final transaction = Transaction(
        id: const Uuid().v4(),
        userId: ref.read(authControllerProvider).user?.id ?? 'guest',
        amount: value,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        categoryId: _selectedCategory!.id,
        subcategoryId: null,
        creditCardId: null,
        isExpense: _isExpense,
        isInstallment: false,
        installmentNumber: 1,
        totalInstallments: 1,
        installmentGroupId: null,
        notes: null,
        ownerId: null,
        partnerSynced: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(transactionsRepositoryProvider);
      await repository.createTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isExpense ? 'Despesa salva com sucesso!' : 'Receita salva com sucesso!'),
            backgroundColor: _isExpense ? AppColors.expense : AppColors.income,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExpense ? 'Nova Despesa' : 'Nova Receita'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tipo: Receita / Despesa
                          Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment<bool>(
                                value: false,
                                label: const Text('Receita'),
                                icon: const Icon(Icons.arrow_downward),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                label: const Text('Despesa'),
                                icon: const Icon(Icons.arrow_upward),
                              ),
                            ],
                            selected: {_isExpense},
                            onSelectionChanged: (selection) => _onTypeChanged(selection.first),
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return _isExpense ? AppColors.expense.withOpacity(0.1) : AppColors.income.withOpacity(0.1);
                                }
                                return Colors.transparent;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return _isExpense ? AppColors.expense : AppColors.income;
                                }
                                return Colors.grey.shade600;
                              }),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Valor
                          Text('Valor', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _valueController,
                            focusNode: _valueFocusNode,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Valor',
                              hintText: 'R\$ 0,00',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Informe o valor';
                              final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                              if (digits.isEmpty || int.parse(digits) == 0) {
                                return 'Valor deve ser maior que zero';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _descriptionFocusNode.requestFocus(),
                          ),
                          const SizedBox(height: 16),

                          // Descrição (opcional)
                          Text('Descrição (opcional)', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _descriptionController,
                            focusNode: _descriptionFocusNode,
                            textInputAction: TextInputAction.next,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Descrição',
                              hintText: 'Ex: Almoço, Uber, Salário...',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 16),

                          // Categoria
                          Text('Categoria', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Category?>
                            value: _selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Categoria',
                              hintText: 'Selecione uma categoria',
                              prefixIcon: const Icon(Icons.category_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: _showAddCategoryModal,
                                tooltip: 'Nova categoria',
                              ),
                            ),
                            items: _categories.map<DropdownMenuItem<Category?>>((category) {
                              return DropdownMenuItem<Category?>
                                value: category,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Color(category.color),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      _getIconData(category.icon),
                                      color: Color(category.color),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(category.name)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedCategory = value),
                            validator: (value) => value == null ? 'Selecione uma categoria' : null,
                          ),
                          const SizedBox(height: 16),

                          // Data
                          Text('Data', style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Data',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Botão Salvar
                          FilledButton(
                            onPressed: _isSaving ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: _isExpense ? AppColors.expense : AppColors.income,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isExpense ? 'Salvar Despesa' : 'Salvar Receita',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant': return Icons.restaurant;
      case 'directions_bus': return Icons.directions_bus;
      case 'shopping_cart': return Icons.shopping_cart;
      case 'movie': return Icons.movie;
      case 'local_hospital': return Icons.local_hospital;
      case 'school': return Icons.school;
      case 'receipt': return Icons.receipt;
      case 'payments': return Icons.payments;
      case 'work': return Icons.work;
      case 'trending_up': return Icons.trending_up;
      case 'pets': return Icons.pets;
      case 'fitness_center': return Icons.fitness_center;
      case 'flight': return Icons.flight;
      case 'hotel': return Icons.hotel;
      case 'games': return Icons.games;
      default: return Icons.category;
    }
  }
}