import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';

void main() {
  group('ShoppingItem', () {
    test('serializa e desserializa mantendo os campos', () {
      const item = ShoppingItem(
        id: 'item-1',
        name: 'Arroz',
        quantity: 2,
        unit: 'kg',
        estimatedPrice: 10.5,
        actualPrice: 11.9,
        isPurchased: true,
        category: 'Mercearia',
      );

      final restored = ShoppingItem.fromJson(item.toJson());

      expect(restored, item);
    });

    test('usa valores padrão no JSON mínimo', () {
      final restored = ShoppingItem.fromJson({
        'id': 'item-2',
        'name': 'Feijão',
      });

      expect(restored.quantity, 1);
      expect(restored.isPurchased, isFalse);
      expect(restored.estimatedPrice, isNull);
      expect(restored.actualPrice, isNull);
    });
  });

  group('ShoppingListSummary', () {
    test('calcula totais estimado, comprado e restante', () {
      final summary = ShoppingListSummary.fromItems(const [
        ShoppingItem(
          id: '1',
          name: 'Arroz',
          estimatedPrice: 10,
          actualPrice: 12,
          isPurchased: true,
        ),
        ShoppingItem(
          id: '2',
          name: 'Feijão',
          estimatedPrice: 20,
        ),
      ]);

      expect(summary.estimatedTotal, 30);
      expect(summary.purchasedTotal, 12);
      expect(summary.remainingTotal, 20);
      expect(summary.totalItems, 2);
      expect(summary.purchasedItems, 1);
    });

    test('item comprado sem valor real não soma no total pago', () {
      final summary = ShoppingListSummary.fromItems(const [
        ShoppingItem(
          id: '1',
          name: 'Arroz',
          estimatedPrice: 10,
          isPurchased: true,
        ),
      ]);

      expect(summary.estimatedTotal, 10);
      expect(summary.purchasedTotal, 0);
      expect(summary.remainingTotal, 0);
      expect(summary.purchasedItems, 1);
    });

    test('lista vazia retorna totais zerados', () {
      final summary = ShoppingListSummary.fromItems(const []);

      expect(summary.estimatedTotal, 0);
      expect(summary.purchasedTotal, 0);
      expect(summary.remainingTotal, 0);
      expect(summary.totalItems, 0);
      expect(summary.purchasedItems, 0);
    });
  });
}
