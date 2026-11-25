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
      const sampleHtml = r'''
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
    <table id="totalNota">
      <tr><th>Qtde. total de itens</th><td>2</td></tr>
      <tr><th>Valor total R$</th><td>114,90</td></tr>
      <tr><th>Desconto R$</th><td>0,00</td></tr>
      <tr><th>Valor a pagar R$</th><td>114,90</td></tr>
    </table>
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

    test('aplica desconto por item e desconto da nota no total', () {
      const sampleHtml = r'''
<!DOCTYPE html>
<html>
<body>
  <div id="conteudo">
    <span class="txtTopo">MERCADO DESCONTO LTDA</span>
    <span class="CNPJ">12.345.678/0001-90</span>
    <span>Emissão: 21/11/2026 10:00:00</span>
    <table id="tabResult">
      <tr>
        <td>
          <span class="txtTit">SABAO EM PO OMO 1.6KG</span>
          <span class="RCod">(Código: 1234)</span>
          <span class="Rqtd">Qtde.: 1,000</span>
          <span class="RUN">UN: UN</span>
          <span class="RvlUnit">Vl. Unit.: 24,90</span>
          <span class="Rdesc">Desconto: 2,00</span>
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
    <table id="totalNota">
      <tr><th>Qtde. total de itens</th><td>2</td></tr>
      <tr><th>Valor total R$</th><td>114,90</td></tr>
      <tr><th>Desconto R$</th><td>10,00</td></tr>
      <tr><th>Valor a pagar R$</th><td>104,90</td></tr>
    </table>
  </div>
</body>
</html>
''';

      final receipt = parser.parseFromHtml(sampleHtml);

      expect(receipt.items.length, 2);
      // Bruto: 24,90 + 90,00
      expect(receipt.itemsGrossTotal, closeTo(114.90, 0.001));
      // Líquido dos itens: 22,90 + 90,00
      expect(receipt.itemsNetTotal, closeTo(112.90, 0.001));
      // O total salvo é o "Valor a pagar", já depois dos descontos
      expect(receipt.totalAmount, closeTo(104.90, 0.001));

      final omo = receipt.items.first;
      expect(omo.discount, closeTo(2.00, 0.001));
      expect(omo.totalPrice, closeTo(22.90, 0.001));

      // 114,90 - 104,90 = 10,00 de desconto total; 2,00 são do item,
      // então 8,00 ficam no desconto da nota.
      expect(receipt.discountTotal, closeTo(10.00, 0.001));
      expect(receipt.discountAmount, closeTo(8.00, 0.001));
    });

    test('reconstroi o total a partir do valor total quando falta o valor a pagar', () {
      const sampleHtml = r'''
<!DOCTYPE html>
<html>
<body>
  <div id="conteudo">
    <span class="txtTopo">MERCADO SEM PAGAR LTDA</span>
    <table id="tabResult">
      <tr>
        <td>
          <span class="txtTit">ARROZ 5KG</span>
          <span class="Rqtd">Qtde.: 1</span>
          <span class="RUN">UN: UN</span>
          <span class="RvlUnit">Vl. Unit.: 30,00</span>
          <span class="RvlTot">30,00</span>
        </td>
      </tr>
    </table>
    <table id="totalNota">
      <tr><th>Valor total R$</th><td>30,00</td></tr>
      <tr><th>Desconto R$</th><td>5,00</td></tr>
    </table>
  </div>
</body>
</html>
''';

      final receipt = parser.parseFromHtml(sampleHtml);

      expect(receipt.totalAmount, closeTo(25.00, 0.001));
      expect(receipt.itemsGrossTotal, closeTo(30.00, 0.001));
      expect(receipt.discountTotal, closeTo(5.00, 0.001));
      expect(receipt.discountAmount, closeTo(5.00, 0.001));
    });

    test('extrai itens renderizados em divs (fora da tabela tabResult)', () {
      const sampleHtml = r'''
<!DOCTYPE html>
<html>
<body>
  <div id="conteudo">
    <span class="txtTopo">COMERCIO DE MEDICAMENTOS TESTE LTDA</span>
    <span>CNPJ: 88.212.113/1091-01</span>
    <div class="produto">
      <div class="nome">DIPIRONA 500MG</div>
      <div class="descricao">Qtde.: 2 UN: UN Vl. Unit.: 10,00</div>
      <div class="preco">R$ 20,00</div>
    </div>
    <div class="produto">
      <div class="nome">VITAMINA C 1G</div>
      <div class="descricao">Qtde.: 1 UN: UN Vl. Unit.: 15,00</div>
      <div class="preco">R$ 15,00</div>
    </div>
    <table id="totalNota">
      <tr><th>Valor total R$</th><td>35,00</td></tr>
      <tr><th>Desconto R$</th><td>0,00</td></tr>
      <tr><th>Valor a pagar R$</th><td>35,00</td></tr>
    </table>
  </div>
