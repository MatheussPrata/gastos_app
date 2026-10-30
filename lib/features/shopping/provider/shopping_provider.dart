import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/shopping/models/shopping_models.dart';
import 'package:gastos_app/features/shopping/repository/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) => ShoppingRepository());

class ShoppingListNotifier extends StateNotifier<AsyncValue<List<ShoppingItem>>> {
  final ShoppingRepository _repository;

  ShoppingListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadShopping();
  }

  Future<void> loadShopping({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.getShoppingItems(forceRefresh: forceRefresh);
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createItem(ShoppingItem item) async {
    try {
      await _repository.createShoppingItem(item);
      await loadShopping();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateItem(ShoppingItem item) async {
    try {
      await _repository.updateShoppingItem(item);
      await loadShopping();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repository.deleteShoppingItem(id);
      await loadShopping();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleItem(ShoppingItem item) async {
    await updateItem(item.copyWith(isChecked: !item.isChecked));
  }
}

final shoppingListProvider = StateNotifierProvider<ShoppingListNotifier, AsyncValue<List<ShoppingItem>>>((ref) {
  final repository = ref.watch(shoppingRepositoryProvider);
  return ShoppingListNotifier(repository);
});