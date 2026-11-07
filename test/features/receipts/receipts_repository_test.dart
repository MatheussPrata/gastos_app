import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ReceiptsRepository repo;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repo = ReceiptsRepository(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('salva cupom com transacao e recupera itens e resumo por categorias', () async {
    final receipt = Receipt(
      id: 'r-1',
      transactionId: '',
      establishmentName: 'Supermercado Teste',
      establishmentCnpj: '12.345.678/0001-90',
      issueDate: DateTime(2026, 11, 7, 10, 0),
      totalAmount: 120.0,
      paymentMethod: PaymentMethods.creditCard,
      createdAt: DateTime.now(),
      items: const [
        ReceiptItem(
          id: 'i-1',
          receiptId: 'r-1',
          name: 'Carne Alcatra',
          quantity: 1,
          unit: 'KG',
          unitPrice: 50.0,
          totalPrice: 50.0,
          category: ReceiptItemCategorizer.acougue,
        ),
        ReceiptItem(
          id: 'i-2',
          receiptId: 'r-1',
          name: 'Detergente Ype',
          quantity: 2,
          unit: 'UN',
          unitPrice: 3.0,
          totalPrice: 6.0,
          category: ReceiptItemCategorizer.limpeza,
        ),
        ReceiptItem(
          id: 'i-3',
          receiptId: 'r-1',
          name: 'Picanha Bovina',
          quantity: 1,
          unit: 'KG',
          unitPrice: 64.0,
          totalPrice: 64.0,
          category: ReceiptItemCategorizer.acougue,
        ),
      ],
    );

    final saved = await repo.saveReceiptWithTransaction(
      receipt: receipt,
      categoryId: 'cat-mercado',
      userId: 'user-1',
    );

    expect(saved.transaction.amount, 120.0);
    expect(saved.transaction.receiptId, 'r-1');
    expect(saved.transaction.categoryId, 'cat-mercado');

    // Recupera pelo ID da transacao
    final loaded = await repo.getReceiptByTransactionId(saved.transaction.id);
    expect(loaded, isNotNull);
    expect(loaded!.establishmentName, 'Supermercado Teste');
    expect(loaded.items.length, 3);

    // Resumo por categoria
    final summaries = ReceiptsRepository.getCategorySummaries(loaded);
    expect(summaries.length, 2);

    // Acougue: 50 + 64 = 114
    final acougueSummary = summaries.firstWhere(
      (s) => s.category == ReceiptItemCategorizer.acougue,
    );
    expect(acougueSummary.totalAmount, 114.0);
    expect(acougueSummary.itemCount, 2);

    // Limpeza: 6
    final limpezaSummary = summaries.firstWhere(
      (s) => s.category == ReceiptItemCategorizer.limpeza,
    );
    expect(limpezaSummary.totalAmount, 6.0);
    expect(limpezaSummary.itemCount, 1);
  });
}
