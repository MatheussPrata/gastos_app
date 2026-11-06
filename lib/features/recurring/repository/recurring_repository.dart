import 'dart:async';

import 'package:drift/drift.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/recurring/models/recurring_models.dart';

class RecurringRepository {
  final db.AppDatabase _db;
  final SyncService _sync;

  RecurringRepository({
    db.AppDatabase? database,
    SyncService? syncService,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService();

  Future<List<RecurringTransaction>> getRecurring(
      {bool forceRefresh = false}) async {
    final localResults = await _db.select(_db.recurringTransactions).get();

    final recurring = localResults.map(_toModel).toList();

    if (forceRefresh) {
      _syncWithServer();
    }

    return recurring;
  }

  Future<RecurringTransaction?> getRecurringById(String id) async {
    final row = await (_db.select(_db.recurringTransactions)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  RecurringTransaction _toModel(db.RecurringTransaction r) {
    return RecurringTransaction(
      id: r.id,
      userId: r.userId,
      description: r.description,
      amount: r.amount,
      type: r.type,
      categoryId: r.categoryId,
      subcategoryId: r.subcategoryId,
      creditCardId: r.creditCardId,
      frequency: r.frequency,
      dayOfMonth: r.dayOfMonth,
      startDate: r.startDate,
      endDate: r.endDate,
      isActive: r.isActive,
      nextDueDate: r.nextDueDate,
      lastGeneratedAt: r.lastGeneratedAt,
      createdAt: r.createdAt,
    );
  }

  Future<RecurringTransaction> createRecurring(
      RecurringTransaction recurring) async {
    await _db
        .into(_db.recurringTransactions)
        .insert(db.RecurringTransactionsCompanion(
          id: Value(recurring.id),
          userId: Value(recurring.userId),
          description: Value(recurring.description),
          amount: Value(recurring.amount),
          type: Value(recurring.type),
          categoryId: Value(recurring.categoryId),
          subcategoryId: Value(recurring.subcategoryId),
          creditCardId: Value(recurring.creditCardId),
          frequency: Value(recurring.frequency),
          dayOfMonth: Value(recurring.dayOfMonth),
          startDate: Value(recurring.startDate),
          endDate: Value(recurring.endDate),
          isActive: Value(recurring.isActive),
          nextDueDate: Value(recurring.nextDueDate),
          lastGeneratedAt: Value(recurring.lastGeneratedAt),
          createdAt: Value(recurring.createdAt),
          isSynced: const Value(false),
        ));

    unawaited(_sync.push());
    return recurring;
  }

  Future<RecurringTransaction> updateRecurring(
      RecurringTransaction recurring) async {
    await _db
        .update(_db.recurringTransactions)
        .replace(db.RecurringTransactionsCompanion(
          id: Value(recurring.id),
          userId: Value(recurring.userId),
          description: Value(recurring.description),
          amount: Value(recurring.amount),
          type: Value(recurring.type),
          categoryId: Value(recurring.categoryId),
          subcategoryId: Value(recurring.subcategoryId),
          creditCardId: Value(recurring.creditCardId),
          frequency: Value(recurring.frequency),
          dayOfMonth: Value(recurring.dayOfMonth),
          startDate: Value(recurring.startDate),
          endDate: Value(recurring.endDate),
          isActive: Value(recurring.isActive),
          nextDueDate: Value(recurring.nextDueDate),
          lastGeneratedAt: Value(recurring.lastGeneratedAt),
          createdAt: Value(recurring.createdAt),
          isSynced: const Value(false),
        ));

    unawaited(_sync.push());
    return recurring;
  }

  Future<void> deleteRecurring(String id) async {
    await (_db.delete(_db.recurringTransactions)..where((r) => r.id.equals(id)))
        .go();
    await _sync.tombstone('recurring', id);
    unawaited(_sync.push());
  }

  /// A base local e a fonte da verdade; envio e restauracao passam pelo
  /// [SyncService].
  Future<void> _syncWithServer() async {
    await _sync.push();
  }
}
