import 'package:freezed_annotation/freezed_annotation.dart';

part 'recurring_models.freezed.dart';
part 'recurring_models.g.dart';

@freezed
class RecurringTransaction with _$RecurringTransaction {
  const factory RecurringTransaction({
    required String id,
    required String userId,
    required String description,
    required double amount,
    required String type, // 'income' or 'expense'
    String? categoryId,
    String? subcategoryId,
    String? creditCardId,
    required String frequency, // 'daily', 'weekly', 'monthly', 'yearly'
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