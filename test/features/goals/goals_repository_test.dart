import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/database/app_database.dart';
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/goals/repository/goals_repository.dart';

class _MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MockSyncService syncService;
  late GoalsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncService = _MockSyncService();
    when(() => syncService.push()).thenAnswer((_) async => const SyncOutcome());
    when(() => syncService.tombstone(any(), any())).thenAnswer((_) async {});
    when(() => syncService.clearTombstone(any(), any()))
        .thenAnswer((_) async {});

    repo = GoalsRepository(database: db, syncService: syncService);
  });

  tearDown(() async {
    await db.close();
  });

  group('GoalsRepository', () {
    test('salva com updatedAt, isSynced=false, limpa tombstone e apaga com tombstone',
        () async {
      await repo.saveGoal(
        id: 'goal-1',
        name: 'Viagem',
        targetAmount: 5000.0,
        savedAmount: 1000.0,
        color: 0xFF2EC4B6,
      );

      final saved = await repo.getGoals();
      expect(saved, hasLength(1));
      expect(saved.single.isSynced, isFalse);
      expect(saved.single.updatedAt, isNotNull);
      verify(() => syncService.clearTombstone('goal', 'goal-1')).called(1);
      verify(() => syncService.push()).called(1);

      final originalCreatedAt = saved.single.createdAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await repo.saveGoal(
        id: 'goal-1',
        name: 'Viagem Atualizada',
        targetAmount: 5000.0,
        savedAmount: 2000.0,
        color: 0xFF2EC4B6,
      );

      final updated = await repo.getGoals();
      expect(updated.single.name, 'Viagem Atualizada');
      expect(updated.single.createdAt, originalCreatedAt);

      await repo.deleteGoal('goal-1');
      expect(await repo.getGoals(), isEmpty);
      verify(() => syncService.tombstone('goal', 'goal-1')).called(1);
    });
  });
}
