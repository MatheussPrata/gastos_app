import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository();
});

class TransactionsRepository {
  final db.AppDatabase _db;
  final Uuid _uuid;
  final SyncService _sync;

  TransactionsRepository({
    db.AppDatabase? database,
    SyncService? syncService,
    Uuid? uuid,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService(),
        _uuid = uuid ?? const Uuid();

  // ---------------------------------------------------------------- mapping

  Transaction _toModel(db.Transaction t) => Transaction(
        id: t.id,
        userId: t.userId,
        amount: t.amount,
        description: t.description,
        date: t.date,
        categoryId: t.categoryId,
        subcategoryId: t.subcategoryId,
        creditCardId: t.creditCardId,
        paymentMethod: t.paymentMethod,
        isExpense: t.isExpense,
        isInstallment: t.isInstallment,
        installmentNumber: t.installmentNumber,
        totalInstallments: t.totalInstallments,
        installmentGroupId: t.installmentGroupId,
        notes: t.notes,
        ownerId: t.ownerId,
        partnerSynced: t.partnerSynced,
        isSynced: t.isSynced,
        reminderAt: t.reminderAt,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      );

  db.TransactionsCompanion _toCompanion(Transaction t, {required bool synced}) {
    return db.TransactionsCompanion(
      id: Value(t.id),
      userId: Value(t.userId),
      amount: Value(t.amount),
      description: Value(t.description),
      date: Value(t.date),
      categoryId: Value(t.categoryId),
      subcategoryId: Value(t.subcategoryId),
      creditCardId: Value(t.creditCardId),
      paymentMethod: Value(t.paymentMethod),
      isExpense: Value(t.isExpense),
      isInstallment: Value(t.isInstallment),
      installmentNumber: Value(t.installmentNumber),
      totalInstallments: Value(t.totalInstallments),
      installmentGroupId: Value(t.installmentGroupId),
      notes: Value(t.notes),
      ownerId: Value(t.ownerId),
      partnerSynced: Value(t.partnerSynced),
      reminderAt: Value(t.reminderAt),
      createdAt: Value(t.createdAt),
      updatedAt: Value(t.updatedAt),
      isSynced: Value(synced),
    );
  }

  // ------------------------------------------------------------------ reads

  Future<List<Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? creditCardId,
    bool? isExpense,
    int limit = 1000,
    int offset = 0,
  }) async {
    final query = _db.select(_db.transactions);

    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }
    if (creditCardId != null) {
      query.where((t) => t.creditCardId.equals(creditCardId));
    }
    if (isExpense != null) {
      query.where((t) => t.isExpense.equals(isExpense));
    }

