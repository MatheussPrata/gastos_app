import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';

/// Lista e gerenciamento das categorias de GASTOS (transações).
///
/// Categorias usadas nos lançamentos de gastos.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias de gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova categoria',
            onPressed: () => context.push(
              RouteNames.categoryForm,
              extra: {'isEditing': false},
            ),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('Nenhuma categoria cadastrada.'));
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(category.color),
                  child: Icon(
                    categoryIcon(category.icon),
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                title: Text(category.name),
                subtitle: Text(
                  category.isExpenseDefault ? 'Despesa' : 'Receita',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar',
                      onPressed: () => context.push(
                        RouteNames.categoryForm,
                        extra: {'id': category.id, 'isEditing': true},
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Excluir',
                      onPressed: () =>
                          _confirmDelete(context, ref, category),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova categoria',
        onPressed: () => context.push(
          RouteNames.categoryForm,
          extra: {'isEditing': false},
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${category.name}"?'),
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

    if (confirmed == true) {
      await ref.read(categoriesListProvider.notifier).deleteCategory(category.id);
    }
  }
}
