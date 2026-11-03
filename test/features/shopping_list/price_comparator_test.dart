import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/shopping_list/data/price_comparator.dart';

void main() {
  group('normalizeUnit', () {
    test('normaliza massa para kg', () {
      final info = normalizeUnit('G');

      expect(info, isNotNull);
      expect(info!.type, UnitType.mass);
      expect(info.baseUnit, 'kg');
      expect(info.factorToBase, 0.001);
    });

    test('normaliza volume para litro', () {
      final info = normalizeUnit('ml');

      expect(info, isNotNull);
      expect(info!.type, UnitType.volume);
      expect(info.baseUnit, 'L');
      expect(info.factorToBase, 0.001);
    });

    test('normaliza unidades de contagem', () {
      final un = normalizeUnit('un');
      final unid = normalizeUnit('UNID');

      expect(un?.type, UnitType.count);
      expect(unid?.type, UnitType.count);
      expect(un?.factorToBase, 1);
      expect(unid?.factorToBase, 1);
    });

    test('retorna null para unidade desconhecida ou vazia', () {
      expect(normalizeUnit('caixa'), isNull);
      expect(normalizeUnit(''), isNull);
      expect(normalizeUnit(null), isNull);
    });
  });

  group('compareProducts', () {
    test('compara massa em unidades diferentes', () {
      const a = ProductEntry(
        name: 'Pacote A',
        price: 5,
        quantity: 500,
        unit: 'g',
      );
      const b = ProductEntry(
        name: 'Pacote B',
        price: 8,
        quantity: 1,
        unit: 'kg',
      );

      final result = compareProducts(a, b);

      expect(result, isNotNull);
      expect(result!.winner, 'B');
      expect(result.baseUnit, 'kg');
      expect(result.cheaperPricePerBase, closeTo(8, 0.001));
      expect(result.expensivePricePerBase, closeTo(10, 0.001));
      expect(result.savingsPercent, closeTo(20, 0.001));
    });

    test('compara volume em unidades diferentes', () {
      const a = ProductEntry(
        name: 'Garrafa A',
        price: 6,
        quantity: 1,
        unit: 'L',
      );
      const b = ProductEntry(
        name: 'Garrafa B',
        price: 4,
        quantity: 500,
        unit: 'ml',
      );

      final result = compareProducts(a, b);

      expect(result, isNotNull);
      expect(result!.winner, 'A');
      expect(result.baseUnit, 'L');
      expect(result.cheaperPricePerBase, closeTo(6, 0.001));
      expect(result.expensivePricePerBase, closeTo(8, 0.001));
      expect(result.savingsPercent, closeTo(25, 0.001));
    });

    test('compara unidades de contagem', () {
      const a = ProductEntry(
        name: 'Unidade A',
        price: 3,
        quantity: 1,
        unit: 'un',
      );
      const b = ProductEntry(
        name: 'Unidade B',
        price: 5,
        quantity: 2,
        unit: 'unid',
      );

      final result = compareProducts(a, b);

      expect(result, isNotNull);
      expect(result!.winner, 'B');
      expect(result.baseUnit, 'un');
      expect(result.savingsPercent, closeTo(16.666, 0.01));
    });

    test('retorna null para grandezas diferentes', () {
      const a = ProductEntry(
        name: 'Massa',
        price: 5,
        quantity: 1,
        unit: 'kg',
      );
      const b = ProductEntry(
        name: 'Volume',
        price: 5,
        quantity: 1,
        unit: 'L',
      );

      expect(compareProducts(a, b), isNull);
    });

    test('retorna null para quantidade zero ou negativa', () {
      const a = ProductEntry(
        name: 'A',
        price: 5,
        quantity: 0,
        unit: 'kg',
      );
      const b = ProductEntry(
        name: 'B',
        price: 5,
        quantity: 1,
        unit: 'kg',
      );

      expect(compareProducts(a, b), isNull);
    });

    test('retorna null para preço negativo', () {
      const a = ProductEntry(
        name: 'A',
        price: -1,
        quantity: 1,
        unit: 'kg',
      );
      const b = ProductEntry(
        name: 'B',
        price: 5,
        quantity: 1,
        unit: 'kg',
      );

      expect(compareProducts(a, b), isNull);
    });

    test('preços equivalentes elegem A com economia zero', () {
      const a = ProductEntry(
        name: 'A',
        price: 10,
        quantity: 1,
        unit: 'kg',
      );
      const b = ProductEntry(
        name: 'B',
        price: 10,
        quantity: 1000,
        unit: 'g',
      );

      final result = compareProducts(a, b);

      expect(result, isNotNull);
      expect(result!.winner, 'A');
      expect(result.savingsPercent, 0);
    });
  });
}