    query
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ])
      ..limit(limit, offset: offset);

    final results = await query.get();

    unawaited(syncPendingTransactions());

    return results.map(_toModel).toList();
  }

  Future<List<Transaction>> getTransactionsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final query = _db.select(_db.transactions)
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerThanValue(end))
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.createdAt),
      ]);

    final results = await query.get();
    unawaited(syncPendingTransactions());

    return results.map(_toModel).toList();
  }

  /// Get a single transaction by id (for editing).
  Future<Transaction?> getTransactionById(String id) async {
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  // ---------------------------------------------------------------- writes

  Future<List<Transaction>> createTransaction(Transaction transaction) async {
    final created = <Transaction>[];

    if (transaction.isInstallment && transaction.totalInstallments > 1) {
      final groupId = transaction.installmentGroupId ?? _uuid.v4();
      final perInstallment =
          _roundToCents(transaction.amount / transaction.totalInstallments);

      for (var i = 1; i <= transaction.totalInstallments; i++) {
        final installment = transaction.copyWith(
          id: _uuid.v4(),
          amount: perInstallment,
          description:
              '${transaction.description} ($i/${transaction.totalInstallments})',
          date: _addMonths(transaction.date, i - 1),
          isInstallment: true,
          installmentNumber: i,
          totalInstallments: transaction.totalInstallments,
          installmentGroupId: groupId,
        );
        await _db
            .into(_db.transactions)
            .insert(_toCompanion(installment, synced: false));
        created.add(installment);
      }
    } else {
      final single = transaction.copyWith(
        id: transaction.id.isEmpty ? _uuid.v4() : transaction.id,
        isInstallment: false,
        installmentNumber: 1,
        totalInstallments: 1,
        installmentGroupId: null,
      );
      await _db
          .into(_db.transactions)
          .insert(_toCompanion(single, synced: false));
      created.add(single);
    }

    // O lembrete e agendado no aparelho para cada parcela criada.
    for (final transaction in created) {
      unawaited(_scheduleReminder(transaction));
    }

    unawaited(syncPendingTransactions());
    return created;
  }

  Future<Transaction> updateTransaction(Transaction transaction) async {
    final updated =
        transaction.copyWith(updatedAt: DateTime.now(), isSynced: false);
    await _db
        .update(_db.transactions)
        .replace(_toCompanion(updated, synced: false));
    unawaited(_scheduleReminder(updated));
    unawaited(syncPendingTransactions());
    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    await TransactionReminderService.instance.cancel(id);
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    // A eliminacao e enviada na proxima sincronizacao (funciona offline).
    await _sync.tombstone('transaction', id);
    unawaited(_sync.push());
  }

  // ---------------------------------------------------------------- stats

  Future<List<MonthlyStats>> getMonthlyStats({int months = 12}) async {
    final all = await _db.select(_db.transactions).get();

    final data = <String, Map<String, double>>{};
    for (final t in all) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      final entry = data.putIfAbsent(key, () => {'income': 0, 'expense': 0});
      if (t.isExpense) {
        entry['expense'] = (entry['expense'] ?? 0) + t.amount;
      } else {
        entry['income'] = (entry['income'] ?? 0) + t.amount;
      }
    }

    final keys = data.keys.toList()..sort();
    final selected =
        keys.length > months ? keys.sublist(keys.length - months) : keys;

    return selected.map((k) {
      final e = data[k]!;
      final income = e['income'] ?? 0;
      final expense = e['expense'] ?? 0;
      return MonthlyStats(
        month: k,
        income: income,
        expense: expense,
        balance: income - expense,
      );
    }).toList();
  }

  Future<List<CategoryExpense>> getExpensesByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final results = await (_db.select(_db.transactions)
          ..where((t) => t.isExpense.equals(true))
          ..where((t) => t.date.isBiggerOrEqualValue(startDate))
          ..where((t) => t.date.isSmallerOrEqualValue(endDate)))
        .get();

    final totals = <String, double>{};
    for (final t in results) {
      final key = t.categoryId ?? 'none';
      totals[key] = (totals[key] ?? 0) + t.amount;
    }

    final categories = await _db.select(_db.categories).get();
    final nameMap = {for (final c in categories) c.id: c.name};
    final colorMap = {for (final c in categories) c.id: c.color};

    final list = totals.entries.map((e) {
      return CategoryExpense(
        categoryId: e.key,
        categoryName: nameMap[e.key] ?? 'Sem categoria',
        categoryColor: colorMap[e.key] ?? 0xFFB8B8B8,
        total: e.value,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return list;
  }

  /// Monthly income/expense with expenses broken down by category.
  Future<List<MonthlyCategoryStats>> getMonthlyCategoryStats({
    int months = 12,
  }) async {
    final all = await _db.select(_db.transactions).get();
    final categories = await _db.select(_db.categories).get();
    final nameMap = {for (final c in categories) c.id: c.name};
    final colorMap = {for (final c in categories) c.id: c.color};

    final income = <String, double>{};
    final expense = <String, double>{};
    final byCategory = <String, Map<String, double>>{};

    for (final transaction in all) {
      final key =
          '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';
      if (transaction.isExpense) {
        expense[key] = (expense[key] ?? 0) + transaction.amount;
        final categoryKey = transaction.categoryId ?? 'none';
        final monthMap = byCategory.putIfAbsent(key, () => {});
        monthMap[categoryKey] =
            (monthMap[categoryKey] ?? 0) + transaction.amount;
      } else {
        income[key] = (income[key] ?? 0) + transaction.amount;
      }
    }

    final keys = {...income.keys, ...expense.keys}.toList()..sort();
    final selected =
        keys.length > months ? keys.sublist(keys.length - months) : keys;

    return selected.map((key) {
      final categoryList = (byCategory[key] ?? const <String, double>{})
          .entries
          .map(
            (entry) => CategoryExpense(
              categoryId: entry.key,
              categoryName: nameMap[entry.key] ?? 'Sem categoria',
              categoryColor: colorMap[entry.key] ?? 0xFFB8B8B8,
              total: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));

      return MonthlyCategoryStats(
        month: key,
        income: income[key] ?? 0,
        expense: expense[key] ?? 0,
        categories: categoryList,
      );
    }).toList();
  }

  // ------------------------------------------------------------------ sync

  /// Envia as transacoes pendentes (e o resto dos dados) para o servidor.
  Future<void> syncPendingTransactions() async {
    await _sync.push();
  }

  /// Agenda ou cancela o lembrete de [transaction] no aparelho.
  Future<void> _scheduleReminder(Transaction transaction) async {
    try {
      await TransactionReminderService.instance.schedule(
        transactionId: transaction.id,
        description: transaction.description,
        amount: transaction.amount,
        isExpense: transaction.isExpense,
        reminderAt: transaction.reminderAt,
      );
    } catch (_) {
      // O lembrete nunca deve impedir a gravacao da transacao.
    }
  }

  // ----------------------------------------------------------------- helpers

  double _roundToCents(double value) => (value * 100).roundToDouble() / 100;

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final year = date.year + totalMonths ~/ 12;
    final month = totalMonths % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }
}
