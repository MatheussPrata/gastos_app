import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';

/// Formulário de criação/edição de categoria de GASTOS.
class CategoryFormPage extends ConsumerStatefulWidget {
  final String? categoryId;
  final bool isEditing;

  const CategoryFormPage({
    super.key,
    this.categoryId,
    required this.isEditing,
  });

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  int _color = kCategoryColors.first;
  String _icon = 'category';
  bool _isExpense = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.categoryId != null) {
      final categories =
          ref.read(categoriesListProvider).value ?? const <Category>[];
      for (final c in categories) {
        if (c.id == widget.categoryId) {
          _nameController.text = c.name;
          _color = c.color;
          _icon = c.icon;
          _isExpense = c.isExpenseDefault;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final name = _nameController.text.trim();
    final notifier = ref.read(categoriesListProvider.notifier);
    final current = ref.read(categoriesListProvider).value ?? const <Category>[];

    final category = Category(
      id: widget.isEditing && widget.categoryId != null
          ? widget.categoryId!
          : const Uuid().v4(),
      name: name,
      color: _color,
      icon: _icon,
      isDefault: false,
      isExpenseDefault: _isExpense,
      sortOrder: widget.isEditing ? 0 : current.length,
    );

    try {
      if (widget.isEditing) {
        await notifier.updateCategory(category);
      } else {
        await notifier.createCategory(category);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar categoria' : 'Nova categoria'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: !widget.isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: 20),
            Text('Tipo', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Despesa')),
                ButtonSegment(value: false, label: Text('Receita')),
              ],
              selected: {_isExpense},
              onSelectionChanged: (s) => setState(() => _isExpense = s.first),
            ),
            const SizedBox(height: 20),
            Text('Cor', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kCategoryColors.map((color) {
                final selected = color == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = color),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(color),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Ícone', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kCategoryIcons.map((icon) {
                final selected = icon == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = icon),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: selected
                        ? Color(_color).withOpacity(0.25)
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      categoryIcon(icon),
                      color: selected ? Color(_color) : theme.colorScheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Salvar' : 'Criar categoria'),
            ),
          ],
        ),
      ),
    );
  }
}
