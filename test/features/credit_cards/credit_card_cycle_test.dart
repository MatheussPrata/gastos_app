import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/database/app_database.dart';
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart'
    as tm;
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';

class _MockSyncService extends Mock implements SyncService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CreditCardCycleHelper', () {
    test('effectiveClosingDay ajusta para o último dia de meses curtos', () {
      expect(CreditCardCycleHelper.effectiveClosingDay(2026, 2, 31), equals(28));
      expect(CreditCardCycleHelper.effectiveClosingDay(2024, 2, 31), equals(29)); // bissexto
      expect(CreditCardCycleHelper.effectiveClosingDay(2026, 4, 31), equals(30));
      expect(CreditCardCycleHelper.effectiveClosingDay(2026, 12, 25), equals(25));
    });

    test('invoiceMonthForDate define o mês da fatura antes e depois do fechamento', () {
      // closingDay = 25
      final beforeClosing = DateTime(2026, 11, 20);
      final onClosing = DateTime(2026, 11, 25);
      final afterClosing = DateTime(2026, 11, 26);

      expect(
        CreditCardCycleHelper.invoiceMonthForDate(beforeClosing, 25),
        equals(DateTime(2026, 11, 1)),
      );
      expect(
        CreditCardCycleHelper.invoiceMonthForDate(onClosing, 25),
        equals(DateTime(2026, 11, 1)),
      );
      // Após o fechamento: vai para a fatura de Dezembro
      expect(
        CreditCardCycleHelper.invoiceMonthForDate(afterClosing, 25),
        equals(DateTime(2026, 12, 1)),
      );
    });

    test('invoiceMonthForDate vira o ano quando compra é após fechamento em Dezembro', () {
      final endOfYear = DateTime(2026, 12, 26);
      expect(
        CreditCardCycleHelper.invoiceMonthForDate(endOfYear, 25),
        equals(DateTime(2027, 1, 1)),
      );
    });

    test('invoiceDateRange calcula o início e fim corretos do ciclo', () {
      final range = CreditCardCycleHelper.invoiceDateRange(
        invoiceMonth: DateTime(2026, 11, 1),
        closingDay: 25,
      );

      expect(range.start, equals(DateTime(2026, 10, 26, 0, 0, 0, 0)));
      expect(range.end, equals(DateTime(2026, 11, 25, 23, 59, 59, 999)));
    });

    test('bestDayToBuy é o dia seguinte ao fechamento', () {
      expect(CreditCardCycleHelper.bestDayToBuy(25), equals(26));
      expect(CreditCardCycleHelper.bestDayToBuy(31), equals(1));
    });

    test('installmentDateForCycle calcula datas pertencentes aos ciclos subsequentes', () {
      final purchaseDate = DateTime(2026, 11, 26); // Após fechamento (25) -> 1ª parcela na fatura de Dezembro
      const closingDay = 25;

      final date1 = CreditCardCycleHelper.installmentDateForCycle(
        baseDate: purchaseDate,
        installmentIndex: 0,
        closingDay: closingDay,
      );
      final date2 = CreditCardCycleHelper.installmentDateForCycle(
        baseDate: purchaseDate,
        installmentIndex: 1,
        closingDay: closingDay,
      );
      final date3 = CreditCardCycleHelper.installmentDateForCycle(
        baseDate: purchaseDate,
        installmentIndex: 2,
        closingDay: closingDay,
      );

      expect(CreditCardCycleHelper.invoiceMonthForDate(date1, closingDay),
          equals(DateTime(2026, 12, 1)));
      expect(CreditCardCycleHelper.invoiceMonthForDate(date2, closingDay),
          equals(DateTime(2027, 1, 1)));
      expect(CreditCardCycleHelper.invoiceMonthForDate(date3, closingDay),
          equals(DateTime(2027, 2, 1)));
    });
  });

  group('CreditCardsRepository - Ciclos e Fatura Paga', () {
    late AppDatabase db;
    late _MockSyncService syncService;
    late CreditCardsRepository repo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      syncService = _MockSyncService();
      when(() => syncService.push()).thenAnswer((_) async => const SyncOutcome());
      when(() => syncService.tombstone(any(), any())).thenAnswer((_) async {});

      repo = CreditCardsRepository(database: db, syncService: syncService);

      await repo.createCreditCard(const CreditCardItem(
        id: 'card-1',
        name: 'Nubank',
        color: 0xFF8A05BE,
        closingDay: 25,
        dueDay: 5,
        limitAmount: 5000.0,
      ));
    });

    tearDown(() async => db.close());

    test('getCardSpentForMonth considera o ciclo de fechamento', () async {
      // Ciclo de Novembro/2026 com closingDay 25: 26/10/2026 a 25/11/2026
      // Transação em 26/10 (pertence a Nov)
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-1',
        userId: 'u1',
        amount: 100.0,
        description: 'Compra 1',
        date: DateTime(2026, 10, 26, 14, 0),
        creditCardId: const Value('card-1'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Transação em 10/11 (pertence a Nov)
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-2',
        userId: 'u1',
        amount: 150.0,
        description: 'Compra 2',
        date: DateTime(2026, 11, 10),
        creditCardId: const Value('card-1'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Transação em 26/11 (pertence a Dezembro, NÃO a Novembro)
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-3',
        userId: 'u1',
        amount: 200.0,
        description: 'Compra 3',
        date: DateTime(2026, 11, 26, 10, 0),
        creditCardId: const Value('card-1'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final spentNov = await repo.getCardSpentForMonth('card-1', DateTime(2026, 11, 1));
      expect(spentNov, equals(250.0)); // 100 + 150

      final spentDec = await repo.getCardSpentForMonth('card-1', DateTime(2026, 12, 1));
      expect(spentDec, equals(200.0)); // 200
    });

    test('marca e desmarca fatura como paga', () async {
      final month = DateTime(2026, 11, 1);
      expect(await repo.isInvoicePaid('card-1', month), isFalse);

      await repo.setInvoicePaid('card-1', month, true);
      expect(await repo.isInvoicePaid('card-1', month), isTrue);

      await repo.setInvoicePaid('card-1', month, false);
      expect(await repo.isInvoicePaid('card-1', month), isFalse);
    });

    test('getCardSpentByCategory agrupa gastos e inclui diferença de fatura', () async {
      final month = DateTime(2026, 11, 1);

      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-1',
        userId: 'u1',
        amount: 300.0,
        description: 'Mercado',
        date: DateTime(2026, 11, 10),
        creditCardId: const Value('card-1'),
        categoryId: const Value('cat-mercado'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Fatura de R$ 500,00 informada
      await repo.setCardInvoiceAmount('card-1', month, 500.0);

      final breakdown = await repo.getCardSpentByCategory(
        cardId: 'card-1',
        month: month,
      );

      expect(breakdown['cat-mercado'], equals(300.0));
      expect(breakdown['nao_informada'], equals(200.0));
    });

    test('getFutureInvoicesForecast retorna previsão de faturas futuras', () async {
      final startMonth = DateTime(2026, 11, 1);

      // Transação em nov (250)
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-1',
        userId: 'u1',
        amount: 250.0,
        description: 'Novembro',
        date: DateTime(2026, 11, 10),
        creditCardId: const Value('card-1'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Transação em dez (100)
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'tx-2',
        userId: 'u1',
        amount: 100.0,
        description: 'Dezembro',
        date: DateTime(2026, 12, 10),
        creditCardId: const Value('card-1'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final forecast = await repo.getFutureInvoicesForecast(
        cardId: 'card-1',
        startMonth: startMonth,
        numberOfMonths: 3,
      );

      expect(forecast.length, equals(3));
      expect(forecast[0].month, equals(DateTime(2026, 11, 1)));
      expect(forecast[0].spent, equals(250.0));
      expect(forecast[1].month, equals(DateTime(2026, 12, 1)));
      expect(forecast[1].spent, equals(100.0));
      expect(forecast[2].month, equals(DateTime(2027, 1, 1)));
      expect(forecast[2].spent, equals(0.0));
    });
  });

  group('TransactionsRepository - Parcelamento em Cartão com Ciclo', () {
    late AppDatabase db;
    late _MockSyncService syncService;
    late TransactionsRepository txRepo;
    late CreditCardsRepository cardsRepo;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      syncService = _MockSyncService();
      when(() => syncService.push()).thenAnswer((_) async => const SyncOutcome());
      when(() => syncService.tombstone(any(), any())).thenAnswer((_) async {});

      txRepo = TransactionsRepository(database: db, syncService: syncService);
      cardsRepo = CreditCardsRepository(database: db, syncService: syncService);

      await cardsRepo.createCreditCard(const CreditCardItem(
        id: 'card-inter',
        name: 'Inter',
        color: 0xFFFF7A00,
        closingDay: 25,
        dueDay: 5,
      ));
    });

    tearDown(() async => db.close());

    test('gera parcelas no ciclo de fatura correto quando comprado após fechamento', () async {
      // Compra feita em 26/11 (após fechamento 25)
      // Parcela 1: fatura de Dezembro/2026
      // Parcela 2: fatura de Janeiro/2027
      // Parcela 3: fatura de Fevereiro/2027
      final tx = tm.Transaction(
        id: 'tx-parent',
        userId: 'u1',
        amount: 300.0,
        description: 'TV Parcelada',
        date: DateTime(2026, 11, 26),
        creditCardId: 'card-inter',
        paymentMethod: 'Cartão de Crédito',
        isExpense: true,
        isInstallment: true,
        installmentNumber: 1,
        totalInstallments: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created = await txRepo.createTransaction(tx);
      expect(created.length, equals(3));
      expect(created[0].amount, equals(100.0));
      expect(created[1].amount, equals(100.0));
      expect(created[2].amount, equals(100.0));

      final invoice1 = CreditCardCycleHelper.invoiceMonthForDate(created[0].date, 25);
      final invoice2 = CreditCardCycleHelper.invoiceMonthForDate(created[1].date, 25);
      final invoice3 = CreditCardCycleHelper.invoiceMonthForDate(created[2].date, 25);

      expect(invoice1, equals(DateTime(2026, 12, 1)));
      expect(invoice2, equals(DateTime(2027, 1, 1)));
      expect(invoice3, equals(DateTime(2027, 2, 1)));
    });
  });
}
