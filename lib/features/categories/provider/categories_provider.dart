import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) => CategoriesRepository());

/// Categories list provider
class CategoriesListNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final CategoriesRepository _repository;

  CategoriesListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    
    try {
      final categories = await _repository.getCategories(forceRefresh: forceRefresh);
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

final categoriesListProvider = StateNotifierProvider<CategoriesListNotifier, AsyncValue<List<Category>>>((ref) {
  final repository = ref.watch(categoriesRepositoryProvider);
  return CategoriesListNotifier(repository);
});

/// Subcategories provider
final subcategoriesProvider = FutureProvider.family<List<Subcategory>, String>((ref, categoryId) async {
  final repository = ref.watch(categoriesRepositoryProvider);
  return repository.getSubcategories(categoryId);
});