import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';

final creditCardsRepositoryProvider = Provider<CreditCardsRepository>((ref) {
  return CreditCardsRepository();
});

class CreditCardsRepository {
  final db.AppDatabase _db;
  final SyncService _sync;

  CreditCardsRepository({
    db.AppDatabase? database,
    SyncService? syncService,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService();

  /// Returns all credit cards ordered by sortOrder and name.
  Future<List<CreditCardItem>> getCreditCards({
    bool includeInactive = false,
  }) async {
    final query = _db.select(_db.creditCards)
      ..orderBy([
        (c) => OrderingTerm(expression: c.sortOrder, mode: OrderingMode.asc),
        (c) => OrderingTerm(expression: c.name, mode: OrderingMode.asc),
      ]);

    if (!includeInactive) {
      query.where((c) => c.isActive.equals(true));
    }

    final rows = await query.get();
    return rows.map(CreditCardItem.fromDb).toList();
  }

  /// Get credit card by id.
  Future<CreditCardItem?> getCreditCardById(String id) async {
    final query = _db.select(_db.creditCards)..where((c) => c.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : CreditCardItem.fromDb(row);
  }

  /// Create a new credit card.
  Future<CreditCardItem> createCreditCard(CreditCardItem card) async {
    await _db.into(_db.creditCards).insert(db.CreditCardsCompanion(
          id: Value(card.id),
          name: Value(card.name),
          color: Value(card.color),
          lastFourDigits: Value(card.lastFourDigits),
          brand: Value(card.brand),
          limitAmount: Value(card.limitAmount),
          closingDay: Value(card.closingDay),
          dueDay: Value(card.dueDay),
          isActive: Value(card.isActive),
          sortOrder: Value(card.sortOrder),
          isSynced: const Value(false),
        ));

    unawaited(_sync.push());
    return card;
  }

  /// Update an existing credit card.
  Future<CreditCardItem> updateCreditCard(CreditCardItem card) async {
    await (_db.update(_db.creditCards)..where((c) => c.id.equals(card.id)))
        .write(db.CreditCardsCompanion(
      name: Value(card.name),
      color: Value(card.color),
      lastFourDigits: Value(card.lastFourDigits),
      brand: Value(card.brand),
      limitAmount: Value(card.limitAmount),
      closingDay: Value(card.closingDay),
      dueDay: Value(card.dueDay),
      isActive: Value(card.isActive),
      sortOrder: Value(card.sortOrder),
      isSynced: const Value(false),
    ));

    unawaited(_sync.push());
    return card;
  }

  /// Delete a credit card and remove link from transactions.
  Future<void> deleteCreditCard(String id) async {
    await (_db.delete(_db.creditCards)..where((c) => c.id.equals(id))).go();
    await _sync.tombstone('credit_card', id);
    unawaited(_sync.push());
  }

  /// Total spent on a card for a given reference invoice month.
  /// Uses the card's invoice closing cycle (closingDay(M-1)+1 to closingDay(M)).
  Future<double> getCardSpentForMonth(String cardId, DateTime month) async {
    final card = await getCreditCardById(cardId);
    final DateTime start;
    final DateTime end;
    if (card != null) {
      final range = CreditCardCycleHelper.invoiceDateRange(
        invoiceMonth: month,
        closingDay: card.closingDay,
      );
      start = range.start;
      end = range.end;
    } else {
      start = DateTime(month.year, month.month, 1);
      end = DateTime(month.year, month.month + 1, 1);
    }

    final query = _db.select(_db.transactions)
      ..where((t) =>
          t.creditCardId.equals(cardId) &
          t.isExpense.equals(true) &
          t.date.isBiggerOrEqualValue(start) &
          t.date.isSmallerOrEqualValue(end));

    final rows = await query.get();
    return rows.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Transactions for a given card, optionally filtered by invoice month cycle.
  Future<List<db.Transaction>> getCardTransactions(
    String cardId, {
    DateTime? month,
  }) async {
    final query = _db.select(_db.transactions)
      ..where((t) => t.creditCardId.equals(cardId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc),
      ]);

    if (month != null) {
      final card = await getCreditCardById(cardId);
      final DateTime start;
      final DateTime end;
      if (card != null) {
        final range = CreditCardCycleHelper.invoiceDateRange(
          invoiceMonth: month,
          closingDay: card.closingDay,
        );
        start = range.start;
        end = range.end;
      } else {
        start = DateTime(month.year, month.month, 1);
        end = DateTime(month.year, month.month + 1, 1);
      }
      query.where((t) =>
          t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end));
    }

    return query.get();
  }

  /// Returns all transactions belonging to the invoice cycles of all cards for [month].
  Future<List<db.Transaction>> getAllCardTransactions({
    required DateTime month,
  }) async {
    final cards = await getCreditCards();
    final allTxs = <db.Transaction>[];
    final seenIds = <String>{};

    for (final card in cards) {
      final txs = await getCardTransactions(card.id, month: month);
      for (final tx in txs) {
        if (seenIds.add(tx.id)) {
          allTxs.add(tx);
        }
      }
    }

    // Also include transactions marked as 'Cartão de Crédito' without a cardId
    final calendarStart = DateTime(month.year, month.month, 1);
    final calendarEnd = DateTime(month.year, month.month + 1, 1);
    final unassignedQuery = _db.select(_db.transactions)
      ..where((t) =>
          t.paymentMethod.equals('Cartão de Crédito') &
          t.creditCardId.isNull() &
          t.date.isBiggerOrEqualValue(calendarStart) &
          t.date.isSmallerThanValue(calendarEnd));
    final unassigned = await unassignedQuery.get();
    for (final tx in unassigned) {
      if (seenIds.add(tx.id)) {
        allTxs.add(tx);
      }
    }

    allTxs.sort((a, b) => b.date.compareTo(a.date));
    return allTxs;
  }

  /// Returns the total invoice amount defined by the user for a card and month.
  Future<double> getCardInvoiceAmount(String cardId, DateTime month) async {
    final key = 'card_invoice_${cardId}_${month.year}_${month.month}';
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return 0.0;
    return double.tryParse(row.value) ?? 0.0;
  }

  /// Saves or clears the total invoice amount for a card and month.
  Future<void> setCardInvoiceAmount(
    String cardId,
    DateTime month,
    double amount,
  ) async {
    final key = 'card_invoice_${cardId}_${month.year}_${month.month}';
    if (amount <= 0) {
      await (_db.delete(_db.appSettings)..where((s) => s.key.equals(key))).go();
    } else {
      await _db.into(_db.appSettings).insertOnConflictUpdate(
            db.AppSettingsCompanion(
              key: Value(key),
              value: Value(amount.toString()),
              isSynced: const Value(false),
            ),
          );
    }
    unawaited(_sync.push());
  }

  /// Returns whether the invoice for [cardId] in [month] is marked as paid.
  Future<bool> isInvoicePaid(String cardId, DateTime month) async {
    final key = 'card_invoice_paid_${cardId}_${month.year}_${month.month}';
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value == 'true';
  }

  /// Marks or unmarks an invoice as paid.
  Future<void> setInvoicePaid(
    String cardId,
    DateTime month,
    bool isPaid,
  ) async {
    final key = 'card_invoice_paid_${cardId}_${month.year}_${month.month}';
    if (!isPaid) {
      await (_db.delete(_db.appSettings)..where((s) => s.key.equals(key))).go();
    } else {
      await _db.into(_db.appSettings).insertOnConflictUpdate(
            db.AppSettingsCompanion(
              key: Value(key),
              value: const Value('true'),
              isSynced: const Value(false),
            ),
          );
    }
    unawaited(_sync.push());
  }

  /// Returns a map of {cardId: isPaid} for the given month.
  Future<Map<String, bool>> getAllCardPaidInvoicesForMonth(
    DateTime month,
  ) async {
    final prefix = 'card_invoice_paid_';
    final suffix = '_${month.year}_${month.month}';
    final rows = await _db.select(_db.appSettings).get();

    final result = <String, bool>{};
    for (final row in rows) {
      if (row.key.startsWith(prefix) && row.key.endsWith(suffix)) {
        final cardId = row.key.substring(
          prefix.length,
          row.key.length - suffix.length,
        );
        result[cardId] = row.value == 'true';
      }
    }
    return result;
  }

  /// Returns a map of {cardId: invoiceAmount} for the given month.
  Future<Map<String, double>> getAllCardInvoicesForMonth(DateTime month) async {
    final prefix = 'card_invoice_';
    final suffix = '_${month.year}_${month.month}';
    final rows = await _db.select(_db.appSettings).get();

    final result = <String, double>{};
    for (final row in rows) {
      if (row.key.startsWith(prefix) &&
          !row.key.startsWith('card_invoice_paid_') &&
          row.key.endsWith(suffix)) {
        final cardId = row.key.substring(
          prefix.length,
          row.key.length - suffix.length,
        );
        final val = double.tryParse(row.value) ?? 0.0;
        if (val > 0) {
          result[cardId] = val;
        }
      }
    }
    return result;
  }

  /// Spending grouped by category for a specific card or all cards in [month].
  /// Includes difference in 'nao_informada' if manual invoice > launched spent.
  Future<Map<String, double>> getCardSpentByCategory({
    String? cardId,
    required DateTime month,
  }) async {
    final totals = <String, double>{};

    if (cardId != null) {
      final txs = await getCardTransactions(cardId, month: month);
      var spent = 0.0;
      for (final tx in txs) {
        if (tx.isExpense) {
          final cat = tx.categoryId ?? 'none';
          totals[cat] = (totals[cat] ?? 0.0) + tx.amount;
          spent += tx.amount;
        }
      }
      final invoice = await getCardInvoiceAmount(cardId, month);
      if (invoice > spent) {
        final diff = invoice - spent;
        totals['nao_informada'] = (totals['nao_informada'] ?? 0.0) + diff;
      }
    } else {
      final cards = await getCreditCards();
      final invoiceMap = await getAllCardInvoicesForMonth(month);

      for (final card in cards) {
        final txs = await getCardTransactions(card.id, month: month);
        var cardSpent = 0.0;
        for (final tx in txs) {
          if (tx.isExpense) {
            final cat = tx.categoryId ?? 'none';
            totals[cat] = (totals[cat] ?? 0.0) + tx.amount;
            cardSpent += tx.amount;
          }
        }
        final invoice = invoiceMap[card.id] ?? 0.0;
        if (invoice > cardSpent) {
          final diff = invoice - cardSpent;
          totals['nao_informada'] = (totals['nao_informada'] ?? 0.0) + diff;
        }
      }

      // Add unassigned credit card transactions
      final calendarStart = DateTime(month.year, month.month, 1);
      final calendarEnd = DateTime(month.year, month.month + 1, 1);
      final unassignedQuery = _db.select(_db.transactions)
        ..where((t) =>
            t.paymentMethod.equals('Cartão de Crédito') &
            t.creditCardId.isNull() &
            t.isExpense.equals(true) &
            t.date.isBiggerOrEqualValue(calendarStart) &
            t.date.isSmallerThanValue(calendarEnd));
      final unassigned = await unassignedQuery.get();
      for (final tx in unassigned) {
        final cat = tx.categoryId ?? 'none';
        totals[cat] = (totals[cat] ?? 0.0) + tx.amount;
      }
    }

    return totals;
  }

  /// Forecast of invoices across [numberOfMonths] starting from [startMonth].
  Future<List<InvoiceForecast>> getFutureInvoicesForecast({
    String? cardId,
    required DateTime startMonth,
    int numberOfMonths = 6,
  }) async {
    final list = <InvoiceForecast>[];

    for (var i = 0; i < numberOfMonths; i++) {
      final m = DateTime(startMonth.year, startMonth.month + i, 1);
      double spent = 0.0;
      double invoiceTotal = 0.0;
      bool isPaid = false;
      int count = 0;

      if (cardId != null) {
        spent = await getCardSpentForMonth(cardId, m);
        invoiceTotal = await getCardInvoiceAmount(cardId, m);
        isPaid = await isInvoicePaid(cardId, m);
        final txs = await getCardTransactions(cardId, month: m);
        count = txs.length;
      } else {
        final cards = await getCreditCards();
        final invoices = await getAllCardInvoicesForMonth(m);
        final paids = await getAllCardPaidInvoicesForMonth(m);
        final allTxs = await getAllCardTransactions(month: m);
        count = allTxs.length;

        for (final c in cards) {
          spent += await getCardSpentForMonth(c.id, m);
          invoiceTotal += invoices[c.id] ?? 0.0;
        }
        isPaid = cards.isNotEmpty && cards.every((c) => paids[c.id] == true);
      }

      list.add(InvoiceForecast(
        month: m,
        spent: spent,
        invoiceTotal: invoiceTotal,
        isPaid: isPaid,
        transactionCount: count,
      ));
    }

    return list;
  }
}
