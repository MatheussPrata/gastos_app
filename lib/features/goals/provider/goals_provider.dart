import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/goals/repository/goals_repository.dart';

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, AsyncValue<List<db.Goal>>>((ref) {
  return GoalsNotifier(ref.watch(goalsRepositoryProvider));
});

class GoalsNotifier extends StateNotifier<AsyncValue<List<db.Goal>>> {
  GoalsNotifier(this._repository) : super(const AsyncValue.loading()) {
    _load();
  }

  final GoalsRepository _repository;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.getGoals);
  }

  Future<void> refresh() => _load();

  Future<void> save({
    String? id,
    required String name,
    required double targetAmount,
    required double savedAmount,
    DateTime? targetDate,
    required int color,
  }) async {
    await _repository.saveGoal(
      id: id,
      name: name,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      targetDate: targetDate,
      color: color,
    );
    await _load();
  }

  Future<void> delete(String id) async {
    await _repository.deleteGoal(id);
    await _load();
  }
}
