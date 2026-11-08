import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/database/app_database.dart';
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';

class _MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MockSyncService syncService;
  late CreditCardsRepository cardsRepo;
  late PlanningRepository planningRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    syncService = _MockSyncService();
    when(() => syncService.push()).thenAnswer((_) async => const SyncOutcome());
    when(() => syncService.tombstone(any(), any())).thenAnswer((_) async {});

    cardsRepo = CreditCardsRepository(database: db, syncService: syncService);
    planningRepo = PlanningRepository(database: db, syncService: syncService);
  });

  tearDown(() async {
    await db.close();
  });

  group('CreditCardItem model', () {
    test('displayName retorna apenas o nome, sem dados confidenciais', () {
      const card = CreditCardItem(
        id: 'c1',
        name: 'Nubank Roxinho',
        color: 0xFF8A05BE,
      );
      expect(card.displayName, equals('Nubank Roxinho'));
      expect(card.lastFourDigits, isEmpty);
      expect(card.brand, isEmpty);
    });
  });

  group('CreditCardsRepository - Fatura Total', () {
    test('salva e recupera valor total da fatura para o mês', () async {
      final month = DateTime(2026, 11, 1);
      expect(await cardsRepo.getCardInvoiceAmount('card-1', month), 0.0);

      await cardsRepo.setCardInvoiceAmount('card-1', month, 1500.50);
      expect(await cardsRepo.getCardInvoiceAmount('card-1', month), 1500.50);

      // Zerar valor remove do banco
      await cardsRepo.setCardInvoiceAmount('card-1', month, 0.0);
      expect(await cardsRepo.getCardInvoiceAmount('card-1', month), 0.0);
    });
  });

  group('PlanningRepository - Diferença de fatura na categoria Não informada', () {
    test('atribui diferença à categoria nao_informada quando fatura > gastos lançados', () async {
      final month = DateTime(2026, 11, 1);

      // Cria cartão
      await cardsRepo.createCreditCard(const CreditCardItem(
        id: 'card-abc',
        name: 'Inter',
        color: 0xFFFF7A00,
        closingDay: 25,
        dueDay: 5,
      ));

      // Lança transação no cartão de R$ 300 numa categoria qualquer
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-1',
        userId: 'u1',
        amount: 300.0,
        description: 'Mercado',
        date: DateTime(2026, 11, 10),
        creditCardId: const Value('card-abc'),
        categoryId: const Value('cat-mercado'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Fatura total informada pelo usuário: R$ 500.00
      await cardsRepo.setCardInvoiceAmount('card-abc', month, 500.0);

      final spent = await planningRepo.getSpentByCategory(month, scope: BudgetScope.individual);

      expect(spent['cat-mercado'], equals(300.0));
      // Diferença: 500 - 300 = 200
      expect(spent['nao_informada'], equals(200.0));
    });

    test('não gera categoria nao_informada se fatura <= gastos lançados', () async {
      final month = DateTime(2026, 11, 1);

      await cardsRepo.createCreditCard(const CreditCardItem(
        id: 'card-xyz',
        name: 'Nubank',
        color: 0xFF8A05BE,
      ));

      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-2',
        userId: 'u1',
        amount: 400.0,
        description: 'Padaria',
        date: DateTime(2026, 11, 15),
        creditCardId: const Value('card-xyz'),
        categoryId: const Value('cat-padaria'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Fatura informada menor ou igual aos gastos lançados (400)
      await cardsRepo.setCardInvoiceAmount('card-xyz', month, 350.0);

      final spent = await planningRepo.getSpentByCategory(month, scope: BudgetScope.individual);

      expect(spent['cat-padaria'], equals(400.0));
      expect(spent.containsKey('nao_informada'), isFalse);
    });
  });
}
