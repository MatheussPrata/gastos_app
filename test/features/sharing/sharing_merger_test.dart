import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/sharing/repository/sharing_merger.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';

void main() {
  ShoppingItem item(String id, String name, {bool purchased = false}) =>
      ShoppingItem(id: id, name: name, isPurchased: purchased);

  group('SharingMerger.mergeShoppingItems', () {
    test('adiciona itens do parceiro e registra os ids compartilhados', () {
      final result = SharingMerger.mergeShoppingItems(
        local: [item('1', 'Local')],
        partnerItems: [
          {
            'id': '2',
            'name': 'Cafe',
            'quantity': 2,
            'unit': 'un',
            'estimatedPrice': 19.9,
            'isPurchased': false,
          }
        ],
        sharedIds: const {},
      );

      expect(result.items.map((e) => e.id), containsAll(['1', '2']));
      expect(result.sharedIds, contains('2'));
      expect(result.sharedIds, isNot(contains('1')));
      final cafe = result.items.firstWhere((e) => e.id == '2');
      expect(cafe.name, 'Cafe');
      expect(cafe.quantity, 2);
      expect(cafe.unit, 'un');
      expect(cafe.estimatedPrice, 19.9);
      expect(cafe.isPurchased, isFalse);
    });

    test('item do parceiro sobrescreve o local com o mesmo id', () {
      final result = SharingMerger.mergeShoppingItems(
        local: [item('1', 'Antigo')],
        partnerItems: [
          {'id': '1', 'name': 'Atualizado', 'isPurchased': true}
        ],
        sharedIds: const {'1'},
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.name, 'Atualizado');
      expect(result.items.single.isPurchased, isTrue);
    });

    test('mantem os ids ja compartilhados de sincronizacoes anteriores', () {
      final result = SharingMerger.mergeShoppingItems(
        local: [item('1', 'Do parceiro anterior'), item('2', 'Local')],
        partnerItems: const [],
        sharedIds: const {'1'},
      );

      expect(result.sharedIds, {'1'});
      expect(result.items, hasLength(2));
    });

    test('ignora registros sem id', () {
      final result = SharingMerger.mergeShoppingItems(
        local: const [],
        partnerItems: [
          {'name': 'Sem id'},
          {'id': 'ok', 'name': 'Com id'},
        ],
        sharedIds: const {},
      );

      expect(result.items, hasLength(1));
      expect(result.items.single.id, 'ok');
    });

    test('usa isChecked como fallback de isPurchased', () {
      final result = SharingMerger.mergeShoppingItems(
        local: const [],
        partnerItems: [
          {'id': '1', 'name': 'Item', 'isChecked': true}
        ],
        sharedIds: const {},
      );

      expect(result.items.single.isPurchased, isTrue);
    });
  });

  group('SharingMerger.toDouble', () {
    test('converte numeros e strings', () {
      expect(SharingMerger.toDouble(7.77), 7.77);
      expect(SharingMerger.toDouble(3), 3.0);
      expect(SharingMerger.toDouble('12.5'), 12.5);
      expect(SharingMerger.toDouble(null), 0);
      expect(SharingMerger.toDouble('abc'), 0);
    });

    test('toDoubleOrNull devolve null para vazio', () {
      expect(SharingMerger.toDoubleOrNull(null), isNull);
      expect(SharingMerger.toDoubleOrNull(4), 4.0);
      expect(SharingMerger.toDoubleOrNull('abc'), isNull);
    });
  });
}
