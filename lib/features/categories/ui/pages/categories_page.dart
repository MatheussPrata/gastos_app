import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';

/// Gerenciamento de categorias separado por tipo (despesa/receita).
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesListProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorias'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Despesas'),
              Tab(text: 'Receitas'),
            ],
          ),
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
            final expenses =
                categories.where((c) => c.isExpenseDefault).toList();
            final incomes =
                categories.where((c) => !c.isExpenseDefault).toList();
            return TabBarView(
              children: [
                _CategoryList(
                  categories: expenses,
                  emptyLabel: 'Nenhuma categoria de despesa.',
                ),
                _CategoryList(
                  categories: incomes,
                  emptyLabel: 'Nenhuma categoria de receita.',
                ),
              ],
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
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({
    required this.categories,
    required this.emptyLabel,
  });

  final List<Category> categories;
  final String emptyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categories.isEmpty) {
      return Center(child: Text(emptyLabel));
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
                onPressed: () => _confirmDelete(context, ref, category),
              ),
            ],
          ),
        );
      },
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
      await ref
          .read(categoriesListProvider.notifier)
          .deleteCategory(category.id);
    }
  }
}
