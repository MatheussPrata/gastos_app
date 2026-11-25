import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart'
    show BooleanExpressionOperators, OrderingTerm, Value, countAll;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/storage/secure_storage_config.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';

/// Resultado de uma sincronizacao/restauracao com o servidor.
class SyncOutcome {
  const SyncOutcome({
    this.pushed = 0,
    this.pulled = 0,
    this.failed = 0,
    this.skipped = false,
    this.offline = false,
    this.message,
  });

  /// Registos enviados com sucesso.
  final int pushed;

  /// Registos recebidos do servidor.
  final int pulled;

  /// Registos que o servidor recusou.
  final int failed;

  /// A operacao nao foi executada (modo convidado ou base ja preenchida).
  final bool skipped;

  /// Sem ligacao ao servidor; os dados locais continuam validos.
  final bool offline;

  final String? message;

  bool get hasChanges => pushed > 0 || pulled > 0;

  String get summary {
    if (offline) return 'Sem ligacao ao servidor. Dados locais mantidos.';
    if (skipped && pulled == 0) return message ?? 'Nada para sincronizar.';
    if (failed > 0) {
      return 'Sincronizacao parcial: $pushed enviados, $pulled recebidos, '
          '$failed com erro.';
    }
    if (pulled > 0) {
      return 'Sincronizado: $pulled registos restaurados, $pushed enviados.';
    }
    return 'Sincronizado: $pushed registos enviados.';
  }
}

/// Envio (push) e restauracao (pull) dos dados do utilizador.
///
/// Fonte da verdade continua a ser o SQLite local — o servidor existe para
/// sobreviver a uma desinstalacao ou a um aparelho novo.
class SyncService {
  SyncService({
    DioClient? dioClient,
    db.AppDatabase? database,
    FlutterSecureStorage? storage,
  })  : _dioClient = dioClient ?? DioClient(),
        _db = database ?? db.AppDatabase(),
        _storage = storage ?? SecureStorageConfig.create();

  final DioClient _dioClient;
  final db.AppDatabase _db;
  final FlutterSecureStorage _storage;
  final Uuid _uuid = const Uuid();

  /// Evita dois envios simultaneos (varias telas pedem sync ao mesmo tempo).
  Future<SyncOutcome>? _runningPush;

  // ------------------------------------------------------------------ status

