import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return GoalsRepository();
});

/// CRUD de metas financeiras no banco local.
class GoalsRepository {
  GoalsRepository({db.AppDatabase? database})
      : _db = database ?? db.AppDatabase();

  final db.AppDatabase _db;
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
    await _db.into(_db.goals).insertOnConflictUpdate(
          db.GoalsCompanion.insert(
            id: goalId,
            name: name,
            targetAmount: targetAmount,
            savedAmount: Value(savedAmount),
            targetDate: Value(targetDate),
            color: Value(color),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> deleteGoal(String id) async {
    await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
  }
}
