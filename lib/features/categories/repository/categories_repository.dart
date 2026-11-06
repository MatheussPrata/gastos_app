import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository();
});

class CategoriesRepository {
  final db.AppDatabase _db;
  final SyncService _sync;

  CategoriesRepository({
    db.AppDatabase? database,
    SyncService? syncService,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService();

  /// Get all categories
  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
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

    unawaited(_sync.push());
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

    unawaited(_sync.push());
    return category;
  }

  /// Delete category
  Future<void> deleteCategory(String id) async {
    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    await _sync.tombstone('category', id);
    unawaited(_sync.push());
  }

  /// Seed default categories if empty
  Future<void> seedDefaultCategories() async {
    final existing = await _db.select(_db.categories).get();
    if (existing.isNotEmpty) return;

    final defaults = [
      Category(id: '1', name: 'Alimentação', color: 0xFFFF6B6B, icon: 'restaurant', isDefault: true, isExpenseDefault: true, sortOrder: 0),
      Category(id: '2', name: 'Transporte', color: 0xFF4ECDC4, icon: 'directions_bus', isDefault: true, isExpenseDefault: true, sortOrder: 1),
      Category(id: '3', name: 'Moradia', color: 0xFFFFB347, icon: 'home', isDefault: true, isExpenseDefault: true, sortOrder: 2),
      Category(id: '4', name: 'Lazer', color: 0xFF6BCB77, icon: 'movie', isDefault: true, isExpenseDefault: true, sortOrder: 3),
      Category(id: '5', name: 'Saúde', color: 0xFFFF8E8E, icon: 'local_hospital', isDefault: true, isExpenseDefault: true, sortOrder: 4),
      Category(id: '6', name: 'Salário', color: 0xFF43A047, icon: 'payments', isDefault: true, isExpenseDefault: false, sortOrder: 0),
      Category(id: '7', name: 'Outros', color: 0xFFB8B8B8, icon: 'category', isDefault: true, isExpenseDefault: true, sortOrder: 5),
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
        // As categorias padrao tambem sobem para o servidor: sao elas que
        // dao nome/cor aos gastos restaurados noutro aparelho.
        isSynced: const Value(false),
      ));
    }
  }

  /// A lista local e a fonte da verdade; o servidor e populado pelo
  /// [SyncService.push] e consultado apenas na restauracao.
  Future<void> _syncWithServer() async {
    await _sync.push();
  }
}