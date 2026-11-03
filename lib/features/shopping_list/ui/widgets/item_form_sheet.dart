import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';
import 'package:gastos_app/features/shopping_list/provider/shopping_list_provider.dart';

/// Abre o formulario (bottom sheet) para criar ou editar um item.
Future<void> showItemFormSheet(
  BuildContext context, {
  ShoppingItem? item,
  String? initialName,
  double? initialEstimatedPrice,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ItemFormSheet(
      item: item,
      initialName: initialName,
      initialEstimatedPrice: initialEstimatedPrice,
    ),
  );
}

const List<int> _newCategoryColors = [
  0xFFFF6B6B,
  0xFF4ECDC4,
  0xFFFFB347,
  0xFF6BCB77,
  0xFFFF8E8E,
  0xFFA8E6CF,
  0xFFB8B8B8,
];

class ItemFormSheet extends ConsumerStatefulWidget {
  const ItemFormSheet({
    super.key,
    this.item,
    this.initialName,
    this.initialEstimatedPrice,
  });

  final ShoppingItem? item;
  final String? initialName;
  final double? initialEstimatedPrice;

  @override
  ConsumerState<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  String? _categoryName;
  String _unit = 'un';
  bool _saving = false;

  static const List<String> _units = ['un', 'g', 'kg', 'ml', 'L'];

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(
      text: item?.name ?? widget.initialName ?? '',
    );
    _quantityController = TextEditingController(
      text: item == null ? '1' : _formatQuantity(item.quantity),
    );
    final initialPrice = item?.estimatedPrice ?? widget.initialEstimatedPrice;
    _priceController = TextEditingController(
      text: initialPrice == null ? '' : _formatPrice(initialPrice),
    );
    _categoryName = item?.category;
    _unit = item?.unit ?? 'un';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  static String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String _formatPrice(double value) {
    return value.toStringAsFixed(2).replaceAll('.', ',');
  }

  double? _parsePrice(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  double _parseQuantity(String text) {
    final t = text.trim();
    if (t.isEmpty) return 1;
    return double.tryParse(t.replaceAll(',', '.')) ?? 1;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final quantity = _parseQuantity(_quantityController.text);
    final price = _parsePrice(_priceController.text);
    final category = (_categoryName ?? '').trim();

    final notifier = ref.read(shoppingListProvider.notifier);

    try {
      if (_isEditing) {
        await notifier.updateItem(
          widget.item!.copyWith(
            name: name,
            quantity: quantity,
            unit: _unit.isEmpty ? null : _unit,
            estimatedPrice: price,
            category: category.isEmpty ? null : category,
          ),
        );
      } else {
        await notifier.addItem(
          name: name,
          quantity: quantity,
          unit: _unit.isEmpty ? null : _unit,
          estimatedPrice: price,
          category: category.isEmpty ? null : category,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel salvar o item.')),
        );
      }
    }
  }

  Future<void> _createCategory() async {
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
      setState(() => _categoryName = categories[existingIndex].name);
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
      isExpenseDefault: true,
      sortOrder: categories.length,
    );

    try {
      await ref.read(categoriesListProvider.notifier).createCategory(category);
      if (mounted) setState(() => _categoryName = category.name);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nao foi possivel criar a categoria.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final categoriesAsync = ref.watch(categoriesListProvider);
    final categories = categoriesAsync.value ?? const <Category>[];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar item' : 'Novo item',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome do produto',
                  prefixIcon: Icon(Icons.shopping_basket_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,]'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(
                        labelText: 'Unidade',
                      ),
                      items: _units
                          .map(
                            (u) => DropdownMenuItem<String>(
                              value: u,
                              child: Text(u),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'un'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Preco estimado (R\$)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _categoryName,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem categoria'),
                  ),
                  for (final category in categories)
                    DropdownMenuItem<String?>(
                      value: category.name,
                      child: Text(category.name),
                    ),
                  // Mantem a categoria atual no menu mesmo se ela nao
                  // existir mais na lista de categorias do app.
                  if (_categoryName != null &&
                      !categories.any((c) => c.name == _categoryName))
                    DropdownMenuItem<String?>(
                      value: _categoryName,
                      child: Text(_categoryName!),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryName = value),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _createCategory,
                  icon: const Icon(Icons.add),
                  label: const Text('Nova categoria'),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Salvar' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
