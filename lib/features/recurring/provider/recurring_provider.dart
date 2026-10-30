import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/recurring/models/recurring_models.dart';
import 'package:gastos_app/features/recurring/repository/recurring_repository.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) => RecurringRepository());

class RecurringListNotifier extends StateNotifier<AsyncValue<List<RecurringTransaction>>> {
  final RecurringRepository _repository;

  RecurringListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadRecurring();
  }

  Future<void> loadRecurring({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      final recurring = await _repository.getRecurring(forceRefresh: forceRefresh);
      state = AsyncValue.data(recurring);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createRecurring(RecurringTransaction recurring) async {
    try {
      await _repository.createRecurring(recurring);
      await loadRecurring();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateRecurring(RecurringTransaction recurring) async {
    try {
      await _repository.updateRecurring(recurring);
      await loadRecurring();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _repository.deleteRecurring(id);
      await loadRecurring();
    } catch (e) {
      rethrow;
    }
  }
}

final recurringListProvider = StateNotifierProvider<RecurringListNotifier, AsyncValue<List<RecurringTransaction>>>((ref) {
  final repository = ref.watch(recurringRepositoryProvider);
  return RecurringListNotifier(repository);
});