  Future<bool> isGuestMode() async {
    try {
      return await _storage.read(key: StorageKeys.isGuestMode) == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<String> currentUserId() async {
    try {
      return await _storage.read(key: StorageKeys.userId) ?? 'local';
    } catch (_) {
      return 'local';
    }
  }

  Future<int> localTransactionCount() async {
    final count = countAll();
    final query = _db.selectOnly(_db.transactions)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // -------------------------------------------------------------------- push

  /// Envia tudo o que esta pendente: eliminacoes, categorias, subcategorias,
  /// transacoes, recorrentes e planos de orcamento.
  ///
  /// Chamadas concorrentes reaproveitam o envio em curso, evitando duplicar
  /// requisicoes a cada tela aberta.
  Future<SyncOutcome> push() {
    final running = _runningPush;
    if (running != null) return running;

    final future = _pushOnce();
    _runningPush = future;
    return future.whenComplete(() => _runningPush = null);
  }

  Future<SyncOutcome> _pushOnce() async {
    if (await isGuestMode()) {
      return const SyncOutcome(skipped: true, message: 'Modo convidado.');
    }

    var pushed = 0;
    var failed = 0;

    pushed += await _pushDeletions();

    final payload = <String, dynamic>{};

    final categories = await _db.select(_db.categories).get();
    final unsyncedCategories =
        categories.where((c) => !c.isSynced).toList(growable: false);
    if (unsyncedCategories.isNotEmpty) {
      payload['categories'] = [
        for (final c in unsyncedCategories)
          {
            'id': c.id,
            'name': c.name,
            'color': c.color,
            'icon': c.icon,
            'isDefault': c.isDefault,
            'isExpenseDefault': c.isExpenseDefault,
            'sortOrder': c.sortOrder,
          }
      ];
    }

    final subcategories = await _db.select(_db.subcategories).get();
    final unsyncedSubcategories =
        subcategories.where((s) => !s.isSynced).toList(growable: false);
    if (unsyncedSubcategories.isNotEmpty) {
      payload['subcategories'] = [
        for (final s in unsyncedSubcategories)
          {
            'id': s.id,
            'categoryId': s.categoryId,
            'name': s.name,
            'sortOrder': s.sortOrder,
          }
      ];
    }

    final creditCards = await _db.select(_db.creditCards).get();
    final unsyncedCreditCards =
        creditCards.where((c) => !c.isSynced).toList(growable: false);
    if (unsyncedCreditCards.isNotEmpty) {
      payload['creditCards'] = [
        for (final c in unsyncedCreditCards)
          {
            'id': c.id,
            'name': c.name,
            'color': c.color,
            'lastFourDigits': c.lastFourDigits,
            'brand': c.brand,
            'limitAmount': c.limitAmount,
            'closingDay': c.closingDay,
            'dueDay': c.dueDay,
            'isActive': c.isActive,
            'sortOrder': c.sortOrder,
          }
      ];
    }

    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.isSynced.equals(false)))
        .get();
    if (transactions.isNotEmpty) {
      payload['transactions'] = [
        for (final t in transactions) _transactionToJson(t)
      ];
    }

    final recurring = await (_db.select(_db.recurringTransactions)
          ..where((r) => r.isSynced.equals(false)))
        .get();
    if (recurring.isNotEmpty) {
      payload['recurringTransactions'] = [
        for (final r in recurring) _recurringToJson(r)
      ];
    }

    final plans = await (_db.select(_db.budgetPlans)
          ..where((p) => p.isSynced.equals(false)))
        .get();
    if (plans.isNotEmpty) {
      payload['budgetPlans'] = [for (final p in plans) _planToJson(p)];
    }

    final unsyncedReceipts = await (_db.select(_db.receipts)
          ..where((r) => r.isSynced.equals(false)))
        .get();
    if (unsyncedReceipts.isNotEmpty) {
      final serializedReceipts = <Map<String, dynamic>>[];
      for (final r in unsyncedReceipts) {
        final items = await (_db.select(_db.receiptItems)
              ..where((i) => i.receiptId.equals(r.id))
              ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
            .get();
        serializedReceipts.add(_receiptToJson(r, items));
      }
      payload['receipts'] = serializedReceipts;
    }

    if (payload.isEmpty) {
      return SyncOutcome(pushed: pushed, failed: failed);
    }

    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.sync,
        data: payload,
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return SyncOutcome(
          pushed: pushed,
          failed: transactions.length + recurring.length,
          message: 'O servidor recusou a sincronizacao.',
        );
      }

      final data = response.data is Map ? response.data['data'] : null;
      final failedIds = <String>{
        if (data is Map && data['failedIds'] is List)
          for (final id in data['failedIds'] as List) id.toString()
      };

      await _markCategoriesSynced(unsyncedCategories, failedIds);
      await _markSubcategoriesSynced(unsyncedSubcategories, failedIds);
      await _markCreditCardsSynced(unsyncedCreditCards, failedIds);
      await _markTransactionsSynced(transactions, failedIds);
      await _markRecurringSynced(recurring, failedIds);
      await _markPlansSynced(plans, failedIds);
      await _markReceiptsSynced(unsyncedReceipts, failedIds);

      final sent = [
        ...unsyncedCategories.map((c) => c.id),
        ...unsyncedSubcategories.map((s) => s.id),
        ...unsyncedCreditCards.map((c) => c.id),
        ...transactions.map((t) => t.id),
        ...recurring.map((r) => r.id),
        ...plans.map((p) => p.id),
        ...unsyncedReceipts.map((r) => r.id),
      ];
      final rejected = sent.where(failedIds.contains).length;
      pushed += sent.length - rejected;
      failed += rejected;
    } on DioException {
      return SyncOutcome(
        pushed: pushed,
        failed: transactions.length + recurring.length,
        offline: true,
      );
    }

    return SyncOutcome(pushed: pushed, failed: failed);
  }

