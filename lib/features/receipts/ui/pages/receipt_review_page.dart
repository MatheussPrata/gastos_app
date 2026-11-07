import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart' hide Category;
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

class ReceiptReviewPage extends ConsumerStatefulWidget {
  final Receipt initialReceipt;

  const ReceiptReviewPage({super.key, required this.initialReceipt});

  @override
  ConsumerState<ReceiptReviewPage> createState() => _ReceiptReviewPageState();
}

class _ReceiptReviewPageState extends ConsumerState<ReceiptReviewPage> {
  late TextEditingController _establishmentController;
  late DateTime _selectedDate;
  late String _selectedPaymentMethod;
  String? _selectedCategoryId;
  late List<ReceiptItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _establishmentController = TextEditingController(
      text: widget.initialReceipt.establishmentName,
    );
    _selectedDate = widget.initialReceipt.issueDate;
    _selectedPaymentMethod = widget.initialReceipt.paymentMethod.isNotEmpty
        ? widget.initialReceipt.paymentMethod
        : PaymentMethods.creditCard;
    _items = List.from(widget.initialReceipt.items);
  }

  @override
  void dispose() {
    _establishmentController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    if (_items.isEmpty) return widget.initialReceipt.totalAmount;
    return _items.fold(0.0, (acc, item) => acc + item.totalPrice);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final qtdController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    var category = ReceiptItemCategorizer.alimentacao;
    var unit = 'UN';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          final suggested = ReceiptItemCategorizer.categorize(nameController.text);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: bottomPadding + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Adicionar Item',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Produto (ex: Biscoito, Arroz, Sabão)',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      final auto = ReceiptItemCategorizer.categorize(val);
                      setSheetState(() => category = auto);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Detecção inteligente: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      InkWell(
                        onTap: () => setSheetState(() => category = suggested),
                        child: Text(
                          suggested,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: qtdController,
                          decoration: InputDecoration(
                            labelText: 'Qtd.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          decoration: InputDecoration(
                            labelText: 'Unidade',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'UN', child: Text('UN')),
                            DropdownMenuItem(value: 'KG', child: Text('KG')),
                            DropdownMenuItem(value: 'L', child: Text('L')),
                            DropdownMenuItem(value: 'G', child: Text('G')),
                            DropdownMenuItem(value: 'ML', child: Text('ML')),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => unit = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: priceController,
                          decoration: InputDecoration(
                            labelText: 'Preço Total (R\$)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Categoria:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReceiptItemCategorizer.availableCategories.map((c) {
                      final isSelected = c == category;
                      final color = ReceiptItemCategorizer.getColor(c);
                      final icon = ReceiptItemCategorizer.getIcon(c);

                      return ChoiceChip(
                        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                        label: Text(c),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withAlpha(20),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : color,
                        ),
                        onSelected: (val) {
                          if (val) setSheetState(() => category = c);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final name = nameController.text.trim();
                      final qtd = double.tryParse(qtdController.text.replaceAll(',', '.')) ?? 1.0;
                      final price = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0.0;

                      if (name.isNotEmpty && price > 0) {
                        setState(() {
                          _items.add(
                            ReceiptItem(
                              id: const Uuid().v4(),
                              receiptId: widget.initialReceipt.id,
                              name: name,
                              quantity: qtd,
                              unit: unit,
                              unitPrice: (price / qtd),
                              totalPrice: price,
                              category: category,
                              sortOrder: _items.length,
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Adicionar Item'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditItemDialog(int itemIndex) {
    final item = _items[itemIndex];
    final nameController = TextEditingController(text: item.name);
    final qtdController = TextEditingController(
      text: item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toString(),
    );
    final unitPriceController = TextEditingController(
      text: item.unitPrice > 0 ? item.unitPrice.toStringAsFixed(2) : '',
    );
    final totalPriceController = TextEditingController(
      text: item.totalPrice > 0 ? item.totalPrice.toStringAsFixed(2) : '',
    );
    var category = item.category;
    var unit = ['UN', 'KG', 'L', 'G', 'ML'].contains(item.unit.toUpperCase())
        ? item.unit.toUpperCase()
        : 'UN';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          final suggestedCat = ReceiptItemCategorizer.categorize(nameController.text);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: bottomPadding + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Editar Item do Cupom',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nome do Produto / Descrição',
                      prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      final auto = ReceiptItemCategorizer.categorize(val);
                      setSheetState(() => category = auto);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Detecção inteligente: ',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      InkWell(
                        onTap: () => setSheetState(() => category = suggestedCat),
                        child: Text(
                          suggestedCat,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: qtdController,
                          decoration: InputDecoration(
                            labelText: 'Qtd.',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final q = double.tryParse(val.replaceAll(',', '.')) ?? 1.0;
                            final u = double.tryParse(unitPriceController.text.replaceAll(',', '.')) ?? 0.0;
                            if (q > 0 && u > 0) {
                              totalPriceController.text = (q * u).toStringAsFixed(2);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          decoration: InputDecoration(
                            labelText: 'Unidade',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'UN', child: Text('UN')),
                            DropdownMenuItem(value: 'KG', child: Text('KG')),
                            DropdownMenuItem(value: 'L', child: Text('L')),
                            DropdownMenuItem(value: 'G', child: Text('G')),
                            DropdownMenuItem(value: 'ML', child: Text('ML')),
                          ],
                          onChanged: (val) {
                            if (val != null) setSheetState(() => unit = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: totalPriceController,
                          decoration: InputDecoration(
                            labelText: 'Total (R\$)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final t = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
                            final q = double.tryParse(qtdController.text.replaceAll(',', '.')) ?? 1.0;
                            if (t > 0 && q > 0) {
                              unitPriceController.text = (t / q).toStringAsFixed(2);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Categoria do Item:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReceiptItemCategorizer.availableCategories.map((c) {
                      final isSelected = c == category;
                      final color = ReceiptItemCategorizer.getColor(c);
                      final icon = ReceiptItemCategorizer.getIcon(c);

                      return ChoiceChip(
                        avatar: Icon(icon, size: 14, color: isSelected ? Colors.white : color),
                        label: Text(c),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withAlpha(20),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : color,
                        ),
                        onSelected: (val) {
                          if (val) setSheetState(() => category = c);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Excluir', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          _removeItem(itemIndex);
                          Navigator.pop(ctx);
                        },
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final name = nameController.text.trim();
                          final q = double.tryParse(qtdController.text.replaceAll(',', '.')) ?? 1.0;
                          final total = double.tryParse(totalPriceController.text.replaceAll(',', '.')) ?? item.totalPrice;
                          final unitPrice = q > 0 ? (total / q) : total;

                          if (name.isNotEmpty && total > 0) {
                            setState(() {
                              _items[itemIndex] = _items[itemIndex].copyWith(
                                name: name,
                                quantity: q,
                                unit: unit,
                                unitPrice: unitPrice,
                                totalPrice: total,
                                category: category,
                              );
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        child: const Text('Salvar Item'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveReceipt() async {
    if (_isSaving) return;

    final user = ref.read(currentUserProvider);
    final userId = user?.id ?? '';

    setState(() => _isSaving = true);

    try {
      final updatedReceipt = widget.initialReceipt.copyWith(
        establishmentName: _establishmentController.text.trim().isNotEmpty
            ? _establishmentController.text.trim()
            : 'Supermercado (PR)',
        issueDate: _selectedDate,
        paymentMethod: _selectedPaymentMethod,
        totalAmount: _totalAmount,
        items: _items,
      );

      final result = await ref
          .read(receiptsRepositoryProvider)
          .saveReceiptWithTransaction(
            receipt: updatedReceipt,
            categoryId: _selectedCategoryId,
            userId: userId,
          );

      // Invalida todos os providers de dados financeiros
      ref
        ..invalidate(transactionsListProvider)
        ..invalidate(monthTransactionsProvider)
        ..invalidate(monthlyStatsProvider)
        ..invalidate(monthlyCategoryStatsProvider)
        ..invalidate(monthPlanningProvider)
        ..invalidate(planningProgressProvider)
        ..invalidate(planningAlertsProvider)
        ..invalidate(unreadAlertsProvider)
        ..invalidate(monthlyIncomeProvider)
        ..invalidate(incomeAttributionProvider)
        ..invalidate(monthSpentTotalProvider);

      for (final scope in BudgetScope.values) {
        ref.read(planningRepositoryProvider).checkAndCreateAlertsInBackground(
              month: updatedReceipt.issueDate,
              scope: scope,
            );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compra e cupom fiscal salvos com sucesso!'),
          backgroundColor: AppColors.income,
        ),
      );

      // Navega para a tela de detalhes do cupom
      context.go(RouteNames.dashboard);
      context.push(
        RouteNames.receiptDetail,
        extra: {
          'receiptId': result.receipt.id,
          'transactionId': result.transaction.id,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar cupom: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar Cupom Fiscal'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (categories) {
          // Preenche a categoria padrão se ainda não tiver
          if (_selectedCategoryId == null && categories.isNotEmpty) {
            final match = categories.firstWhere(
              (c) =>
                  c.name.toLowerCase().contains('compra') ||
                  c.name.toLowerCase().contains('supermercado') ||
                  c.name.toLowerCase().contains('aliment'),
              orElse: () => categories.firstWhere(
                (c) => c.isExpenseDefault,
                orElse: () => categories.first,
              ),
            );
            _selectedCategoryId = match.id;
          }

          final summaries = ReceiptsRepository.getCategorySummaries(
            widget.initialReceipt.copyWith(
              totalAmount: _totalAmount,
              items: _items,
            ),
          );

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  children: [
                    _buildGeneralInfoCard(categories),
                    const SizedBox(height: 12),
                    _buildCategorySummaries(summaries),
                    const SizedBox(height: 16),
                    _buildItemsHeader(),
                    const SizedBox(height: 8),
                    _buildCategorizedItemsList(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveReceipt,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirmar e Salvar Compra (${CurrencyFormatter.format(_totalAmount)})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoCard(List<Category> categories) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _establishmentController,
              decoration: const InputDecoration(
                labelText: 'Estabelecimento / Supermercado',
                prefixIcon: Icon(Icons.store),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data da Compra',
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      child: Text(
                        DateFormatter.formatDayMonthYear(_selectedDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Pagamento',
                      prefixIcon: Icon(Icons.payment, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PaymentMethods.creditCard,
                        child: Text('Crédito'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethods.debitCard,
                        child: Text('Débito'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethods.pix,
                        child: Text('PIX'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethods.money,
                        child: Text('Dinheiro'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPaymentMethod = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Categoria Financeira Macro',
                prefixIcon: Icon(Icons.category, size: 20),
              ),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCategoryId = val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySummaries(List<ReceiptCategorySummary> summaries) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Divisão por Setor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              '${summaries.length} categorias identificadas',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: summaries.map((s) {
            final color = ReceiptItemCategorizer.getColor(s.category);
            final icon = ReceiptItemCategorizer.getIcon(s.category);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    '${s.category}: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                  Text(
                    '${CurrencyFormatter.format(s.totalAmount)} (${s.percentage}%)',
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildItemsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Itens por Categoria (${_items.length})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        TextButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Adicionar'),
          onPressed: _showAddItemDialog,
        ),
      ],
    );
  }

  Widget _buildCategorizedItemsList() {
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum item na lista'),
        ),
      );
    }

    // Agrupa os itens pelas categorias preservando a ordem
    final grouped = <String, List<({int originalIndex, ReceiptItem item})>>{};
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      grouped.putIfAbsent(item.category, () => []).add((originalIndex: i, item: item));
    }

    // Ordena as categorias de acordo com availableCategories
    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) {
        final idxA = ReceiptItemCategorizer.availableCategories.indexOf(a);
        final idxB = ReceiptItemCategorizer.availableCategories.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return Column(
      children: sortedCategories.map((category) {
        final categoryItems = grouped[category]!;
        final color = ReceiptItemCategorizer.getColor(category);
        final icon = ReceiptItemCategorizer.getIcon(category);
        final totalCategory = categoryItems.fold(0.0, (acc, entry) => acc + entry.item.totalPrice);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho da Categoria
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Text(
                      category,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${categoryItems.length} ${categoryItems.length == 1 ? "item" : "itens"}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.format(totalCategory),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),

              // Itens pertencentes a essa categoria
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: categoryItems.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withAlpha(30)),
                itemBuilder: (context, idx) {
                  final entry = categoryItems[idx];
                  final item = entry.item;
                  final originalIndex = entry.originalIndex;

                  return InkWell(
                    onTap: () => _showEditItemDialog(originalIndex),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.quantity.toStringAsFixed(item.unit == "KG" ? 3 : 1)} ${item.unit} × ${CurrencyFormatter.format(item.unitPrice)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyFormatter.format(item.totalPrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: AppColors.expense,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                                    tooltip: 'Editar item',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _showEditItemDialog(originalIndex),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                    tooltip: 'Remover',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _removeItem(originalIndex),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
