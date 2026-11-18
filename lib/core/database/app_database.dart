import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'dart:io';

import 'package:gastos_app/core/storage/db_key.dart';

part 'app_database.g.dart';

/// Users table - local cache of authenticated user
class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get username => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isAdmin => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Categories table
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get icon => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isExpenseDefault =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Subcategories table
class Subcategories extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Credit cards table
class CreditCards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get lastFourDigits => text().withDefault(const Constant(''))();
  TextColumn get brand => text().withDefault(const Constant(''))();
  RealColumn get limitAmount => real().withDefault(const Constant(0.0))();
  IntColumn get closingDay => integer().withDefault(const Constant(1))();
  IntColumn get dueDay => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transactions table
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  RealColumn get amount => real()();
  TextColumn get description => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get subcategoryId => text().nullable()();
  TextColumn get creditCardId => text().nullable()();
  TextColumn get paymentMethod => text().withDefault(const Constant(''))();
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  BoolColumn get isInstallment =>
      boolean().withDefault(const Constant(false))();
  IntColumn get installmentNumber => integer().withDefault(const Constant(1))();
  IntColumn get totalInstallments => integer().withDefault(const Constant(1))();
  TextColumn get installmentGroupId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get ownerId => text().nullable()();
  BoolColumn get partnerSynced =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  /// Quando verdadeiro, o aparelho avisa antes e no dia do vencimento.
  /// A antecedencia vem das configuracoes de notificacoes.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// ID do cupom fiscal vinculado (NFC-e), se houver.
  TextColumn get receiptId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Recurring transactions table
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get categoryId => text().nullable()();
  TextColumn get subcategoryId => text().nullable()();
  TextColumn get creditCardId => text().nullable()();
  TextColumn get frequency =>
      text()(); // 'daily', 'weekly', 'monthly', 'yearly'
  IntColumn get dayOfMonth => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get lastGeneratedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Shopping items table
class ShoppingItems extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get checkedAt => dateTime().nullable()();
  TextColumn get checkedBy => text().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// App settings table
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {key};
}

/// Budget plans table (monthly financial planning)
class BudgetPlans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();

  /// Reference month, normalized to the first day (local time).
  DateTimeColumn get month => dateTime()();

  /// 'individual' or 'couple' (see BudgetScope in planning_models.dart).
  TextColumn get scope => text().withDefault(const Constant('individual'))();

  /// 'manual' or 'actual' (see IncomeMode in planning_models.dart).
  TextColumn get incomeMode => text().withDefault(const Constant('manual'))();
  RealColumn get manualIncome => real().withDefault(const Constant(0.0))();
  RealColumn get monthlyBudget => real().withDefault(const Constant(0.0))();

  /// Serialized List<CategoryBudget>.
  TextColumn get categoriesJson => text().withDefault(const Constant('[]'))();

  /// Serialized NotificationSettings.
  TextColumn get notificationsJson =>
      text().withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Budget alerts table (thresholds reached per category/month plan)
class BudgetAlerts extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  TextColumn get categoryId => text()();
  TextColumn get categoryName => text()();
  TextColumn get scope => text().withDefault(const Constant('individual'))();
  IntColumn get threshold => integer()();
  RealColumn get spentAmount => real()();
  RealColumn get allocatedAmount => real()();
  DateTimeColumn get triggeredAt => dateTime()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tombstones for records deleted while offline.
///
/// A row here means "delete this id on the server on the next sync".
/// Without it, a restore would resurrect everything the user deleted.
class PendingDeletions extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get remoteId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Connections table (for sharing with partner)
class Connections extends Table {
  TextColumn get id => text()();
  TextColumn get myUserId => text()();
  TextColumn get partnerUserId => text()();
  TextColumn get partnerUsername => text()();
  TextColumn get inviteCode => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Password reset tokens table (for local reference)
class PasswordResetTokens extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get tokenHash => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get usedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sessions table (for refresh tokens)
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get refreshTokenHash => text()();
  TextColumn get userAgent => text().nullable()();
  TextColumn get ipAddress => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get revokedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Fiscal receipts table (NFC-e / Cupom Fiscal)
class Receipts extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get establishmentName => text()();
  TextColumn get establishmentCnpj => text().withDefault(const Constant(''))();
  DateTimeColumn get issueDate => dateTime()();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant(''))();
  TextColumn get accessKey => text().nullable()();
  TextColumn get rawUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Items within a fiscal receipt
class ReceiptItems extends Table {
  TextColumn get id => text()();
  TextColumn get receiptId => text()();
  TextColumn get name => text()();
  TextColumn get code => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('UN'))();
  RealColumn get unitPrice => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real().withDefault(const Constant(0.0))();
  TextColumn get category => text().withDefault(const Constant('Outros'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Metas financeiras (ex.: juntar para uma viagem).
@DataClassName('Goal')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get savedAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF2EC4B6))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Users,
  Categories,
  Subcategories,
  CreditCards,
  Transactions,
  RecurringTransactions,
  ShoppingItems,
  AppSettings,
  BudgetPlans,
  BudgetAlerts,
  Connections,
  PendingDeletions,
  PasswordResetTokens,
  Sessions,
  Receipts,
  ReceiptItems,
  Goals,
])
class AppDatabase extends _$AppDatabase {
  factory AppDatabase() => _instance;

