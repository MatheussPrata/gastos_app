import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/recurring/models/recurring_models.dart';
import 'package:gastos_app/features/recurring/utils/recurring_dates.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';

final recurringGeneratorServiceProvider =
    Provider<RecurringGeneratorService>((ref) => RecurringGeneratorService());

/// Resultado da execução da geração de transações recorrentes.
class RecurringGenerationResult {
  const RecurringGenerationResult({
    required this.generatedCount,
    required this.updatedRecurringCount,
    required this.generatedIds,
  });

  final int generatedCount;
  final int updatedRecurringCount;
  final List<String> generatedIds;
}

/// Gera lançamentos reais em [db.Transactions] a partir de [db.RecurringTransactions]
/// vencidas ou sob demanda ("Lançar agora"), mantendo idempotência offline/online.
class RecurringGeneratorService {
  RecurringGeneratorService({
    db.AppDatabase? database,
    SyncService? syncService,
    DateTime Function()? clock,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService(),
        _clock = clock ?? DateTime.now;

  final db.AppDatabase _db;
  final SyncService _sync;
  final DateTime Function() _clock;

  static const Uuid _uuid = Uuid();
  static const int _maxOccurrencesPerRun = 60;

  /// UUID determinístico para evitar duplicações entre execuções ou aparelhos.
  static String deterministicTransactionId(
    String recurringId,
    DateTime dueDate,
  ) {
    final yyyy = dueDate.year.toString().padLeft(4, '0');
    final mm = dueDate.month.toString().padLeft(2, '0');
    final dd = dueDate.day.toString().padLeft(2, '0');
    return _uuid.v5(
      Namespace.url.value,
      'kuanto:recurring:$recurringId:$yyyy-$mm-$dd',
    );
  }

  /// Gera todas as ocorrências com `nextDueDate <= fim do dia atual`.
  Future<RecurringGenerationResult> generateDueTransactions({
    DateTime? now,
  }) async {
    final refNow = now ?? _clock();
    final endOfToday = DateTime(refNow.year, refNow.month, refNow.day, 23, 59, 59);

    final activeRows = await (_db.select(_db.recurringTransactions)
          ..where((r) => r.isActive.equals(true)))
        .get();

    if (activeRows.isEmpty) {
      return const RecurringGenerationResult(
        generatedCount: 0,
        updatedRecurringCount: 0,
        generatedIds: [],
      );
    }

    final existingTxIds = <String>{
      for (final t in await _db.select(_db.transactions).get()) t.id,
    };
    final deletedTxIds = <String>{
      for (final d in await (_db.select(_db.pendingDeletions)
            ..where((p) => p.entityType.equals('transaction')))
          .get())
        d.remoteId,
    };

    var generatedCount = 0;
    var updatedRecurringCount = 0;
    final generatedIds = <String>[];

    for (final rec in activeRows) {
      var due = rec.nextDueDate;
      var lastGeneratedAt = rec.lastGeneratedAt;
      var stillActive = rec.isActive;
      var changed = false;
      var iterations = 0;

      while (stillActive &&
          !due.isAfter(endOfToday) &&
          iterations < _maxOccurrencesPerRun) {
        if (rec.endDate != null &&
            _isDateAfterDay(due, rec.endDate!)) {
          stillActive = false;
          changed = true;
          break;
        }

        final txId = deterministicTransactionId(rec.id, due);
        if (!existingTxIds.contains(txId) && !deletedTxIds.contains(txId)) {
          final hasCard = rec.creditCardId != null && rec.creditCardId!.isNotEmpty;
          final txCreatedAt = _clock();
          await _db.into(_db.transactions).insertOnConflictUpdate(
                db.TransactionsCompanion(
                  id: Value(txId),
                  userId: Value(rec.userId),
                  amount: Value(rec.amount),
                  description: Value(rec.description),
                  date: Value(due),
                  categoryId: Value(rec.categoryId),
                  subcategoryId: Value(rec.subcategoryId),
                  creditCardId: Value(rec.creditCardId),
                  paymentMethod: Value(hasCard ? 'Cartão de Crédito' : ''),
                  isExpense: Value(rec.type == 'expense'),
                  isInstallment: const Value(false),
                  installmentNumber: const Value(1),
                  totalInstallments: const Value(1),
                  notes: const Value('Gerada automaticamente (recorrente)'),
                  reminderEnabled: const Value(false),
                  createdAt: Value(txCreatedAt),
                  updatedAt: Value(txCreatedAt),
                  isSynced: const Value(false),
                ),
              );
          existingTxIds.add(txId);
          generatedCount++;
          generatedIds.add(txId);
        }

        lastGeneratedAt = due;
        due = RecurringDates.nextDue(
          due,
          rec.frequency,
          preferredDay: rec.dayOfMonth,
        );
        if (rec.endDate != null && _isDateAfterDay(due, rec.endDate!)) {
          stillActive = false;
        }
        changed = true;
        iterations++;
      }

      if (changed) {
        await (_db.update(_db.recurringTransactions)
              ..where((r) => r.id.equals(rec.id)))
            .write(
          db.RecurringTransactionsCompanion(
            nextDueDate: Value(due),
            lastGeneratedAt: Value(lastGeneratedAt),
            isActive: Value(stillActive),
            isSynced: const Value(false),
          ),
        );
        updatedRecurringCount++;
      }
    }

    if (generatedCount > 0 || updatedRecurringCount > 0) {
      await _rescheduleAndPush();
    }

    return RecurringGenerationResult(
      generatedCount: generatedCount,
      updatedRecurringCount: updatedRecurringCount,
      generatedIds: generatedIds,
    );
  }

  /// Gera imediatamente a ocorrência de `recurring.nextDueDate` (mesmo futura)
  /// e avança para o próximo ciclo.
  Future<bool> generateNow(
    RecurringTransaction recurring, {
    DateTime? now,
  }) async {
    final rec = await (_db.select(_db.recurringTransactions)
          ..where((r) => r.id.equals(recurring.id)))
        .getSingleOrNull();
    final targetDue = rec?.nextDueDate ?? recurring.nextDueDate;
    final userId = rec?.userId ?? recurring.userId;
    final preferredDay = rec?.dayOfMonth ?? recurring.dayOfMonth;
    final endDate = rec?.endDate ?? recurring.endDate;

    final txId = deterministicTransactionId(recurring.id, targetDue);
    final existing = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(txId)))
        .getSingleOrNull();

    var created = false;
    final txNow = now ?? _clock();
    if (existing == null) {
      final hasCard =
          recurring.creditCardId != null && recurring.creditCardId!.isNotEmpty;
      await _db.into(_db.transactions).insertOnConflictUpdate(
            db.TransactionsCompanion(
              id: Value(txId),
              userId: Value(userId),
              amount: Value(recurring.amount),
              description: Value(recurring.description),
              date: Value(targetDue),
              categoryId: Value(recurring.categoryId),
              subcategoryId: Value(recurring.subcategoryId),
              creditCardId: Value(recurring.creditCardId),
              paymentMethod: Value(hasCard ? 'Cartão de Crédito' : ''),
              isExpense: Value(recurring.type == 'expense'),
              isInstallment: const Value(false),
              installmentNumber: const Value(1),
              totalInstallments: const Value(1),
              notes: const Value('Gerada manualmente (recorrente)'),
              reminderEnabled: const Value(false),
              createdAt: Value(txNow),
              updatedAt: Value(txNow),
              isSynced: const Value(false),
            ),
          );
      await _sync.clearTombstone('transaction', txId);
      created = true;
    }

    final nextDue = RecurringDates.nextDue(
      targetDue,
      recurring.frequency,
      preferredDay: preferredDay,
    );
    final shouldStayActive =
        (rec?.isActive ?? recurring.isActive) &&
        (endDate == null || !_isDateAfterDay(nextDue, endDate));

    await (_db.update(_db.recurringTransactions)
          ..where((r) => r.id.equals(recurring.id)))
        .write(
      db.RecurringTransactionsCompanion(
        nextDueDate: Value(nextDue),
        lastGeneratedAt: Value(targetDue),
        isActive: Value(shouldStayActive),
        isSynced: const Value(false),
      ),
    );

    await _rescheduleAndPush();
    return created;
  }

  static bool _isDateAfterDay(DateTime candidate, DateTime limit) {
    final c = DateTime(candidate.year, candidate.month, candidate.day);
    final l = DateTime(limit.year, limit.month, limit.day);
    return c.isAfter(l);
  }

  Future<void> _rescheduleAndPush() async {
    try {
      await TransactionReminderService.instance.syncAllFromDatabase(_db);
    } catch (_) {
      // Em testes unitarios sem canal nativo de notificacoes, ignora.
    }
    unawaited(_sync.push());
  }
}
