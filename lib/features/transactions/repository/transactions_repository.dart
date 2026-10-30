import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  return TransactionsRepository();
});

class TransactionsRepository {
  final DioClient _dioClient;
  final db.AppDatabase _db;

  TransactionsRepository({
    DioClient? dioClient,
    db.AppDatabase? database,
  })  : _dioClient = dioClient ?? DioClient(),
        _db = database ?? db.AppDatabase();

  /// Get transactions with optional filters
  Future<List<Transaction>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? creditCardId,
    bool? isExpense,
    int limit = 50,
    int offset = 0,
  }) async {
    final localQuery = _db.select(_db.transactions);

    if (startDate != null) {
      localQuery.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      localQuery.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      localQuery.where((t) => t.categoryId.equals(categoryId));
    }
    if (creditCardId != null) {
      localQuery.where((t) => t.creditCardId.equals(creditCardId));
    }
    if (isExpense != null) {
      localQuery.where((t) => t.isExpense.equals(isExpense));
    }

    localQuery
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(limit, offset: offset);

    final localResults = await localQuery.get();

    final transactions = localResults.map((t) => Transaction(
      id: t.id,
      userId: t.userId,
      amount: t.amount,
      description: t.description,
      date: t.date,
      categoryId: t.categoryId,
      subcategoryId: t.subcategoryId,
      creditCardId: t.creditCardId,
      isExpense: t.isExpense,
      isInstallment: t.isInstallment,
      installmentNumber: t.installmentNumber,
      totalInstallments: t.totalInstallments,
      installmentGroupId: t.installmentGroupId,
      notes: t.notes,
      ownerId: t.ownerId,
      partnerSynced: t.partnerSynced,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    )).toList();

    _syncWithServer();

    return transactions;
  }

  /// Create transaction (offline-first)
  Future<Transaction> createTransaction(Transaction transaction) async {
    await _db.into(_db.transactions).insert(db.TransactionsCompanion(
      id: Value(transaction.id),
      userId: Value(transaction.userId),
      amount: Value(transaction.amount),
      description: Value(transaction.description),
      date: Value(transaction.date),
      categoryId: Value(transaction.categoryId),
      subcategoryId: Value(transaction.subcategoryId),
      creditCardId: Value(transaction.creditCardId),
      isExpense: Value(transaction.isExpense),
      isInstallment: Value(transaction.isInstallment),
      installmentNumber: Value(transaction.installmentNumber),
      totalInstallments: Value(transaction.totalInstallments),
      installmentGroupId: Value(transaction.installmentGroupId),
      notes: Value(transaction.notes),
      ownerId: Value(transaction.ownerId),
      partnerSynced: Value(transaction.partnerSynced),
      createdAt: Value(transaction.createdAt),
      updatedAt: Value(transaction.updatedAt),
      isSynced: const Value(false),
    ));

    _syncTransaction(transaction);
    return transaction;
  }

  /// Update transaction (offline-first)
  Future<Transaction> updateTransaction(Transaction transaction) async {
    await _db.update(_db.transactions).replace(db.TransactionsCompanion(
      id: Value(transaction.id),
      userId: Value(transaction.userId),
      amount: Value(transaction.amount),
      description: Value(transaction.description),
      date: Value(transaction.date),
      categoryId: Value(transaction.categoryId),
      subcategoryId: Value(transaction.subcategoryId),
      creditCardId: Value(transaction.creditCardId),
      isExpense: Value(transaction.isExpense),
      isInstallment: Value(transaction.isInstallment),
      installmentNumber: Value(transaction.installmentNumber),
      totalInstallments: Value(transaction.totalInstallments),
      installmentGroupId: Value(transaction.installmentGroupId),
      notes: Value(transaction.notes),
      ownerId: Value(transaction.ownerId),
      partnerSynced: Value(transaction.partnerSynced),
      createdAt: Value(transaction.createdAt),
      updatedAt: Value(DateTime.now()),
      isSynced: const Value(false),
    ));

    _syncTransaction(transaction);
    return transaction;
  }

  /// Delete transaction (offline-first)
  Future<void> deleteTransaction(String id) async {
    await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
    _deleteFromServer(id);
  }

  /// Get monthly stats
  Future<List<MonthlyStats>> getMonthlyStats({int months = 12}) async {
    return [];
  }

  /// Get expenses by category
  Future<List<CategoryExpense>> getExpensesByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return [];
  }

  /// Sync unsynced transactions to server
  Future<void> _syncWithServer() async {
    try {
      final unsynced = await (_db.select(_db.transactions)
        ..where((t) => t.isSynced.equals(false))).get();

      for (final t in unsynced) {
        _syncTransaction(Transaction(
          id: t.id,
          userId: t.userId,
          amount: t.amount,
          description: t.description,
          date: t.date,
          categoryId: t.categoryId,
          subcategoryId: t.subcategoryId,
          creditCardId: t.creditCardId,
          isExpense: t.isExpense,
          isInstallment: t.isInstallment,
          installmentNumber: t.installmentNumber,
          totalInstallments: t.totalInstallments,
          installmentGroupId: t.installmentGroupId,
          notes: t.notes,
          ownerId: t.ownerId,
          partnerSynced: t.partnerSynced,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
        ));
      }
    } catch (_) {}
  }

  Future<void> _syncTransaction(Transaction transaction) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.transactions,
        data: {
          'id': transaction.id,
          'amount': transaction.amount,
          'description': transaction.description,
          'date': transaction.date.toIso8601String(),
          'categoryId': transaction.categoryId,
          'subcategoryId': transaction.subcategoryId,
          'creditCardId': transaction.creditCardId,
          'isExpense': transaction.isExpense,
          'isInstallment': transaction.isInstallment,
          'installmentNumber': transaction.installmentNumber,
          'totalInstallments': transaction.totalInstallments,
          'installmentGroupId': transaction.installmentGroupId,
          'notes': transaction.notes,
          'ownerId': transaction.ownerId,
          'partnerSynced': transaction.partnerSynced,
          'createdAt': transaction.createdAt.toIso8601String(),
          'updatedAt': transaction.updatedAt.toIso8601String(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(transaction.id))).write(
          const db.TransactionsCompanion(isSynced: Value(true)),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteFromServer(String id) async {
    try {
      await _dioClient.dio.delete('${ApiEndpoints.transactionsById}$id');
    } catch (_) {}
  }
}