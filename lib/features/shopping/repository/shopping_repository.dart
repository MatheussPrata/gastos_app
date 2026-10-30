import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/shopping/models/shopping_models.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository();
});

class ShoppingRepository {
  final DioClient _dioClient;
  final db.AppDatabase _db;

  ShoppingRepository({
    DioClient? dioClient,
    db.AppDatabase? database,
  })  : _dioClient = dioClient ?? DioClient(),
        _db = database ?? db.AppDatabase();

  Future<List<ShoppingItem>> getShoppingItems({bool forceRefresh = false}) async {
    final localResults = await _db.select(_db.shoppingItems).get();

    final items = localResults.map((s) => ShoppingItem(
      id: s.id,
      userId: s.userId,
      name: s.name,
      category: s.category,
      isChecked: s.isChecked,
      createdAt: s.createdAt,
      checkedAt: s.checkedAt,
      checkedBy: s.checkedBy,
    )).toList();

    if (forceRefresh || items.isEmpty) {
      _syncWithServer();
    }

    return items;
  }

  Future<ShoppingItem> createShoppingItem(ShoppingItem item) async {
    await _db.into(_db.shoppingItems).insert(db.ShoppingItemsCompanion(
      id: Value(item.id),
      userId: Value(item.userId),
      name: Value(item.name),
      category: Value(item.category),
      isChecked: Value(item.isChecked),
      createdAt: Value(item.createdAt),
      checkedAt: Value(item.checkedAt),
      checkedBy: Value(item.checkedBy),
      isSynced: const Value(false),
    ));

    _syncItem(item);
    return item;
  }

  Future<ShoppingItem> updateShoppingItem(ShoppingItem item) async {
    await _db.update(_db.shoppingItems).replace(db.ShoppingItemsCompanion(
      id: Value(item.id),
      userId: Value(item.userId),
      name: Value(item.name),
      category: Value(item.category),
      isChecked: Value(item.isChecked),
      createdAt: Value(item.createdAt),
      checkedAt: Value(item.checkedAt),
      checkedBy: Value(item.checkedBy),
      isSynced: const Value(false),
    ));

    _syncItem(item);
    return item;
  }

  Future<void> deleteShoppingItem(String id) async {
    await (_db.delete(_db.shoppingItems)..where((s) => s.id.equals(id))).go();
    _deleteFromServer(id);
  }

  Future<void> _syncWithServer() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.shopping);
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        for (final json in data) {
          final item = ShoppingItem.fromJson(json as Map<String, dynamic>);
          await _db.into(_db.shoppingItems).insertOnConflictUpdate(db.ShoppingItemsCompanion(
            id: Value(item.id),
            userId: Value(item.userId),
            name: Value(item.name),
            category: Value(item.category),
            isChecked: Value(item.isChecked),
            createdAt: Value(item.createdAt),
            checkedAt: Value(item.checkedAt),
            checkedBy: Value(item.checkedBy),
            isSynced: const Value(true),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _syncItem(ShoppingItem item) async {
    try {
      await _dioClient.dio.post(
        ApiEndpoints.shopping,
        data: item.toJson(),
      );
      await (_db.update(_db.shoppingItems)..where((s) => s.id.equals(item.id))).write(
        const db.ShoppingItemsCompanion(isSynced: Value(true)),
      );
    } catch (_) {}
  }

  Future<void> _deleteFromServer(String id) async {
    try {
      await _dioClient.dio.delete('${ApiEndpoints.shoppingById}$id');
    } catch (_) {}
  }
}
