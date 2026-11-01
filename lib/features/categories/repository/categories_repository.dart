import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/categories/models/category_models.dart';

class CategoriesRepository {
  final DioClient _dioClient = DioClient();
  final db.AppDatabase _db = db.AppDatabase();

  /// Get all categories
  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    // Try local first
    final localResults = await _db.select(_db.categories).get();
    
    final categories = localResults.map((c) => Category(
      id: c.id,
      name: c.name,
      color: c.color,
      icon: c.icon,
      isDefault: c.isDefault,
      isExpenseDefault: c.isExpenseDefault,
      sortOrder: c.sortOrder,
    )).toList();

    // Try to sync with server in background
    if (forceRefresh || categories.isEmpty) {
      _syncWithServer();
    }
    
    return categories;
  }

  /// Get subcategories for a category
  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    final localResults = await (_db.select(_db.subcategories)
      ..where((s) => s.categoryId.equals(categoryId))).get();
    
    return localResults.map((s) => Subcategory(
      id: s.id,
      categoryId: s.categoryId,
      name: s.name,
      sortOrder: s.sortOrder,
    )).toList();
  }

  /// Create category (offline-first)
  Future<Category> createCategory(Category category) async {
    await _db.into(_db.categories).insert(db.CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      color: Value(category.color),
      icon: Value(category.icon),
      isDefault: Value(category.isDefault),
      isExpenseDefault: Value(category.isExpenseDefault),
      sortOrder: Value(category.sortOrder),
      isSynced: const Value(false),
    ));

    _syncCategory(category);
    return category;
  }

  /// Update category
  Future<Category> updateCategory(Category category) async {
    await _db.update(_db.categories).replace(db.CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      color: Value(category.color),
      icon: Value(category.icon),
      isDefault: Value(category.isDefault),
      isExpenseDefault: Value(category.isExpenseDefault),
      sortOrder: Value(category.sortOrder),
      isSynced: const Value(false),
    ));

    _syncCategory(category);
    return category;
  }

  /// Delete category
  Future<int> deleteCategory(String id) async {
    return await _db.executor.runDelete('DELETE FROM categories WHERE id = ?', [id]);
  }

  /// Seed default categories if empty
  Future<void> seedDefaultCategories() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;

    final defaults = [
      Category(id: '1', name: 'Alimentação', color: 0xFFFF6B6B, icon: 'restaurant', isDefault: true, isExpenseDefault: true, sortOrder: 0),
      Category(id: '2', name: 'Transporte', color: 0xFF4ECDC4, icon: 'directions_bus', isDefault: true, isExpenseDefault: true, sortOrder: 1),
      Category(id: '3', name: 'Compras', color: 0xFFFFD93D, icon: 'shopping_cart', isDefault: true, isExpenseDefault: true, sortOrder: 2),
      Category(id: '4', name: 'Lazer', color: 0xFF6BCB77, icon: 'movie', isDefault: true, isExpenseDefault: true, sortOrder: 3),
      Category(id: '5', name: 'Saúde', color: 0xFFFF8E8E, icon: 'local_hospital', isDefault: true, isExpenseDefault: true, sortOrder: 4),
      Category(id: '6', name: 'Educação', color: 0xFFA8E6CF, icon: 'school', isDefault: true, isExpenseDefault: true, sortOrder: 5),
      Category(id: '7', name: 'Contas', color: 0xFFFFB347, icon: 'receipt', isDefault: true, isExpenseDefault: true, sortOrder: 6),
      Category(id: '8', name: 'Outros', color: 0xFFB8B8B8, icon: 'category', isDefault: true, isExpenseDefault: true, sortOrder: 7),
      Category(id: '9', name: 'Salário', color: 0xFF43A047, icon: 'payments', isDefault: true, isExpenseDefault: false, sortOrder: 0),
      Category(id: '10', name: 'Freelance', color: 0xFF2E7D32, icon: 'work', isDefault: true, isExpenseDefault: false, sortOrder: 1),
      Category(id: '11', name: 'Investimentos', color: 0xFF1B5E20, icon: 'trending_up', isDefault: true, isExpenseDefault: false, sortOrder: 2),
    ];

    for (final cat in defaults) {
      await _db.into(_db.categories).insert(db.CategoriesCompanion(
        id: Value(cat.id),
        name: Value(cat.name),
        color: Value(cat.color),
        icon: Value(cat.icon),
        isDefault: Value(cat.isDefault),
        isExpenseDefault: Value(cat.isExpenseDefault),
        sortOrder: Value(cat.sortOrder),
        isSynced: const Value(true), // Local defaults are already "synced"
      ));
    }
  }

  Future<void> _syncWithServer() async {
    try {
      final response = await DioClient().dio.get(ApiEndpoints.categories);
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        for (final json in data) {
          final cat = Category.fromJson(json as Map<String, dynamic>);
          await _db.into(_db.categories).insertOnConflictUpdate(db.CategoriesCompanion(
            id: Value(cat.id),
            name: Value(cat.name),
            color: Value(cat.color),
            icon: Value(cat.icon),
            isDefault: Value(cat.isDefault),
            isExpenseDefault: Value(cat.isExpenseDefault),
            sortOrder: Value(cat.sortOrder),
            isSynced: const Value(true),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _syncCategory(Category category) async {
    try {
      await DioClient().dio.post(
        ApiEndpoints.categories,
        data: category.toJson(),
      );
      await _db.markCategorySynced(category.id);
    } catch (_) {}
  }

  Future<void> _deleteFromServer(String id) async {
    try {
      await DioClient().dio.delete('${ApiEndpoints.categoriesById}$id');
    } catch (_) {}
  }
}