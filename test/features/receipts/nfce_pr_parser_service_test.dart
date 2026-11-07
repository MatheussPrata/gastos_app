import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/receipts/services/nfce_pr_parser_service.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

void main() {
  group('NfcePrParserService', () {
    final parser = NfcePrParserService();

    test('gera demo receipt com itens validos e categorias preenchidas', () {
      final receipt = parser.getDemoReceipt();

      expect(receipt.establishmentName, contains('Condor'));
      expect(receipt.establishmentCnpj, isNotEmpty);
      expect(receipt.totalAmount, greaterThan(100));
      expect(receipt.paymentMethod, PaymentMethods.creditCard);
      expect(receipt.items, isNotEmpty);

      // Verifica presenca de categorias diferentes
      final categories = receipt.items.map((i) => i.category).toSet();
      expect(categories, contains(ReceiptItemCategorizer.acougue));
      expect(categories, contains(ReceiptItemCategorizer.limpeza));
      expect(categories, contains(ReceiptItemCategorizer.hortifruti));
      expect(categories, contains(ReceiptItemCategorizer.cozinha));
    });

    test('parseFromHtml processa layout padrao SEFAZ PR com tabResult', () {
      const sampleHtml = '''
<!DOCTYPE html>
<html>
<head><title>NFC-e</title></head>
<body>
  <div id="conteudo">
    <div class="header">
      <span class="txtTopo">SUPERMERCADOS CONDOR LTDA</span>
      <span class="CNPJ">76.189.406/0001-40</span>
    </div>
    <div class="info">
      <span>Emissão: 07/11/2026 14:30:00</span>
      <span>Forma de pagamento: Cartão de Crédito</span>
    </div>
    <table id="tabResult">
      <tr>
        <td>
          <span class="txtTit">SABAO EM PO OMO 1.6KG</span>
          <span class="RCod">(Código: 1234)</span>
          <span class="Rqtd">Qtde.: 1,000</span>
          <span class="RUN">UN: UN</span>
          <span class="RvlUnit">Vl. Unit.: 24,90</span>
          <span class="RvlTot">24,90</span>
        </td>
      </tr>
      <tr>
        <td>
          <span class="txtTit">PICANHA BOVINA KG</span>
          <span class="RCod">(Código: 5678)</span>
          <span class="Rqtd">Qtde.: 1,500</span>
          <span class="RUN">UN: KG</span>
          <span class="RvlUnit">Vl. Unit.: 60,00</span>
          <span class="RvlTot">90,00</span>
        </td>
      </tr>
    </table>
    <div id="linhaTotal">
      <span class="totalNfe">114,90</span>
    </div>
  </div>
</body>
</html>
''';

      final receipt = parser.parseFromHtml(sampleHtml);

      expect(receipt.establishmentName, 'SUPERMERCADOS CONDOR LTDA');
      expect(receipt.establishmentCnpj, '76.189.406/0001-40');
      expect(receipt.totalAmount, 114.90);
      expect(receipt.paymentMethod, PaymentMethods.creditCard);
      expect(receipt.items.length, 2);

      final omo = receipt.items[0];
      expect(omo.name, 'SABAO EM PO OMO 1.6KG');
      expect(omo.quantity, 1.0);
      expect(omo.unitPrice, 24.90);
      expect(omo.totalPrice, 24.90);
      expect(omo.category, ReceiptItemCategorizer.limpeza);

      final picanha = receipt.items[1];
      expect(picanha.name, 'PICANHA BOVINA KG');
      expect(picanha.quantity, 1.5);
      expect(picanha.unitPrice, 60.00);
      expect(picanha.totalPrice, 90.00);
      expect(picanha.category, ReceiptItemCategorizer.acougue);
    });
  });
}
