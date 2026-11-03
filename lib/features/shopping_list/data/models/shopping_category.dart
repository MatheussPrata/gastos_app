/// Categoria da lista de compras — separada das categorias de gastos.
///
/// Diferente de [Category] (gastos/transações), as categorias de compras são
/// mais simples e voltadas ao supermercado (Alimentação, Limpeza, Higiene…).
/// São editáveis pelo usuário e ficam 100% locais (SharedPreferences).
class ShoppingCategory {
  final String id;
  final String name;
  final int sortOrder;

  const ShoppingCategory({
    required this.id,
    required this.name,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
      };

  factory ShoppingCategory.fromJson(Map<String, dynamic> json) {
    return ShoppingCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  ShoppingCategory copyWith({String? name, int? sortOrder}) {
    return ShoppingCategory(
      id: id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
