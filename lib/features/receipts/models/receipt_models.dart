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

    /// Valor bruto total dos itens antes dos descontos.
    @Default(0.0) double subtotalAmount,

    /// Desconto total aplicado na compra (itens + desconto da nota).
    @Default(0.0) double totalDiscount,

    /// Desconto aplicado pela nota como um todo (fora dos descontos por item).
    @Default(0.0) double discountAmount,
    @Default('') String paymentMethod,
    String? accessKey,
    String? rawUrl,
    required DateTime createdAt,
    DateTime? updatedAt,
    @Default(false) bool isSynced,
    @Default([]) List<ReceiptItem> items,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);

  /// Valor efetivamente pago (alias semântico de [totalAmount]).
  double get finalAmount => totalAmount;

  /// Soma dos itens antes de qualquer desconto.
  double get itemsGrossTotal =>
      items.fold(0.0, (acc, item) => acc + item.effectiveGrossTotal);

  /// Soma dos itens já líquida (com os descontos por item aplicados).
  double get itemsNetTotal =>
      items.fold(0.0, (acc, item) => acc + item.totalPrice);

  /// Subtotal bruto efetivo do cupom (antes dos descontos).
  double get effectiveSubtotal {
    if (subtotalAmount > 0.005) return subtotalAmount;
    if (itemsGrossTotal > 0.005) return itemsGrossTotal;
    return totalAmount + discountTotal;
  }

  /// Desconto total: diferença entre o bruto dos itens e o valor pago.
  double get discountTotal {
    if (totalDiscount > 0.005) return totalDiscount;
    if (items.isEmpty) return discountAmount > 0 ? discountAmount : 0.0;
    final diff = effectiveSubtotal - totalAmount;
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

    /// Valor bruto do item antes do desconto.
    @Default(0.0) double grossTotal,

    /// Valor final líquido pago pelo item ([grossTotal] - [discount]).
    @Default(0.0) double totalPrice,

    /// Desconto aplicado nesta linha (bruto - líquido).
    @Default(0.0) double discount,
    @Default('Outros') String category,
    @Default(0) int sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    @Default(false) bool isSynced,
  }) = _ReceiptItem;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);

  /// Valor bruto da linha antes do desconto (com fallback seguro para registros legados).
  double get effectiveGrossTotal {
    if (grossTotal > 0.005) return grossTotal;
    if (discount > 0.005) return totalPrice + discount;
    final byUnit = quantity * unitPrice;
    return byUnit > 0.005 ? byUnit : totalPrice;
  }

  /// Valor líquido final pago pelo item.
  double get netTotal => totalPrice;
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