</body>
</html>
''';

      final receipt = parser.parseFromHtml(sampleHtml);

      expect(receipt.items.length, 2);
      expect(receipt.items[0].name, 'DIPIRONA 500MG');
      expect(receipt.items[0].quantity, 2);
      expect(receipt.items[0].unitPrice, closeTo(10.00, 0.001));
      expect(receipt.items[0].totalPrice, closeTo(20.00, 0.001));
      expect(receipt.items[1].name, 'VITAMINA C 1G');
      expect(receipt.items[1].totalPrice, closeTo(15.00, 0.001));
      expect(receipt.totalAmount, closeTo(35.00, 0.001));
    });

    test('parseFromHtml extrai layout real SEFAZ-PR com txtTit2, #totalNota em divs e itens repetidos', () {
      const sefazPrRealHtml = r'''
<html>
<title>DF-e Portal/Pr - Consulta DANFE NFC-e</title>
<body>
<div data-role="content">
 <div id="conteudo">
  <div class="txtCenter">
   <div id="u20" class="txtTopo">SUPERMERCADO EXEMPLO PR LTDA</div>
   <div class="text">CNPJ: 11.222.333/0001-44</div>
   <div class="text">AV BRASIL, 1000, CENTRO, CURITIBA, PR</div>
  </div>
  <table id="tabResult" data-filter="true">
   <tr id="Item + 1">
    <td valign="top">
     <span class="txtTit2">ANALGESICO EXEMPLO 500MG 10CP</span>
     <span class="RCod">(Código: 10087408)</span>
     <br></br>
     <span class="Rqtd"><strong>Qtde.:</strong>2</span>
     <span class="RUN"><strong>UN: </strong>UN</span>
     <span class="RvlUnit"><strong>Vl. Unit.:</strong>&nbsp;10,2</span>
    </td>
    <td align="right" valign="top" class="txtTit3 noWrap">Vl. Total
     <br></br>
     <span class="valor">20,40</span>
    </td>
   </tr>
   <tr id="Item + 2">
    <td valign="top">
     <span class="txtTit2">PEITO DE FRANGO RESFRIADO KG</span>
     <span class="RCod">(Código: 147834)</span>
     <br></br>
     <span class="Rqtd"><strong>Qtde.:</strong>1,500</span>
     <span class="RUN"><strong>UN: </strong>KG</span>
     <span class="RvlUnit"><strong>Vl. Unit.:</strong>&nbsp;20,00</span>
    </td>
    <td align="right" valign="top" class="txtTit3 noWrap">Vl. Total
     <br></br>
     <span class="valor">30,00</span>
    </td>
   </tr>
   <tr id="Item + 3">
    <td valign="top">
     <span class="txtTit2">CHOCOLATE AO LEITE 90G</span>
     <span class="RCod">(Código: 318493)</span>
     <br></br>
     <span class="Rqtd"><strong>Qtde.:</strong>1</span>
     <span class="RUN"><strong>UN: </strong>UN</span>
     <span class="RvlUnit"><strong>Vl. Unit.:</strong>&nbsp;5,00</span>
    </td>
    <td align="right" valign="top" class="txtTit3 noWrap">Vl. Total
     <br></br>
     <span class="valor">5,00</span>
    </td>
   </tr>
   <tr id="Item + 4">
    <td valign="top">
     <span class="txtTit2">CHOCOLATE AO LEITE 90G</span>
     <span class="RCod">(Código: 318493)</span>
     <br></br>
     <span class="Rqtd"><strong>Qtde.:</strong>1</span>
     <span class="RUN"><strong>UN: </strong>UN</span>
     <span class="RvlUnit"><strong>Vl. Unit.:</strong>&nbsp;5,00</span>
    </td>
    <td align="right" valign="top" class="txtTit3 noWrap">Vl. Total
     <br></br>
     <span class="valor">5,00</span>
    </td>
   </tr>
  </table>
  <div id="totalNota" class="txtRight">
   <div id="linhaTotal">
    <label>Qtd. total de itens:</label>
    <span class="totalNumb">4</span>
   </div>
   <div id="linhaTotal">
    <label>Valor total R$:</label>
    <span class="totalNumb">60,40</span>
   </div>
   <div id="linhaTotal">
    <label>Descontos R$:</label>
    <span class="totalNumb">8,40</span>
   </div>
   <div id="linhaTotal" class="linhaShade">
    <label>Valor a pagar R$:</label>
    <span class="totalNumb txtMax">52,00</span>
   </div>
   <div id="linhaForma">
    <label class="txtMax2">Forma de pagamento:</label>
    <span class="totalNumb txtMax2">Valor pago R$:</span>
   </div>
   <div id="linhaTotal">
    <label class="tx">Cartão de Crédito</label>
    <span class="totalNumb">52,00</span>
   </div>
   <div id="linhaTotal" class="spcTop">
    <label class="txtObs">Informação dos Tributos Totais Incidentes (Lei Federal 12.741/2012)&nbsp;R$</label>
    <span class="totalNumb txtObs">12,50</span>
   </div>
  </div>
 </div>
 <div id="infos" class="txtCenter">
  <div>
   <strong>Emissão: </strong>21/11/2026 18:19:10 - Via Consumidor
   <span class="chave">4126 1111 2223 3300 0144 6501 7000 0113 9811 3003 9782</span>
  </div>
  <div>Secretaria de Estado da Fazenda do Paraná - Data/Hora da Consulta: 25/11/2026 12:26:25</div>
 </div>
