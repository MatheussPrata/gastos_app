import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository();
});

/// CRUD de metas financeiras no banco local (com sincronizacao offline-first).
class GoalsRepository {
  GoalsRepository({
    db.AppDatabase? database,
    SyncService? syncService,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService();

  final db.AppDatabase _db;
  final SyncService _sync;
  final Uuid _uuid = const Uuid();

  Future<List<db.Goal>> getGoals() {
    final query = _db.select(_db.goals)
      ..where((g) => g.isArchived.equals(false))
      ..orderBy([
        (g) => OrderingTerm(expression: g.createdAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  Future<void> saveGoal({
    String? id,
    required String name,
    required double targetAmount,
    required double savedAmount,
    DateTime? targetDate,
    required int color,
  }) async {
    final goalId = id ?? _uuid.v4();
    final now = DateTime.now();
    final existing = id == null
        ? null
        : await (_db.select(_db.goals)..where((g) => g.id.equals(goalId)))
            .getSingleOrNull();

    await _db.into(_db.goals).insertOnConflictUpdate(
          db.GoalsCompanion.insert(
            id: goalId,
            name: name,
            targetAmount: targetAmount,
            savedAmount: Value(savedAmount),
            targetDate: Value(targetDate),
            color: Value(color),
            createdAt: existing?.createdAt ?? now,
            updatedAt: Value(now),
            isSynced: const Value(false),
          ),
        );

    await _sync.clearTombstone('goal', goalId);
    unawaited(_sync.push());
  }

  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
    await _sync.tombstone('goal', id);
    unawaited(_sync.push());
  }
}
