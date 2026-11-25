import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';

class _FakeDio extends Mock implements Dio {}

class _FakeDioClient extends Mock implements DioClient {}

class _FakeStorage extends Mock implements FlutterSecureStorage {}

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

  test('persiste desconto por item e desconto da nota', () async {
    final receipt = Receipt(
      id: 'r-2',
      transactionId: '',
      establishmentName: 'Mercado Desconto',
      issueDate: DateTime(2026, 11, 21, 9, 0),
      totalAmount: 95.0,
      discountAmount: 5.0,
      paymentMethod: PaymentMethods.pix,
      createdAt: DateTime.now(),
      items: const [
        ReceiptItem(
          id: 'i-1',
          receiptId: 'r-2',
          name: 'Cafe',
          quantity: 1,
          unitPrice: 50.0,
          totalPrice: 45.0,
          discount: 5.0,
          category: ReceiptItemCategorizer.alimentacao,
        ),
        ReceiptItem(
          id: 'i-2',
          receiptId: 'r-2',
          name: 'Leite',
          quantity: 1,
          unitPrice: 55.0,
          totalPrice: 55.0,
          category: ReceiptItemCategorizer.padaria,
        ),
      ],
    );

    final saved = await repo.saveReceiptWithTransaction(
      receipt: receipt,
      categoryId: 'cat-mercado',
      userId: 'user-1',
    );

    expect(saved.transaction.amount, 95.0);

    final loaded = await repo.getReceiptById('r-2');
    expect(loaded, isNotNull);
    expect(loaded!.totalAmount, 95.0);
    expect(loaded.discountAmount, 5.0);
    expect(loaded.items.length, 2);
    expect(loaded.items.first.discount, 5.0);
    expect(loaded.items.first.totalPrice, 45.0);
    expect(loaded.items.last.discount, 0.0);

    // Bruto 105,00 - pago 95,00 = 10,00 de desconto total.
    expect(loaded.itemsGrossTotal, 105.0);
    expect(loaded.discountTotal, 10.0);
  });

  test('salva cupom parcelado em 3x e vincula todas as parcelas ao cupom', () async {
    final receipt = Receipt(
      id: 'r-3',
      transactionId: '',
      establishmentName: 'Supermercado Parcelado',
      issueDate: DateTime(2026, 11, 10, 14, 0),
      totalAmount: 150.0,
      paymentMethod: PaymentMethods.creditCard,
      createdAt: DateTime.now(),
      items: const [
        ReceiptItem(
          id: 'i-31',
          receiptId: 'r-3',
          name: 'Item Caro',
          quantity: 1,
          unitPrice: 150.0,
          totalPrice: 150.0,
          category: ReceiptItemCategorizer.outros,
        ),
      ],
    );

    final saved = await repo.saveReceiptWithTransaction(
      receipt: receipt,
      categoryId: 'cat-mercado',
      userId: 'user-1',
      isInstallment: true,
      totalInstallments: 3,
    );

    expect(saved.transaction.isInstallment, isTrue);
    expect(saved.transaction.totalInstallments, 3);
    expect(saved.transaction.installmentNumber, 1);
    expect(saved.transaction.amount, 50.0);
    expect(saved.transaction.receiptId, 'r-3');

    // Consulta todas as transacoes geradas no banco
    final allTxs = await database.select(database.transactions).get();
    final installments = allTxs.where((t) => t.receiptId == 'r-3').toList();
    expect(installments.length, 3);
    expect(installments[0].installmentNumber, 1);
    expect(installments[1].installmentNumber, 2);
    expect(installments[2].installmentNumber, 3);
    expect(installments[0].amount, 50.0);
    expect(installments[1].amount, 50.0);
    expect(installments[2].amount, 50.0);
    expect(installments[0].installmentGroupId, isNotNull);
    expect(installments[1].installmentGroupId, installments[0].installmentGroupId);
    expect(installments[2].installmentGroupId, installments[0].installmentGroupId);

    // Todas as parcelas devem recuperar o mesmo cupom com os itens
    for (final tx in installments) {
      final loadedFromTx = await repo.getReceiptByTransactionId(tx.id);
      expect(loadedFromTx, isNotNull, reason: 'Falha ao buscar cupom pela parcela ${tx.installmentNumber}');
      expect(loadedFromTx!.id, 'r-3');
      expect(loadedFromTx.items.length, 1);
      expect(loadedFromTx.items.first.name, 'Item Caro');
    }
  });

  test('editar cupom parcelado nao duplica parcelas antigas e limpa excedentes', () async {
    final initial = Receipt(
      id: 'r-edit',
      transactionId: '',
      establishmentName: 'Loja Eletronicos',
      issueDate: DateTime(2026, 11, 12, 10, 0),
      totalAmount: 300.0,
      paymentMethod: PaymentMethods.creditCard,
      createdAt: DateTime.now(),
      items: const [
        ReceiptItem(
          id: 'item-a',
          receiptId: 'r-edit',
          name: 'Fone Bluetooth',
          quantity: 1,
          unitPrice: 300.0,
          totalPrice: 300.0,
          category: ReceiptItemCategorizer.outros,
        ),
      ],
    );

    final firstSave = await repo.saveReceiptWithTransaction(
      receipt: initial,
      categoryId: 'cat-1',
      userId: 'user-1',
      isInstallment: true,
      totalInstallments: 3,
    );

    var linked = await (database.select(database.transactions)
          ..where((t) => t.receiptId.equals('r-edit')))
        .get();
    expect(linked, hasLength(3));

    // Regrava reduzindo de 3x para 2x
    await repo.saveReceiptWithTransaction(
      receipt: firstSave.receipt,
      categoryId: 'cat-1',
      userId: 'user-1',
      isInstallment: true,
      totalInstallments: 2,
    );

    linked = await (database.select(database.transactions)
          ..where((t) => t.receiptId.equals('r-edit')))
        .get();
    expect(linked, hasLength(2));
    expect(linked.map((t) => t.amount), [150.0, 150.0]);

    // Regrava transformando em compra a vista (sem parcelamento)
    await repo.saveReceiptWithTransaction(
      receipt: firstSave.receipt,
      categoryId: 'cat-1',
      userId: 'user-1',
      isInstallment: false,
      totalInstallments: 1,
    );

    linked = await (database.select(database.transactions)
          ..where((t) => t.receiptId.equals('r-edit')))
        .get();
    expect(linked, hasLength(1));
    expect(linked.single.amount, 300.0);
    expect(linked.single.isInstallment, isFalse);
  });

  test('auto-repara receiptId ausente na transacao e limpa cupom ao excluir ultima transacao', () async {
    final dio = _FakeDio();
    final dioClient = _FakeDioClient();
    final storage = _FakeStorage();
    when(() => dioClient.dio).thenReturn(dio);
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'true'); // guest mode evita rede no teste
    final sync = SyncService(
      dioClient: dioClient,
      database: database,
      storage: storage,
    );
    final txRepo = TransactionsRepository(database: database, syncService: sync);
    final receiptRepo = ReceiptsRepository(database: database, syncService: sync);

    final saved = await receiptRepo.saveReceiptWithTransaction(
      receipt: Receipt(
        id: 'r-legacy',
        transactionId: '',
        establishmentName: 'Padaria Central',
        issueDate: DateTime(2026, 11, 15, 8, 0),
        totalAmount: 25.0,
        paymentMethod: PaymentMethods.pix,
        createdAt: DateTime.now(),
        items: const [
          ReceiptItem(
            id: 'item-pao',
            receiptId: 'r-legacy',
            name: 'Pao Frances',
            quantity: 1,
            unitPrice: 25.0,
            totalPrice: 25.0,
            category: ReceiptItemCategorizer.padaria,
          ),
        ],
      ),
      categoryId: 'cat-1',
      userId: 'user-1',
    );

    // Simula transacao antiga sem receiptId preenchido
    await (database.update(database.transactions)
          ..where((t) => t.id.equals(saved.transaction.id)))
        .write(const db.TransactionsCompanion(receiptId: Value(null)));

    final found =
        await receiptRepo.getReceiptByTransactionId(saved.transaction.id);
    expect(found, isNotNull);
    expect(found!.items.single.name, 'Pao Frances');

    final repairedTx = await txRepo.getTransactionById(saved.transaction.id);
    expect(repairedTx?.receiptId, 'r-legacy');

    // Excluir a transacao remove tambem o cupom orfao e seus itens
    await txRepo.deleteTransaction(saved.transaction.id);
    expect(await receiptRepo.getReceiptById('r-legacy'), isNull);
    expect(await database.select(database.receiptItems).get(), isEmpty);
  });
}
