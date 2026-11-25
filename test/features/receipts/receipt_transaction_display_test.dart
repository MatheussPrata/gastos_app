import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/notifications/notification_permission_service.dart';
import 'package:gastos_app/core/notifications/notification_permissions_provider.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/utils/formatters.dart';
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
import 'package:gastos_app/features/receipts/ui/pages/receipt_review_page.dart';
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

  testWidgets(
      'ReceiptDetailPage exibe cupom fiscal digital no tema escuro com descontos por item e resumo completo',
      (tester) async {
    final receiptWithDiscount = Receipt(
      id: 'nf-cupom-1',
      transactionId: 'tx-nf-1',
      establishmentName: 'Supermercado Cupom Real',
      establishmentCnpj: '11.222.333/0001-44',
      issueDate: DateTime(2026, 11, 24, 19, 45),
      totalAmount: 19.0,
      subtotalAmount: 25.0,
      totalDiscount: 6.0,
      discountAmount: 1.0,
      paymentMethod: PaymentMethods.creditCard,
      createdAt: DateTime(2026, 11, 24, 19, 45),
      items: const [
        ReceiptItem(
          id: 'item-d1',
          receiptId: 'nf-cupom-1',
          name: 'Café Torrado Especial',
          quantity: 1,
          unit: 'UN',
          unitPrice: 15.0,
          grossTotal: 15.0,
          discount: 5.0,
          totalPrice: 10.0,
        ),
        ReceiptItem(
          id: 'item-d2',
          receiptId: 'nf-cupom-1',
          name: 'Leite Integral 1L',
          quantity: 2,
          unit: 'UN',
          unitPrice: 5.0,
          grossTotal: 10.0,
          discount: 0.0,
          totalPrice: 10.0,
        ),
      ],
    );

    when(() => receiptsRepo.getReceiptById('nf-cupom-1'))
        .thenAnswer((_) async => receiptWithDiscount);
    when(() => txRepo.getTransactionById('tx-nf-1'))
        .thenAnswer((_) async => buildNfTransaction(receiptId: 'nf-cupom-1'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          receiptsRepositoryProvider.overrideWithValue(receiptsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
          creditCardsRepositoryProvider.overrideWithValue(cardsRepo),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const ReceiptDetailPage(
            receiptId: 'nf-cupom-1',
            transactionId: 'tx-nf-1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('DANFE NFC-e • CUPOM FISCAL DIGITAL'), findsOneWidget);
    expect(find.text('Supermercado Cupom Real'), findsOneWidget);
    expect(find.text('Café Torrado Especial'), findsOneWidget);
    expect(find.text('Leite Integral 1L'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(15.0)), findsOneWidget);
    expect(
      find.text('- ${CurrencyFormatter.format(5.0)} desc.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('VALOR TOTAL PAGO'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Qtd. Total de Itens'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Subtotal (Valor Bruto)'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(25.0)), findsOneWidget);
    expect(find.text('Descontos'), findsOneWidget);
    expect(find.text('- ${CurrencyFormatter.format(6.0)}'), findsOneWidget);
    expect(find.text('VALOR TOTAL PAGO'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(19.0)), findsOneWidget);
  });

  testWidgets(
      'ReceiptReviewPage lista itens individuais com desconto e resumo antes de salvar',
      (tester) async {
    final reviewReceipt = Receipt(
      id: 'nf-review-1',
      transactionId: '',
      establishmentName: 'Farmácia Paraná',
      establishmentCnpj: '22.333.444/0001-55',
      issueDate: DateTime(2026, 11, 25, 10, 15),
      totalAmount: 18.0,
      subtotalAmount: 22.0,
      totalDiscount: 4.0,
      paymentMethod: PaymentMethods.creditCard,
      createdAt: DateTime(2026, 11, 25, 10, 15),
      items: const [
        ReceiptItem(
          id: 'rev-1',
          receiptId: 'nf-review-1',
          name: 'Dipirona 500mg',
          quantity: 2,
          unit: 'UN',
          unitPrice: 11.0,
          grossTotal: 22.0,
          discount: 4.0,
          totalPrice: 18.0,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesRepositoryProvider.overrideWithValue(categoriesRepo),
          creditCardsRepositoryProvider.overrideWithValue(cardsRepo),
          receiptsRepositoryProvider.overrideWithValue(receiptsRepo),
          transactionsRepositoryProvider.overrideWithValue(txRepo),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ReceiptReviewPage(initialReceipt: reviewReceipt),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Dipirona 500mg'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dipirona 500mg'), findsOneWidget);
    expect(
      find.text('- ${CurrencyFormatter.format(4.0)} desc.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('VALOR TOTAL PAGO'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Qtd. Total de Itens'), findsOneWidget);
    expect(find.text('Subtotal (Valor Bruto)'), findsOneWidget);
    expect(find.text('VALOR TOTAL PAGO'), findsOneWidget);
  });
}
