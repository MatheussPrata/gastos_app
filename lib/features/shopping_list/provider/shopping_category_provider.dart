import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/features/shopping_list/data/models/shopping_category.dart';
import 'package:gastos_app/features/shopping_list/data/repositories/shopping_category_repository.dart';

final _uuid = const Uuid();

final shoppingCategoryRepositoryProvider = Provider<ShoppingCategoryRepository>(
  (ref) => ShoppingCategoryRepository(),
);

/// Gerencia as categorias de compras (CRUD + seed dos padrões).
class ShoppingCategoryNotifier
    extends StateNotifier<AsyncValue<List<ShoppingCategory>>> {
  final ShoppingCategoryRepository _repository;

  ShoppingCategoryNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    load();
  }

  List<ShoppingCategory> get _categories => state.valueOrNull ?? const [];

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      await _repository.seedDefaults();
      final categories = await _repository.loadCategories();
      state = AsyncValue.data(categories);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _persist(List<ShoppingCategory> categories) async {
    state = AsyncValue.data(categories);
    await _repository.saveCategories(categories);
  }

  /// Adiciona uma categoria (ignora nomes duplicados, case-insensitive).
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final exists = _categories
        .any((c) => c.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) return;

    final category = ShoppingCategory(
      id: _uuid.v4(),
      name: trimmed,
      sortOrder: _categories.length,
    );
    await _persist([..._categories, category]);
  }

  Future<void> renameCategory(String id, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final exists = _categories.any((c) =>
        c.id != id && c.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) return;

    await _persist(
      _categories
          .map((c) => c.id == id ? c.copyWith(name: trimmed) : c)
          .toList(),
    );
  }

  Future<void> deleteCategory(String id) async {
    await _persist(_categories.where((c) => c.id != id).toList());
  }
}

final shoppingCategoryProvider =
    StateNotifierProvider<ShoppingCategoryNotifier,
        AsyncValue<List<ShoppingCategory>>>(
  (ref) {
    final repository = ref.watch(shoppingCategoryRepositoryProvider);
    return ShoppingCategoryNotifier(repository);
  },
);
