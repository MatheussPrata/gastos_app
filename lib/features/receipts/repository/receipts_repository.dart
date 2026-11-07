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

  /// Salva ou atualiza o cupom fiscal, seus itens e cria/atualiza a transação macro correspondente.
  Future<({Transaction transaction, Receipt receipt})> saveReceiptWithTransaction({
    required Receipt receipt,
    required String? categoryId,
    required String userId,
  }) async {
    final transactionId = receipt.transactionId.isNotEmpty ? receipt.transactionId : _uuid.v4();
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
      createdAt: receipt.createdAt,
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
      // 1. Insere ou atualiza a transação
      await _db.into(_db.transactions).insertOnConflictUpdate(
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

      // 2. Insere ou atualiza o cupom fiscal
      await _db.into(_db.receipts).insertOnConflictUpdate(
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

      // 3. Remove os itens anteriores para gravar a lista atualizada
      await (_db.delete(_db.receiptItems)
            ..where((t) => t.receiptId.equals(receiptId)))
          .go();

      // 4. Insere todos os itens
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

    final itemsRows = await (_db.select(_db.receiptItems)
          ..where((i) => i.receiptId.equals(row.id))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .get();

    final items = itemsRows
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
      items: items,
      createdAt: row.createdAt,
    );
  }

  /// Busca um cupom fiscal pelo id próprio.
  Future<Receipt?> getReceiptById(String receiptId) async {
    final row = await (_db.select(_db.receipts)
          ..where((r) => r.id.equals(receiptId)))
        .getSingleOrNull();

    if (row == null) return null;

    final itemsRows = await (_db.select(_db.receiptItems)
          ..where((i) => i.receiptId.equals(row.id))
          ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
        .get();

    final items = itemsRows
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
      items: items,
      createdAt: row.createdAt,
    );
  }

  /// Calcula o resumo de gastos por categoria dos itens do cupom.
  static List<ReceiptCategorySummary> getCategorySummaries(Receipt receipt) {
    if (receipt.items.isEmpty) return const [];

    final map = <String, double>{};
    final counts = <String, int>{};
    for (final item in receipt.items) {
      map[item.category] = (map[item.category] ?? 0.0) + item.totalPrice;
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }

    final total = receipt.totalAmount > 0
        ? receipt.totalAmount
        : map.values.fold(0.0, (acc, val) => acc + val);

    return map.entries.map((e) {
      final percentage = total > 0 ? (e.value / total) * 100 : 0.0;
      return ReceiptCategorySummary(
        category: e.key,
        totalAmount: e.value,
        itemCount: counts[e.key] ?? 1,
        percentage: double.parse(percentage.toStringAsFixed(1)),
      );
    }).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }
}
