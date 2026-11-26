import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';
import 'package:gastos_app/features/home_widgets/services/home_widget_service.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';

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

  /// Salva ou atualiza o cupom fiscal, seus itens e cria/atualiza a transação (ou parcelas) correspondente.
  Future<({Transaction transaction, Receipt receipt})> saveReceiptWithTransaction({
    required Receipt receipt,
    required String? categoryId,
    required String userId,
    String? creditCardId,
    bool isInstallment = false,
    int totalInstallments = 1,
  }) async {
    final transactionId = receipt.transactionId.isNotEmpty ? receipt.transactionId : _uuid.v4();
    final receiptId = receipt.id.isNotEmpty ? receipt.id : _uuid.v4();
    final now = DateTime.now();

    final finalGross = receipt.items.fold(
      0.0,
      (acc, item) => acc + item.effectiveGrossTotal,
    );
    final finalSubtotal = receipt.subtotalAmount > 0.005
        ? receipt.subtotalAmount
        : (finalGross > 0.005
            ? finalGross
            : receipt.totalAmount + receipt.discountAmount);
    final finalTotalDiscount = receipt.totalDiscount > 0.005
        ? receipt.totalDiscount
        : (finalSubtotal > receipt.totalAmount
            ? _roundToCents(finalSubtotal - receipt.totalAmount)
            : receipt.discountAmount);

    final finalReceipt = receipt.copyWith(
      id: receiptId,
      transactionId: transactionId,
      subtotalAmount: finalSubtotal,
      totalDiscount: finalTotalDiscount < 0.005 ? 0.0 : finalTotalDiscount,
      updatedAt: now,
      isSynced: false,
      items: [
        for (var i = 0; i < receipt.items.length; i++)
          () {
            final item = receipt.items[i];
            return item.copyWith(
              id: item.id.isNotEmpty ? item.id : _uuid.v4(),
              receiptId: receiptId,
              grossTotal: item.effectiveGrossTotal,
              sortOrder: i,
              createdAt: item.createdAt ?? now,
              updatedAt: now,
              isSynced: false,
            );
          }(),
      ],
    );

    late Transaction firstTxModel;
    final removedTxIds = <String>[];
    final writtenTxs = <Transaction>[];

    await _db.transaction(() async {
      final existingLinked = await (_db.select(_db.transactions)
            ..where(
              (t) => t.receiptId.equals(receiptId) | t.id.equals(transactionId),
            ))
          .get();
      final existingByInstallment = <int, db.Transaction>{
        for (final row in existingLinked) row.installmentNumber: row,
      };
      final existingPrimary = existingLinked
          .where((row) => row.id == transactionId)
          .firstOrNull;
      final keptTxIds = <String>{};

      // 1. Cria transação única ou parcelas
      if (isInstallment && totalInstallments > 1) {
        final groupId = existingLinked
                .map((row) => row.installmentGroupId)
                .whereType<String>()
                .where((g) => g.isNotEmpty)
                .firstOrNull ??
            _uuid.v4();
        final perInstallment =
            _roundToCents(receipt.totalAmount / totalInstallments);

        int? closingDay;
        if (creditCardId != null && creditCardId.isNotEmpty) {
          final cardRow = await (_db.select(_db.creditCards)
                ..where((c) => c.id.equals(creditCardId)))
              .getSingleOrNull();
          if (cardRow != null) closingDay = cardRow.closingDay;
        }

        for (var i = 1; i <= totalInstallments; i++) {
          final DateTime installmentDate;
          if (closingDay != null) {
            installmentDate = CreditCardCycleHelper.installmentDateForCycle(
              baseDate: receipt.issueDate,
              installmentIndex: i - 1,
              closingDay: closingDay,
            );
          } else {
            installmentDate = _addMonths(receipt.issueDate, i - 1);
          }

          final prevRow = i == 1
              ? (existingPrimary ?? existingByInstallment[1])
              : existingByInstallment[i];
          final thisTxId =
              i == 1 ? transactionId : (prevRow?.id ?? _uuid.v4());
          keptTxIds.add(thisTxId);

          final amount = i == totalInstallments
              ? _roundToCents(
                  receipt.totalAmount - perInstallment * (totalInstallments - 1))
              : perInstallment;

          final tx = Transaction(
            id: thisTxId,
            userId: userId,
            amount: amount,
            description: '${receipt.establishmentName} ($i/$totalInstallments)',
            date: installmentDate,
            categoryId: categoryId,
            creditCardId: creditCardId,
            paymentMethod: receipt.paymentMethod,
            isExpense: true,
            isInstallment: true,
            installmentNumber: i,
            totalInstallments: totalInstallments,
            installmentGroupId: groupId,
            notes: prevRow?.notes ?? 'Cupom fiscal NFC-e PR',
            reminderEnabled: prevRow?.reminderEnabled ?? false,
            receiptId: receiptId,
            createdAt: prevRow?.createdAt ?? receipt.createdAt,
            updatedAt: now,
          );

          if (i == 1) {
            firstTxModel = tx;
          }
          writtenTxs.add(tx);

          await _db.into(_db.transactions).insertOnConflictUpdate(
                db.TransactionsCompanion(
                  id: Value(tx.id),
                  userId: Value(tx.userId),
                  amount: Value(tx.amount),
                  description: Value(tx.description),
                  date: Value(tx.date),
                  categoryId: Value(tx.categoryId),
                  creditCardId: Value(tx.creditCardId),
                  paymentMethod: Value(tx.paymentMethod),
                  isExpense: const Value(true),
                  isInstallment: const Value(true),
                  installmentNumber: Value(tx.installmentNumber),
                  totalInstallments: Value(tx.totalInstallments),
                  installmentGroupId: Value(tx.installmentGroupId),
                  notes: Value(tx.notes),
                  reminderEnabled: Value(tx.reminderEnabled),
                  receiptId: Value(receiptId),
                  createdAt: Value(tx.createdAt),
                  updatedAt: Value(tx.updatedAt),
                  isSynced: const Value(false),
                ),
              );
        }
      } else {
        keptTxIds.add(transactionId);
        firstTxModel = Transaction(
          id: transactionId,
          userId: userId,
          amount: receipt.totalAmount,
          description: receipt.establishmentName,
          date: receipt.issueDate,
          categoryId: categoryId,
          creditCardId: creditCardId,
          paymentMethod: receipt.paymentMethod,
          isExpense: true,
          isInstallment: false,
          installmentNumber: 1,
          totalInstallments: 1,
          installmentGroupId: null,
          notes: existingPrimary?.notes ?? 'Cupom fiscal NFC-e PR',
          reminderEnabled: existingPrimary?.reminderEnabled ?? false,
          receiptId: receiptId,
          createdAt: existingPrimary?.createdAt ?? receipt.createdAt,
          updatedAt: now,
        );
        writtenTxs.add(firstTxModel);

        await _db.into(_db.transactions).insertOnConflictUpdate(
              db.TransactionsCompanion(
                id: Value(firstTxModel.id),
                userId: Value(firstTxModel.userId),
                amount: Value(firstTxModel.amount),
                description: Value(firstTxModel.description),
                date: Value(firstTxModel.date),
                categoryId: Value(firstTxModel.categoryId),
                creditCardId: Value(firstTxModel.creditCardId),
                paymentMethod: Value(firstTxModel.paymentMethod),
                isExpense: const Value(true),
                isInstallment: const Value(false),
                installmentNumber: const Value(1),
                totalInstallments: const Value(1),
                installmentGroupId: const Value(null),
                notes: Value(firstTxModel.notes),
                reminderEnabled: Value(firstTxModel.reminderEnabled),
                receiptId: Value(receiptId),
                createdAt: Value(firstTxModel.createdAt),
                updatedAt: Value(firstTxModel.updatedAt),
                isSynced: const Value(false),
              ),
            );
      }

      // Remove parcelas antigas excedentes caso o utilizador tenha reduzido ou desfeito o parcelamento
      for (final oldRow in existingLinked) {
        if (!keptTxIds.contains(oldRow.id)) {
          await (_db.delete(_db.transactions)
                ..where((t) => t.id.equals(oldRow.id)))
              .go();
          removedTxIds.add(oldRow.id);
        }
      }

      // 2. Insere ou atualiza o cupom fiscal
      await _db.into(_db.receipts).insertOnConflictUpdate(
            db.ReceiptsCompanion(
              id: Value(finalReceipt.id),
              transactionId: Value(firstTxModel.id),
              establishmentName: Value(finalReceipt.establishmentName),
              establishmentCnpj: Value(finalReceipt.establishmentCnpj),
              issueDate: Value(finalReceipt.issueDate),
              totalAmount: Value(finalReceipt.totalAmount),
              subtotalAmount: Value(finalReceipt.subtotalAmount),
              totalDiscount: Value(finalReceipt.totalDiscount),
              discountAmount: Value(finalReceipt.discountAmount),
              paymentMethod: Value(finalReceipt.paymentMethod),
              accessKey: Value(finalReceipt.accessKey),
              rawUrl: Value(finalReceipt.rawUrl),
              createdAt: Value(finalReceipt.createdAt),
              updatedAt: Value(finalReceipt.updatedAt ?? now),
              isSynced: const Value(false),
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
                grossTotal: Value(item.grossTotal),
                totalPrice: Value(item.totalPrice),
                discount: Value(item.discount),
                category: Value(item.category),
                sortOrder: Value(item.sortOrder),
                createdAt: Value(item.createdAt ?? now),
                updatedAt: Value(item.updatedAt ?? now),
                isSynced: const Value(false),
              ),
            );
      }
    });

    for (final oldId in removedTxIds) {
      unawaited(TransactionReminderService.instance.cancel(oldId));
      try {
        await _sync?.tombstone('transaction', oldId);
      } catch (_) {}
    }

    for (final tx in writtenTxs) {
      if (tx.reminderEnabled) {
        unawaited(
          TransactionReminderService.instance.schedule(
            transactionId: tx.id,
            description: tx.description,
            amount: tx.amount,
            isExpense: true,
            dueDate: tx.date,
            enabled: true,
            now: now,
            allowSameDayFallback: true,
          ),
        );
      }
    }

    // Envia sincronização se online
    try {
      unawaited(_sync?.push());
    } catch (_) {}
    HomeWidgetService.instance.scheduleSync();

    return (transaction: firstTxModel, receipt: finalReceipt);
  }

  DateTime _addMonths(DateTime date, int months) {
    final year = date.year + ((date.month + months - 1) ~/ 12);
    final month = ((date.month + months - 1) % 12) + 1;
    final maxDays = DateTime(year, month + 1, 0).day;
    final day = date.day > maxDays ? maxDays : date.day;
    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }

  double _roundToCents(double value) => (value * 100).roundToDouble() / 100;

  /// Busca um cupom fiscal pelo id da transação associada.
  Future<Receipt?> getReceiptByTransactionId(String transactionId) async {
    var row = await (_db.select(_db.receipts)
          ..where((r) => r.transactionId.equals(transactionId)))
        .getSingleOrNull();

    if (row == null) {
      final tx = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (tx?.receiptId != null && tx!.receiptId!.isNotEmpty) {
        row = await (_db.select(_db.receipts)
              ..where((r) => r.id.equals(tx.receiptId!)))
            .getSingleOrNull();
      }
    }

    final receiptRow = row;
    if (receiptRow == null) return null;

    // Auto-repara o vinculo na transacao caso estivesse ausente.
    try {
      final tx = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(transactionId)))
          .getSingleOrNull();
      if (tx != null && (tx.receiptId == null || tx.receiptId!.isEmpty)) {
        await (_db.update(_db.transactions)
              ..where((t) => t.id.equals(transactionId)))
            .write(
          db.TransactionsCompanion(
            receiptId: Value(receiptRow.id),
            isSynced: const Value(false),
          ),
        );
      }
    } catch (_) {}

    final itemsRows = await (_db.select(_db.receiptItems)
          ..where((i) => i.receiptId.equals(receiptRow.id))
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
            grossTotal: i.grossTotal > 0 ? i.grossTotal : i.totalPrice + i.discount,
            totalPrice: i.totalPrice,
            discount: i.discount,
            category: i.category,
            sortOrder: i.sortOrder,
            createdAt: i.createdAt,
            updatedAt: i.updatedAt,
            isSynced: i.isSynced,
          ),
        )
        .toList();

    return Receipt(
      id: receiptRow.id,
      transactionId: receiptRow.transactionId,
      establishmentName: receiptRow.establishmentName,
      establishmentCnpj: receiptRow.establishmentCnpj,
      issueDate: receiptRow.issueDate,
      totalAmount: receiptRow.totalAmount,
      subtotalAmount: receiptRow.subtotalAmount,
      totalDiscount: receiptRow.totalDiscount,
      discountAmount: receiptRow.discountAmount,
      paymentMethod: receiptRow.paymentMethod,
      accessKey: receiptRow.accessKey,
      rawUrl: receiptRow.rawUrl,
      items: items,
      createdAt: receiptRow.createdAt,
      updatedAt: receiptRow.updatedAt,
      isSynced: receiptRow.isSynced,
    );
  }

  /// Busca um cupom fiscal pelo id próprio.
  Future<Receipt?> getReceiptById(String receiptId) async {
    final row = await (_db.select(_db.receipts)
          ..where((r) => r.id.equals(receiptId)))
        .getSingleOrNull();

    final receiptRow = row;
    if (receiptRow == null) return null;

    final itemsRows = await (_db.select(_db.receiptItems)
          ..where((i) => i.receiptId.equals(receiptRow.id))
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
            grossTotal: i.grossTotal > 0 ? i.grossTotal : i.totalPrice + i.discount,
            totalPrice: i.totalPrice,
            discount: i.discount,
            category: i.category,
            sortOrder: i.sortOrder,
            createdAt: i.createdAt,
            updatedAt: i.updatedAt,
            isSynced: i.isSynced,
          ),
        )
        .toList();

    return Receipt(
      id: receiptRow.id,
      transactionId: receiptRow.transactionId,
      establishmentName: receiptRow.establishmentName,
      establishmentCnpj: receiptRow.establishmentCnpj,
      issueDate: receiptRow.issueDate,
      totalAmount: receiptRow.totalAmount,
      subtotalAmount: receiptRow.subtotalAmount,
      totalDiscount: receiptRow.totalDiscount,
      discountAmount: receiptRow.discountAmount,
      paymentMethod: receiptRow.paymentMethod,
      accessKey: receiptRow.accessKey,
      rawUrl: receiptRow.rawUrl,
      items: items,
      createdAt: receiptRow.createdAt,
      updatedAt: receiptRow.updatedAt,
      isSynced: receiptRow.isSynced,
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
