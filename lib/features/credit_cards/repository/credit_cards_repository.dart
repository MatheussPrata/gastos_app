import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';

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

  /// Total spent on a card for a given reference month.
  Future<double> getCardSpentForMonth(String cardId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final query = _db.select(_db.transactions)
      ..where((t) =>
          t.creditCardId.equals(cardId) &
          t.isExpense.equals(true) &
          t.date.isBiggerOrEqualValue(start) &
          t.date.isSmallerThanValue(end));

    final rows = await query.get();
    return rows.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  /// Transactions for a given card, optionally filtered by month.
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
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 1);
      query.where((t) =>
          t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end));
    }

    return query.get();
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

  /// Returns a map of {cardId: invoiceAmount} for the given month.
  Future<Map<String, double>> getAllCardInvoicesForMonth(DateTime month) async {
    final prefix = 'card_invoice_';
    final suffix = '_${month.year}_${month.month}';
    final rows = await _db.select(_db.appSettings).get();

    final result = <String, double>{};
    for (final row in rows) {
      if (row.key.startsWith(prefix) && row.key.endsWith(suffix)) {
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
}
