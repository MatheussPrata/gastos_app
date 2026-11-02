import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/categories/models/category_models.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository();
});

/// Thrown when a category cannot be deleted or have its type changed because
/// it is still referenced by transactions or recurring transactions.
class CategoryInUseException implements Exception {
  final String message;

  CategoryInUseException([
    this.message =
        'Esta categoria está vinculada a transações e não pode ser excluída.',
  ]);

  @override
  String toString() => message;
}

class CategoriesRepository {
  static const String _seedKey = 'categories_seeded_v2';

  final DioClient _dioClient;
  final db.AppDatabase _db;
  final FlutterSecureStorage _storage;

  CategoriesRepository({
    DioClient? dioClient,
    db.AppDatabase? database,
    FlutterSecureStorage? storage,
  })  : _dioClient = dioClient ?? DioClient(),
        _db = database ?? db.AppDatabase(),
        _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------- mapping

  Category _toModel(db.Category c) {
    return Category(
      id: c.id,
      name: c.name,
      type: _typeFromDb(c),
      icon: c.icon,
      color: c.color,
      isDefault: c.isDefault,
      sortOrder: c.sortOrder,
      createdAt: c.createdAt ?? DateTime.now(),
      updatedAt: c.updatedAt ?? c.createdAt ?? DateTime.now(),
      isSynced: c.isSynced,
    );
  }

