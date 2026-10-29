import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:gastos_flutter/core/api/dio_client.dart';
import 'package:gastos_flutter/core/api/endpoints.dart';
import 'package:gastos_flutter/core/database/app_database.dart' as db;
import 'package:gastos_flutter/features/recurring/models/recurring_models.dart';

class RecurringRepository {
  final DioClient _dioClient = DioClient();
  final db.AppDatabase _db = db.AppDatabase();

  Future<List<RecurringTransaction>> getRecurring({bool forceRefresh = false}) async {
    final localResults = await _db.select(_db.recurringTransactions).get();
    
    final recurring = localResults.map((r) => RecurringTransaction(
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
    )).toList();

    if (forceRefresh || recurring.isEmpty) {
      _syncWithServer();
    }
    
    return recurring;
  }

  Future<RecurringTransaction> createRecurring(RecurringTransaction recurring) async {
    await _db.into(_db.recurringTransactions).insert(Recurringdb.db.db.db.TransactionsCompanion(
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

    _syncRecurring(recurring);
    return recurring;
  }

  Future<RecurringTransaction> updateRecurring(RecurringTransaction recurring) async {
    await _db.update(_db.recurringTransactions).replace(Recurringdb.db.db.db.TransactionsCompanion(
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

    _syncRecurring(recurring);
    return recurring;
  }

  Future<void> deleteRecurring(String id) async {
    await _db.delete(_db.recurringTransactions).where((r) => r.id.equals(id)).go();
    _deleteFromServer(id);
  }

  Future<void> _syncWithServer() async {
    try {
      final response = await DioClient().dio.get(ApiEndpoints.recurring);
      if (response.statusCode == 200) {
        final data = response.data['data'] as List? ?? [];
        for (final json in data) {
          final r = RecurringTransaction.fromJson(json as Map<String, dynamic>);
          await _db.into(_db.recurringTransactions).insertOnConflictUpdate(Recurringdb.db.db.db.TransactionsCompanion(
            id: Value(r.id),
            userId: Value(r.userId),
            description: Value(r.description),
            amount: Value(r.amount),
            type: Value(r.type),
            categoryId: Value(r.categoryId),
            subcategoryId: Value(r.subcategoryId),
            creditCardId: Value(r.creditCardId),
            frequency: Value(r.frequency),
            dayOfMonth: Value(r.dayOfMonth),
            startDate: Value(r.startDate),
            endDate: Value(r.endDate),
            isActive: Value(r.isActive),
            nextDueDate: Value(r.nextDueDate),
            lastGeneratedAt: Value(r.lastGeneratedAt),
            createdAt: Value(r.createdAt),
            isSynced: const Value(true),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _syncRecurring(RecurringTransaction recurring) async {
    try {
      await DioClient().dio.post(
        ApiEndpoints.recurring,
        data: recurring.toJson(),
      );
      await _db.markRecurringSynced(recurring.id);
    } catch (_) {}
  }

  Future<void> _deleteFromServer(String id) async {
    try {
      await DioClient().dio.delete('${ApiEndpoints.recurringById}$id');
    } catch (_) {}
  }
}