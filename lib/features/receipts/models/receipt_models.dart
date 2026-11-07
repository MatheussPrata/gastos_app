import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt_models.freezed.dart';
part 'receipt_models.g.dart';

@freezed
class Receipt with _$Receipt {
  const factory Receipt({
    required String id,
    required String transactionId,
    required String establishmentName,
    @Default('') String establishmentCnpj,
    required DateTime issueDate,
    required double totalAmount,
    @Default('') String paymentMethod,
    String? accessKey,
    String? rawUrl,
    required DateTime createdAt,
    @Default([]) List<ReceiptItem> items,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);
}

@freezed
class ReceiptItem with _$ReceiptItem {
  const factory ReceiptItem({
    required String id,
    required String receiptId,
    required String name,
    String? code,
    @Default(1.0) double quantity,
    @Default('UN') String unit,
    @Default(0.0) double unitPrice,
    @Default(0.0) double totalPrice,
    @Default('Outros') String category,
    @Default(0) int sortOrder,
  }) = _ReceiptItem;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);
}

/// Category summary within a receipt for category chips and graphs
class ReceiptCategorySummary {
  final String category;
  final double totalAmount;
  final int itemCount;
  final double percentage;

  const ReceiptCategorySummary({
    required this.category,
    required this.totalAmount,
    required this.itemCount,
    required this.percentage,
  });
}
