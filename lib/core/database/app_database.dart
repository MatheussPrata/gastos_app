import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

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
  BoolColumn get isExpenseDefault => boolean().withDefault(const Constant(true))();
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
  BoolColumn get isExpense => boolean().withDefault(const Constant(true))();
  BoolColumn get isInstallment => boolean().withDefault(const Constant(false))();
  IntColumn get installmentNumber => integer().withDefault(const Constant(1))();
  IntColumn get totalInstallments => integer().withDefault(const Constant(1))();
  TextColumn get installmentGroupId => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get ownerId => text().nullable()();
  BoolColumn get partnerSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  
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
  TextColumn get frequency => text()(); // 'daily', 'weekly', 'monthly', 'yearly'
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

@DriftDatabase(tables: [
  Users,
  Categories,
  Subcategories,
  CreditCards,
  Transactions,
  RecurringTransactions,
  ShoppingItems,
  AppSettings,
  Connections,
  PasswordResetTokens,
  Sessions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Upsert user (insert or update)
  Future<void> upsertUser(UsersCompanion user) {
    return into(users).insertOnConflictUpdate(user);
  }

  // Get current user from local DB
  Future<User?> getCurrentUser() {
    return (select(users)..limit(1)).getSingleOrNull();
  }

  // Get unsynced transactions
  Future<List<Transaction>> getUnsyncedTransactions() {
    return (select(transactions)
          ..where((t) => t.isSynced.equals(false)))
        .get();
  }

  // Mark transaction as synced
  Future<void> markTransactionSynced(String id) {
    return (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(isSynced: const Value(true)));
  }

  // Mark category as synced
  Future<void> markCategorySynced(String id) {
    return (update(categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(isSynced: const Value(true)));
  }

  // Mark recurring transaction as synced
  Future<void> markRecurringSynced(String id) {
    return (update(recurringTransactions)..where((r) => r.id.equals(id)))
        .write(RecurringTransactionsCompanion(isSynced: const Value(true)));
  }

  // Mark shopping item as synced
  Future<void> markShoppingSynced(String id) {
    return (update(shoppingItems)..where((s) => s.id.equals(id)))
        .write(ShoppingItemsCompanion(isSynced: const Value(true)));
  }

  // Clear all data (for logout)
  Future<void> clearAllData() {
    return transaction(() async {
      await delete(transactions).go();
      await delete(recurringTransactions).go();
      await delete(shoppingItems).go();
      await delete(categories).go();
      await delete(subcategories).go();
      await delete(creditCards).go();
      await delete(appSettings).go();
      await delete(connections).go();
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
    return NativeDatabase(file);
  });
}