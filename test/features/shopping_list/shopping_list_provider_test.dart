import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';
import 'package:gastos_app/features/shopping_list/data/repositories/shopping_list_repository.dart';
import 'package:gastos_app/features/shopping_list/provider/shopping_list_provider.dart';

class _FakeShoppingListRepository extends ShoppingListRepository {
  List<ShoppingItem> stored = [];

  @override
  Future<List<ShoppingItem>> loadItems() async {
    return List<ShoppingItem>.from(stored);
  }

  @override
  Future<void> saveItems(List<ShoppingItem> items) async {
    stored = List<ShoppingItem>.from(items);
  }
}

void main() {
  late _FakeShoppingListRepository repository;
  late ShoppingListNotifier notifier;

  setUp(() async {
    repository = _FakeShoppingListRepository();
    notifier = ShoppingListNotifier(repository);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() {
    notifier.dispose();
  });

  test('adiciona item e persiste na lista', () async {
    await notifier.addItem(
      name: 'Arroz',
      quantity: 2,
      unit: 'kg',
      estimatedPrice: 10.5,
      category: 'Mercearia',
    );

    final items = notifier.state.valueOrNull!;

    expect(items, hasLength(1));
    expect(items.single.name, 'Arroz');
    expect(items.single.quantity, 2);
    expect(items.single.unit, 'kg');
    expect(items.single.estimatedPrice, 10.5);
    expect(items.single.category, 'Mercearia');
    expect(repository.stored, hasLength(1));
  });

  test('edita um item existente', () async {
    await notifier.addItem(name: 'Arroz', estimatedPrice: 10);
    final item = notifier.state.valueOrNull!.single;

    await notifier.updateItem(
      item.copyWith(name: 'Arroz integral', quantity: 3, estimatedPrice: 12),
    );

    final updated = notifier.state.valueOrNull!.single;

    expect(updated.name, 'Arroz integral');
    expect(updated.quantity, 3);
    expect(updated.estimatedPrice, 12);
    expect(repository.stored.single.name, 'Arroz integral');
  });

  test('alterna o status de comprado', () async {
    await notifier.addItem(name: 'Arroz');
    final id = notifier.state.valueOrNull!.single.id;

    await notifier.togglePurchased(id);
    expect(notifier.state.valueOrNull!.single.isPurchased, isTrue);

    await notifier.togglePurchased(id);
    expect(notifier.state.valueOrNull!.single.isPurchased, isFalse);
  });

  test('registra valor real e usa como base para a próxima compra', () async {
    await notifier.addItem(name: 'Arroz', estimatedPrice: 10);
    final id = notifier.state.valueOrNull!.single.id;

    await notifier.setActualPrice(id, 15.5);

    final item = notifier.state.valueOrNull!.single;

    expect(item.actualPrice, 15.5);
    expect(item.estimatedPrice, 15.5);
    expect(item.isPurchased, isTrue);
  });

  test('remove um item da lista', () async {
    await notifier.addItem(name: 'Arroz');
    await notifier.addItem(name: 'Feijão');
    final id = notifier.state.valueOrNull!.first.id;

    await notifier.deleteItem(id);

    final items = notifier.state.valueOrNull!;

    expect(items, hasLength(1));
    expect(items.single.name, 'Feijão');
    expect(repository.stored, hasLength(1));
  });
}
