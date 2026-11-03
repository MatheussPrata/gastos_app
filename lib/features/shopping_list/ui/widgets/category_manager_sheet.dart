import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/features/shopping_list/data/models/shopping_category.dart';
import 'package:gastos_app/features/shopping_list/provider/shopping_category_provider.dart';
import 'package:gastos_app/features/shopping_list/provider/shopping_list_provider.dart';

/// Abre o gerenciador de categorias de compras (criar, renomear, excluir).
Future<void> showCategoryManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CategoryManagerSheet(),
  );
}

class CategoryManagerSheet extends ConsumerWidget {
  const CategoryManagerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(shoppingCategoryProvider);
    final categories = categoriesAsync.valueOrNull ?? const <ShoppingCategory>[];

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  'Categorias de compras',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erro: $e')),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                        child: Text('Nenhuma categoria. Crie a primeira.'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final category = list[index];
                        return ListTile(
                          leading: const Icon(Icons.label_outline),
                          title: Text(category.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Renomear',
                                onPressed: () => _rename(context, ref, category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Excluir',
                                onPressed: () =>
                                    _delete(context, ref, category),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ShoppingCategory category,
  ) async {
    final controller = TextEditingController(text: category.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renomear categoria'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Novo nome'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
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
      ),
    );

    if (newName == null || newName.isEmpty || newName == category.name) return;

    final notifier = ref.read(shoppingCategoryProvider.notifier);
    final listNotifier = ref.read(shoppingListProvider.notifier);
    await notifier.renameCategory(category.id, newName);
    await listNotifier.renameCategoryOnItems(category.name, newName);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ShoppingCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${category.name}"?'),
        content: const Text(
          'Os itens desta categoria ficarão sem categoria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final notifier = ref.read(shoppingCategoryProvider.notifier);
    final listNotifier = ref.read(shoppingListProvider.notifier);
    await notifier.deleteCategory(category.id);
    await listNotifier.clearCategoryOnItems(category.name);
  }
}