  Future<void> _markCategoriesSynced(
      List<db.Category> rows, Set<String> failedIds) async {
    for (final c in rows) {
      if (failedIds.contains(c.id)) continue;
      await (_db.update(_db.categories)..where((r) => r.id.equals(c.id)))
          .write(const db.CategoriesCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _markSubcategoriesSynced(
      List<db.Subcategory> rows, Set<String> failedIds) async {
    for (final s in rows) {
      if (failedIds.contains(s.id)) continue;
      await (_db.update(_db.subcategories)..where((r) => r.id.equals(s.id)))
          .write(const db.SubcategoriesCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _markCreditCardsSynced(
      List<db.CreditCard> rows, Set<String> failedIds) async {
    for (final c in rows) {
      if (failedIds.contains(c.id)) continue;
      await (_db.update(_db.creditCards)..where((r) => r.id.equals(c.id)))
          .write(const db.CreditCardsCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _markTransactionsSynced(
      List<db.Transaction> rows, Set<String> failedIds) async {
    for (final t in rows) {
      if (failedIds.contains(t.id)) continue;
      await (_db.update(_db.transactions)..where((r) => r.id.equals(t.id)))
          .write(const db.TransactionsCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _markRecurringSynced(
      List<db.RecurringTransaction> rows, Set<String> failedIds) async {
    for (final r in rows) {
      if (failedIds.contains(r.id)) continue;
      await (_db.update(_db.recurringTransactions)
            ..where((x) => x.id.equals(r.id)))
          .write(const db.RecurringTransactionsCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _markPlansSynced(
      List<db.BudgetPlan> rows, Set<String> failedIds) async {
    for (final p in rows) {
      if (failedIds.contains(p.id)) continue;
      await (_db.update(_db.budgetPlans)..where((x) => x.id.equals(p.id)))
          .write(const db.BudgetPlansCompanion(isSynced: Value(true)));
    }
  }

  Future<void> _markReceiptsSynced(
      List<db.Receipt> rows, Set<String> failedIds) async {
    for (final r in rows) {
      if (failedIds.contains(r.id)) continue;
      await (_db.update(_db.receipts)..where((x) => x.id.equals(r.id)))
          .write(const db.ReceiptsCompanion(isSynced: Value(true)));
      await (_db.update(_db.receiptItems)
            ..where((x) => x.receiptId.equals(r.id)))
          .write(const db.ReceiptItemsCompanion(isSynced: Value(true)));
    }
  }

  /// Aplica no servidor as eliminacoes feitas offline.
  ///
  /// Uma lápide so e removida quando o servidor confirma a eliminacao; caso
  /// contrario fica para a proxima tentativa.
  Future<int> _pushDeletions() async {
    final tombstones = await _db.select(_db.pendingDeletions).get();
    if (tombstones.isEmpty) return 0;

    final payload = [
      for (final tomb in tombstones)
        {'type': tomb.entityType, 'id': tomb.remoteId}
    ];

    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.syncDeletions,
        data: {'deletions': payload},
      );
      if (response.statusCode != 200) return 0;

      final data = response.data is Map ? response.data['data'] : null;
      final failed = <String>{};
      if (data is Map && data['failed'] is List) {
        for (final item in data['failed'] as List) {
          if (item is Map) failed.add('${item['type']}:${item['id']}');
        }
      }

      var applied = 0;
      for (final tomb in tombstones) {
        if (failed.contains('${tomb.entityType}:${tomb.remoteId}')) continue;
        await (_db.delete(_db.pendingDeletions)
              ..where((d) => d.id.equals(tomb.id)))
            .go();
        applied++;
      }
      return applied;
    } on DioException {
      // Offline: as lápides continuam guardadas.
      return 0;
    }
  }

  /// Regista uma eliminacao para ser enviada na proxima sincronizacao.
  ///
  /// Sem isto, uma restauracao traria de volta o que o utilizador apagou.
  Future<void> tombstone(String entityType, String remoteId) async {
    if (await isGuestMode()) return;
    await _db.into(_db.pendingDeletions).insertOnConflictUpdate(
          db.PendingDeletionsCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            remoteId: remoteId,
            createdAt: DateTime.now(),
          ),
        );
  }

  // -------------------------------------------------------------------- pull

  /// Baixa os dados do utilizador a partir do servidor.
  ///
  /// [onlyIfEmpty] evita sobrepor dados locais quando o aparelho ja tem
  /// informacao (ex.: sincronizacao automatica ao abrir a app).
  Future<SyncOutcome> restore({bool onlyIfEmpty = false}) async {
    if (await isGuestMode()) {
      return const SyncOutcome(
        skipped: true,
        message: 'Modo convidado: os dados ficam apenas no aparelho.',
      );
    }

    if (onlyIfEmpty) {
      final hasLocal = await localTransactionCount();
      if (hasLocal > 0) {
        return const SyncOutcome(skipped: true, message: 'Dados locais activos.');
      }
    }

    Map<String, dynamic> data;
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.sync);
      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      if (raw is! Map) {
        return const SyncOutcome(message: 'Resposta invalida do servidor.');
      }
      data = Map<String, dynamic>.from(raw);
    } on DioException {
      return const SyncOutcome(offline: true);
    }

    final userId = await currentUserId();
    final tombstones = await _db.select(_db.pendingDeletions).get();
    final blocked = <String>{
      for (final t in tombstones) '${t.entityType}:${t.remoteId}'
    };

    var pulled = 0;
    pulled += await _restoreCategories(data['categories'], userId, blocked);
    pulled += await _restoreSubcategories(data['subcategories'], userId, blocked);
    pulled += await _restoreCreditCards(data['creditCards'], userId, blocked);
    pulled +=
        await _restoreTransactions(data['transactions'], userId, blocked);
    pulled += await _restoreReceipts(data['receipts'], blocked);
    pulled += await _restoreRecurring(
        data['recurringTransactions'], userId, blocked);
    pulled += await _restorePlans(data['budgetPlans'], userId);

    // Num aparelho novo os lembretes tem de ser reagendados localmente.
    if (pulled > 0) await _rescheduleRestoredReminders();

    return SyncOutcome(pulled: pulled);
  }

  Future<int> _restoreCategories(
      dynamic raw, String userId, Set<String> blocked) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.categories).get()) row.id: row
    };
    var count = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final id = json['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (blocked.contains('category:$id')) continue;

      final name = json['name']?.toString() ?? '';
      if (name.isEmpty) continue;

      final existing = local[id];
      // Categorias locais pendentes de envio sao mais recentes.
      if (existing != null && !existing.isSynced) continue;

      await _db.into(_db.categories).insertOnConflictUpdate(
            db.CategoriesCompanion(
              id: Value(id),
              name: Value(name),
              color: Value(
                  (json['color'] is num) ? (json['color'] as num).toInt() : 0),
              icon: Value(json['icon']?.toString() ?? 'category'),
              isDefault: Value(json['isDefault'] as bool? ?? false),
              isExpenseDefault: Value(json['isExpenseDefault'] as bool? ?? true),
              sortOrder: Value((json['sortOrder'] is num)
                  ? (json['sortOrder'] as num).toInt()
                  : 0),
              isSynced: const Value(true),
            ),
          );
      count++;
    }
    return count;
  }

  Future<int> _restoreSubcategories(
      dynamic raw, String userId, Set<String> blocked) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.subcategories).get()) row.id: row
    };
    var count = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final id = json['id']?.toString();
      final categoryId = json['categoryId']?.toString();
      if (id == null || id.isEmpty || categoryId == null) continue;
      if (blocked.contains('subcategory:$id')) continue;

      final existing = local[id];
      if (existing != null && !existing.isSynced) continue;

      await _db.into(_db.subcategories).insertOnConflictUpdate(
            db.SubcategoriesCompanion(
              id: Value(id),
              categoryId: Value(categoryId),
              name: Value(json['name']?.toString() ?? ''),
              sortOrder: Value((json['sortOrder'] is num)
                  ? (json['sortOrder'] as num).toInt()
                  : 0),
              isSynced: const Value(true),
            ),
          );
      count++;
    }
    return count;
  }

  Future<int> _restoreCreditCards(
      dynamic raw, String userId, Set<String> blocked) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.creditCards).get()) row.id: row
    };
    var count = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final id = json['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (blocked.contains('credit_card:$id') ||
          blocked.contains('creditCard:$id')) continue;

      final existing = local[id];
      if (existing != null && !existing.isSynced) continue;

      await _db.into(_db.creditCards).insertOnConflictUpdate(
            db.CreditCardsCompanion(
              id: Value(id),
              name: Value(json['name']?.toString() ?? ''),
              color: Value((json['color'] is num)
                  ? (json['color'] as num).toInt()
                  : 0),
              lastFourDigits:
                  Value(json['lastFourDigits']?.toString() ?? ''),
              brand: Value(json['brand']?.toString() ?? ''),
              limitAmount: Value(_toDouble(json['limitAmount'])),
              closingDay: Value((json['closingDay'] is num)
                  ? (json['closingDay'] as num).toInt()
                  : 1),
              dueDay: Value((json['dueDay'] is num)
                  ? (json['dueDay'] as num).toInt()
                  : 1),
              isActive: Value(json['isActive'] ?? true),
              sortOrder: Value((json['sortOrder'] is num)
                  ? (json['sortOrder'] as num).toInt()
                  : 0),
              isSynced: const Value(true),
            ),
          );
      count++;
    }
    return count;
  }

  Future<int> _restoreTransactions(
      dynamic raw, String userId, Set<String> blocked) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.transactions).get()) row.id: row
    };
    var count = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final id = json['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (blocked.contains('transaction:$id')) continue;

      final date = DateTime.tryParse(json['date']?.toString() ?? '');
      if (date == null) continue;

      final createdAt =
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? date;
      final updatedAt =
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? createdAt;

      final existing = local[id];
      if (existing != null) {
        // Alteracoes locais ainda nao enviadas ganham.
        if (!existing.isSynced) continue;
        if (!updatedAt.isAfter(existing.updatedAt)) continue;
      }

      final incomingReceiptId = json['receiptId']?.toString();
      final resolvedReceiptId =
          (incomingReceiptId != null && incomingReceiptId.isNotEmpty)
              ? incomingReceiptId
              : existing?.receiptId;

      await _db.into(_db.transactions).insertOnConflictUpdate(
            db.TransactionsCompanion(
              id: Value(id),
              userId: Value(json['userId']?.toString() ?? userId),
              amount: Value(_toDouble(json['amount'])),
              description: Value(json['description']?.toString() ?? ''),
              date: Value(date),
              categoryId: Value(json['categoryId']?.toString()),
              subcategoryId: Value(json['subcategoryId']?.toString()),
              creditCardId: Value(json['creditCardId']?.toString()),
              paymentMethod: Value(json['paymentMethod']?.toString() ?? ''),
              isExpense: Value(json['isExpense'] as bool? ?? true),
              isInstallment: Value(json['isInstallment'] as bool? ?? false),
              installmentNumber:
                  Value(json['installmentNumber'] as int? ?? 1),
              totalInstallments:
                  Value(json['totalInstallments'] as int? ?? 1),
              installmentGroupId:
                  Value(json['installmentGroupId']?.toString()),
              notes: Value(json['notes']?.toString()),
              ownerId: Value(json['ownerId']?.toString()),
              partnerSynced: Value(json['partnerSynced'] as bool? ?? false),
              reminderEnabled:
                  Value(json['reminderEnabled'] as bool? ?? false),
              receiptId: Value(resolvedReceiptId),
              createdAt: Value(createdAt),
              updatedAt: Value(updatedAt),
              isSynced: const Value(true),
            ),
          );
      count++;
    }
    return count;
  }

  Future<int> _restoreReceipts(dynamic raw, Set<String> blocked) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.receipts).get()) row.id: row
    };
    var count = 0;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final json = Map<String, dynamic>.from(entry);
      final id = json['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (blocked.contains('receipt:$id')) continue;

      final existing = local[id];
      if (existing != null && !existing.isSynced) continue;

      final issueDate =
          DateTime.tryParse(json['issueDate']?.toString() ?? '') ??
              DateTime.now();
      final createdAt =
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? issueDate;
      final updatedAt = _optionalDate(json['updatedAt']) ?? createdAt;
      final transactionId = json['transactionId']?.toString() ?? '';
      final totalAmount = _toDouble(json['totalAmount']);
      final discountAmount = _toDouble(json['discountAmount']);
      final rawItems = json['items'];

      var itemsGrossSum = 0.0;
      if (rawItems is List) {
        for (final itemRaw in rawItems) {
          if (itemRaw is! Map) continue;
          final gross = _toDouble(itemRaw['grossTotal']);
          if (gross > 0) {
            itemsGrossSum += gross;
          } else {
            itemsGrossSum +=
                _toDouble(itemRaw['totalPrice']) + _toDouble(itemRaw['discount']);
          }
        }
      }
      final rawSubtotal = _toDouble(json['subtotalAmount']);
      final subtotalAmount = rawSubtotal > 0
          ? rawSubtotal
          : (itemsGrossSum > 0 ? itemsGrossSum : totalAmount + discountAmount);
      final rawTotalDiscount = _toDouble(json['totalDiscount']);
      final totalDiscount = rawTotalDiscount > 0
          ? rawTotalDiscount
          : (subtotalAmount > totalAmount
              ? subtotalAmount - totalAmount
              : discountAmount);

      await _db.transaction(() async {
        await _db.into(_db.receipts).insertOnConflictUpdate(
              db.ReceiptsCompanion(
                id: Value(id),
                transactionId: Value(transactionId),
                establishmentName:
                    Value(json['establishmentName']?.toString() ?? ''),
                establishmentCnpj:
                    Value(json['establishmentCnpj']?.toString() ?? ''),
                issueDate: Value(issueDate),
                totalAmount: Value(totalAmount),
                subtotalAmount: Value(subtotalAmount),
                totalDiscount: Value(totalDiscount < 0 ? 0.0 : totalDiscount),
                discountAmount: Value(discountAmount),
                paymentMethod: Value(json['paymentMethod']?.toString() ?? ''),
                accessKey: Value(json['accessKey']?.toString()),
                rawUrl: Value(json['rawUrl']?.toString()),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
                isSynced: const Value(true),
              ),
            );

        await (_db.delete(_db.receiptItems)
              ..where((i) => i.receiptId.equals(id)))
            .go();

        if (rawItems is List) {
          for (var idx = 0; idx < rawItems.length; idx++) {
            final itemRaw = rawItems[idx];
            if (itemRaw is! Map) continue;
            final item = Map<String, dynamic>.from(itemRaw);
            final itemId = item['id']?.toString();
            final itemNet = _toDouble(item['totalPrice']);
            final itemDiscount = _toDouble(item['discount']);
            final rawItemGross = _toDouble(item['grossTotal']);
            final itemGross =
                rawItemGross > 0 ? rawItemGross : itemNet + itemDiscount;
            await _db.into(_db.receiptItems).insert(
                  db.ReceiptItemsCompanion(
                    id: Value(
                      (itemId != null && itemId.isNotEmpty)
                          ? itemId
                          : _uuid.v4(),
                    ),
                    receiptId: Value(id),
                    name: Value(item['name']?.toString() ?? ''),
                    code: Value(item['code']?.toString()),
                    quantity: Value(
                      item['quantity'] == null
                          ? 1.0
                          : _toDouble(item['quantity']),
                    ),
                    unit: Value(item['unit']?.toString() ?? 'UN'),
                    unitPrice: Value(_toDouble(item['unitPrice'])),
                    grossTotal: Value(itemGross),
                    totalPrice: Value(itemNet),
                    discount: Value(itemDiscount),
                    category: Value(item['category']?.toString() ?? 'Outros'),
                    sortOrder: Value(
                      (item['sortOrder'] is num)
                          ? (item['sortOrder'] as num).toInt()
                          : idx,
                    ),
                    createdAt: Value(_optionalDate(item['createdAt']) ?? createdAt),
                    updatedAt: Value(_optionalDate(item['updatedAt']) ?? updatedAt),
                    isSynced: const Value(true),
                  ),
                );
          }
        }

        if (transactionId.isNotEmpty) {
          await (_db.update(_db.transactions)
                ..where(
                  (t) =>
                      t.id.equals(transactionId) &
                      (t.receiptId.isNull() | t.receiptId.equals('')),
                ))
              .write(db.TransactionsCompanion(receiptId: Value(id)));
        }
      });
      count++;
    }
    return count;
  }

  Future<int> _restoreRecurring(
      dynamic raw, String userId, Set<String> blocked) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.recurringTransactions).get())
        row.id: row
    };
    var count = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final id = json['id']?.toString();
      if (id == null || id.isEmpty) continue;
      if (blocked.contains('recurring:$id')) continue;

      final startDate = DateTime.tryParse(json['startDate']?.toString() ?? '');
      final nextDueDate =
          DateTime.tryParse(json['nextDueDate']?.toString() ?? '');
      if (startDate == null || nextDueDate == null) continue;

      final existing = local[id];
      if (existing != null && !existing.isSynced) continue;

      await _db.into(_db.recurringTransactions).insertOnConflictUpdate(
            db.RecurringTransactionsCompanion(
              id: Value(id),
              userId: Value(json['userId']?.toString() ?? userId),
              description: Value(json['description']?.toString() ?? ''),
              amount: Value(_toDouble(json['amount'])),
              type: Value(json['type']?.toString() ?? 'expense'),
              categoryId: Value(json['categoryId']?.toString()),
              subcategoryId: Value(json['subcategoryId']?.toString()),
              creditCardId: Value(json['creditCardId']?.toString()),
              frequency: Value(json['frequency']?.toString() ?? 'monthly'),
              dayOfMonth: Value(json['dayOfMonth'] as int? ?? 1),
              startDate: Value(startDate),
              endDate: Value(_optionalDate(json['endDate'])),
              isActive: Value(json['isActive'] as bool? ?? true),
              nextDueDate: Value(nextDueDate),
              lastGeneratedAt:
                  Value(_optionalDate(json['lastGeneratedAt'])),
              createdAt: Value(
                  DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                      startDate),
              isSynced: const Value(true),
            ),
          );
      count++;
    }
    return count;
  }

  /// Planos individuais voltam para o aparelho; os do casal vem do parceiro.
  Future<int> _restorePlans(dynamic raw, String userId) async {
    if (raw is! List) return 0;
    final local = {
      for (final row in await _db.select(_db.budgetPlans).get())
        '${row.month.toIso8601String().substring(0, 7)}:${row.scope}': row
    };
    var count = 0;
    for (final item in raw) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final month = DateTime.tryParse(json['month']?.toString() ?? '');
      if (month == null) continue;

      final scope = json['scope']?.toString() == 'couple' ? 'couple' : 'individual';
      final updatedAt =
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
              DateTime.now();
      final key =
          '${month.toIso8601String().substring(0, 7)}:$scope';
      final existing = local[key];

      if (existing != null) {
        if (!existing.isSynced) continue;
        if (!updatedAt.isAfter(existing.updatedAt)) continue;
      }

      final normalized = DateTime(month.year, month.month, 1);
      final id = (existing?.id ?? json['id']?.toString() ?? '')
          .trim();
      await _db.into(_db.budgetPlans).insertOnConflictUpdate(
            db.BudgetPlansCompanion(
              id: Value(id.isEmpty ? _uuid.v4() : id),
              userId: Value(userId),
              month: Value(normalized),
              scope: Value(scope),
              incomeMode: Value(json['incomeMode']?.toString() ?? 'manual'),
              manualIncome: Value(_toDouble(json['manualIncome'])),
              monthlyBudget: Value(_toDouble(json['monthlyBudget'])),
              categoriesJson:
                  Value(_jsonString(json['categories'], fallback: '[]')),
              notificationsJson:
                  Value(_jsonString(json['notifications'], fallback: '{}')),
              createdAt: Value(
                  DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                      normalized),
              updatedAt: Value(updatedAt),
              isSynced: const Value(true),
            ),
          );
      count++;
    }
    return count;
  }

  /// Reagenda no sistema operativo os lembretes restaurados do servidor.
  Future<void> _rescheduleRestoredReminders() async {
    try {
      await TransactionReminderService.instance.syncAllFromDatabase(_db);
    } catch (_) {
      // Um lembrete que falha nao impede o restauro dos dados.
    }
  }

  // --------------------------------------------------------------- helpers

  Map<String, dynamic> _transactionToJson(db.Transaction t) => {
        'id': t.id,
        'userId': t.userId,
        'amount': t.amount,
        'description': t.description,
        'date': t.date.toIso8601String(),
        'categoryId': t.categoryId,
        'subcategoryId': t.subcategoryId,
        'creditCardId': t.creditCardId,
        'paymentMethod': t.paymentMethod,
        'isExpense': t.isExpense,
        'isInstallment': t.isInstallment,
        'installmentNumber': t.installmentNumber,
        'totalInstallments': t.totalInstallments,
        'installmentGroupId': t.installmentGroupId,
        'notes': t.notes,
        'ownerId': t.ownerId,
        'partnerSynced': t.partnerSynced,
        'reminderEnabled': t.reminderEnabled,
        'receiptId': t.receiptId,
        'createdAt': t.createdAt.toIso8601String(),
        'updatedAt': t.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _receiptToJson(
    db.Receipt r,
    List<db.ReceiptItem> items,
  ) =>
      {
        'id': r.id,
        'transactionId': r.transactionId,
        'establishmentName': r.establishmentName,
        'establishmentCnpj': r.establishmentCnpj,
        'issueDate': r.issueDate.toIso8601String(),
        'totalAmount': r.totalAmount,
        'subtotalAmount': r.subtotalAmount,
        'totalDiscount': r.totalDiscount,
        'discountAmount': r.discountAmount,
        'paymentMethod': r.paymentMethod,
        'accessKey': r.accessKey,
        'rawUrl': r.rawUrl,
        'createdAt': r.createdAt.toIso8601String(),
        'updatedAt': (r.updatedAt ?? r.createdAt).toIso8601String(),
        'items': [
          for (final item in items)
            {
              'id': item.id,
              'receiptId': item.receiptId,
              'name': item.name,
              'code': item.code,
              'quantity': item.quantity,
              'unit': item.unit,
              'unitPrice': item.unitPrice,
              'grossTotal': item.grossTotal,
              'totalPrice': item.totalPrice,
              'discount': item.discount,
              'category': item.category,
              'sortOrder': item.sortOrder,
              'createdAt': item.createdAt?.toIso8601String(),
              'updatedAt': item.updatedAt?.toIso8601String(),
            },
        ],
      };

  Map<String, dynamic> _recurringToJson(db.RecurringTransaction r) => {
        'id': r.id,
        'userId': r.userId,
        'description': r.description,
        'amount': r.amount,
        'type': r.type,
        'categoryId': r.categoryId,
        'subcategoryId': r.subcategoryId,
        'creditCardId': r.creditCardId,
        'frequency': r.frequency,
        'dayOfMonth': r.dayOfMonth,
        'startDate': r.startDate.toIso8601String(),
        'endDate': r.endDate?.toIso8601String(),
        'isActive': r.isActive,
        'nextDueDate': r.nextDueDate.toIso8601String(),
        'lastGeneratedAt': r.lastGeneratedAt?.toIso8601String(),
        'createdAt': r.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _planToJson(db.BudgetPlan p) => {
        'id': p.id,
        'userId': p.userId,
        'month': p.month.toIso8601String(),
        'scope': p.scope,
        'incomeMode': p.incomeMode,
        'manualIncome': p.manualIncome,
        'monthlyBudget': p.monthlyBudget,
        'categories': _decodeJson(p.categoriesJson, fallback: const []),
        'notifications': _decodeJson(p.notificationsJson, fallback: const {}),
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
      };

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _optionalDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static dynamic _decodeJson(String raw, {required dynamic fallback}) {
    if (raw.trim().isEmpty) return fallback;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return fallback;
    }
  }

  static String _jsonString(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    if (value is String) return value.trim().isEmpty ? fallback : value;
    return jsonEncode(value);
  }
}
