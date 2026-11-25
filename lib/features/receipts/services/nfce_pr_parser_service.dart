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

/// Serviço de extração e análise de NFC-e do Paraná (SEFAZ-PR) e layouts compatíveis.
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
    final now = DateTime.now();

    // 1. Razão Social / Estabelecimento
    final establishmentName = _extractEstablishmentName(document);

    // 2. CNPJ
    final cnpj = _extractCnpj(document);

    // 3. Data de Emissão
    final issueDate = _extractIssueDate(document);

    // 4. Chave de Acesso (caso não tenha vindo na URL)
    final resolvedAccessKey =
        (accessKey != null && accessKey.isNotEmpty)
            ? accessKey
            : _extractAccessKey(document);

    // 5. Valores gerais (subtotal bruto, descontos e valor a pagar)
    final totals = _extractTotals(document);

    // 6. Forma de Pagamento
    final paymentMethod = _extractPaymentMethod(document);

    // 7. Itens / Produtos
    final receiptId = _uuid.v4();
    final items = _extractItems(document, receiptId, now);

    final itemsGross = items.fold(
      0.0,
      (acc, item) => acc + item.effectiveGrossTotal,
    );
    final itemsNet = items.fold(0.0, (acc, item) => acc + item.totalPrice);
    final itemDiscounts = items.fold(0.0, (acc, item) => acc + item.discount);

    // O valor final pago vem de "Valor a pagar".
    // Se a SEFAZ não expôs esse campo, reconstruímos a partir dos itens.
    var totalAmount = (totals.total ?? 0) > 0 ? _round2(totals.total!) : 0.0;
    if (totalAmount <= 0) {
      totalAmount = _round2(itemsNet > 0 ? itemsNet : itemsGross);
      if (totalAmount > 0) {
        final extraDiscount = ((totals.discount ?? 0) - itemDiscounts)
            .clamp(0.0, double.infinity);
        totalAmount = _round2(
          (totalAmount - extraDiscount).clamp(0.0, double.infinity).toDouble(),
        );
      }
    }

    // Fallback apenas quando a SEFAZ não exibiu nenhuma linha de produto.
    if (items.isEmpty && totalAmount > 0) {
      final grossFallback = (totals.subtotal != null && totals.subtotal! > 0)
          ? _round2(totals.subtotal!)
          : totalAmount;
      final discountFallback =
          (grossFallback - totalAmount).clamp(0.0, grossFallback).toDouble();
      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          receiptId: receiptId,
          name: 'Compra de Supermercado',
          quantity: 1,
          unit: 'UN',
          unitPrice: grossFallback,
          grossTotal: grossFallback,
          totalPrice: totalAmount,
          discount: _round2(discountFallback),
          category: ReceiptItemCategorizer.outros,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    final finalGross = items.fold(
      0.0,
      (acc, item) => acc + item.effectiveGrossTotal,
    );
    final finalItemDiscounts =
        items.fold(0.0, (acc, item) => acc + item.discount);

    final subtotalAmount = finalGross > 0
        ? _round2(finalGross)
        : _round2(totals.subtotal ?? totalAmount);
    final finalAmount = totalAmount > 0 ? totalAmount : _round2(itemsNet);

    var totalDiscount = 0.0;
    if (subtotalAmount > finalAmount) {
      totalDiscount = _round2(subtotalAmount - finalAmount);
      if (totalDiscount < 0.01) totalDiscount = 0.0;
    } else if ((totals.discount ?? 0) > 0) {
      totalDiscount = _round2(totals.discount!);
    } else if (finalItemDiscounts > 0.005) {
      totalDiscount = _round2(finalItemDiscounts);
    }

    final receiptDiscount = _round2(
      (totalDiscount - finalItemDiscounts).clamp(0.0, double.infinity),
    );

    return Receipt(
      id: receiptId,
      transactionId: '',
      establishmentName: establishmentName.isNotEmpty
          ? establishmentName
          : 'Supermercado (NFC-e PR)',
      establishmentCnpj: cnpj,
      issueDate: issueDate,
      totalAmount: finalAmount,
      subtotalAmount: subtotalAmount > 0 ? subtotalAmount : finalAmount,
      totalDiscount: totalDiscount,
      discountAmount: receiptDiscount < 0.01 ? 0.0 : receiptDiscount,
      paymentMethod: paymentMethod,
      accessKey: resolvedAccessKey,
      rawUrl: rawUrl,
      createdAt: now,
      updatedAt: now,
      items: items,
    );
  }

  String _extractEstablishmentName(dom.Document doc) {
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

    final allText = doc.body?.text ?? '';
    final match =
        RegExp(r'(?:Razão Social|Emitente):\s*([^\n\r]+)').firstMatch(allText);
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

  String? _extractAccessKey(dom.Document doc) {
    final chaveEl = doc.querySelector('.chave') ?? doc.querySelector('#chave');
    if (chaveEl != null) {
      final digits = chaveEl.text.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 44) return digits;
    }
    final allText = doc.body?.text ?? '';
    final match = RegExp(r'(?:\d{4}[\s-]?){11}').firstMatch(allText);
    if (match != null) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 44) return digits;
    }
    return null;
  }

  DateTime _extractIssueDate(dom.Document doc) {
    final allText = doc.body?.text ?? '';
    // Prioriza a data ancorada no campo "Emissão:" para não confundir com a
    // data/hora da consulta exibida no rodapé da SEFAZ.
    final anchored = RegExp(
      r'emiss[ãa]o\s*:?\s*(\d{2}/\d{2}/\d{4})(?:\s+às\s+|\s+)?(\d{2}:\d{2}(?::\d{2})?)?',
      caseSensitive: false,
    ).firstMatch(allText);
    final match = anchored ??
        RegExp(
          r'(\d{2}/\d{2}/\d{4})(?:\s+às\s+|\s+)?(\d{2}:\d{2}(?::\d{2})?)?',
        ).firstMatch(allText);

    if (match != null) {
      final dateStr = match.group(1)!;
      final timeStr = match.group(2);
      try {
        final partsDate = dateStr.split('/');
        final day = int.parse(partsDate[0]);
        final month = int.parse(partsDate[1]);
        final year = int.parse(partsDate[2]);
        if (timeStr != null) {
          final partsTime = timeStr.split(':');
          final hour = int.parse(partsTime[0]);
          final minute = int.parse(partsTime[1]);
          final second = partsTime.length > 2 ? int.parse(partsTime[2]) : 0;
          return DateTime(year, month, day, hour, minute, second);
        }
        return DateTime(year, month, day);
      } catch (_) {}
    }

    return DateTime.now();
  }

  _NfceTotals _extractTotals(dom.Document doc) {
    final result = _NfceTotals();

    final totalsBox = doc.querySelector('#totalNota') ??
        doc.querySelector('table#totalNota') ??
        doc.querySelector('.totalNota');

    void consumeLabel(String label, String value) {
      final normalized = _cleanText(label).toLowerCase();
      if (normalized.contains('tributo') ||
          normalized.contains('qtd') ||
          normalized.contains('qtde')) {
        return;
      }
      final parsed = _parseCurrency(value);
      if (parsed <= 0) return;

      if (normalized.contains('valor a pagar') ||
          normalized.contains('total a pagar') ||
          normalized.contains('valor pago')) {
        result.total = parsed;
      } else if (normalized.contains('desconto')) {
        result.discount = parsed;
      } else if (normalized.contains('valor total') ||
          normalized.contains('total da nota')) {
        result.subtotal = parsed;
      }
    }

    if (totalsBox != null) {
      // Layout div padrão SEFAZ-PR (<div id="linhaTotal"><label>...</label><span class="totalNumb">...</span></div>)
      for (final line in totalsBox.querySelectorAll('#linhaTotal, .linhaTotal, div')) {
        final labelEl = line.querySelector('label');
        final valEl = line.querySelector('.totalNumb, .valor, span');
        if (labelEl != null && valEl != null && labelEl != valEl) {
          consumeLabel(labelEl.text, valEl.text);
        }
      }

      // Layout tabular alternativo (<table id="totalNota"><tr><th>...</th><td>...</td></tr></table>)
      for (final row in totalsBox.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length < 2) continue;
        consumeLabel(cells.first.text, cells.last.text);
      }
    }

    // 2) Fallback por texto (fora da tabela de itens para não confundir desconto de item com desconto da nota).
    var allText = doc.body?.text ?? '';
    final itemsTable = doc.querySelector('table#tabResult') ??
        doc.querySelector('table.tabResult') ??
        doc.querySelector('#tabResult');
    if (itemsTable != null && itemsTable.text.isNotEmpty) {
      allText = allText.replaceFirst(itemsTable.text, ' ');
    }
    final flat = allText.replaceAll(RegExp(r'\s+'), ' ');

    result.total ??= _matchCurrency(
      flat,
      r'valor a pagar(?:\s*R\$)?\s*:?\s*(?:R\$)?\s*([\d.,]+)',
    );
    result.discount ??= _matchCurrency(
      flat,
      r'descontos?(?:\s*R\$)?\s*:?\s*(?:R\$)?\s*([\d.,]+)',
    );
    result.subtotal ??= _matchCurrency(
      flat,
      r'valor total(?:\s*R\$)?\s*:?\s*(?:R\$)?\s*([\d.,]+)',
    );

    // 3) Fallback por classes conhecidas do layout.
    if (result.total == null) {
      final totalNfe = doc.querySelector('#linhaTotal .totalNfe') ??
          doc.querySelector('.totalNfe') ??
          doc.querySelector('span.totalNfe');
      if (totalNfe != null) {
        final value = _parseCurrency(totalNfe.text);
        if (value > 0) result.total = value;
      }
    }

    if (result.total == null) {
      final maxElements = doc.querySelectorAll('.txtMax');
      final values = maxElements
          .map((el) => _parseCurrency(el.text))
          .where((value) => value > 0)
          .toList();
      if (values.length >= 2) {
        result.subtotal ??= values.first;
        result.total = values.last;
      } else if (values.length == 1) {
        final el = maxElements.first;
        final parentText = el.parent?.text.toLowerCase() ?? '';
        if (parentText.contains('pagar')) {
          result.total = values.first;
        } else {
          result.subtotal ??= values.first;
        }
      }
    }

    if (result.total == null && result.subtotal != null) {
      result.total = _round2(
        (result.subtotal! - (result.discount ?? 0)).clamp(0.0, double.infinity),
      );
    }

    if (result.subtotal == null && result.total != null) {
      result.subtotal = _round2(result.total! + (result.discount ?? 0));
    }

    return result;
  }

  double? _matchCurrency(String text, String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    final value = _parseCurrency(match.group(1) ?? '');
    return value > 0 ? value : null;
  }

  String _bodyTextWithoutItems(dom.Document doc) {
    var allText = doc.body?.text ?? '';
    final itemsTable = doc.querySelector('table#tabResult') ??
        doc.querySelector('table.tabResult') ??
        doc.querySelector('#tabResult');
    if (itemsTable != null && itemsTable.text.isNotEmpty) {
      allText = allText.replaceFirst(itemsTable.text, ' ');
    }
    return allText.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _extractPaymentMethod(dom.Document doc) {
    final paymentLabels =
        doc.querySelectorAll('#totalNota label.tx, #totalNota .tx');
    if (paymentLabels.isNotEmpty) {
      final found = _classifyPaymentMethodOrNull(
        paymentLabels.map((e) => e.text).join(' ').toLowerCase(),
      );
      if (found != null) return found;
    }

    final totalNotaText = doc.querySelector('#totalNota')?.text.toLowerCase();
    if (totalNotaText != null && totalNotaText.isNotEmpty) {
      final found = _classifyPaymentMethodOrNull(totalNotaText);
      if (found != null) return found;
    }

    final fallback = _classifyPaymentMethodOrNull(
      _bodyTextWithoutItems(doc).toLowerCase(),
    );
    return fallback ?? PaymentMethods.debitCard;
  }

  String? _classifyPaymentMethodOrNull(String text) {
    if (text.contains('cartao de credito') ||
        text.contains('cartão de crédito') ||
        text.contains('credito') ||
        text.contains('crédito')) {
      return PaymentMethods.creditCard;
    }
    if (text.contains('cartao de debito') ||
        text.contains('cartão de débito') ||
        text.contains('debito') ||
        text.contains('débito')) {
      return PaymentMethods.debitCard;
    }
    if (text.contains('pix')) {
      return PaymentMethods.pix;
    }
    if (text.contains('dinheiro') || text.contains('especie')) {
      return PaymentMethods.money;
    }
    if (text.contains('boleto')) {
      return PaymentMethods.boleto;
    }
    return null;
  }

  List<ReceiptItem> _extractItems(
    dom.Document doc,
    String receiptId,
    DateTime now,
  ) {
    // 1) Layout nacional/PR: linhas de #tabResult com .txtTit2 / .txtTit / .Rqtd / .RvlUnit...
    final fromRows = _extractItemsFromRows(doc, receiptId, now);
    if (fromRows.isNotEmpty) return fromRows;

    // 2) Itens renderizados fora de tabelas (divs de produto).
    final fromBlocks = _extractItemsFromBlocks(doc, receiptId, now);
    if (fromBlocks.isNotEmpty) return fromBlocks;

    // 3) Último recurso: qualquer tabela com nome + valor na mesma linha.
    return _extractItemsFromGenericTables(doc, receiptId, now);
  }

  dom.Element? _findTitleElement(dom.Element row) {
    return row.querySelector('.txtTit2') ??
        row.querySelector('.txtTit') ??
        row.querySelector('span.txtTit2') ??
        row.querySelector('span.txtTit') ??
        row.querySelector('.nomeProduto') ??
        row.querySelector('.descricaoProduto') ??
        row.querySelector('.descricao') ??
        row.querySelector('.nome') ??
        row.querySelector('.titulo');
  }

  List<ReceiptItem> _extractItemsFromRows(
    dom.Document doc,
    String receiptId,
    DateTime now,
  ) {
    final items = <ReceiptItem>[];

    final table = doc.querySelector('table#tabResult') ??
        doc.querySelector('table.tabResult') ??
        doc.querySelector('#tabResult');
    final rows = table?.querySelectorAll('tr') ?? doc.querySelectorAll('tr');

    var order = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final titleEl = _findTitleElement(row);
      if (titleEl == null || titleEl.text.trim().isEmpty) continue;

      final name = _cleanText(titleEl.text);
      if (!_looksLikeProductName(name)) continue;

      final codeEl = row.querySelector('.RCod');
      final code = codeEl != null
          ? codeEl.text.replaceAll(RegExp(r'[^\d]'), '').trim()
          : null;

      final qtdEl = row.querySelector('.Rqtd');
      final qtd = qtdEl != null ? _parseQuantity(qtdEl.text) : 1.0;

      final unEl = row.querySelector('.RUN');
      final unit = unEl != null
          ? _cleanText(unEl.text)
              .replaceAll(RegExp(r'^UN\s*:?\s*', caseSensitive: false), '')
              .replaceAll(':', '')
              .trim()
              .toUpperCase()
          : 'UN';

      final unitValEl = row.querySelector('.RvlUnit');
      final unitVal =
          unitValEl != null ? _parseCurrency(unitValEl.text) : 0.0;

      final totalValEl = row.querySelector('.RvlTot') ??
          row.querySelector('.valor') ??
          row.querySelector('.txtValor');
      final totalVal = totalValEl != null
          ? _parseCurrency(totalValEl.text)
          : _round2(qtd * unitVal);

      // Desconto da linha: pode estar numa classe específica, em texto na
      // própria linha (ex: "Desconto Clube Amigo: R$ 1,00"), ou em uma linha
      // irmã de detalhe logo abaixo (<tr class="info-item">).
      var lineDiscount = _extractRowDiscount(row);
      if (lineDiscount <= 0 && i + 1 < rows.length) {
        final nextRow = rows[i + 1];
        final nextTitle = _findTitleElement(nextRow);
        final nextIsProduct =
            nextTitle != null && _looksLikeProductName(_cleanText(nextTitle.text));
        if (!nextIsProduct) {
          final siblingDiscount = _extractRowDiscount(nextRow);
          if (siblingDiscount > 0) {
            lineDiscount = siblingDiscount;
            i++;
          }
        }
      }

      final normalizedQty = qtd > 0 ? qtd : 1.0;
      final rawGross = unitVal > 0 ? _round2(normalizedQty * unitVal) : 0.0;

      late double grossTotal;
      late double netTotal;

      if (lineDiscount > 0) {
        final totalLooksGross = totalVal <= 0 ||
            (rawGross > 0 && (totalVal - rawGross).abs() <= 0.03);
        if (totalLooksGross) {
          grossTotal = rawGross > 0 ? rawGross : totalVal;
          netTotal = _round2(
            (grossTotal - lineDiscount).clamp(0.0, double.infinity),
          );
        } else {
          netTotal = _round2(totalVal);
          grossTotal = rawGross > 0
              ? rawGross
              : _round2(netTotal + lineDiscount);
        }
      } else {
        if (totalVal > 0 && rawGross > 0 && (rawGross - totalVal) > 0.02) {
          lineDiscount = _round2(rawGross - totalVal);
          grossTotal = rawGross;
          netTotal = _round2(totalVal);
        } else {
          final base = totalVal > 0 ? _round2(totalVal) : rawGross;
          grossTotal = base;
          netTotal = base;
        }
      }

      if (netTotal < 0) netTotal = 0;
      lineDiscount = grossTotal > 0
          ? _round2(lineDiscount.clamp(0.0, grossTotal))
          : 0.0;

      final unitPrice = unitVal > 0
          ? unitVal
          : (normalizedQty > 0 ? _round2(grossTotal / normalizedQty) : grossTotal);

      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          receiptId: receiptId,
          name: name,
          code: (code != null && code.isNotEmpty) ? code : null,
          quantity: normalizedQty,
          unit: unit.isNotEmpty ? unit : 'UN',
          unitPrice: unitPrice,
          grossTotal: grossTotal,
          totalPrice: netTotal,
          discount: lineDiscount,
          category: ReceiptItemCategorizer.categorize(name),
          sortOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return items;
  }

  double _extractRowDiscount(dom.Element row) {
    final discountEl = row.querySelector('.Rdesc') ??
        row.querySelector('.RvlDesc') ??
        row.querySelector('.txtDesconto') ??
        row.querySelector('.desconto');
    if (discountEl != null) {
      final parsed = _parseCurrency(discountEl.text);
      if (parsed > 0) return parsed;
    }

    final match = RegExp(
      r'desconto(?:\s+[^:\d\n\r]{0,40})?\s*:?\s*-?\s*(?:R\$)?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(row.text);
    if (match != null) {
      return _parseCurrency(match.group(1) ?? '');
    }
    return 0.0;
  }

  List<ReceiptItem> _extractItemsFromBlocks(
    dom.Document doc,
    String receiptId,
    DateTime now,
  ) {
    final items = <ReceiptItem>[];
    final seen = <String>{};

    final candidates = doc.querySelectorAll(
      '.txtTit2, .txtTit, .nomeProduto, .descricaoProduto, .descricao, '
      '.produto .nome, .item .nome, '
      '[class*="produto"] [class*="nome"], '
      '[class*="item"] [class*="nome"], '
      '[class*="item"] [class*="descricao"]',
    );

    for (final titleEl in candidates) {
      final container = _closestItemContainer(titleEl);
      if (container == null) continue;

      final item = _buildGenericItem(
        container,
        titleEl,
        receiptId,
        items.length,
        now,
      );
      if (item == null) continue;

      if (!seen.add(_itemKey(item))) continue;
      items.add(item.copyWith(sortOrder: items.length));
    }

    return items;
  }

  List<ReceiptItem> _extractItemsFromGenericTables(
    dom.Document doc,
    String receiptId,
    DateTime now,
  ) {
    final items = <ReceiptItem>[];
    final seen = <String>{};

    for (final table in doc.querySelectorAll('table')) {
      final id = table.id.toLowerCase();
      if (id == 'totalnota' || id == 'linhatotal') continue;

      for (final row in table.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length < 2) continue;

        final item = _buildGenericItem(
          row,
          cells.first,
          receiptId,
          items.length,
          now,
        );
        if (item == null) continue;

        if (!seen.add(_itemKey(item))) continue;
        items.add(item.copyWith(sortOrder: items.length));
      }
    }

    return items;
  }

  String _itemKey(ReceiptItem item) =>
      '${item.name.toLowerCase()}|${item.quantity}|'
      '${item.totalPrice.toStringAsFixed(2)}';

  dom.Element? _closestItemContainer(dom.Element titleEl) {
    var node = titleEl.parent;
    for (var depth = 0; depth < 6 && node != null; depth++) {
      final text = node.text;
      if (RegExp(r'(?:qtde|qtd|quantidade)', caseSensitive: false)
              .hasMatch(text) ||
          RegExp(r'(?:vl\.?\s*unit|valor\s*unit)', caseSensitive: false)
              .hasMatch(text) ||
          RegExp(r'R\$\s*\d', caseSensitive: false).hasMatch(text)) {
        return node;
      }
      node = node.parent;
    }
    return titleEl.parent;
  }

  bool _looksLikeProductName(String name) {
    final normalized = _cleanText(name).toLowerCase();
    if (normalized.length < 3 || normalized.length > 120) return false;
    if (!RegExp(r'[a-zà-ÿ]').hasMatch(normalized)) return false;
    if (RegExp(
      r'^(?:(?:qtde|qtd|quantidade|un|valor|total)\b|vl\.?\b|r\$)',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return false;
    }
    if (normalized.contains('qtde') &&
        RegExp(r'unit[áa]rio|vl\.?\s*unit').hasMatch(normalized)) {
      return false;
    }

    const blocked = [
      'total',
      'desconto',
      'tributo',
      'valor a pagar',
      'forma de pagamento',
      'pagamento',
      'cartão',
      'cartao',
      'pix',
      'dinheiro',
      'cnpj',
      'cpf',
      'consumidor',
      'operador',
      'caixa',
      'chave de acesso',
      'protocolo',
      'autoriza',
      'consulta',
      'documento auxiliar',
      'data de emiss',
    ];
    return !blocked.any(normalized.contains);
  }

  ReceiptItem? _buildGenericItem(
    dom.Element container,
    dom.Element titleEl,
    String receiptId,
    int sortOrder,
    DateTime now,
  ) {
    final name = _cleanText(titleEl.text);
    if (!_looksLikeProductName(name)) return null;

    final text = container.text;

    final codeMatch =
        RegExp(r'c[óo]digo\s*:?\s*(\d+)', caseSensitive: false).firstMatch(text);
    final code = codeMatch?.group(1);

    final qtyMatch = RegExp(
      r'(?:qtde|qtd|quantidade)\.?\s*:?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final qty = qtyMatch != null ? _parseQuantity(qtyMatch.group(1)!) : 1.0;

    final unitMatch = RegExp(
      r'\bUN\s*:?\s*([A-Za-zÀ-ÿ]{1,4})',
      caseSensitive: false,
    ).firstMatch(text);
    final unit = unitMatch?.group(1)?.trim().toUpperCase() ?? 'UN';

    final unitPriceMatch = RegExp(
      r'(?:vl\.?\s*unit\.?|valor\s*unit[áa]rio|unit[áa]rio)\s*:?\s*'
      r'(?:R\$)?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    var unitPrice = unitPriceMatch != null
        ? _parseCurrency(unitPriceMatch.group(1)!)
        : 0.0;

    final discountMatch = RegExp(
      r'desconto(?:\s+[^:\d\n\r]{0,40})?\s*:?\s*-?\s*(?:R\$)?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    var discount =
        discountMatch != null ? _parseCurrency(discountMatch.group(1)!) : 0.0;

    final totalsText = text.replaceAll(
      RegExp(
        r'desconto(?:\s+[^:\d\n\r]{0,40})?\s*:?\s*-?\s*(?:R\$)?\s*[\d.,]+',
        caseSensitive: false,
      ),
      ' ',
    );
    final values = _currencyValues(totalsText);

    final normalizedQty = qty > 0 ? qty : 1.0;
    var grossTotal =
        unitPrice > 0 ? _round2(unitPrice * normalizedQty) : 0.0;
    var total = values.isNotEmpty ? _round2(values.last) : 0.0;

    if (total <= 0) total = grossTotal;
    if (grossTotal <= 0) {
      grossTotal = discount > 0 ? _round2(total + discount) : total;
    }
    if (total <= 0 && grossTotal <= 0) return null;

    if (discount > 0) {
      if ((total - grossTotal).abs() <= 0.03) {
        total = _round2(grossTotal - discount);
      }
    } else if (grossTotal - total > 0.02) {
      discount = _round2(grossTotal - total);
    } else {
      grossTotal = total;
    }

    if (total < 0) total = 0;
    discount =
        grossTotal > 0 ? _round2(discount.clamp(0.0, grossTotal)) : 0.0;
    if (unitPrice <= 0) {
      unitPrice = normalizedQty > 0
          ? _round2(grossTotal / normalizedQty)
          : grossTotal;
    }

    return ReceiptItem(
      id: _uuid.v4(),
      receiptId: receiptId,
      name: name,
      code: code,
      quantity: normalizedQty,
      unit: unit.isNotEmpty ? unit : 'UN',
      unitPrice: unitPrice,
      grossTotal: grossTotal,
      totalPrice: total,
      discount: discount,
      category: ReceiptItemCategorizer.categorize(name),
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<double> _currencyValues(String text) {
    final matches = RegExp(
      r'(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*,\d{2}|\d+\.\d{2})',
    ).allMatches(text);
    return matches
        .map((match) => _parseCurrency(match.group(1)!))
        .where((value) => value > 0)
        .toList();
  }

  double _parseCurrency(String text) {
    var clean = text
        .replaceAll('R\$', '')
        .replaceAll('Vl. Unit.:', '')
        .replaceAll('\u00A0', '')
        .trim();
    clean = clean.replaceAll(' ', '');
    if (clean.contains(',') && clean.contains('.')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    clean = clean.replaceAll(RegExp(r'[^\d\.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  double _parseQuantity(String text) {
    var clean = text
        .replaceAll('Qtde.:', '')
        .replaceAll('Qtd.:', '')
        .replaceAll('\u00A0', '')
        .trim();
    if (clean.contains(',')) {
      clean = clean.replaceAll(',', '.');
    }
    clean = clean.replaceAll(RegExp(r'[^\d\.]'), '');
    return double.tryParse(clean) ?? 1.0;
  }

  String _cleanText(String text) {
    return text.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;

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
        'discount': 1.50,
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
        'discount': 2.00,
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
      final discount = _round2(((data['discount'] as num?) ?? 0).toDouble());
      final grossTotal = _round2(qtd * unitPrice);
      final netTotal = _round2((grossTotal - discount).clamp(0.0, grossTotal));
      return ReceiptItem(
        id: _uuid.v4(),
        receiptId: receiptId,
        name: data['name'] as String,
        code: '789${100000000 + sort}',
        quantity: qtd,
        unit: data['un'] as String,
        unitPrice: unitPrice,
        grossTotal: grossTotal,
        totalPrice: netTotal,
        discount: discount,
        category: data['category'] as String,
        sortOrder: sort++,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();

    final subtotalAmount = _round2(
      items.fold(0.0, (acc, item) => acc + item.grossTotal),
    );
    final itemsNetAmount = _round2(
      items.fold(0.0, (acc, item) => acc + item.totalPrice),
    );
    final itemDiscounts = _round2(
      items.fold(0.0, (acc, item) => acc + item.discount),
    );
    const receiptDiscount = 3.00;
    final totalAmount = _round2(itemsNetAmount - receiptDiscount);
    final totalDiscount = _round2(itemDiscounts + receiptDiscount);

    return Receipt(
      id: receiptId,
      transactionId: '',
      establishmentName: 'Supermercado Condor - Curitiba/PR',
      establishmentCnpj: '76.189.406/0001-40',
      issueDate: now,
      totalAmount: totalAmount,
      subtotalAmount: subtotalAmount,
      totalDiscount: totalDiscount,
      discountAmount: receiptDiscount,
      paymentMethod: PaymentMethods.creditCard,
      accessKey: '41261176189406000140650010001234561001234567',
      rawUrl:
          'http://www.fazenda.pr.gov.br/nfce/qrcode?p=41261176189406000140650010001234561001234567|2|1|1|ABCD',
      createdAt: now,
      updatedAt: now,
      items: items,
    );
  }
}

/// Valores extraídos do rodapé da NFC-e.
class _NfceTotals {
  double? subtotal;
  double? discount;
  double? total;
}
