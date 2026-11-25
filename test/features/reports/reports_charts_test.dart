import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/reports/ui/pages/reports_page.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';

class _FakeDio extends Mock implements Dio {}

class _FakeDioClient extends Mock implements DioClient {}

class _FakeStorage extends Mock implements FlutterSecureStorage {}

class _MockTransactionsRepository extends Mock
    implements TransactionsRepository {}

class _MockCreditCardsRepository extends Mock
    implements CreditCardsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TransactionsRepository estatisticas de graficos', () {
    late db.AppDatabase database;
    late SyncService sync;
    late TransactionsRepository txRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      final dio = _FakeDio();
      final dioClient = _FakeDioClient();
      final storage = _FakeStorage();
      when(() => dioClient.dio).thenReturn(dio);
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'true');
      sync = SyncService(
        dioClient: dioClient,
        database: database,
        storage: storage,
      );
      txRepo = TransactionsRepository(database: database, syncService: sync);
    });

    tearDown(() async {
      await database.close();
    });

    test('getMonthlyStats com until nao deixa parcelas futuras apagarem o passado',
        () async {
      final now = DateTime(2026, 11, 20);
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'past-aug',
              userId: 'u1',
              amount: 300,
              description: 'Compra agosto',
              date: DateTime(2026, 8, 10),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'curr-nov',
              userId: 'u1',
              amount: 500,
              description: 'Compra novembro',
              date: DateTime(2026, 11, 5),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Simula 8 parcelas futuras em 2027
      for (var m = 1; m <= 8; m++) {
        await database.into(database.transactions).insert(
              db.TransactionsCompanion.insert(
                id: 'fut-$m',
                userId: 'u1',
                amount: 100,
                description: 'Parcela $m/8',
                date: DateTime(2027, m, 10),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final stats = await txRepo.getMonthlyStats(
        months: 6,
        since: DateTime(2026, 6, 1),
        until: DateTime(2026, 11, 30, 23, 59, 59),
      );

      expect(stats.map((s) => s.month), ['2026-08', '2026-11']);
      expect(stats.first.expense, 300);
      expect(stats.last.expense, 500);
    });

    test('getExpensesByPaymentMethod agrupa, ordena e faz fallback de cartao',
        () async {
      final now = DateTime(2026, 11, 20);
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 't1',
              userId: 'u1',
              amount: 420,
              description: 'Mercado PIX',
              date: DateTime(2026, 11, 10),
              paymentMethod: const Value(PaymentMethods.pix),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 't2',
              userId: 'u1',
              amount: 80,
              description: 'Farmacia PIX',
              date: DateTime(2026, 11, 12),
              paymentMethod: const Value(PaymentMethods.pix),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 't3',
              userId: 'u1',
              amount: 950,
              description: 'Notebook cartao sem campo paymentMethod',
              date: DateTime(2026, 11, 14),
              creditCardId: const Value('card-1'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 't4',
              userId: 'u1',
              amount: 50,
              description: 'Avulso',
              date: DateTime(2026, 11, 15),
              createdAt: now,
              updatedAt: now,
            ),
          );
      // Entrada nao deve aparecer nos gastos por forma de pagamento
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 't5-income',
              userId: 'u1',
              amount: 5000,
              description: 'Salario',
              date: DateTime(2026, 11, 5),
              isExpense: const Value(false),
              paymentMethod: const Value(PaymentMethods.pix),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final result = await txRepo.getExpensesByPaymentMethod(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30, 23, 59, 59),
      );

      expect(result.length, 3);
      expect(result[0].method, PaymentMethods.creditCard);
      expect(result[0].total, 950);
      expect(result[0].count, 1);
      expect(result[1].method, PaymentMethods.pix);
      expect(result[1].total, 500);
      expect(result[1].count, 2);
      expect(result[2].method, 'Não informado');
      expect(result[2].total, 50);
    });
  });

  group('Helpers puros de ReportsPage', () {
    test('formatCompactCurrencyAxis formata negativos, decimais <10k e zero',
        () {
      expect(formatCompactCurrencyAxis(0), '0');
      expect(formatCompactCurrencyAxis(-2500), '-2,5k');
      expect(formatCompactCurrencyAxis(-15000), '-15k');
      expect(formatCompactCurrencyAxis(1500), '1,5k');
      expect(formatCompactCurrencyAxis(2000), '2k');
      expect(formatCompactCurrencyAxis(1200000), '1,2M');
      expect(formatCompactCurrencyAxis(450), '450');
    });

    test('buildDailyCumulativeBalancePoints acumula entradas e saidas por dia',
        () {
      final month = DateTime(2026, 11, 1);
      final txs = [
        Transaction(
          id: 'inc-1',
          userId: 'u1',
          amount: 1000,
          description: 'Salario',
          date: DateTime(2026, 11, 1),
          isExpense: false,
          createdAt: month,
          updatedAt: month,
        ),
        Transaction(
          id: 'exp-3',
          userId: 'u1',
          amount: 250,
          description: 'Supermercado',
          date: DateTime(2026, 11, 3),
          createdAt: month,
          updatedAt: month,
        ),
      ];

      final points = buildDailyCumulativeBalancePoints(
        txs,
        month,
        now: DateTime(2026, 11, 5),
      );

      expect(points.length, 5);
      expect(points[0], (day: 1, balance: 1000.0));
      expect(points[1], (day: 2, balance: 1000.0));
      expect(points[2], (day: 3, balance: 750.0));
      expect(points[4], (day: 5, balance: 750.0));
    });

    test('buildMonthlyComparisonSeries retorna 6 meses no modo Mes e 12 no modo Ano passado',
        () {
      const sample = [
        MonthlyCategoryStats(
          month: '2026-11',
          income: 3000,
          expense: 1200,
          categories: [],
        ),
      ];

      final monthSeries = buildMonthlyComparisonSeries(
        sample,
        ReportPeriod.month,
        DateTime(2026, 11, 1),
        now: DateTime(2026, 11, 25),
      );
      expect(monthSeries.map((s) => s.month), [
        '2026-06',
        '2026-07',
        '2026-08',
        '2026-09',
        '2026-10',
        '2026-11',
      ]);

      final pastYearSeries = buildMonthlyComparisonSeries(
        const [],
        ReportPeriod.year,
        DateTime(2025, 3, 1),
        now: DateTime(2026, 11, 25),
      );
      expect(pastYearSeries.length, 12);
      expect(pastYearSeries.first.month, '2025-01');
      expect(pastYearSeries.last.month, '2025-12');
    });
  });

  group('ReportsPage widget', () {
    testWidgets(
        'exibe taxa de economia, card unificado de categorias, formas de pagamento e uso individual do limite dos cartoes',
        (tester) async {
      final selectedMonth = DateTime(2026, 11, 1);
      final mockTxRepo = _MockTransactionsRepository();
      final mockCardsRepo = _MockCreditCardsRepository();

      final monthTxs = [
        Transaction(
          id: 'tx-inc',
          userId: 'u1',
          amount: 5000,
          description: 'Salario',
          date: DateTime(2026, 11, 1),
          isExpense: false,
          createdAt: selectedMonth,
          updatedAt: selectedMonth,
        ),
        Transaction(
          id: 'tx-exp-1',
          userId: 'u1',
          amount: 1000,
          description: 'Aluguel',
          date: DateTime(2026, 11, 5),
          categoryId: 'cat-1',
          paymentMethod: PaymentMethods.pix,
          createdAt: selectedMonth,
          updatedAt: selectedMonth,
        ),
        Transaction(
          id: 'tx-exp-2',
          userId: 'u1',
          amount: 950,
          description: 'Cartao B',
          date: DateTime(2026, 11, 10),
          categoryId: 'cat-2',
          creditCardId: 'card-b',
          paymentMethod: PaymentMethods.creditCard,
          createdAt: selectedMonth,
          updatedAt: selectedMonth,
        ),
      ];

      when(() => mockTxRepo.getTransactionsForMonth(any()))
          .thenAnswer((_) async => monthTxs);
      when(
        () => mockTxRepo.getMonthlyStats(
          months: any(named: 'months'),
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer(
        (_) async => const [
          MonthlyStats(
            month: '2026-11',
            income: 5000,
            expense: 1950,
            balance: 3050,
          ),
        ],
      );
      when(
        () => mockTxRepo.getMonthlyCategoryStats(
          months: any(named: 'months'),
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer(
        (_) async => const [
          MonthlyCategoryStats(
            month: '2026-11',
            income: 5000,
            expense: 1950,
            categories: [
              CategoryExpense(
                categoryId: 'cat-1',
                categoryName: 'Moradia',
                categoryColor: 0xFFFFB347,
                total: 1000,
              ),
              CategoryExpense(
                categoryId: 'cat-2',
                categoryName: 'Compras',
                categoryColor: 0xFF7E57C2,
                total: 950,
              ),
            ],
          ),
        ],
      );
      when(
        () => mockTxRepo.getExpensesByCategory(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => const [
          CategoryExpense(
            categoryId: 'cat-1',
            categoryName: 'Moradia',
            categoryColor: 0xFFFFB347,
            total: 1000,
          ),
          CategoryExpense(
            categoryId: 'cat-2',
            categoryName: 'Compras',
            categoryColor: 0xFF7E57C2,
            total: 950,
          ),
        ],
      );
      when(
        () => mockTxRepo.getExpensesByPaymentMethod(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        ),
      ).thenAnswer(
        (_) async => const [
          PaymentMethodExpense(
            method: PaymentMethods.pix,
            total: 1000,
            count: 1,
          ),
          PaymentMethodExpense(
            method: PaymentMethods.creditCard,
            total: 950,
            count: 1,
          ),
        ],
      );

      when(
        () => mockCardsRepo.getCreditCards(
          includeInactive: any(named: 'includeInactive'),
        ),
      ).thenAnswer(
        (_) async => const [
          CreditCardItem(
            id: 'card-a',
            name: 'Cartão Alto Limite',
            color: 0xFF7E57C2,
            limitAmount: 10000,
          ),
          CreditCardItem(
            id: 'card-b',
            name: 'Cartão Dia a Dia',
            color: 0xFF29B6F6,
            limitAmount: 1000,
          ),
        ],
      );
      when(() => mockCardsRepo.getCardSpentForMonth('card-a', any()))
          .thenAnswer((_) async => 500);
      when(() => mockCardsRepo.getCardSpentForMonth('card-b', any()))
          .thenAnswer((_) async => 950);
      when(() => mockCardsRepo.getCardInvoiceAmount(any(), any()))
          .thenAnswer((_) async => 0);
      when(() => mockCardsRepo.isInvoicePaid(any(), any()))
          .thenAnswer((_) async => false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedMonthProvider.overrideWith((_) => selectedMonth),
            transactionsRepositoryProvider.overrideWithValue(mockTxRepo),
            creditCardsRepositoryProvider.overrideWithValue(mockCardsRepo),
          ],
          child: const MaterialApp(home: ReportsPage()),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Taxa de economia (3050 / 5000 = 61%)
      expect(find.text('Economia de 61% das entradas'), findsOneWidget);

      // 2. Top categorias removido + donut com Total no centro
      expect(find.text('Top categorias'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Total'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(CurrencyFormatter.format(1950)), findsWidgets);

      // 3. Novo grafico: Gastos por forma de pagamento
      await tester.scrollUntilVisible(
        find.text('Gastos por forma de pagamento'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Gastos por forma de pagamento'), findsOneWidget);
      expect(find.text(PaymentMethods.pix), findsOneWidget);
      expect(find.text(PaymentMethods.creditCard), findsOneWidget);

      // 4. Cartoes calculados sobre o limite individual de cada cartao
      await tester.scrollUntilVisible(
        find.text('Cartão Dia a Dia'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Cartão Alto Limite'), findsOneWidget);
      expect(
        find.text('5% do limite (${CurrencyFormatter.format(10000)})'),
        findsOneWidget,
      );
      expect(find.text('Cartão Dia a Dia'), findsOneWidget);
      expect(
        find.text('95% do limite (${CurrencyFormatter.format(1000)})'),
        findsOneWidget,
      );
    });
  });
}
