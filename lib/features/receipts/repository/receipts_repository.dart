import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

final receiptsRepositoryProvider = Provider<ReceiptsRepository>((ref) {
  return ReceiptsRepository(syncService: SyncService());
});

class ReceiptsRepository {
  final db.AppDatabase _db;
  final Uuid _uuid;
  final SyncService? _sync;

  ReceiptsRepository({
    db.AppDatabase? database,
    SyncService? syncService,
    Uuid? uuid,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService,
        _uuid = uuid ?? const Uuid();

  /// Salva o cupom fiscal, seus itens e cria a transação macro correspondente.
  Future<({Transaction transaction, Receipt receipt})> saveReceiptWithTransaction({
    required Receipt receipt,
    required String? categoryId,
    required String userId,
  }) async {
    final transactionId = _uuid.v4();
    final receiptId = receipt.id.isNotEmpty ? receipt.id : _uuid.v4();
    final now = DateTime.now();

    final txModel = Transaction(
      id: transactionId,
      userId: userId,
      amount: receipt.totalAmount,
      description: receipt.establishmentName,
      date: receipt.issueDate,
      categoryId: categoryId,
      paymentMethod: receipt.paymentMethod,
      isExpense: true,
      notes: 'Cupom fiscal NFC-e PR',
      receiptId: receiptId,
      createdAt: now,
      updatedAt: now,
    );

    final finalReceipt = receipt.copyWith(
      id: receiptId,
      transactionId: transactionId,
      items: [
        for (var i = 0; i < receipt.items.length; i++)
          receipt.items[i].copyWith(
            id: receipt.items[i].id.isNotEmpty
                ? receipt.items[i].id
                : _uuid.v4(),
            receiptId: receiptId,
            sortOrder: i,
          ),
      ],
    );

    await _db.transaction(() async {
      // 1. Insere a transação
      await _db.into(_db.transactions).insert(
            db.TransactionsCompanion(
              id: Value(txModel.id),
              userId: Value(txModel.userId),
              amount: Value(txModel.amount),
              description: Value(txModel.description),
              date: Value(txModel.date),
              categoryId: Value(txModel.categoryId),
              paymentMethod: Value(txModel.paymentMethod),
              isExpense: const Value(true),
              notes: Value(txModel.notes),
              receiptId: Value(receiptId),
              createdAt: Value(txModel.createdAt),
              updatedAt: Value(txModel.updatedAt),
              isSynced: const Value(false),
            ),
          );

      // 2. Insere o cupom fiscal
      await _db.into(_db.receipts).insert(
            db.ReceiptsCompanion(
              id: Value(finalReceipt.id),
              transactionId: Value(transactionId),
              establishmentName: Value(finalReceipt.establishmentName),
              establishmentCnpj: Value(finalReceipt.establishmentCnpj),
              issueDate: Value(finalReceipt.issueDate),
              totalAmount: Value(finalReceipt.totalAmount),
              paymentMethod: Value(finalReceipt.paymentMethod),
              accessKey: Value(finalReceipt.accessKey),
              rawUrl: Value(finalReceipt.rawUrl),
              createdAt: Value(finalReceipt.createdAt),
            ),
          );

      // 3. Insere todos os itens
      for (final item in finalReceipt.items) {
        await _db.into(_db.receiptItems).insert(
              db.ReceiptItemsCompanion(
                id: Value(item.id),
                receiptId: Value(receiptId),
                name: Value(item.name),
                code: Value(item.code),
                quantity: Value(item.quantity),
                unit: Value(item.unit),
                unitPrice: Value(item.unitPrice),
                totalPrice: Value(item.totalPrice),
                category: Value(item.category),
                sortOrder: Value(item.sortOrder),
              ),
            );
      }
    });

    // Envia sincronização se online
    try {
      _sync?.push();
    } catch (_) {}

    return (transaction: txModel, receipt: finalReceipt);
  }

  /// Busca um cupom fiscal pelo id da transação associada.
  Future<Receipt?> getReceiptByTransactionId(String transactionId) async {
    final row = await (_db.select(_db.receipts)
          ..where((r) => r.transactionId.equals(transactionId)))
        .getSingleOrNull();

    if (row == null) return null;

    final itemRows = await (_db.select(_db.receiptItems)
          ..where((i) => i.receiptId.equals(row.id))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .get();

    final items = itemRows
        .map(
          (i) => ReceiptItem(
            id: i.id,
            receiptId: i.receiptId,
            name: i.name,
            code: i.code,
            quantity: i.quantity,
            unit: i.unit,
            unitPrice: i.unitPrice,
            totalPrice: i.totalPrice,
            category: i.category,
            sortOrder: i.sortOrder,
          ),
        )
        .toList();

    return Receipt(
      id: row.id,
      transactionId: row.transactionId,
      establishmentName: row.establishmentName,
      establishmentCnpj: row.establishmentCnpj,
      issueDate: row.issueDate,
      totalAmount: row.totalAmount,
      paymentMethod: row.paymentMethod,
      accessKey: row.accessKey,
      rawUrl: row.rawUrl,
      createdAt: row.createdAt,
      items: items,
    );
  }

  /// Busca um cupom fiscal pelo seu id direto.
  Future<Receipt?> getReceiptById(String receiptId) async {
    final row = await (_db.select(_db.receipts)
          ..where((r) => r.id.equals(receiptId)))
        .getSingleOrNull();

    if (row == null) return null;

    final itemRows = await (_db.select(_db.receiptItems)
          ..where((i) => i.receiptId.equals(row.id))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .get();

    final items = itemRows
        .map(
          (i) => ReceiptItem(
            id: i.id,
            receiptId: i.receiptId,
            name: i.name,
            code: i.code,
            quantity: i.quantity,
            unit: i.unit,
            unitPrice: i.unitPrice,
            totalPrice: i.totalPrice,
            category: i.category,
            sortOrder: i.sortOrder,
          ),
        )
        .toList();

    return Receipt(
      id: row.id,
      transactionId: row.transactionId,
      establishmentName: row.establishmentName,
      establishmentCnpj: row.establishmentCnpj,
      issueDate: row.issueDate,
      totalAmount: row.totalAmount,
      paymentMethod: row.paymentMethod,
      accessKey: row.accessKey,
      rawUrl: row.rawUrl,
      createdAt: row.createdAt,
      items: items,
    );
  }

  /// Agrupa os itens da compra por categoria calculando subtotais e percentuais.
  static List<ReceiptCategorySummary> getCategorySummaries(Receipt receipt) {
    if (receipt.items.isEmpty) return const [];

    final map = <String, double>{};
    final countMap = <String, int>{};
    var total = 0.0;

    for (final item in receipt.items) {
      map[item.category] = (map[item.category] ?? 0.0) + item.totalPrice;
      countMap[item.category] = (countMap[item.category] ?? 0) + 1;
      total += item.totalPrice;
    }

    if (total == 0) total = receipt.totalAmount;

    final summaries = map.entries.map((entry) {
      final category = entry.key;
      final amount = (entry.value * 100).roundToDouble() / 100;
      final count = countMap[category] ?? 0;
      final pct = total > 0 ? (amount / total) * 100 : 0.0;
      return ReceiptCategorySummary(
        category: category,
        totalAmount: amount,
        itemCount: count,
        percentage: (pct * 10).roundToDouble() / 10,
      );
    }).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return summaries;
  }
}
