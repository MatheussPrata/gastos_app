import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';
import 'package:gastos_app/features/shopping_list/data/repositories/shopping_list_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('salva e carrega os itens da lista', () async {
    final repository = ShoppingListRepository();
    const items = [
      ShoppingItem(
        id: '1',
        name: 'Arroz',
        quantity: 2,
        unit: 'kg',
        estimatedPrice: 10.5,
      ),
      ShoppingItem(
        id: '2',
        name: 'Feijão',
        estimatedPrice: 8,
        isPurchased: true,
        actualPrice: 8.5,
      ),
    ];

    await repository.saveItems(items);
    final loaded = await repository.loadItems();

    expect(loaded, items);
  });

  test('retorna lista vazia quando ainda não há dados', () async {
    final loaded = await ShoppingListRepository().loadItems();

    expect(loaded, isEmpty);
  });

  test('retorna lista vazia quando o JSON salvo é inválido', () async {
    SharedPreferences.setMockInitialValues({
      ShoppingListRepository.storageKey: 'json-invalido',
    });

    final loaded = await ShoppingListRepository().loadItems();

    expect(loaded, isEmpty);
  });
}
