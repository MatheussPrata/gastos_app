import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_models.freezed.dart';
part 'transaction_models.g.dart';

@freezed
class Transaction with _$Transaction {
  const factory Transaction({
    required String id,
    required String userId,
    required double amount,
    required String description,
    required DateTime date,
    String? categoryId,
    String? subcategoryId,
    String? creditCardId,
    @Default(true) bool isExpense,
    @Default(false) bool isInstallment,
    @Default(1) int installmentNumber,
    @Default(1) int totalInstallments,
    String? installmentGroupId,
    String? notes,
    String? ownerId,
    @Default(false) bool partnerSynced,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) => _$TransactionFromJson(json);
}

@freezed
class Category with _$Category {
  const factory Category({
    required String id,
    required String name,
    required int color,
    required String icon,
    @Default(false) bool isDefault,
    @Default(true) bool isExpenseDefault,
    @Default(0) int sortOrder,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}

@freezed
class CreditCard with _$CreditCard {
  const factory CreditCard({
    required String id,
    required String name,
    required int color,
    @Default('') String lastFourDigits,
    @Default('') String brand,
    @Default(0.0) double limitAmount,
    @Default(1) int closingDay,
    @Default(1) int dueDay,
    @Default(true) bool isActive,
    @Default(0) int sortOrder,
  }) = _CreditCard;

  factory CreditCard.fromJson(Map<String, dynamic> json) => _$CreditCardFromJson(json);
}

@freezed
class RecurringTransaction with _$RecurringTransaction {
  const factory RecurringTransaction({
    required String id,
    required String userId,
    required String description,
    required double amount,
    required String type,
    String? categoryId,
    String? subcategoryId,
    String? creditCardId,
    required String frequency,
    required int dayOfMonth,
    required DateTime startDate,
    DateTime? endDate,
    @Default(true) bool isActive,
    required DateTime nextDueDate,
    DateTime? lastGeneratedAt,
    required DateTime createdAt,
  }) = _RecurringTransaction;

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) => _$RecurringTransactionFromJson(json);
}

@freezed
class ShoppingItem with _$ShoppingItem {
  const factory ShoppingItem({
    required String id,
    required String userId,
    required String name,
    String? category,
    @Default(false) bool isChecked,
    required DateTime createdAt,
    DateTime? checkedAt,
    String? checkedBy,
  }) = _ShoppingItem;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => _$ShoppingItemFromJson(json);
}

@freezed
class MonthlyStats with _$MonthlyStats {
  const factory MonthlyStats({
    required String month,
    required double income,
    required double expense,
    required double balance,
  }) = _MonthlyStats;

  factory MonthlyStats.fromJson(Map<String, dynamic> json) => _$MonthlyStatsFromJson(json);
}

@freezed
class CategoryExpense with _$CategoryExpense {
  const factory CategoryExpense({
    required String categoryId,
    required String categoryName,
    required int categoryColor,
    required double total,
  }) = _CategoryExpense;

  factory CategoryExpense.fromJson(Map<String, dynamic> json) => _$CategoryExpenseFromJson(json);
}