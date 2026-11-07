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

  void _changeItemCategory(int index, String newCategory) {
    setState(() {
      _items[index] = _items[index].copyWith(category: newCategory);
    });
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
    var category = ReceiptItemCategorizer.outros;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Adicionar Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  onChanged: (val) {
                    final auto = ReceiptItemCategorizer.categorize(val);
                    setDialogState(() => category = auto);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtdController,
                        decoration: const InputDecoration(labelText: 'Qtd'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: priceController,
                        decoration:
                            const InputDecoration(labelText: 'Preço Total (R\$)'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: ReceiptItemCategorizer.availableCategories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            children: [
                              Icon(
                                ReceiptItemCategorizer.getIcon(c),
                                size: 18,
                                color: ReceiptItemCategorizer.getColor(c),
                              ),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => category = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final qtd = double.tryParse(
                      qtdController.text.replaceAll(',', '.'),
                    ) ??
                    1.0;
                final price = double.tryParse(
                      priceController.text.replaceAll(',', '.'),
                    ) ??
                    0.0;

                if (name.isNotEmpty && price > 0) {
                  setState(() {
                    _items.add(
                      ReceiptItem(
                        id: const Uuid().v4(),
                        receiptId: widget.initialReceipt.id,
                        name: name,
                        quantity: qtd,
                        unit: 'UN',
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
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPickerSheet(int itemIndex) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Alterar categoria do item',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ReceiptItemCategorizer.availableCategories.length,
                  itemBuilder: (ctx, i) {
                    final cat =
                        ReceiptItemCategorizer.availableCategories[i];
                    final isSelected = _items[itemIndex].category == cat;
                    final color = ReceiptItemCategorizer.getColor(cat);
                    final icon = ReceiptItemCategorizer.getIcon(cat);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withAlpha(38),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        cat,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check, color: color)
                          : null,
                      onTap: () {
                        _changeItemCategory(itemIndex, cat);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
                    _buildItemsList(),
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
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data da Compra',
                        prefixIcon: Icon(Icons.calendar_today, size: 20),
                      ),
                      child: Text(
                        DateFormatter.formatDayMonthYear(_selectedDate),
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
                    items: PaymentMethods.all
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
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
                labelText: 'Categoria Macro (para relatórios)',
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
              'Divisão por Setores da Compra',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              'Total: ${CurrencyFormatter.format(_totalAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.expense,
              ),
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
          'Itens do Cupom (${_items.length})',
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

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum item na lista'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final item = _items[index];
        final catColor = ReceiptItemCategorizer.getColor(item.category);
        final catIcon = ReceiptItemCategorizer.getIcon(item.category);

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity.toStringAsFixed(item.unit == "KG" ? 3 : 1)} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Chip da categoria do item
                      InkWell(
                        onTap: () => _showCategoryPickerSheet(index),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: catColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: catColor.withAlpha(70)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(catIcon, size: 14, color: catColor),
                              const SizedBox(width: 4),
                              Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: catColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 14,
                                color: catColor,
                              ),
                            ],
                          ),
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
                        fontSize: 14,
                        color: AppColors.expense,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.grey,
                        size: 20,
                      ),
                      tooltip: 'Remover',
                      onPressed: () => _removeItem(index),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
