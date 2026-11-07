import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';

void main() {
  group('ReceiptItemCategorizer', () {
    test('categoriza itens de acougue', () {
      expect(
        ReceiptItemCategorizer.categorize('PICANHA BOVINA RESFRIADA KG'),
        ReceiptItemCategorizer.acougue,
      );
      expect(
        ReceiptItemCategorizer.categorize('FILE DE PEITO DE FRANGO'),
        ReceiptItemCategorizer.acougue,
      );
      expect(
        ReceiptItemCategorizer.categorize('LINGUICA TOSCANA SADIA 1KG'),
        ReceiptItemCategorizer.acougue,
      );
    });

    test('categoriza itens de limpeza', () {
      expect(
        ReceiptItemCategorizer.categorize('DETERGENTE LIQUIDO YPE 500ML'),
        ReceiptItemCategorizer.limpeza,
      );
      expect(
        ReceiptItemCategorizer.categorize('SABAO EM PO OMO LAVAGEM PERFEITA'),
        ReceiptItemCategorizer.limpeza,
      );
      expect(
        ReceiptItemCategorizer.categorize('DESINFETANTE PINHO SOL 1L'),
        ReceiptItemCategorizer.limpeza,
      );
      expect(
        ReceiptItemCategorizer.categorize('AGUA SANITARIA QBOA 2L'),
        ReceiptItemCategorizer.limpeza,
      );
    });

    test('categoriza itens de cozinha e casa', () {
      expect(
        ReceiptItemCategorizer.categorize('PAPEL TOALHA SNOB C/ 2 ROLOS'),
        ReceiptItemCategorizer.cozinha,
      );
      expect(
        ReceiptItemCategorizer.categorize('GUARDANAPO DE PAPEL 50UN'),
        ReceiptItemCategorizer.cozinha,
      );
      expect(
        ReceiptItemCategorizer.categorize('SACO LIXO 50L 30UN'),
        ReceiptItemCategorizer.cozinha,
      );
    });

    test('categoriza itens de hortifruti', () {
      expect(
        ReceiptItemCategorizer.categorize('BANANA PRATA KG'),
        ReceiptItemCategorizer.hortifruti,
      );
      expect(
        ReceiptItemCategorizer.categorize('TOMATE LONGA VIDA KG'),
        ReceiptItemCategorizer.hortifruti,
      );
      expect(
        ReceiptItemCategorizer.categorize('ALFACE CRESPA UN'),
        ReceiptItemCategorizer.hortifruti,
      );
    });

    test('categoriza itens de bebidas', () {
      expect(
        ReceiptItemCategorizer.categorize('REFRIGERANTE COCA-COLA 2L'),
        ReceiptItemCategorizer.bebidas,
      );
      expect(
        ReceiptItemCategorizer.categorize('CERVEJA HEINEKEN LATA 350ML'),
        ReceiptItemCategorizer.bebidas,
      );
      expect(
        ReceiptItemCategorizer.categorize('AGUA MINERAL SEM GAS 500ML'),
        ReceiptItemCategorizer.bebidas,
      );
    });

    test('retorna Outros para itens desconhecidos', () {
      expect(
        ReceiptItemCategorizer.categorize('ITEM MISTERIOSO XYZ 123'),
        ReceiptItemCategorizer.outros,
      );
    });
  });
}
