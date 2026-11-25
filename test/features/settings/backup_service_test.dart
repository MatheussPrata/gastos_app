import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/database/app_database.dart';
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/settings/services/backup_service.dart';

class _MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MockSyncService syncService;
  late Directory tempDir;
  late BackupService backupService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncService = _MockSyncService();
    when(() => syncService.currentUserId()).thenAnswer((_) async => 'user-1');
    when(() => syncService.push()).thenAnswer((_) async => const SyncOutcome());
    tempDir = await Directory.systemTemp.createTemp('kuanto_backup_test_');
    backupService = BackupService(
      database: db,
      syncService: syncService,
      documentsDirProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupService', () {
    test('exporta e restaura todas as entidades preservando isSynced = false',
        () async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'cat-1',
            name: 'Mercado',
            color: 0xFFFF6B6B,
            icon: 'shopping_basket',
            isSynced: const Value(true),
          ));
      await db.into(db.creditCards).insert(CreditCardsCompanion.insert(
            id: 'card-1',
            name: 'Nubank',
            color: 0xFF8A05BE,
            isSynced: const Value(true),
          ));
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: 'tx-1',
            userId: 'user-1',
            amount: 89.90,
            description: 'Supermercado',
            date: DateTime(2026, 11, 20),
            categoryId: const Value('cat-1'),
            creditCardId: const Value('card-1'),
            receiptId: const Value('recp-1'),
            createdAt: DateTime(2026, 11, 20),
            updatedAt: DateTime(2026, 11, 20),
            isSynced: const Value(true),
          ));
      await db.into(db.receipts).insert(ReceiptsCompanion.insert(
            id: 'recp-1',
            transactionId: 'tx-1',
            establishmentName: 'Supermercado Sul',
            issueDate: DateTime(2026, 11, 20),
            totalAmount: 89.90,
            subtotalAmount: const Value(99.90),
            totalDiscount: const Value(10.0),
            createdAt: DateTime(2026, 11, 20),
            isSynced: const Value(true),
          ));
      await db.into(db.receiptItems).insert(ReceiptItemsCompanion.insert(
            id: 'item-1',
            receiptId: 'recp-1',
            name: 'Café 500g',
            unitPrice: const Value(25.0),
            grossTotal: const Value(25.0),
            totalPrice: const Value(20.0),
            discount: const Value(5.0),
            isSynced: const Value(true),
          ));
      await db.into(db.goals).insert(GoalsCompanion.insert(
            id: 'goal-1',
            name: 'Reserva',
            targetAmount: 5000.0,
            savedAmount: const Value(1500.0),
            createdAt: DateTime(2026, 11, 1),
            updatedAt: Value(DateTime(2026, 11, 10)),
            isSynced: const Value(true),
          ));
      await db.into(db.budgetPlans).insert(BudgetPlansCompanion.insert(
            id: 'plan-1',
            userId: 'user-1',
            month: DateTime(2026, 11, 1),
            monthlyBudget: const Value(3000.0),
            createdAt: DateTime(2026, 11, 1),
            updatedAt: DateTime(2026, 11, 2),
            isSynced: const Value(true),
          ));
      await db.into(db.budgetAlerts).insert(BudgetAlertsCompanion.insert(
            id: 'alert-1',
            planId: 'plan-1',
            categoryId: 'cat-1',
            categoryName: 'Mercado',
            threshold: 80,
            spentAmount: 800,
            allocatedAmount: 1000,
            triggeredAt: DateTime(2026, 11, 15),
            isSynced: const Value(true),
          ));
      await db.into(db.appSettings).insert(AppSettingsCompanion.insert(
            key: 'card_invoice_card-1_2026_11',
            value: '450.0',
            isSynced: const Value(true),
          ));

      final file = await backupService.createLocalBackupFile();
      expect(await file.exists(), isTrue);

      final listed = await backupService.listLocalBackups();
      expect(listed, hasLength(1));

      // Limpa todo o banco antes de restaurar
      await db.clearAllData();
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.goals).get(), isEmpty);

      final result = await backupService.restoreFromFile(file);
      expect(result.categories, 1);
      expect(result.creditCards, 1);
      expect(result.transactions, 1);
      expect(result.receipts, 1);
      expect(result.goals, 1);
      expect(result.budgetPlans, 1);
      expect(result.budgetAlerts, 1);
      expect(result.appSettings, 1);

      final restoredTx = await db.select(db.transactions).getSingle();
      expect(restoredTx.description, 'Supermercado');
      expect(restoredTx.isSynced, isFalse);

      final restoredGoal = await db.select(db.goals).getSingle();
      expect(restoredGoal.name, 'Reserva');
      expect(restoredGoal.isSynced, isFalse);

      final restoredItems = await db.select(db.receiptItems).get();
      expect(restoredItems.single.name, 'Café 500g');
      expect(restoredItems.single.discount, 5.0);

      final restoredSettings = await db.select(db.appSettings).get();
      expect(restoredSettings.single.value, '450.0');
    });

    test('rejeita JSON inválido ou de formato incompatível', () async {
      expect(
        () => backupService.restoreFromJsonString('{invalido'),
        throwsA(isA<BackupFormatException>()),
      );

      final foreignJson = jsonEncode({'app': 'outro', 'data': {}});
      expect(
        () => backupService.restoreFromJsonString(foreignJson),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });
}