  db.CategoriesCompanion _toCompanion(
    Category category, {
    required bool synced,
  }) {
    return db.CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      type: Value(category.type.name),
      color: Value(category.color),
      icon: Value(category.icon),
      isDefault: Value(category.isDefault),
      isExpenseDefault: Value(category.type == CategoryType.expense),
      sortOrder: Value(category.sortOrder),
      createdAt: Value(category.createdAt),
      updatedAt: Value(category.updatedAt),
      isSynced: Value(synced),
    );
  }

  Map<String, dynamic> _toSyncJson(Category category) {
    return {
      'id': category.id,
      'name': category.name,
      'type': category.type.name,
      'icon': category.icon,
      'color': category.color,
      'isDefault': category.isDefault,
      'isExpenseDefault': category.type == CategoryType.expense,
      'sortOrder': category.sortOrder,
      'createdAt': category.createdAt.toIso8601String(),
      'updatedAt': category.updatedAt.toIso8601String(),
    };
  }

  CategoryType _typeFromDb(db.Category category) {
    return CategoryType.values.firstWhere(
      (type) => type.name == category.type,
      orElse: () => category.isExpenseDefault
          ? CategoryType.expense
          : CategoryType.income,
    );
  }

  CategoryType _typeFromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    if (rawType == CategoryType.income.name) return CategoryType.income;
    if (rawType == CategoryType.expense.name) return CategoryType.expense;

    final isExpense = json['isExpenseDefault'] as bool? ?? true;
    return isExpense ? CategoryType.expense : CategoryType.income;
  }

  DateTime? _parseDate(Object? value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    return null;
  }

  // ------------------------------------------------------------------ reads

  /// Get categories, optionally filtered by [type]. Local data is always
  /// returned immediately (offline-first) and the server is synced in the
  /// background when the user is authenticated.
  Future<List<Category>> getCategories({
    CategoryType? type,
    bool forceRefresh = false,
  }) async {
    final query = _db.select(_db.categories);
    if (type != null) {
      query.where((c) => c.type.equals(type.name));
    }
    query.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.name),
    ]);

    final localResults = await query.get();
    final isGuest = await _isGuestMode();

    if (!isGuest) {
      if (forceRefresh || localResults.isEmpty) {
        unawaited(_syncWithServer());
      }
      unawaited(syncPendingCategories());
    }

    return localResults.map(_toModel).toList();
  }

  /// Get a single category by id (used by the edit form).
  Future<Category?> getCategoryById(String id) async {
    final row = await (_db.select(_db.categories)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Get subcategories for a category.
  Future<List<Subcategory>> getSubcategories(String categoryId) async {
    final localResults = await (_db.select(_db.subcategories)
          ..where((s) => s.categoryId.equals(categoryId)))
        .get();

    return localResults
        .map((s) => Subcategory(
              id: s.id,
              categoryId: s.categoryId,
              name: s.name,
              sortOrder: s.sortOrder,
            ))
        .toList();
  }

  // ---------------------------------------------------------------- writes

  /// Create category (offline-first).
  Future<Category> createCategory(Category category) async {
    final now = DateTime.now();
    final created = category.copyWith(
      createdAt: category.createdAt,
      updatedAt: now,
      isSynced: false,
    );

    await _db.into(_db.categories).insert(_toCompanion(created, synced: false));

    unawaited(_syncCategory(created));
    return created;
  }

  /// Update category.
  Future<Category> updateCategory(Category category) async {
    final existing = await getCategoryById(category.id);
    if (existing != null && existing.type != category.type) {
      final inUse = await _categoryIsInUse(category.id);
      if (inUse) {
        throw CategoryInUseException(
          'Não é possível alterar o tipo de uma categoria vinculada a transações.',
        );
      }
    }

    final updated = category.copyWith(
      createdAt: existing?.createdAt ?? category.createdAt,
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await _db
        .update(_db.categories)
        .replace(_toCompanion(updated, synced: false));

    unawaited(_syncCategory(updated));
    return updated;
  }

  /// Delete category. Throws [CategoryInUseException] when it is referenced by
  /// an existing transaction or recurring transaction.
  Future<void> deleteCategory(String id) async {
    if (await _categoryIsInUse(id)) {
      throw CategoryInUseException();
    }

    await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
    unawaited(_deleteFromServer(id));
  }

  Future<bool> _categoryIsInUse(String id) async {
    final transaction = await (_db.select(_db.transactions)
          ..where((t) => t.categoryId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (transaction != null) return true;

    final recurring = await (_db.select(_db.recurringTransactions)
          ..where((t) => t.categoryId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return recurring != null;
  }

  // -------------------------------------------------------------- defaults

  /// Seed the default categories once per installation. Existing default
  /// categories are upgraded with the new icon/type metadata.
  Future<void> seedDefaultCategories() async {
    final seeded = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(_seedKey)))
        .getSingleOrNull();
    if (seeded != null) return;

    final existing = await _db.select(_db.categories).get();

    for (final category in _defaultCategories()) {
      final match = existing.where(
        (c) =>
            c.name.toLowerCase() == category.name.toLowerCase() &&
            _typeFromDb(c) == category.type,
      );

      if (match.isNotEmpty) {
        final current = match.first;
        if (!current.isDefault) continue;

        await (_db.update(_db.categories)
              ..where((c) => c.id.equals(current.id)))
            .write(db.CategoriesCompanion(
          icon: Value(category.icon),
          color: Value(category.color),
          type: Value(category.type.name),
          isExpenseDefault: Value(category.type == CategoryType.expense),
          isDefault: const Value(true),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ));
        continue;
      }

      await _db
          .into(_db.categories)
          .insert(_toCompanion(category, synced: false));
    }

    await _db.into(_db.appSettings).insertOnConflictUpdate(
          db.AppSettingsCompanion.insert(key: _seedKey, value: '1'),
        );
  }

  List<Category> _defaultCategories() {
    final now = DateTime.now();
    Category category({
      required String id,
      required String name,
      required CategoryType type,
      required String icon,
      required int color,
      required int sortOrder,
    }) {
      return Category(
        id: id,
        name: name,
        type: type,
        icon: icon,
        color: color,
        isDefault: true,
        sortOrder: sortOrder,
        createdAt: now,
        updatedAt: now,
      );
    }

    return [
      // Expenses
      category(
        id: '1',
        name: 'Alimentação',
        type: CategoryType.expense,
        icon: 'restaurant',
        color: 0xFFFF6B6B,
        sortOrder: 0,
      ),
      category(
        id: '2',
        name: 'Transporte',
        type: CategoryType.expense,
        icon: 'directions_car',
        color: 0xFF4ECDC4,
        sortOrder: 1,
      ),
      category(
        id: '3',
        name: 'Moradia',
        type: CategoryType.expense,
        icon: 'home',
        color: 0xFFFFB347,
        sortOrder: 2,
      ),
      category(
        id: '4',
        name: 'Lazer',
        type: CategoryType.expense,
        icon: 'sports_esports',
        color: 0xFF6BCB77,
        sortOrder: 3,
      ),
      category(
        id: '5',
        name: 'Saúde',
        type: CategoryType.expense,
        icon: 'medical_services',
        color: 0xFFFF8E8E,
        sortOrder: 4,
      ),
      category(
        id: '8',
        name: 'Compras',
        type: CategoryType.expense,
        icon: 'shopping_bag',
        color: 0xFFFFD93D,
        sortOrder: 5,
      ),
      category(
        id: '9',
        name: 'Educação',
        type: CategoryType.expense,
        icon: 'school',
        color: 0xFFA8E6CF,
        sortOrder: 6,
      ),
      category(
        id: '7',
        name: 'Outros',
        type: CategoryType.expense,
        icon: 'more_horiz',
        color: 0xFFB8B8B8,
        sortOrder: 7,
      ),
      // Income
      category(
        id: '6',
        name: 'Salário',
        type: CategoryType.income,
        icon: 'payments',
        color: 0xFF43A047,
        sortOrder: 0,
      ),
      category(
        id: '10',
        name: 'Freelance/Serviços',
        type: CategoryType.income,
        icon: 'work',
        color: 0xFF1E88E5,
        sortOrder: 1,
      ),
      category(
        id: '11',
        name: 'Rendimentos/Investimentos',
        type: CategoryType.income,
        icon: 'trending_up',
        color: 0xFF00897B,
        sortOrder: 2,
      ),
      category(
        id: '12',
        name: 'Presente',
        type: CategoryType.income,
        icon: 'redeem',
        color: 0xFF8E24AA,
        sortOrder: 3,
      ),
      category(
        id: '13',
        name: 'Outros',
        type: CategoryType.income,
        icon: 'attach_money',
        color: 0xFF66BB6A,
        sortOrder: 4,
      ),
    ];
  }

  // ------------------------------------------------------------------ sync

  /// Push categories created/edited locally while offline.
  Future<void> syncPendingCategories() async {
    if (await _isGuestMode()) return;

    try {
      final unsynced = await (_db.select(_db.categories)
            ..where((c) => c.isSynced.equals(false)))
          .get();

      for (final row in unsynced) {
        await _syncCategory(_toModel(row));
      }
    } catch (_) {
      // Keep isSynced = false and retry later.
    }
  }

  Future<void> _syncWithServer() async {
    if (await _isGuestMode()) return;

    try {
      final response = await _dioClient.dio.get(ApiEndpoints.categories);
      if (response.statusCode != 200) return;

      final raw = response.data;
      final data = raw is Map ? raw['data'] as List? ?? [] : raw as List? ?? [];

      for (final item in data) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final id = json['id'] as String?;
        if (id == null || id.isEmpty) continue;

        final local = await (_db.select(_db.categories)
              ..where((c) => c.id.equals(id)))
            .getSingleOrNull();
        // Never overwrite local changes that have not been synced yet.
        if (local != null && !local.isSynced) continue;

        final now = DateTime.now();
        final category = Category(
          id: id,
          name: json['name'] as String? ?? 'Sem nome',
          type: _typeFromJson(json),
          icon: json['icon'] as String? ?? 'category',
          color: json['color'] as int? ?? 0xFFB8B8B8,
          isDefault: json['isDefault'] as bool? ?? false,
          sortOrder: json['sortOrder'] as int? ?? 0,
          createdAt: _parseDate(json['createdAt']) ?? now,
          updatedAt: _parseDate(json['updatedAt']) ?? now,
          isSynced: true,
        );

        await _db
            .into(_db.categories)
            .insertOnConflictUpdate(_toCompanion(category, synced: true));
      }
    } catch (_) {
      // Offline or server error: local data remains available.
    }
  }

  Future<void> _syncCategory(Category category) async {
    if (await _isGuestMode()) return;

    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.categories,
        data: _toSyncJson(category),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await (_db.update(_db.categories)
              ..where((c) => c.id.equals(category.id)))
            .write(const db.CategoriesCompanion(isSynced: Value(true)));
      }
    } catch (_) {
      // Keep isSynced = false and retry on the next refresh.
    }
  }

  Future<void> _deleteFromServer(String id) async {
    if (await _isGuestMode()) return;

    try {
      await _dioClient.dio.delete('${ApiEndpoints.categoriesById}$id');
    } catch (_) {}
  }

  Future<bool> _isGuestMode() async {
    try {
      final value = await _storage.read(key: StorageKeys.isGuestMode);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }
}
