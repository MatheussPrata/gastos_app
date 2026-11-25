import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/notifications/notification_permission_service.dart';
import 'package:gastos_app/core/notifications/notification_permissions_provider.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/features/categories/models/category_models.dart'
    as cat;
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart'
    hide categoriesRepositoryProvider;
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';
import 'package:gastos_app/features/receipts/ui/pages/receipt_detail_page.dart';
import 'package:gastos_app/features/receipts/ui/receipt_navigation.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';
import 'package:gastos_app/features/transactions/ui/pages/transaction_form_page.dart';

class _MockReceiptsRepository extends Mock implements ReceiptsRepository {}

class _MockTransactionsRepository extends Mock
    implements TransactionsRepository {}

class _MockCategoriesRepository extends Mock implements CategoriesRepository {}

class _MockCreditCardsRepository extends Mock
    implements CreditCardsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockReceiptsRepository receiptsRepo;
  late _MockTransactionsRepository txRepo;
  late _MockCategoriesRepository categoriesRepo;
  late _MockCreditCardsRepository cardsRepo;

  Receipt buildSevenItemReceipt() {
    return Receipt(
      id: 'nf-7-items',
      transactionId: 'tx-nf-1',
      establishmentName: 'Supermercado Muffato',
      establishmentCnpj: '76.430.438/0001-71',
      issueDate: DateTime(2026, 11, 24, 18, 30),
      totalAmount: 135,
      discountAmount: 5,
      paymentMethod: 'PIX',
      createdAt: DateTime(2026, 11, 24, 18, 30),
      items: [
        for (var i = 1; i <= 7; i++)
          ReceiptItem(
            id: 'item-$i',
            receiptId: 'nf-7-items',
            name: 'Produto Comprado $i',
            quantity: i.toDouble(),
            unit: 'UN',
            unitPrice: 5,
            totalPrice: i * 5.0,
            category: 'Alimentação',
            sortOrder: i - 1,
          ),
      ],
    );
  }

  Transaction buildNfTransaction({String? receiptId = 'nf-7-items'}) {
    return Transaction(
      id: 'tx-nf-1',
      userId: 'user-1',
      amount: 135,
      description: 'Supermercado Muffato',
      date: DateTime(2026, 11, 24, 18, 30),
      categoryId: 'cat-1',
      paymentMethod: 'PIX',
      receiptId: receiptId,
      createdAt: DateTime(2026, 11, 24, 18, 30),
      updatedAt: DateTime(2026, 11, 24, 18, 30),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    receiptsRepo = _MockReceiptsRepository();
    txRepo = _MockTransactionsRepository();
    categoriesRepo = _MockCategoriesRepository();
    cardsRepo = _MockCreditCardsRepository();

    when(() => cardsRepo.getCreditCards()).thenAnswer(
      (_) async => const <CreditCardItem>[],
    );
    when(() => categoriesRepo.seedDefaultCategories())
        .thenAnswer((_) async {});
    when(
      () => categoriesRepo.getCategories(
        forceRefresh: any(named: 'forceRefresh'),
      ),
    ).thenAnswer(
      (_) async => const <cat.Category>[
        cat.Category(
          id: 'cat-1',
          name: 'Supermercado',
          color: 0xFFFF6B6B,
          icon: 'shopping_cart',
        ),
      ],
    );
  });

  testWidgets(
      'ReceiptDetailPage exibe todos os itens comprados na NF',
      (tester) async {
    final receipt = buildSevenItemReceipt();
    final tx = buildNfTransaction();
    when(() => receiptsRepo.getReceiptById('nf-7-items'))
        .thenAnswer((_) async => receipt);
    when(() => txRepo.getTransactionById('tx-nf-1'))
        .thenAnswer((_) async => tx);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptsRepositoryProvider.overrideWithValue(receiptsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
          creditCardsRepositoryProvider.overrideWithValue(cardsRepo),
        ],
        child: const MaterialApp(
          home: ReceiptDetailPage(
            receiptId: 'nf-7-items',
            transactionId: 'tx-nf-1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Supermercado Muffato'), findsOneWidget);
    expect(find.text('7 itens'), findsOneWidget);
    for (var i = 1; i <= 7; i++) {
      await tester.scrollUntilVisible(
        find.text('Produto Comprado $i'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Produto Comprado $i'), findsOneWidget);
    }
  });

  testWidgets(
      'TransactionFormPage exibe todos os itens comprados mesmo quando receiptId estava nulo na transacao',
      (tester) async {
    final receipt = buildSevenItemReceipt();
    final txWithoutReceiptId = buildNfTransaction(receiptId: null);
    when(() => txRepo.getTransactionById('tx-nf-1'))
        .thenAnswer((_) async => txWithoutReceiptId);
    when(() => receiptsRepo.getReceiptByTransactionId('tx-nf-1'))
        .thenAnswer((_) async => receipt);
    when(() => receiptsRepo.getReceiptById('nf-7-items'))
        .thenAnswer((_) async => receipt);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptsRepositoryProvider.overrideWithValue(receiptsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
          creditCardsRepositoryProvider.overrideWithValue(cardsRepo),
          notificationPermissionsProvider.overrideWith(
            (_) async => const NotificationPermissions(
              status: NotificationPermissionStatus.granted,
              canScheduleExact: true,
              exactAlarmsSupported: true,
            ),
          ),
        ],
        child: const MaterialApp(
          home: TransactionFormPage(
            transactionId: 'tx-nf-1',
            isEditing: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Itens Comprados na NF (7)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Itens Comprados na NF (7)'), findsOneWidget);
    for (var i = 1; i <= 7; i++) {
      await tester.scrollUntilVisible(
        find.text('Produto Comprado $i'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Produto Comprado $i'), findsOneWidget);
    }
  });

  testWidgets(
      'openTransactionOrReceipt abre os detalhes da NF com os itens comprados ao clicar na transacao',
      (tester) async {
    final receipt = buildSevenItemReceipt();
    final tx = buildNfTransaction(receiptId: null);
    when(() => receiptsRepo.getReceiptByTransactionId('tx-nf-1'))
        .thenAnswer((_) async => receipt);
    when(() => receiptsRepo.getReceiptById('nf-7-items'))
        .thenAnswer((_) async => receipt);
    when(() => txRepo.getTransactionById('tx-nf-1'))
        .thenAnswer((_) async => tx);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => openTransactionOrReceipt(
                  context,
                  ref,
                  transactionId: 'tx-nf-1',
                ),
                child: const Text('Abrir transação NF'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.receiptDetail,
          builder: (context, state) {
            final extra = state.extra! as Map<String, dynamic>;
            return ReceiptDetailPage(
              receiptId: extra['receiptId'] as String?,
              transactionId: extra['transactionId'] as String?,
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptsRepositoryProvider.overrideWithValue(receiptsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
          creditCardsRepositoryProvider.overrideWithValue(cardsRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Abrir transação NF'));
    await tester.pumpAndSettle();

    expect(find.text('Supermercado Muffato'), findsOneWidget);
    expect(find.text('7 itens'), findsOneWidget);
    expect(find.text('Produto Comprado 1'), findsOneWidget);
  });
}
