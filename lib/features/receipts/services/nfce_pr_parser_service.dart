import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:uuid/uuid.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

class NfceParseException implements Exception {
  final String message;
  const NfceParseException(this.message);

  @override
  String toString() => message;
}

/// Serviço de extração e análise de NFC-e do Paraná (SEFAZ-PR)
class NfcePrParserService {
  final Dio _dio;
  final Uuid _uuid;

  NfcePrParserService({Dio? dio, Uuid? uuid})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                  'Accept':
                      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
                },
              ),
            ),
        _uuid = uuid ?? const Uuid();

  /// Busca a página da SEFAZ pela URL do QR Code e realiza o parsing.
  Future<Receipt> parseFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (!cleanUrl.toLowerCase().contains('fazenda.pr.gov.br') &&
        !cleanUrl.toLowerCase().contains('nfce') &&
        !cleanUrl.toLowerCase().contains('qrcode')) {
      throw const NfceParseException(
        'A URL informada não aparenta ser um QR Code de NFC-e do Paraná.',
      );
    }

    String? accessKey;
    try {
      final uri = Uri.parse(cleanUrl);
      final pParam = uri.queryParameters['p'];
      if (pParam != null) {
        final parts = pParam.split('|');
        if (parts.isNotEmpty && parts[0].length >= 44) {
          accessKey = parts[0].substring(0, 44);
        }
      }
    } catch (_) {}

    try {
      final response = await _dio.get<String>(
        cleanUrl,
        options: Options(responseType: ResponseType.plain),
      );

      final htmlBody = response.data;
      if (htmlBody == null || htmlBody.isEmpty) {
        throw const NfceParseException(
          'A SEFAZ não retornou o conteúdo da nota fiscal.',
        );
      }

      return parseFromHtml(
        htmlBody,
        rawUrl: cleanUrl,
        accessKey: accessKey,
      );
    } on DioException catch (e) {
      throw NfceParseException(
        'Erro ao conectar com a SEFAZ-PR: ${e.message ?? 'Verifique sua conexão.'}',
      );
    }
  }

  /// Processa o HTML da NFC-e e monta o objeto [Receipt] com seus [ReceiptItem]s.
  Receipt parseFromHtml(
    String htmlContent, {
    String? rawUrl,
    String? accessKey,
  }) {
    final document = html_parser.parse(htmlContent);

    // 1. Razão Social / Estabelecimento
    final establishmentName = _extractEstablishmentName(document);

    // 2. CNPJ
    final cnpj = _extractCnpj(document);

    // 3. Data de Emissão
    final issueDate = _extractIssueDate(document);

    // 4. Valor Total
    final totalAmount = _extractTotalAmount(document);

    // 5. Forma de Pagamento
    final paymentMethod = _extractPaymentMethod(document);

    // 6. Itens / Produtos
    final receiptId = _uuid.v4();
    final items = _extractItems(document, receiptId);

    // Se nenhum item foi extraído mas temos total, cria ao menos um item resumo
    if (items.isEmpty && totalAmount > 0) {
      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          receiptId: receiptId,
          name: 'Compra de Supermercado',
          quantity: 1,
          unit: 'UN',
          unitPrice: totalAmount,
          totalPrice: totalAmount,
          category: ReceiptItemCategorizer.outros,
          sortOrder: 0,
        ),
      );
    }

    return Receipt(
      id: receiptId,
      transactionId: '',
      establishmentName: establishmentName.isNotEmpty
          ? establishmentName
          : 'Supermercado (NFC-e PR)',
      establishmentCnpj: cnpj,
      issueDate: issueDate,
      totalAmount: totalAmount > 0
          ? totalAmount
          : items.fold(0.0, (acc, item) => acc + item.totalPrice),
      paymentMethod: paymentMethod,
      accessKey: accessKey,
      rawUrl: rawUrl,
      createdAt: DateTime.now(),
      items: items,
    );
  }

  String _extractEstablishmentName(dom.Document doc) {
    // Padrão SEFAZ PR: .txtTopo, #u20, .txtNome, ou primeiro h4/span no cabeçalho
    final candidateSelectors = [
      '.txtTopo',
      '#u20',
      '.txtNome',
      'div#conteudo .header .txtTopo',
      '#conteudo .txtTopo',
      'table.linhaTopo .txtTopo',
    ];

    for (final sel in candidateSelectors) {
      final el = doc.querySelector(sel);
      if (el != null && el.text.trim().isNotEmpty) {
        return _cleanText(el.text);
      }
    }

    // Procura por nós de texto que contenham razão social
    final allText = doc.body?.text ?? '';
    final match = RegExp(r'(?:Razão Social|Emitente):\s*([^\n\r]+)').firstMatch(allText);
    if (match != null) {
      return _cleanText(match.group(1) ?? '');
    }

    return 'Supermercado (PR)';
  }

  String _extractCnpj(dom.Document doc) {
    final cnpjEl = doc.querySelector('.CNPJ') ??
        doc.querySelector('.txtCNPJ') ??
        doc.querySelector('#u21');
    if (cnpjEl != null && cnpjEl.text.trim().isNotEmpty) {
      final match = RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}')
          .firstMatch(cnpjEl.text);
      if (match != null) return match.group(0)!;
    }

    final allText = doc.body?.text ?? '';
    final match = RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}').firstMatch(allText);
    return match?.group(0) ?? '';
  }

  DateTime _extractIssueDate(dom.Document doc) {
    final allText = doc.body?.text ?? '';
    // Procura por data: dd/MM/yyyy HH:mm:ss ou dd/MM/yyyy
    final match = RegExp(
      r'(\d{2}/\d{2}/\d{4})(?:\s+às\s+|\s+)?(\d{2}:\d{2}(?::\d{2})?)?',
    ).firstMatch(allText);

    if (match != null) {
      final dateStr = match.group(1)!;
      final timeStr = match.group(2);
      try {
        if (timeStr != null) {
          final partsDate = dateStr.split('/');
          final partsTime = timeStr.split(':');
          final day = int.parse(partsDate[0]);
          final month = int.parse(partsDate[1]);
          final year = int.parse(partsDate[2]);
          final hour = int.parse(partsTime[0]);
          final minute = int.parse(partsTime[1]);
          final second = partsTime.length > 2 ? int.parse(partsTime[2]) : 0;
          return DateTime(year, month, day, hour, minute, second);
        } else {
          final parts = dateStr.split('/');
          return DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {}
    }

    return DateTime.now();
  }

  double _extractTotalAmount(dom.Document doc) {
    final candidateSelectors = [
      '#linhaTotal .totalNfe',
      '.txtMax',
      '.totalNfe',
      '#linhaTotal .valor',
      'span.totalNfe',
      '.totalNfe span',
    ];

    for (final sel in candidateSelectors) {
      final el = doc.querySelector(sel);
      if (el != null) {
        final val = _parseCurrency(el.text);
        if (val > 0) return val;
      }
    }

    // Busca por regex no texto
    final allText = doc.body?.text ?? '';
    final match = RegExp(
      r'(?:Valor a pagar|Valor total|Total da Nota|Total)\s*:?\s*R?\$?\s*([\d\.,]+)',
      caseSensitive: false,
    ).firstMatch(allText);

    if (match != null) {
      return _parseCurrency(match.group(1) ?? '0');
    }

    return 0.0;
  }

  String _extractPaymentMethod(dom.Document doc) {
    final allText = doc.body?.text.toLowerCase() ?? '';

    if (allText.contains('cartao de credito') ||
        allText.contains('cartão de crédito') ||
        allText.contains('credito') ||
        allText.contains('crédito')) {
      return PaymentMethods.creditCard;
    }
    if (allText.contains('cartao de debito') ||
        allText.contains('cartão de débito') ||
        allText.contains('debito') ||
        allText.contains('débito')) {
      return PaymentMethods.debitCard;
    }
    if (allText.contains('pix')) {
      return PaymentMethods.pix;
    }
    if (allText.contains('dinheiro') || allText.contains('especie')) {
      return PaymentMethods.money;
    }

    return PaymentMethods.debitCard; // Forma padrão mais comum em mercado
  }

  List<ReceiptItem> _extractItems(dom.Document doc, String receiptId) {
    final items = <ReceiptItem>[];

    // No padrão SEFAZ: tabela #tabResult com linhas tr
    final table = doc.querySelector('table#tabResult') ??
        doc.querySelector('table.tabResult') ??
        doc.querySelector('#tabResult');

    final rows = table?.querySelectorAll('tr') ?? doc.querySelectorAll('tr');

    var order = 0;
    for (final row in rows) {
      final titleEl = row.querySelector('.txtTit') ??
          row.querySelector('span.txtTit') ??
          row.querySelector('.nome');

      if (titleEl == null || titleEl.text.trim().isEmpty) continue;

      final name = _cleanText(titleEl.text);
      if (name.isEmpty) continue;

      final codeEl = row.querySelector('.RCod');
      final code = codeEl != null
          ? codeEl.text.replaceAll(RegExp(r'[^\d]'), '').trim()
          : null;

      final qtdEl = row.querySelector('.Rqtd');
      final qtd = qtdEl != null
          ? _parseQuantity(qtdEl.text)
          : 1.0;

      final unEl = row.querySelector('.RUN');
      final unit = unEl != null
          ? unEl.text.replaceAll('UN:', '').replaceAll(':', '').trim()
          : 'UN';

      final unitValEl = row.querySelector('.RvlUnit');
      final unitVal = unitValEl != null
          ? _parseCurrency(unitValEl.text)
          : 0.0;

      final totalValEl = row.querySelector('.RvlTot') ??
          row.querySelector('.valor') ??
          row.querySelector('.txtValor');
      final totalVal = totalValEl != null
          ? _parseCurrency(totalValEl.text)
          : (qtd * unitVal);

      final category = ReceiptItemCategorizer.categorize(name);

      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          receiptId: receiptId,
          name: name,
          code: code,
          quantity: qtd > 0 ? qtd : 1.0,
          unit: unit.isNotEmpty ? unit : 'UN',
          unitPrice: unitVal > 0 ? unitVal : (totalVal / (qtd > 0 ? qtd : 1)),
          totalPrice: totalVal > 0 ? totalVal : (qtd * unitVal),
          category: category,
          sortOrder: order++,
        ),
      );
    }

    return items;
  }

  double _parseCurrency(String text) {
    var clean = text.replaceAll('R\$', '').replaceAll('Vl. Unit.:', '').trim();
    clean = clean.replaceAll(' ', '');
    // Se formato brasileiro: 1.234,56
    if (clean.contains(',') && clean.contains('.')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    // Remove qualquer caractere que não seja número ou ponto
    clean = clean.replaceAll(RegExp(r'[^\d\.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  double _parseQuantity(String text) {
    var clean = text.replaceAll('Qtde.:', '').replaceAll('Qtd.:', '').trim();
    if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    clean = clean.replaceAll(RegExp(r'[^\d\.]'), '');
    return double.tryParse(clean) ?? 1.0;
  }

  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Retorna um cupom fiscal de demonstração do Paraná para testes imediatos.
  Receipt getDemoReceipt() {
    final receiptId = _uuid.v4();
    final now = DateTime.now();

    final sampleItemsData = [
      {
        'name': 'PICANHA BOVINA RESFRIADA KG',
        'qtd': 1.250,
        'un': 'KG',
        'unitPrice': 69.90,
        'category': ReceiptItemCategorizer.acougue,
      },
      {
        'name': 'FILE DE PEITO DE FRANGO 1KG',
        'qtd': 2.0,
        'un': 'UN',
        'unitPrice': 19.90,
        'category': ReceiptItemCategorizer.acougue,
      },
      {
        'name': 'BANANA PRATA KG',
        'qtd': 1.400,
        'un': 'KG',
        'unitPrice': 6.99,
        'category': ReceiptItemCategorizer.hortifruti,
      },
      {
        'name': 'TOMATE LONGA VIDA KG',
        'qtd': 0.850,
        'un': 'KG',
        'unitPrice': 7.49,
        'category': ReceiptItemCategorizer.hortifruti,
      },
      {
        'name': 'DETERGENTE LIQUIDO YPE 500ML',
        'qtd': 3.0,
        'un': 'UN',
        'unitPrice': 2.69,
        'category': ReceiptItemCategorizer.limpeza,
      },
      {
        'name': 'SABAO EM PO OMO LAVAGEM PERFEITA 1.6KG',
        'qtd': 1.0,
        'un': 'UN',
        'unitPrice': 24.90,
        'category': ReceiptItemCategorizer.limpeza,
      },
      {
        'name': 'PAPEL TOALHA SNOB C/ 2 ROLOS',
        'qtd': 2.0,
        'un': 'UN',
        'unitPrice': 6.89,
        'category': ReceiptItemCategorizer.cozinha,
      },
      {
        'name': 'CREME DENTAL COLGATE TOTAL 12 90G',
        'qtd': 2.0,
        'un': 'UN',
        'unitPrice': 8.90,
        'category': ReceiptItemCategorizer.higiene,
      },
      {
        'name': 'LEITE INTEGRAL PIRACANJUBA 1L',
        'qtd': 6.0,
        'un': 'UN',
        'unitPrice': 4.79,
        'category': ReceiptItemCategorizer.padaria,
      },
      {
        'name': 'ARROZ BRANCO TIPO 1 CAMIL 5KG',
        'qtd': 1.0,
        'un': 'UN',
        'unitPrice': 28.90,
        'category': ReceiptItemCategorizer.alimentacao,
      },
      {
        'name': 'REFRIGERANTE COCA-COLA 2L',
        'qtd': 2.0,
        'un': 'UN',
        'unitPrice': 9.99,
        'category': ReceiptItemCategorizer.bebidas,
      },
    ];

    var sort = 0;
    final items = sampleItemsData.map((data) {
      final qtd = (data['qtd'] as num).toDouble();
      final unitPrice = (data['unitPrice'] as num).toDouble();
      final total = (qtd * unitPrice * 100).roundToDouble() / 100;
      return ReceiptItem(
        id: _uuid.v4(),
        receiptId: receiptId,
        name: data['name'] as String,
        code: '789${100000000 + sort}',
        quantity: qtd,
        unit: data['un'] as String,
        unitPrice: unitPrice,
        totalPrice: total,
        category: data['category'] as String,
        sortOrder: sort++,
      );
    }).toList();

    final totalAmount =
        items.fold(0.0, (acc, item) => acc + item.totalPrice);

    return Receipt(
      id: receiptId,
      transactionId: '',
      establishmentName: 'Supermercado Condor - Curitiba/PR',
      establishmentCnpj: '76.189.406/0001-40',
      issueDate: now,
      totalAmount: (totalAmount * 100).roundToDouble() / 100,
      paymentMethod: PaymentMethods.creditCard,
      accessKey: '41261176189406000140650010001234561001234567',
      rawUrl:
          'http://www.fazenda.pr.gov.br/nfce/qrcode?p=41261176189406000140650010001234561001234567|2|1|1|ABCD',
      createdAt: now,
      items: items,
    );
  }
}