  static final AppDatabase _instance = AppDatabase._();

  AppDatabase._() : super(_openConnection());

  /// Base em memoria (ou executor alternativo) para testes.
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactions, transactions.paymentMethod);
          }
          if (from < 3) {
            // Non-destructive: drift's createTable emits CREATE TABLE IF NOT
            // EXISTS, so existing tables and data are preserved.
            await m.createTable(budgetPlans);
            await m.createTable(budgetAlerts);
          }
          if (from < 4) {
            // Existing plans/alerts become individual by default.
            await m.addColumn(budgetPlans, budgetPlans.scope);
            await m.addColumn(budgetAlerts, budgetAlerts.scope);
          }
          if (from < 5) {
            await m.createTable(pendingDeletions);
          }
          if (from < 6) {
            // A v6 adicionava reminder_at; a v6 nunca chegou a um aparelho real,
            // por isso a coluna e criada aqui como texto solto para a migracao
            // seguinte poder converte-la.
            await customStatement(
              'ALTER TABLE transactions ADD COLUMN reminder_at INTEGER',
            );
          }
          if (from < 7) {
            await m.addColumn(transactions, transactions.reminderEnabled);
            if (from >= 6) {
              // A versao 6 guardava uma data/hora exata por transacao. Passa a
              // ser um simples "avisar" e a antecedencia vem das configuracoes.
              // Quem tinha lembrete continua com lembrete ligado.
              await customStatement(
                'UPDATE transactions SET reminder_enabled = 1 '
                'WHERE reminder_at IS NOT NULL',
              );
              try {
                await customStatement(
                  'ALTER TABLE transactions DROP COLUMN reminder_at',
                );
              } catch (_) {
                // SQLite antigo: a coluna fica, mas deixa de ser usada.
              }
            }
          }
          if (from < 8) {
            await m.createTable(receipts);
            await m.createTable(receiptItems);
            await m.addColumn(transactions, transactions.receiptId);
          }
          if (from < 9) {
            await m.createTable(goals);
          }
        },
      );

  // Clear all data (for logout)
  Future<void> clearAllData() {
    return transaction(() async {
      await delete(receiptItems).go();
      await delete(receipts).go();
      await delete(goals).go();
      await delete(budgetAlerts).go();
      await delete(budgetPlans).go();
      await delete(transactions).go();
      await delete(recurringTransactions).go();
      await delete(shoppingItems).go();
      await delete(categories).go();
      await delete(subcategories).go();
      await delete(creditCards).go();
      await delete(appSettings).go();
      await delete(connections).go();
      await delete(pendingDeletions).go();
      await delete(users).go();
      await delete(sessions).go();
      await delete(passwordResetTokens).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gastos.db'));
    final backup = File('${file.path}.plaintext.bak');
    var key = await getDbKey();
    final prefs = await SharedPreferences.getInstance();
    var verified = prefs.getBool(_dbVerifiedKey) ?? false;

    // 1. Banco existente.
    if (await file.exists() && !await _isPlaintextDatabase(file)) {
      // 1a. Chave antiga (passphrase) -> re-chaveia uma unica vez para raw.
      if (!key.isRaw) {
        final rekeyed = await _rekeyToRaw(file, key);
        if (rekeyed) {
          key = await getDbKey();
          verified = true;
          await prefs.setBool(_dbVerifiedKey, true);
        }
      }

      // 1b. Valida a chave apenas na primeira abertura.
      if (key.isRaw && !verified) {
        if (await _canOpenEncrypted(file, key)) {
          await prefs.setBool(_dbVerifiedKey, true);
          if (await backup.exists()) {
            await backup.delete();
          }
        } else {
          debugPrint('Banco cifrado nao abriu; tentando recuperar.');
          await prefs.setBool(_dbVerifiedKey, false);
          await _recoverDatabase(file, backup);
        }
      } else if (verified && await backup.exists()) {
        await backup.delete();
      }
    }

    // 2. Banco em texto puro: migra para cifrado.
    if (await _isPlaintextDatabase(file)) {
      final migrated = await _tryEncryptExisting(file, key);
      if (!migrated) {
        return NativeDatabase(file);
      }
      await prefs.setBool(_dbVerifiedKey, true);
    }

    // 3. Abre o banco cifrado.
    return NativeDatabase(file, setup: (db) {
      db.execute('PRAGMA key = ${key.pragma};');
      try {
        final version = db.select('PRAGMA cipher_version;');
        if (version.isEmpty) {
          debugPrint('SQLCipher indisponivel: banco NAO esta cifrado.');
        }
      } catch (error) {
        debugPrint('Falha ao verificar SQLCipher: $error');
      }
    });
  });
}

