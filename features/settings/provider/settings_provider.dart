import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_flutter/features/settings/models/settings_models.dart';
import 'package:gastos_flutter/features/settings/repository/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<void> saveSetting(String key, String value) async {
    state = const AsyncValue.loading();
    try {
      await _repository.saveSetting(key, value);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> triggerBackup() async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.triggerBackup();
      state = const AsyncValue.data(null);
      if (!success) throw Exception('Falha no backup');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> triggerSync() async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.triggerSync();
      state = const AsyncValue.data(null);
      if (!success) throw Exception('Falha na sincronização');
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<Map<String, dynamic>?> getSyncStatus() async {
    return _repository.getSyncStatus();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<void>>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repository);
});

final syncStatusProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.getSyncStatus();
});