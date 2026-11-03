import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_category.dart';
import 'package:gastos_app/features/shopping_list/data/repositories/shopping_category_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cria os padrões apenas no primeiro uso', () async {
    final repository = ShoppingCategoryRepository();

    await repository.seedDefaults();
    final first = await repository.loadCategories();
    expect(first, isNotEmpty);
    expect(first.map((c) => c.name), containsAll(['Alimentação', 'Limpeza']));

    // Não recria os padrões se já foi semeado antes.
    await repository.saveCategories([]);
    await repository.seedDefaults();
    final second = await repository.loadCategories();
    expect(second, isEmpty);
  });

  test('salva e carrega categorias personalizadas', () async {
    final repository = ShoppingCategoryRepository();
    const categories = [
      ShoppingCategory(id: 'a', name: 'Alimentação', sortOrder: 0),
      ShoppingCategory(id: 'b', name: 'Limpeza', sortOrder: 1),
    ];

    await repository.saveCategories(categories);
    final loaded = await repository.loadCategories();

    expect(loaded.length, 2);
    expect(loaded.first.name, 'Alimentação');
    expect(loaded.last.sortOrder, 1);
  });

  test('serializa e desserializa o modelo', () {
    const category = ShoppingCategory(id: 'x', name: 'Higiene', sortOrder: 2);

    final json = category.toJson();
    final restored = ShoppingCategory.fromJson(json);

    expect(restored.id, 'x');
    expect(restored.name, 'Higiene');
    expect(restored.sortOrder, 2);
  });
}
