import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';

void main() {
  group('ReceiptItemCategorizer', () {
    test('categoriza itens de acougue e abreviacoes', () {
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
      expect(
        ReceiptItemCategorizer.categorize('ACEM BOV RESF KG'),
        ReceiptItemCategorizer.acougue,
      );
    });

    test('categoriza itens de alimentacao, bolacha/biscoito e abreviacoes', () {
      expect(
        ReceiptItemCategorizer.categorize('ARROZ T1 TIO JOAO 5KG'),
        ReceiptItemCategorizer.alimentacao,
      );
      expect(
        ReceiptItemCategorizer.categorize('FEIJAO CARIOCA CAMIL 1KG'),
        ReceiptItemCategorizer.alimentacao,
      );
      expect(
        ReceiptItemCategorizer.categorize('BISC RECH PASSATEMPO CHO 130G'),
        ReceiptItemCategorizer.alimentacao,
      );
      expect(
        ReceiptItemCategorizer.categorize('BOLACHA AGUA E SAL MARILAN'),
        ReceiptItemCategorizer.alimentacao,
      );
      expect(
        ReceiptItemCategorizer.categorize('MAC INST NISSIN MIOJO 85G'),
        ReceiptItemCategorizer.alimentacao,
      );
    });

    test('categoriza itens de limpeza e abreviacoes', () {
      expect(
        ReceiptItemCategorizer.categorize('DETERGENTE LIQUIDO YPE 500ML'),
        ReceiptItemCategorizer.limpeza,
      );
      expect(
        ReceiptItemCategorizer.categorize('DET LIMP YPE NEUTRO 500ML'),
        ReceiptItemCategorizer.limpeza,
      );
      expect(
        ReceiptItemCategorizer.categorize('SABAO EM PO OMO LAVAGEM PERFEITA'),
        ReceiptItemCategorizer.limpeza,
      );
      expect(
        ReceiptItemCategorizer.categorize('SAB EM PO OMO 1.6KG'),
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

    test('categoriza itens de higiene e abreviacoes', () {
      expect(
        ReceiptItemCategorizer.categorize('SHAMP SEDA CERAMIDAS 325ML'),
        ReceiptItemCategorizer.higiene,
      );
      expect(
        ReceiptItemCategorizer.categorize('CR DENT COLGATE TOTAL 90G'),
        ReceiptItemCategorizer.higiene,
      );
      expect(
        ReceiptItemCategorizer.categorize('PAPEL HIGIENICO NEVE 12UN'),
        ReceiptItemCategorizer.higiene,
      );
      expect(
        ReceiptItemCategorizer.categorize('SABONETE DOVE ORIGINAL 90G'),
        ReceiptItemCategorizer.higiene,
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
      expect(
        ReceiptItemCategorizer.categorize('CEBOLA NACIONAL KG'),
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
