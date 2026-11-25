import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/transactions/services/transaction_reminder_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

/// Erro lancado quando o JSON de backup nao corresponde ao formato esperado.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Metadados de um arquivo de backup salvo localmente no aparelho.
class BackupFileInfo {
  const BackupFileInfo({
    required this.file,
    required this.fileName,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final File file;
  final String fileName;
  final DateTime modifiedAt;
  final int sizeBytes;
}

/// Resultado de uma restauracao de backup completo.
class BackupRestoreResult {
  const BackupRestoreResult({
    this.categories = 0,
    this.subcategories = 0,
    this.creditCards = 0,
    this.transactions = 0,
    this.receipts = 0,
    this.recurringTransactions = 0,
    this.budgetPlans = 0,
    this.budgetAlerts = 0,
    this.goals = 0,
    this.appSettings = 0,
  });

  final int categories;
  final int subcategories;
  final int creditCards;
  final int transactions;
  final int receipts;
  final int recurringTransactions;
  final int budgetPlans;
  final int budgetAlerts;
  final int goals;
  final int appSettings;

  int get totalRecords =>
      categories +
      subcategories +
      creditCards +
      transactions +
      receipts +
      recurringTransactions +
      budgetPlans +
      budgetAlerts +
      goals +
      appSettings;

  String get summary =>
      'Restaurado: $transactions transações, $creditCards cartões, '
      '$goals metas e $categories categorias ($totalRecords registros).';
}

/// Exportacao e restauracao completa dos dados locais em arquivo JSON versionado.
class BackupService {
  BackupService({
    db.AppDatabase? database,
    SyncService? syncService,
    Future<Directory> Function()? documentsDirProvider,
  })  : _db = database ?? db.AppDatabase(),
        _sync = syncService ?? SyncService(),
        _documentsDirProvider =
            documentsDirProvider ?? getApplicationDocumentsDirectory;

  final db.AppDatabase _db;
  final SyncService _sync;
  final Future<Directory> Function() _documentsDirProvider;

  static const Uuid _uuid = Uuid();
  static const int currentBackupVersion = 1;
  static const int currentSchemaVersion = 13;

  Future<Map<String, dynamic>> buildBackupMap() async {
    final categories = await _db.select(_db.categories).get();
    final subcategories = await _db.select(_db.subcategories).get();
    final creditCards = await _db.select(_db.creditCards).get();
    final transactions = await _db.select(_db.transactions).get();
    final receipts = await _db.select(_db.receipts).get();
    final receiptItems = await _db.select(_db.receiptItems).get();
    final recurring = await _db.select(_db.recurringTransactions).get();
    final budgetPlans = await _db.select(_db.budgetPlans).get();
    final budgetAlerts = await _db.select(_db.budgetAlerts).get();
    final goals = await _db.select(_db.goals).get();
    final appSettings = await _db.select(_db.appSettings).get();

    final itemsByReceipt = <String, List<db.ReceiptItem>>{};
    for (final item in receiptItems) {
      itemsByReceipt.putIfAbsent(item.receiptId, () => []).add(item);
    }
    for (final list in itemsByReceipt.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return {
      'app': 'kuanto',
      'version': currentBackupVersion,
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'data': {
        'categories': [
          for (final c in categories)
            {
              'id': c.id,
              'name': c.name,
              'color': c.color,
              'icon': c.icon,
              'isDefault': c.isDefault,
              'isExpenseDefault': c.isExpenseDefault,
              'sortOrder': c.sortOrder,
            },
        ],
        'subcategories': [
          for (final s in subcategories)
            {
              'id': s.id,
              'categoryId': s.categoryId,
              'name': s.name,
              'sortOrder': s.sortOrder,
            },
        ],
        'creditCards': [
          for (final c in creditCards)
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
            },
        ],
        'transactions': [
          for (final t in transactions)
            {
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
            },
        ],
        'receipts': [
          for (final r in receipts)
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
                for (final item in itemsByReceipt[r.id] ?? const <db.ReceiptItem>[])
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
            },
        ],
        'recurringTransactions': [
          for (final r in recurring)
            {
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
            },
        ],
        'budgetPlans': [
          for (final pRow in budgetPlans)
            {
              'id': pRow.id,
              'userId': pRow.userId,
              'month': pRow.month.toIso8601String(),
              'scope': pRow.scope,
              'incomeMode': pRow.incomeMode,
              'manualIncome': pRow.manualIncome,
              'monthlyBudget': pRow.monthlyBudget,
              'categories': _decodeJson(pRow.categoriesJson, fallback: const []),
              'notifications':
                  _decodeJson(pRow.notificationsJson, fallback: const {}),
              'createdAt': pRow.createdAt.toIso8601String(),
              'updatedAt': pRow.updatedAt.toIso8601String(),
            },
        ],
        'budgetAlerts': [
          for (final a in budgetAlerts)
            {
              'id': a.id,
              'planId': a.planId,
              'categoryId': a.categoryId,
              'categoryName': a.categoryName,
              'scope': a.scope,
              'threshold': a.threshold,
              'spentAmount': a.spentAmount,
              'allocatedAmount': a.allocatedAmount,
              'triggeredAt': a.triggeredAt.toIso8601String(),
              'read': a.read,
              'dismissed': a.dismissed,
            },
        ],
        'goals': [
          for (final g in goals)
            {
              'id': g.id,
              'name': g.name,
              'targetAmount': g.targetAmount,
              'savedAmount': g.savedAmount,
              'targetDate': g.targetDate?.toIso8601String(),
              'color': g.color,
              'isArchived': g.isArchived,
              'createdAt': g.createdAt.toIso8601String(),
              'updatedAt': (g.updatedAt ?? g.createdAt).toIso8601String(),
            },
        ],
        'appSettings': [
          for (final s in appSettings)
            {
              'key': s.key,
              'value': s.value,
            },
        ],
      },
    };
  }

  Future<String> buildBackupJson({bool pretty = false}) async {
    final map = await buildBackupMap();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  Future<Directory> _backupsDirectory({Directory? directory}) async {
    final base = directory ?? await _documentsDirProvider();
    final dir = Directory(p.join(base.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> createLocalBackupFile({Directory? directory}) async {
    final dir = await _backupsDirectory(directory: directory);
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final fileName = 'kuanto-backup-$stamp.json';
    final file = File(p.join(dir.path, fileName));
    final content = await buildBackupJson(pretty: true);
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  Future<File> exportAndShareBackup({Directory? directory}) async {
    final file = await createLocalBackupFile(directory: directory);
    final fileName = p.basename(file.path);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Backup Kuanto',
      text: 'Backup completo dos dados do Kuanto',
      fileNameOverrides: [fileName],
    );
    return file;
  }

  Future<List<BackupFileInfo>> listLocalBackups({Directory? directory}) async {
    final dir = await _backupsDirectory(directory: directory);
    if (!await dir.exists()) return const [];
    final entries = await dir.list().toList();
    final backups = <BackupFileInfo>[];
    for (final entity in entries) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      final stat = await entity.stat();
      backups.add(
        BackupFileInfo(
          file: entity,
          fileName: p.basename(entity.path),
          modifiedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    backups.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return backups;
  }

  Future<void> deleteLocalBackup(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<BackupRestoreResult> restoreFromFile(
    File file, {
    bool replaceExisting = true,
  }) async {
    final content = await file.readAsString(encoding: utf8);
    return restoreFromJsonString(content, replaceExisting: replaceExisting);
  }

  Future<BackupRestoreResult> restoreFromJsonString(
    String rawJson, {
    bool replaceExisting = true,
  }) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(rawJson.trim());
    } catch (_) {
      throw const BackupFormatException(
        'Arquivo inválido: não é um JSON válido.',
      );
    }

    if (decoded is! Map) {
      throw const BackupFormatException(
        'Formato inválido: o backup deve ser um objeto JSON.',
      );
    }

    if (decoded['app'] != 'kuanto' || decoded['data'] is! Map) {
      throw const BackupFormatException(
        'Formato incompatível: este JSON não é um backup válido do Kuanto.',
      );
    }

    final data = Map<String, dynamic>.from(decoded['data'] as Map);
    final currentUserId = await _sync.currentUserId();
    final fallbackUserId = currentUserId.isEmpty ? 'local' : currentUserId;

    var categoriesCount = 0;
    var subcategoriesCount = 0;
    var cardsCount = 0;
    var transactionsCount = 0;
    var receiptsCount = 0;
    var recurringCount = 0;
    var plansCount = 0;
    var alertsCount = 0;
    var goalsCount = 0;
    var settingsCount = 0;

    await _db.transaction(() async {
      if (replaceExisting) {
        await _db.delete(_db.receiptItems).go();
        await _db.delete(_db.receipts).go();
        await _db.delete(_db.goals).go();
        await _db.delete(_db.budgetAlerts).go();
        await _db.delete(_db.budgetPlans).go();
        await _db.delete(_db.transactions).go();
        await _db.delete(_db.recurringTransactions).go();
        await _db.delete(_db.categories).go();
        await _db.delete(_db.subcategories).go();
        await _db.delete(_db.creditCards).go();
        await _db.delete(_db.appSettings).go();
        await _db.delete(_db.pendingDeletions).go();
      }

      for (final raw in _listFrom(data['categories'])) {
        final id = raw['id']?.toString();
        final name = raw['name']?.toString() ?? '';
        if (id == null || id.isEmpty || name.isEmpty) continue;
        await _db.into(_db.categories).insertOnConflictUpdate(
              db.CategoriesCompanion(
                id: Value(id),
                name: Value(name),
                color: Value(_toInt(raw['color'], fallback: 0)),
                icon: Value(raw['icon']?.toString() ?? 'category'),
                isDefault: Value(raw['isDefault'] as bool? ?? false),
                isExpenseDefault: Value(raw['isExpenseDefault'] as bool? ?? true),
                sortOrder: Value(_toInt(raw['sortOrder'], fallback: 0)),
                isSynced: const Value(false),
              ),
            );
        categoriesCount++;
      }

      for (final raw in _listFrom(data['subcategories'])) {
        final id = raw['id']?.toString();
        final categoryId = raw['categoryId']?.toString();
        if (id == null || id.isEmpty || categoryId == null) continue;
        await _db.into(_db.subcategories).insertOnConflictUpdate(
              db.SubcategoriesCompanion(
                id: Value(id),
                categoryId: Value(categoryId),
                name: Value(raw['name']?.toString() ?? ''),
                sortOrder: Value(_toInt(raw['sortOrder'], fallback: 0)),
                isSynced: const Value(false),
              ),
            );
        subcategoriesCount++;
      }

      for (final raw in _listFrom(data['creditCards'])) {
        final id = raw['id']?.toString();
        if (id == null || id.isEmpty) continue;
        await _db.into(_db.creditCards).insertOnConflictUpdate(
              db.CreditCardsCompanion(
                id: Value(id),
                name: Value(raw['name']?.toString() ?? ''),
                color: Value(_toInt(raw['color'], fallback: 0)),
                lastFourDigits: Value(raw['lastFourDigits']?.toString() ?? ''),
                brand: Value(raw['brand']?.toString() ?? ''),
                limitAmount: Value(_toDouble(raw['limitAmount'])),
                closingDay: Value(_toInt(raw['closingDay'], fallback: 1)),
                dueDay: Value(_toInt(raw['dueDay'], fallback: 1)),
                isActive: Value(raw['isActive'] as bool? ?? true),
                sortOrder: Value(_toInt(raw['sortOrder'], fallback: 0)),
                isSynced: const Value(false),
              ),
            );
        cardsCount++;
      }

      for (final raw in _listFrom(data['transactions'])) {
        final id = raw['id']?.toString();
        final date = _optionalDate(raw['date']);
        if (id == null || id.isEmpty || date == null) continue;
        final createdAt = _optionalDate(raw['createdAt']) ?? date;
        final updatedAt = _optionalDate(raw['updatedAt']) ?? createdAt;
        final rawUserId = raw['userId']?.toString();
        await _db.into(_db.transactions).insertOnConflictUpdate(
              db.TransactionsCompanion(
                id: Value(id),
                userId: Value((rawUserId != null && rawUserId.isNotEmpty)
                    ? rawUserId
                    : fallbackUserId),
                amount: Value(_toDouble(raw['amount'])),
                description: Value(raw['description']?.toString() ?? ''),
                date: Value(date),
                categoryId: Value(raw['categoryId']?.toString()),
                subcategoryId: Value(raw['subcategoryId']?.toString()),
                creditCardId: Value(raw['creditCardId']?.toString()),
                paymentMethod: Value(raw['paymentMethod']?.toString() ?? ''),
                isExpense: Value(raw['isExpense'] as bool? ?? true),
                isInstallment: Value(raw['isInstallment'] as bool? ?? false),
                installmentNumber:
                    Value(_toInt(raw['installmentNumber'], fallback: 1)),
                totalInstallments:
                    Value(_toInt(raw['totalInstallments'], fallback: 1)),
                installmentGroupId:
                    Value(raw['installmentGroupId']?.toString()),
                notes: Value(raw['notes']?.toString()),
                ownerId: Value(raw['ownerId']?.toString()),
                partnerSynced: Value(raw['partnerSynced'] as bool? ?? false),
                reminderEnabled:
                    Value(raw['reminderEnabled'] as bool? ?? false),
                receiptId: Value(raw['receiptId']?.toString()),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
                isSynced: const Value(false),
              ),
            );
        transactionsCount++;
      }

      for (final raw in _listFrom(data['receipts'])) {
        final id = raw['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final issueDate = _optionalDate(raw['issueDate']) ?? DateTime.now();
        final createdAt = _optionalDate(raw['createdAt']) ?? issueDate;
        final updatedAt = _optionalDate(raw['updatedAt']) ?? createdAt;
        final totalAmount = _toDouble(raw['totalAmount']);
        final discountAmount = _toDouble(raw['discountAmount']);
        final subtotalRaw = _toDouble(raw['subtotalAmount']);
        final totalDiscountRaw = _toDouble(raw['totalDiscount']);
        final subtotalAmount =
            subtotalRaw > 0 ? subtotalRaw : totalAmount + discountAmount;
        final totalDiscount = totalDiscountRaw > 0
            ? totalDiscountRaw
            : (subtotalAmount > totalAmount
                ? subtotalAmount - totalAmount
                : discountAmount);

        await _db.into(_db.receipts).insertOnConflictUpdate(
              db.ReceiptsCompanion(
                id: Value(id),
                transactionId: Value(raw['transactionId']?.toString() ?? ''),
                establishmentName:
                    Value(raw['establishmentName']?.toString() ?? ''),
                establishmentCnpj:
                    Value(raw['establishmentCnpj']?.toString() ?? ''),
                issueDate: Value(issueDate),
                totalAmount: Value(totalAmount),
                subtotalAmount: Value(subtotalAmount),
                totalDiscount: Value(totalDiscount < 0 ? 0.0 : totalDiscount),
                discountAmount: Value(discountAmount),
                paymentMethod: Value(raw['paymentMethod']?.toString() ?? ''),
                accessKey: Value(raw['accessKey']?.toString()),
                rawUrl: Value(raw['rawUrl']?.toString()),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
                isSynced: const Value(false),
              ),
            );

        await (_db.delete(_db.receiptItems)
              ..where((i) => i.receiptId.equals(id)))
            .go();
        final items = raw['items'];
        if (items is List) {
          for (var idx = 0; idx < items.length; idx++) {
            final itemRaw = items[idx];
            if (itemRaw is! Map) continue;
            final item = Map<String, dynamic>.from(itemRaw);
            final itemId = item['id']?.toString();
            final net = _toDouble(item['totalPrice']);
            final discount = _toDouble(item['discount']);
            final grossRaw = _toDouble(item['grossTotal']);
            final gross = grossRaw > 0 ? grossRaw : net + discount;
            await _db.into(_db.receiptItems).insert(
                  db.ReceiptItemsCompanion(
                    id: Value((itemId != null && itemId.isNotEmpty)
                        ? itemId
                        : _uuid.v4()),
                    receiptId: Value(id),
                    name: Value(item['name']?.toString() ?? ''),
                    code: Value(item['code']?.toString()),
                    quantity: Value(item['quantity'] == null
                        ? 1.0
                        : _toDouble(item['quantity'])),
                    unit: Value(item['unit']?.toString() ?? 'UN'),
                    unitPrice: Value(_toDouble(item['unitPrice'])),
                    grossTotal: Value(gross),
                    totalPrice: Value(net),
                    discount: Value(discount),
                    category: Value(item['category']?.toString() ?? 'Outros'),
                    sortOrder: Value(_toInt(item['sortOrder'], fallback: idx)),
                    createdAt:
                        Value(_optionalDate(item['createdAt']) ?? createdAt),
                    updatedAt:
                        Value(_optionalDate(item['updatedAt']) ?? updatedAt),
                    isSynced: const Value(false),
                  ),
                );
          }
        }
        receiptsCount++;
      }

      for (final raw in _listFrom(data['recurringTransactions'])) {
        final id = raw['id']?.toString();
        final startDate = _optionalDate(raw['startDate']);
        final nextDueDate = _optionalDate(raw['nextDueDate']);
        if (id == null || id.isEmpty || startDate == null || nextDueDate == null) {
          continue;
        }
        final rawUserId = raw['userId']?.toString();
        await _db.into(_db.recurringTransactions).insertOnConflictUpdate(
              db.RecurringTransactionsCompanion(
                id: Value(id),
                userId: Value((rawUserId != null && rawUserId.isNotEmpty)
                    ? rawUserId
                    : fallbackUserId),
                description: Value(raw['description']?.toString() ?? ''),
                amount: Value(_toDouble(raw['amount'])),
                type: Value(raw['type']?.toString() ?? 'expense'),
                categoryId: Value(raw['categoryId']?.toString()),
                subcategoryId: Value(raw['subcategoryId']?.toString()),
                creditCardId: Value(raw['creditCardId']?.toString()),
                frequency: Value(raw['frequency']?.toString() ?? 'monthly'),
                dayOfMonth: Value(_toInt(raw['dayOfMonth'], fallback: 1)),
                startDate: Value(startDate),
                endDate: Value(_optionalDate(raw['endDate'])),
                isActive: Value(raw['isActive'] as bool? ?? true),
                nextDueDate: Value(nextDueDate),
                lastGeneratedAt: Value(_optionalDate(raw['lastGeneratedAt'])),
                createdAt:
                    Value(_optionalDate(raw['createdAt']) ?? startDate),
                isSynced: const Value(false),
              ),
            );
        recurringCount++;
      }

      for (final raw in _listFrom(data['budgetPlans'])) {
        final id = raw['id']?.toString();
        final month = _optionalDate(raw['month']);
        if (id == null || id.isEmpty || month == null) continue;
        final normalized = DateTime(month.year, month.month, 1);
        final rawUserId = raw['userId']?.toString();
        await _db.into(_db.budgetPlans).insertOnConflictUpdate(
              db.BudgetPlansCompanion(
                id: Value(id),
                userId: Value((rawUserId != null && rawUserId.isNotEmpty)
                    ? rawUserId
                    : fallbackUserId),
                month: Value(normalized),
                scope: Value(
                    raw['scope']?.toString() == 'couple' ? 'couple' : 'individual'),
                incomeMode: Value(raw['incomeMode']?.toString() ?? 'manual'),
                manualIncome: Value(_toDouble(raw['manualIncome'])),
                monthlyBudget: Value(_toDouble(raw['monthlyBudget'])),
                categoriesJson:
                    Value(_jsonString(raw['categories'], fallback: '[]')),
                notificationsJson:
                    Value(_jsonString(raw['notifications'], fallback: '{}')),
                createdAt:
                    Value(_optionalDate(raw['createdAt']) ?? normalized),
                updatedAt:
                    Value(_optionalDate(raw['updatedAt']) ?? DateTime.now()),
                isSynced: const Value(false),
              ),
            );
        plansCount++;
      }

      for (final raw in _listFrom(data['budgetAlerts'])) {
        final id = raw['id']?.toString();
        final triggeredAt = _optionalDate(raw['triggeredAt']);
        if (id == null || id.isEmpty || triggeredAt == null) continue;
        await _db.into(_db.budgetAlerts).insertOnConflictUpdate(
              db.BudgetAlertsCompanion(
                id: Value(id),
                planId: Value(raw['planId']?.toString() ?? ''),
                categoryId: Value(raw['categoryId']?.toString() ?? ''),
                categoryName: Value(raw['categoryName']?.toString() ?? ''),
                scope: Value(
                    raw['scope']?.toString() == 'couple' ? 'couple' : 'individual'),
                threshold: Value(_toInt(raw['threshold'], fallback: 80)),
                spentAmount: Value(_toDouble(raw['spentAmount'])),
                allocatedAmount: Value(_toDouble(raw['allocatedAmount'])),
                triggeredAt: Value(triggeredAt),
                read: Value(raw['read'] as bool? ?? false),
                dismissed: Value(raw['dismissed'] as bool? ?? false),
                isSynced: const Value(false),
              ),
            );
        alertsCount++;
      }

      for (final raw in _listFrom(data['goals'])) {
        final id = raw['id']?.toString();
        final name = raw['name']?.toString() ?? '';
        if (id == null || id.isEmpty || name.isEmpty) continue;
        final createdAt = _optionalDate(raw['createdAt']) ?? DateTime.now();
        final updatedAt = _optionalDate(raw['updatedAt']) ?? createdAt;
        await _db.into(_db.goals).insertOnConflictUpdate(
              db.GoalsCompanion(
                id: Value(id),
                name: Value(name),
                targetAmount: Value(_toDouble(raw['targetAmount'])),
                savedAmount: Value(_toDouble(raw['savedAmount'])),
                targetDate: Value(_optionalDate(raw['targetDate'])),
                color: Value(_toInt(raw['color'], fallback: 0xFF2EC4B6)),
                isArchived: Value(raw['isArchived'] as bool? ?? false),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
                isSynced: const Value(false),
              ),
            );
        goalsCount++;
      }

      for (final raw in _listFrom(data['appSettings'])) {
        final key = raw['key']?.toString();
        if (key == null || key.isEmpty) continue;
        await _db.into(_db.appSettings).insertOnConflictUpdate(
              db.AppSettingsCompanion(
                key: Value(key),
                value: Value(raw['value']?.toString() ?? ''),
                isSynced: const Value(false),
              ),
            );
        settingsCount++;
      }
    });

    try {
      await TransactionReminderService.instance.syncAllFromDatabase(_db);
    } catch (_) {}
    unawaited(_sync.push());

    return BackupRestoreResult(
      categories: categoriesCount,
      subcategories: subcategoriesCount,
      creditCards: cardsCount,
      transactions: transactionsCount,
      receipts: receiptsCount,
      recurringTransactions: recurringCount,
      budgetPlans: plansCount,
      budgetAlerts: alertsCount,
      goals: goalsCount,
      appSettings: settingsCount,
    );
  }

  static List<Map<String, dynamic>> _listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
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
