import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';

/// Resultado da fusao entre a lista local e a lista do parceiro.
class ShoppingMergeResult {
  const ShoppingMergeResult({required this.items, required this.sharedIds});

  final List<ShoppingItem> items;
  final Set<String> sharedIds;
}

/// Logica pura de fusao dos dados do parceiro. Separada do repositorio para
/// poder ser testada sem banco, rede ou plugins de plataforma.
class SharingMerger {
  /// Junta os itens do parceiro na lista local.
  ///
  /// Itens com o mesmo id do parceiro sobrescrevem os locais (o servidor e a
  /// fonte da verdade). Os ids retornados entram em [sharedIds] para nao
  /// serem reenviados ao servidor como se fossem do usuario local.
  static ShoppingMergeResult mergeShoppingItems({
    required List<ShoppingItem> local,
    required List<Map<String, dynamic>> partnerItems,
    required Set<String> sharedIds,
  }) {
    final merged = {for (final item in local) item.id: item};
    final ids = {...sharedIds};

    for (final json in partnerItems) {
      final id = json['id'] as String?;
      if (id == null || id.isEmpty) continue;

      merged[id] = shoppingItemFromJson(json);
      ids.add(id);
    }

    return ShoppingMergeResult(items: merged.values.toList(), sharedIds: ids);
  }

  static ShoppingItem shoppingItemFromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Item',
      quantity: toDouble(json['quantity'] ?? 1),
      unit: json['unit'] as String?,
      estimatedPrice: toDoubleOrNull(json['estimatedPrice']),
      actualPrice: toDoubleOrNull(json['actualPrice']),
      isPurchased:
          json['isPurchased'] as bool? ?? json['isChecked'] as bool? ?? false,
      category: json['category'] as String?,
    );
  }

  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
