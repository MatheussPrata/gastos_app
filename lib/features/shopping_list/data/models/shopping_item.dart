import 'package:freezed_annotation/freezed_annotation.dart';

part 'shopping_item.freezed.dart';
part 'shopping_item.g.dart';

/// Item de uma lista de compras com planejamento de preco.
///
/// [estimatedPrice] e o preco planejado/estimado antes da compra, enquanto
/// [actualPrice] e o valor realmente pago quando o item foi comprado.
@freezed
class ShoppingItem with _$ShoppingItem {
  const factory ShoppingItem({
    required String id,
    required String name,
    @Default(1.0) double quantity,
    String? unit,
    double? estimatedPrice,
    double? actualPrice,
    @Default(false) bool isPurchased,
    String? category,
  }) = _ShoppingItem;

  factory ShoppingItem.fromJson(Map<String, dynamic> json) =>
      _$ShoppingItemFromJson(json);
}

/// Resumo financeiro da lista de compras.
class ShoppingListSummary {
  const ShoppingListSummary({
    required this.estimatedTotal,
    required this.purchasedTotal,
    required this.remainingTotal,
    required this.totalItems,
    required this.purchasedItems,
  });

  /// Soma dos precos estimados de todos os itens (planejamento).
  final double estimatedTotal;

  /// Soma dos precos reais dos itens ja comprados.
  final double purchasedTotal;

  /// Soma dos precos estimados dos itens ainda nao comprados.
  final double remainingTotal;

  final int totalItems;
  final int purchasedItems;

  factory ShoppingListSummary.fromItems(List<ShoppingItem> items) {
    var estimated = 0.0;
    var purchased = 0.0;
    var remaining = 0.0;
    var purchasedCount = 0;

    for (final item in items) {
      estimated += item.estimatedPrice ?? 0;
      if (item.isPurchased) {
        purchased += item.actualPrice ?? 0;
        purchasedCount++;
      } else {
        remaining += item.estimatedPrice ?? 0;
      }
    }

    return ShoppingListSummary(
      estimatedTotal: estimated,
      purchasedTotal: purchased,
      remainingTotal: remaining,
      totalItems: items.length,
      purchasedItems: purchasedCount,
    );
  }
}
