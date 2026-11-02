import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart'
    show CategoryInUseException;
import 'package:gastos_app/features/categories/ui/category_icons.dart';

class CategoryFormPage extends ConsumerStatefulWidget {
  final String? categoryId;
  final bool isEditing;
  final CategoryType? initialType;

  const CategoryFormPage({
    super.key,
    this.categoryId,
    required this.isEditing,
    this.initialType,
  });

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  static const List<int> _palette = [
    0xFFFF6B6B,
    0xFF4ECDC4,
    0xFFFFB347,
    0xFF6BCB77,
    0xFFFF8E8E,
    0xFFA8E6CF,
    0xFFFFD93D,
    0xFF1E88E5,
    0xFF8E24AA,
    0xFF00897B,
    0xFFB8B8B8,
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  CategoryType _type = CategoryType.expense;
  String _iconName = 'restaurant';
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? CategoryType.expense;
    _iconName = _defaultIconFor(_type);

    if (widget.isEditing && widget.categoryId != null) {
      _loadCategory();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    setState(() => _isLoading = true);

    try {
      final category = await ref
          .read(categoriesRepositoryProvider)
          .getCategoryById(widget.categoryId!);

      if (!mounted) return;

      if (category != null) {
        setState(() {
          _nameController.text = category.name;
          _type = category.type;
          _iconName = category.icon;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _defaultIconFor(CategoryType type) {
    return type == CategoryType.income ? 'payments' : 'restaurant';
  }

  int _colorForIcon(String icon) {
    final index = CategoryIcons.available.indexOf(icon);
    return _palette[(index < 0 ? 0 : index) % _palette.length];
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(categoriesRepositoryProvider);
      final existing = widget.isEditing && widget.categoryId != null
          ? await repository.getCategoryById(widget.categoryId!)
          : null;
      final now = DateTime.now();

      final category = Category(
        id: existing?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        type: _type,
        icon: _iconName,
        color: existing?.color ?? _colorForIcon(_iconName),
        isDefault: existing?.isDefault ?? false,
        sortOrder: existing?.sortOrder ?? 0,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        isSynced: false,
      );

      final notifier = ref.read(categoriesListProvider.notifier);
      if (existing != null) {
        await notifier.updateCategory(category);
      } else {
        await notifier.createCategory(category);
      }

      if (mounted) Navigator.of(context).pop(true);
    } on CategoryInUseException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('Erro ao salvar categoria: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Categoria' : 'Nova Categoria'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPreview(),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nome da categoria',
                      hintText: 'Ex: Alimentação',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome da categoria';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildTypeSelector(),
                  const SizedBox(height: 24),
                  Text(
                    'Ícone',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildIconPicker(),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.isEditing
                                ? 'Salvar Alterações'
                                : 'Criar Categoria',
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPreview() {
    final color = Color(_colorForIcon(_iconName));
    final name = _nameController.text.trim();

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withAlpha(38),
          child: Icon(
            CategoryIcons.resolve(_iconName),
            color: color,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Nome da categoria' : name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _type.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _type == CategoryType.income
                          ? AppColors.income
                          : AppColors.expense,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<CategoryType>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: CategoryType.expense,
          icon: Icon(Icons.arrow_downward, color: AppColors.expense),
          label: Text('Saída'),
        ),
        ButtonSegment(
          value: CategoryType.income,
          icon: Icon(Icons.arrow_upward, color: AppColors.income),
          label: Text('Entrada'),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (selection) {
        final newType = selection.first;
        setState(() {
          if (!widget.isEditing && _type != newType) {
            _iconName = _defaultIconFor(newType);
          }
          _type = newType;
        });
      },
    );
  }

  Widget _buildIconPicker() {
    final entries = CategoryIcons.entries;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final selected = entry.key == _iconName;

        return InkWell(
          onTap: () => setState(() => _iconName = entry.key),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withAlpha(31) : null,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              entry.value,
              color: selected ? AppColors.primary : Colors.grey.shade600,
            ),
          ),
        );
      },
    );
  }
}
