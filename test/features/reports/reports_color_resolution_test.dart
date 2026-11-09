import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/reports/ui/pages/reports_page.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

void main() {
  test('resolveCategoryColors garante cores distintas mesmo quando categorias possuem a mesma cor', () {
    const duplicateRed = 0xFFFF6B6B;
    final categories = [
      const CategoryExpense(
        categoryId: 'cat-fixos',
        categoryName: 'Custos fixos',
        categoryColor: duplicateRed,
        total: 1486.30,
      ),
      const CategoryExpense(
        categoryId: 'cat-alim',
        categoryName: 'Alimentação',
        categoryColor: duplicateRed,
        total: 964.19,
      ),
      const CategoryExpense(
        categoryId: 'cat-moradia',
        categoryName: 'Moradia',
        categoryColor: 0xFFFFB347,
        total: 900.00,
      ),
      const CategoryExpense(
        categoryId: 'none',
        categoryName: 'Sem categoria',
        categoryColor: 0xFFB8B8B8,
        total: 0.85,
      ),
    ];

    final colorMap = resolveCategoryColorsForTesting(categories);

    expect(colorMap.length, equals(4));

    final colorFixos = colorMap['cat-fixos']!;
    final colorAlim = colorMap['cat-alim']!;
    final colorMoradia = colorMap['cat-moradia']!;
    final colorSemCat = colorMap['none']!;

    // As cores de Custos fixos e Alimentação NÃO podem ser iguais!
    expect(colorFixos, isNot(equals(colorAlim)));

    // Todas as 4 categorias devem ter cores completamente distintas
    final uniqueColors = {colorFixos, colorAlim, colorMoradia, colorSemCat};
    expect(uniqueColors.length, equals(4));
  });
}
