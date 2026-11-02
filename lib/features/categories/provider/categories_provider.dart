import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository();
});

/// Categories list provider
class CategoriesListNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final CategoriesRepository _repository;

  CategoriesListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();

    try {
      await _repository.seedDefaultCategories();
      final categories =
          await _repository.getCategories(forceRefresh: forceRefresh);
      state = AsyncValue.data(categories);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createCategory(Category category) async {
    try {
      await _repository.createCategory(category);
      await loadCategories();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _repository.updateCategory(category);
      await loadCategories();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      await loadCategories();
    } catch (e) {
      rethrow;
    }
  }
}

final categoriesListProvider =
    StateNotifierProvider<CategoriesListNotifier, AsyncValue<List<Category>>>(
        (ref) {
  final repository = ref.watch(categoriesRepositoryProvider);
  return CategoriesListNotifier(repository);
});

/// Categories filtered by type (income/expense).
final categoriesByTypeProvider =
    Provider.family<AsyncValue<List<Category>>, CategoryType>((ref, type) {
  return ref.watch(categoriesListProvider).whenData(
        (categories) => categories
            .where((category) => category.type == type)
            .toList(growable: false),
      );
});

/// Look up a category by id, or null when it is not loaded.
final categoryByIdProvider = Provider.family<Category?, String>((ref, id) {
  final categories = ref.watch(categoriesListProvider).valueOrNull;
  if (categories == null) return null;

  for (final category in categories) {
    if (category.id == id) return category;
  }
  return null;
});

/// Subcategories provider
final subcategoriesProvider =
    FutureProvider.family<List<Subcategory>, String>((ref, categoryId) async {
  final repository = ref.watch(categoriesRepositoryProvider);
  return repository.getSubcategories(categoryId);
});
