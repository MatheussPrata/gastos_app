import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/database/app_database.dart'
    hide RecurringTransaction;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/recurring/models/recurring_models.dart';
import 'package:gastos_app/features/recurring/services/recurring_generator_service.dart';

class _MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MockSyncService syncService;
  late RecurringGeneratorService generator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncService = _MockSyncService();
    when(() => syncService.push()).thenAnswer((_) async => const SyncOutcome());
    when(() => syncService.clearTombstone(any(), any()))
        .thenAnswer((_) async {});

    generator = RecurringGeneratorService(
      database: db,
      syncService: syncService,
      clock: () => DateTime(2026, 11, 25, 10, 0),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('RecurringGeneratorService', () {
    test('gera múltiplas ocorrências atrasadas sem duplicar ao reexecutar',
        () async {
      await db.into(db.recurringTransactions).insert(
            RecurringTransactionsCompanion.insert(
              id: 'rec-1',
              userId: 'user-1',
              description: 'Internet Fibra',
              amount: 129.90,
              type: 'expense',
              categoryId: const Value('cat-1'),
              creditCardId: const Value('card-1'),
              frequency: 'monthly',
              dayOfMonth: 10,
              startDate: DateTime(2026, 9, 10),
              nextDueDate: DateTime(2026, 9, 10),
              createdAt: DateTime(2026, 9, 1),
            ),
          );

      // Em 25/11/2026, 10/09, 10/10 e 10/11 estão vencidas (3 ocorrências).
      final firstRun =
          await generator.generateDueTransactions(now: DateTime(2026, 11, 25));
      expect(firstRun.generatedCount, 3);
      expect(firstRun.updatedRecurringCount, 1);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(3));
      expect(txs.every((t) => t.paymentMethod == 'Cartão de Crédito'), isTrue);
      expect(txs.every((t) => !t.isSynced), isTrue);

      final updatedRec = await (db.select(db.recurringTransactions)
            ..where((r) => r.id.equals('rec-1')))
          .getSingle();
      expect(updatedRec.nextDueDate, DateTime(2026, 12, 10));
      expect(updatedRec.lastGeneratedAt, DateTime(2026, 11, 10));

      // Segunda execução no mesmo dia não gera nada duplicado.
      final secondRun =
          await generator.generateDueTransactions(now: DateTime(2026, 11, 25));
      expect(secondRun.generatedCount, 0);
      expect(await db.select(db.transactions).get(), hasLength(3));
    });

    test('respeita endDate e desativa recorrência após última ocorrência',
        () async {
      await db.into(db.recurringTransactions).insert(
            RecurringTransactionsCompanion.insert(
              id: 'rec-end',
              userId: 'user-1',
              description: 'Parcela Curso',
              amount: 200.0,
              type: 'expense',
              frequency: 'monthly',
              dayOfMonth: 5,
              startDate: DateTime(2026, 10, 5),
              endDate: Value(DateTime(2026, 11, 5)),
              nextDueDate: DateTime(2026, 10, 5),
              createdAt: DateTime(2026, 10, 1),
            ),
          );

      final result =
          await generator.generateDueTransactions(now: DateTime(2026, 12, 1));
      expect(result.generatedCount, 2); // 05/10 e 05/11

      final rec = await (db.select(db.recurringTransactions)
            ..where((r) => r.id.equals('rec-end')))
          .getSingle();
      expect(rec.isActive, isFalse);
    });

    test('não ressuscita ocorrência que possui tombstone de transação', () async {
      final due = DateTime(2026, 11, 10);
      final deterministicId =
          RecurringGeneratorService.deterministicTransactionId('rec-del', due);

      await db.into(db.recurringTransactions).insert(
            RecurringTransactionsCompanion.insert(
              id: 'rec-del',
              userId: 'user-1',
              description: 'Streaming',
              amount: 39.9,
              type: 'expense',
              frequency: 'monthly',
              dayOfMonth: 10,
              startDate: due,
              nextDueDate: due,
              createdAt: DateTime(2026, 11, 1),
            ),
          );

      await db.into(db.pendingDeletions).insert(
            PendingDeletionsCompanion.insert(
              id: 'tomb-1',
              entityType: 'transaction',
              remoteId: deterministicId,
              createdAt: DateTime(2026, 11, 11),
            ),
          );

      final result =
          await generator.generateDueTransactions(now: DateTime(2026, 11, 25));
      expect(result.generatedCount, 0);
      expect(await db.select(db.transactions).get(), isEmpty);

      final rec = await (db.select(db.recurringTransactions)
            ..where((r) => r.id.equals('rec-del')))
          .getSingle();
      expect(rec.nextDueDate, DateTime(2026, 12, 10));
    });

    test('generateNow lança ocorrência futura imediatamente e avança nextDueDate',
        () async {
      final futureDue = DateTime(2026, 12, 15);
      await db.into(db.recurringTransactions).insert(
            RecurringTransactionsCompanion.insert(
              id: 'rec-now',
              userId: 'user-1',
              description: 'Salário',
              amount: 5500.0,
              type: 'income',
              frequency: 'monthly',
              dayOfMonth: 15,
              startDate: futureDue,
              nextDueDate: futureDue,
              createdAt: DateTime(2026, 11, 1),
            ),
          );

      final model = RecurringTransaction(
        id: 'rec-now',
        userId: 'user-1',
        description: 'Salário',
        amount: 5500.0,
        type: 'income',
        frequency: 'monthly',
        dayOfMonth: 15,
        startDate: futureDue,
        nextDueDate: futureDue,
        createdAt: DateTime(2026, 11, 1),
      );

      final created = await generator.generateNow(model);
      expect(created, isTrue);

      final txs = await db.select(db.transactions).get();
      expect(txs, hasLength(1));
      expect(txs.single.description, 'Salário');
      expect(txs.single.isExpense, isFalse);
      expect(txs.single.date, futureDue);

      final rec = await (db.select(db.recurringTransactions)
            ..where((r) => r.id.equals('rec-now')))
          .getSingle();
      expect(rec.nextDueDate, DateTime(2027, 1, 15));
      expect(rec.lastGeneratedAt, futureDue);
    });
  });
}
