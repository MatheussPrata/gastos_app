import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:gastos_flutter/core/api/dio_client.dart';
import 'package:gastos_flutter/core/api/endpoints.dart';
import 'package:gastos_flutter/core/database/app_database.dart' as db;
import 'package:gastos_flutter/features/transactions/models/transaction_models.dart';

class TransactionsRepository {
  final DioClient _dioClient = DioClient();
  final db.AppDatabase _db = db.AppDatabase();

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
    // Try local first for offline support
    final localQuery = _db.select(_db.transactions);
    
    // Apply filters
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
    
    // Convert to domain models
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
    
    // Try to sync with server in background
    _syncWithServer();
    
    return transactions;
  }

  /// Create transaction (offline-first)
  Future<Transaction> createTransaction(Transaction transaction) async {
    // 1. Save to local DB first with isSynced = false
    await _db.into(_db.transactions).insert(db.db.db.db.TransactionsCompanion(
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

    // 2. Try to sync with server
    _syncTransaction(transaction);

    return transaction;
  }

  /// Update transaction (offline-first)
  Future<Transaction> updateTransaction(Transaction transaction) async {
    await _db.update(_db.transactions).replace(db.db.db.db.TransactionsCompanion(
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
    await _db.delete(_db.transactions).where((t) => t.id.equals(id)).go();
    _deleteFromServer(id);
  }

  /// Get monthly stats
  Future<List<MonthlyStats>> getMonthlyStats({int months = 12}) async {
    // Implementation would query local DB with grouping by month
    return [];
  }

  /// Get expenses by category
  Future<List<CategoryExpense>> getExpensesByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Implementation would query local DB with grouping by category
    return [];
  }

  /// Sync unsynced transactions to server
  Future<void> _syncWithServer() async {
    final unsynced = await _db.getUnsyncedTransactions();
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
  }

  Future<void> _syncTransaction(Transaction transaction) async {
    try {
      final dio = DioClient().dio;
      final response = await dio.post(
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
        await _db.markTransactionSynced(transaction.id);
      }
    } catch (_) {
      // Keep isSynced = false for retry later
    }
  }

  Future<void> _deleteFromServer(String id) async {
    try {
      final dio = DioClient().dio;
      await dio.delete('${ApiEndpoints.transactionsById}$id');
    } catch (_) {
      // Handle offline delete later
    }
  }
}