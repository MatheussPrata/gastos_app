import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gastos_app/features/categories/models/category_models.dart' as cat;
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

/// Gera um CSV (separador `;`, compatível com Excel pt-BR) das transações
/// informadas e abre o compartilhamento do aparelho.
Future<void> exportTransactionsCsv({
  required List<Transaction> transactions,
  required List<cat.Category> categories,
}) async {
  final categoryNames = {for (final c in categories) c.id: c.name};
  final buffer = StringBuffer()
    ..writeln(
      'Data;Descrição;Tipo;Valor;Categoria;Cartão;Forma de pagamento;Observações',
    );

  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
  for (final t in sorted) {
    final tipo = t.isExpense ? 'Saída' : 'Entrada';
    final categoria = categoryNames[t.categoryId] ??
        (t.categoryId == null ? 'Sem categoria' : 'Desconhecida');
    buffer.writeln(
      [
        _formatDate(t.date),
        _escape(t.description),
        tipo,
        t.amount.toStringAsFixed(2).replaceAll('.', ','),
        _escape(categoria),
        _escape(t.creditCardId ?? ''),
        _escape(t.paymentMethod),
        _escape(t.notes ?? ''),
      ].join(';'),
    );
  }

  final dir = await getTemporaryDirectory();
  final today = DateTime.now().toIso8601String().split('T').first;
  final fileName = 'kuanto-transacoes-$today.csv';
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(buffer.toString(), encoding: utf8);

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
