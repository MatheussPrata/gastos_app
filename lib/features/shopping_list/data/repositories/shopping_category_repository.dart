import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/features/shopping_list/data/models/shopping_category.dart';

/// Persistência local das categorias de compras (SharedPreferences).
///
/// Assim como a lista de compras, as categorias são 100% offline e ficam
/// salvas localmente. Na primeira execução, um conjunto padrão é criado.
class ShoppingCategoryRepository {
  static const String storageKey = 'shopping_categories';
  static const String seededKey = 'shopping_categories_seeded';

  /// Categorias padrão (supermercado), criadas apenas no primeiro uso.
  static const List<ShoppingCategory> defaultCategories = [
    ShoppingCategory(id: 'alimentacao', name: 'Alimentação', sortOrder: 0),
    ShoppingCategory(id: 'limpeza', name: 'Limpeza', sortOrder: 1),
    ShoppingCategory(id: 'higiene', name: 'Higiene', sortOrder: 2),
    ShoppingCategory(id: 'bebidas', name: 'Bebidas', sortOrder: 3),
    ShoppingCategory(id: 'padaria', name: 'Padaria', sortOrder: 4),
    ShoppingCategory(id: 'hortifruti', name: 'Hortifruti', sortOrder: 5),
    ShoppingCategory(id: 'outros', name: 'Outros', sortOrder: 6),
  ];

  Future<List<ShoppingCategory>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => ShoppingCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCategories(List<ShoppingCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(categories.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, raw);
  }

  /// Cria o conjunto padrão apenas uma vez. Se o usuário apagar tudo,
  /// não recriamos os padrões automaticamente.
  Future<void> seedDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final seeded = prefs.getBool(seededKey) ?? false;
    if (seeded) return;
    await saveCategories(defaultCategories);
    await prefs.setBool(seededKey, true);
  }
}
