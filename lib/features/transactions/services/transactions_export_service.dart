import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gastos_app/features/categories/models/category_models.dart' as cat;
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

/// Monta o conteúdo CSV (separador `;`, compatível com Excel pt-BR) das transações.
String buildTransactionsCsv({
  required List<Transaction> transactions,
  required List<cat.Category> categories,
  List<CreditCardItem> creditCards = const [],
}) {
  final categoryNames = {for (final c in categories) c.id: c.name};
  final cardNames = {for (final c in creditCards) c.id: c.name};
  final buffer = StringBuffer()
    ..writeln(
      'Data;Descrição;Tipo;Valor;Categoria;Cartão;Forma de pagamento;Observações',
    );

  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
  for (final t in sorted) {
    final tipo = t.isExpense ? 'Saída' : 'Entrada';
    final categoria = categoryNames[t.categoryId] ??
        (t.categoryId == null ? 'Sem categoria' : 'Desconhecida');
    final cardId = t.creditCardId;
    final cartao = (cardId == null || cardId.isEmpty)
        ? ''
        : (cardNames[cardId] ?? 'Cartão removido');
    buffer.writeln(
      [
        _formatDate(t.date),
        _escape(t.description),
        tipo,
        t.amount.toStringAsFixed(2).replaceAll('.', ','),
        _escape(categoria),
        _escape(cartao),
        _escape(t.paymentMethod),
        _escape(t.notes ?? ''),
      ].join(';'),
    );
  }

  return buffer.toString();
}

/// Gera um CSV (separador `;`, compatível com Excel pt-BR) das transações
/// informadas e abre o compartilhamento do aparelho.
Future<void> exportTransactionsCsv({
  required List<Transaction> transactions,
  required List<cat.Category> categories,
  List<CreditCardItem> creditCards = const [],
}) async {
  final csv = buildTransactionsCsv(
    transactions: transactions,
    categories: categories,
    creditCards: creditCards,
  );

  final dir = await getTemporaryDirectory();
  final today = DateTime.now().toIso8601String().split('T').first;
  final fileName = 'kuanto-transacoes-$today.csv';
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csv, encoding: utf8);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Transações Kuanto',
    text: 'Exportação de transações do Kuanto',
    fileNameOverrides: [fileName],
  );
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

String _escape(String value) {
  if (!value.contains(';') &&
      !value.contains('"') &&
      !value.contains('\n') &&
      !value.contains('\r')) {
    return value;
  }
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
