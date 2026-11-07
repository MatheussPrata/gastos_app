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
    @Default('') String paymentMethod,
    @Default(true) bool isExpense,
    @Default(false) bool isInstallment,
    @Default(1) int installmentNumber,
    @Default(1) int totalInstallments,
    String? installmentGroupId,
    String? notes,
    String? ownerId,
    @Default(false) bool partnerSynced,
    @Default(false) bool isSynced,

    /// Avisa antes e no dia do vencimento; a antecedencia vem das
    /// configuracoes de notificacoes.
    @Default(false) bool reminderEnabled,

    /// ID do cupom fiscal vinculado (NFC-e), se houver.
    String? receiptId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);
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

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
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

  factory CreditCard.fromJson(Map<String, dynamic> json) =>
      _$CreditCardFromJson(json);
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

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      _$RecurringTransactionFromJson(json);
}

/// Available payment methods for a transaction
class PaymentMethods {
  static const String money = 'Dinheiro';
  static const String pix = 'PIX';
  static const String creditCard = 'Cartão de Crédito';
  static const String debitCard = 'Cartão de Débito';
  static const String bankTransfer = 'Transferência';
  static const String other = 'Outro';

  static const List<String> all = [
    money,
    pix,
    creditCard,
    debitCard,
    bankTransfer,
    other,
  ];
}

/// Helper model for monthly totals calculation
class MonthlyStats {
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;

  const MonthlyStats({
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });

  double get balance => totalIncome - totalExpense;
}

/// Helper model for category expenses
class CategoryExpense {
  final String categoryId;
  final String categoryName;
  final int categoryColor;
  final String categoryIcon;
  final double totalAmount;
  final double percentage;

  const CategoryExpense({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.totalAmount,
    required this.percentage,
  });
}
