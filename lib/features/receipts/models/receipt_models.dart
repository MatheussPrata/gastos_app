import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt_models.freezed.dart';
part 'receipt_models.g.dart';

@freezed
class Receipt with _$Receipt {
  const Receipt._();

  const factory Receipt({
    required String id,
    required String transactionId,
    required String establishmentName,
    @Default('') String establishmentCnpj,
    required DateTime issueDate,
    required double totalAmount,

    /// Desconto aplicado pela nota como um todo (fora dos descontos por item).
    @Default(0.0) double discountAmount,
    @Default('') String paymentMethod,
    String? accessKey,
    String? rawUrl,
    required DateTime createdAt,
    @Default([]) List<ReceiptItem> items,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);

  /// Soma dos itens antes de qualquer desconto (qtd x preço unitário).
  double get itemsGrossTotal =>
      items.fold(0.0, (acc, item) => acc + item.quantity * item.unitPrice);

  /// Soma dos itens já líquida (com os descontos por item aplicados).
  double get itemsNetTotal =>
      items.fold(0.0, (acc, item) => acc + item.totalPrice);

  /// Desconto total: diferença entre o bruto dos itens e o valor pago.
  double get discountTotal {
    if (items.isEmpty) return discountAmount > 0 ? discountAmount : 0.0;
    final diff = itemsGrossTotal - totalAmount;
    return diff > 0.005 ? diff : 0.0;
  }
}

@freezed
class ReceiptItem with _$ReceiptItem {
  const ReceiptItem._();

  const factory ReceiptItem({
    required String id,
    required String receiptId,
    required String name,
    String? code,
    @Default(1.0) double quantity,
    @Default('UN') String unit,
    @Default(0.0) double unitPrice,
    @Default(0.0) double totalPrice,

    /// Desconto aplicado nesta linha (bruto - líquido).
    @Default(0.0) double discount,
    @Default('Outros') String category,
    @Default(0) int sortOrder,
  }) = _ReceiptItem;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);

  /// Valor da linha antes do desconto.
  double get grossTotal => quantity * unitPrice;
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
