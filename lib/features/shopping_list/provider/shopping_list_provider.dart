import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';
import 'package:gastos_app/features/shopping_list/data/repositories/shopping_list_repository.dart';

final _uuid = const Uuid();

/// Gerencia a lista de compras (CRUD, alternar status e registrar preco real).
class ShoppingListNotifier extends StateNotifier<AsyncValue<List<ShoppingItem>>> {
  final ShoppingListRepository _repository;

  ShoppingListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadItems();
  }

  List<ShoppingItem> get _items => state.valueOrNull ?? const [];

  Future<void> loadItems() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repository.loadItems();
      state = AsyncValue.data(items);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _persist(List<ShoppingItem> items) async {
    state = AsyncValue.data(items);
    await _repository.saveItems(items);
  }

  Future<void> addItem({
    required String name,
    double quantity = 1,
    String? unit,
    double? estimatedPrice,
    String? category,
  }) async {
    final item = ShoppingItem(
      id: _uuid.v4(),
      name: name,
      quantity: quantity,
      unit: unit,
      estimatedPrice: estimatedPrice,
      category: category,
    );
    await _persist([..._items, item]);
  }

  Future<void> updateItem(ShoppingItem item) async {
    await _persist(
      _items.map((e) => e.id == item.id ? item : e).toList(),
    );
  }

  Future<void> deleteItem(String id) async {
    await _persist(_items.where((e) => e.id != id).toList());
  }

  Future<void> togglePurchased(String id) async {
    await _persist(
      _items
          .map((e) => e.id == id ? e.copyWith(isPurchased: !e.isPurchased) : e)
          .toList(),
    );
  }

  /// Registra o valor real pago e o usa como base para as proximas compras.
  Future<void> setActualPrice(String id, double price) async {
    await _persist(
      _items
          .map(
            (e) => e.id == id
                ? e.copyWith(
                    actualPrice: price,
                    estimatedPrice: price,
                    isPurchased: true,
                  )
                : e,
          )
          .toList(),
    );
  }
}

final shoppingListProvider =
    StateNotifierProvider<ShoppingListNotifier, AsyncValue<List<ShoppingItem>>>(
  (ref) {
    final repository = ref.watch(shoppingListRepositoryProvider);
    return ShoppingListNotifier(repository);
  },
);

/// Resumo financeiro exibido no topo da tela.
final shoppingListSummaryProvider = Provider<ShoppingListSummary>((ref) {
  final items = ref.watch(shoppingListProvider).valueOrNull ?? const [];
  return ShoppingListSummary.fromItems(items);
});