const _dbVerifiedKey = 'kuanto_db_verified_v1';

/// Confirma que o arquivo abre com a chave atual.
Future<bool> _canOpenEncrypted(File file, DbKey key) async {
  try {
    final db = sqlite3.open(file.path);
    try {
      db.execute('PRAGMA key = ${key.pragma};');
      db.select('SELECT count(*) AS c FROM sqlite_master;');
      return true;
    } finally {
      db.dispose();
    }
  } catch (error) {
    debugPrint('Validacao do banco cifrado falhou: $error');
    return false;
  }
}

/// Re-chaveia o banco antigo (passphrase) para chave raw, sem PBKDF2.
Future<bool> _rekeyToRaw(File file, DbKey legacyKey) async {
  final backup = File('${file.path}.rekey.bak');
  final newKey = DbKey(generateRawKey(), isRaw: true);
  try {
    if (!await backup.exists()) {
      await file.copy(backup.path);
    }
    await savePendingRawKey(newKey.value);

    final db = sqlite3.open(file.path);
    try {
      db.execute('PRAGMA key = ${legacyKey.pragma};');
      db.select('SELECT count(*) FROM sqlite_master;');
      db.execute('PRAGMA rekey = ${newKey.pragma};');
    } finally {
      db.dispose();
    }

    final check = sqlite3.open(file.path);
    try {
      check.execute('PRAGMA key = ${newKey.pragma};');
      final rows = check.select('SELECT count(*) AS c FROM sqlite_master;');
      if (((rows.first['c'] as int?) ?? 0) <= 0) return false;
    } finally {
      check.dispose();
    }

    await promotePendingRawKey(newKey.value);
    if (await backup.exists()) {
      await backup.delete();
    }
    debugPrint('Banco re-chaveado para raw key.');
    return true;
  } catch (error) {
    debugPrint('Falha no rekey: $error');
    await discardPendingRawKey();
    try {
      if (await backup.exists()) {
        if (await file.exists()) await file.delete();
        await backup.copy(file.path);
      }
    } catch (_) {}
    return false;
  }
}

/// Restaura o backup em texto puro; sem backup, isola o arquivo ruim para
/// o app voltar a abrir e o sync repor os dados do servidor.
Future<void> _recoverDatabase(File file, File backup) async {
  try {
    if (await backup.exists()) {
      if (await file.exists()) await file.delete();
      await backup.copy(file.path);
      debugPrint('Banco restaurado do backup em texto puro.');
      return;
    }
  } catch (error) {
    debugPrint('Falha ao restaurar backup: $error');
  }

  try {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await file.rename('${file.path}.corrupt-$stamp');
    debugPrint('Banco movido para ${file.path}.corrupt-$stamp');
  } catch (error) {
    debugPrint('Falha ao mover banco corrompido: $error');
  }
}

/// Um banco SQLite em texto puro comeca com o header oficial.
Future<bool> _isPlaintextDatabase(File file) async {
  if (!await file.exists()) return false;
  final raf = await file.open();
  try {
    final header = await raf.read(16);
    return header.length == 16 &&
        String.fromCharCodes(header) == 'SQLite format 3\u0000';
  } catch (_) {
    return false;
  } finally {
    await raf.close();
  }
}

/// Copia o banco em texto puro para um novo arquivo cifrado com SQLCipher.
Future<bool> _tryEncryptExisting(File file, DbKey key) async {
  final backup = File('${file.path}.plaintext.bak');
  final encrypted = File('${file.path}.encrypted');
  try {
    if (!await backup.exists()) {
      await file.copy(backup.path);
    }
    if (await encrypted.exists()) {
      await encrypted.delete();
    }

    final source = sqlite3.open(file.path);
    try {
      source.execute(
        "ATTACH DATABASE '${_escapeSql(encrypted.path)}' AS encrypted "
        'KEY ${key.pragma};',
      );
      source.execute("SELECT sqlcipher_export('encrypted');");
      source.execute('DETACH DATABASE encrypted;');
    } finally {
      source.dispose();
    }

    // So substitui o original depois de validar o arquivo cifrado.
    final check = sqlite3.open(encrypted.path);
    try {
      check.execute('PRAGMA key = ${key.pragma};');
      final rows = check.select('SELECT count(*) AS c FROM sqlite_master;');
      final count = (rows.first['c'] as int?) ?? 0;
      if (count <= 0) return false;
    } finally {
      check.dispose();
    }

    await file.delete();
    await encrypted.rename(file.path);
    // O backup fica ate o proximo inicio validar a chave; ai e removido.
    debugPrint('Banco local migrado para SQLCipher.');
    return true;
  } catch (error) {
    debugPrint('Falha ao migrar banco para SQLCipher: $error');
    try {
      if (await encrypted.exists()) await encrypted.delete();
    } catch (_) {}
    return false;
  }
}

String _escapeSql(String value) => value.replaceAll("'", "''");