</div>
</body>
</html>
''';

      final receipt = parser.parseFromHtml(sefazPrRealHtml);

      expect(receipt.establishmentName, 'SUPERMERCADO EXEMPLO PR LTDA');
      expect(receipt.establishmentCnpj, '11.222.333/0001-44');
      expect(receipt.issueDate, DateTime(2026, 11, 21, 18, 19, 10));
      expect(receipt.paymentMethod, PaymentMethods.creditCard);
      expect(
        receipt.accessKey,
        '41261111222333000144650170000113981130039782',
      );
      expect(receipt.items.length, 4);
      expect(receipt.items[0].name, 'ANALGESICO EXEMPLO 500MG 10CP');
      expect(receipt.items[0].quantity, 2.0);
      expect(receipt.items[0].unitPrice, closeTo(10.20, 0.001));
      expect(receipt.items[0].grossTotal, closeTo(20.40, 0.001));
      expect(receipt.items[1].unit, 'KG');
      expect(receipt.items[1].quantity, closeTo(1.500, 0.001));
      expect(receipt.items[2].name, 'CHOCOLATE AO LEITE 90G');
      expect(receipt.items[3].name, 'CHOCOLATE AO LEITE 90G');

      expect(receipt.subtotalAmount, closeTo(60.40, 0.001));
      expect(receipt.totalDiscount, closeTo(8.40, 0.001));
      expect(receipt.discountTotal, closeTo(8.40, 0.001));
      expect(receipt.finalAmount, closeTo(52.00, 0.001));
      expect(receipt.totalAmount, closeTo(52.00, 0.001));
    });

    test('extrai desconto por item com texto Clube Amigo e linha info-item irma', () {
      const htmlComDescontoItem = r'''
<html>
<body>
  <div id="conteudo">
    <div id="u20" class="txtTopo">SUPERMERCADO CLUBE LTDA</div>
    <table id="tabResult">
      <tr id="Item + 1">
        <td>
          <span class="txtTit2">CAFE TORRADO 500G</span>
          <span class="Rqtd"><strong>Qtde.:</strong>1</span>
          <span class="RUN"><strong>UN: </strong>UN</span>
          <span class="RvlUnit"><strong>Vl. Unit.:</strong> 20,00</span>
          <span class="Rdesc">Desconto Clube Amigo: R$ 4,00</span>
        </td>
        <td class="txtTit3 noWrap"><span class="valor">20,00</span></td>
      </tr>
      <tr id="Item + 2">
        <td>
          <span class="txtTit2">ACUCAR REFINADO 1KG</span>
          <span class="Rqtd"><strong>Qtde.:</strong>2</span>
          <span class="RUN"><strong>UN: </strong>UN</span>
          <span class="RvlUnit"><strong>Vl. Unit.:</strong> 5,00</span>
        </td>
        <td class="txtTit3 noWrap"><span class="valor">10,00</span></td>
      </tr>
      <tr class="info-item">
        <td colspan="2" class="txtTit2">Desconto sobre o item: R$ 1,50</td>
      </tr>
    </table>
    <div id="totalNota">
      <div id="linhaTotal"><label>Valor total R$:</label><span class="totalNumb">30,00</span></div>
      <div id="linhaTotal"><label>Descontos R$:</label><span class="totalNumb">5,50</span></div>
      <div id="linhaTotal"><label>Valor a pagar R$:</label><span class="totalNumb txtMax">24,50</span></div>
    </div>
  </div>
</body>
</html>
''';

      final receipt = parser.parseFromHtml(htmlComDescontoItem);

      expect(receipt.items.length, 2);
      final cafe = receipt.items[0];
      expect(cafe.name, 'CAFE TORRADO 500G');
      expect(cafe.grossTotal, closeTo(20.00, 0.001));
      expect(cafe.discount, closeTo(4.00, 0.001));
      expect(cafe.netTotal, closeTo(16.00, 0.001));

      final acucar = receipt.items[1];
      expect(acucar.name, 'ACUCAR REFINADO 1KG');
      expect(acucar.grossTotal, closeTo(10.00, 0.001));
      expect(acucar.discount, closeTo(1.50, 0.001));
      expect(acucar.netTotal, closeTo(8.50, 0.001));

      expect(receipt.subtotalAmount, closeTo(30.00, 0.001));
      expect(receipt.totalDiscount, closeTo(5.50, 0.001));
      expect(receipt.finalAmount, closeTo(24.50, 0.001));
    });
  });
}
