import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/repository/categories_repository.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late CategoriesRepository repo;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repo = CategoriesRepository(
      database: database,
      syncService: SyncService(database: database),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('kCategoryColors possui pelo menos 20 cores distintas na paleta', () {
    expect(kCategoryColors.length, greaterThanOrEqualTo(20));
    final uniqueColors = kCategoryColors.toSet();
    expect(uniqueColors.length, equals(kCategoryColors.length));
  });

  test('seedDefaultCategories popula categorias com cores distintas', () async {
    await repo.seedDefaultCategories();
    final categories = await repo.getCategories();

    expect(categories, isNotEmpty);
    final colors = categories.map((c) => c.color).toSet();
    // Nenhuma cor padrão duplicada
    expect(colors.length, equals(categories.length));
  });

  test('ensureUniqueCategoryColors resolve colisão de cores duplicadas no SQLite', () async {
    // Insere intencionalmente duas categorias com a mesma cor exata (ex: 0xFFFF6B6B)
    const duplicateColor = 0xFFFF6B6B;
    await database.into(database.categories).insert(db.CategoriesCompanion(
      id: const Value('cat-1'),
      name: const Value('Alimentação'),
      color: const Value(duplicateColor),
      icon: const Value('restaurant'),
      isDefault: const Value(true),
      isExpenseDefault: const Value(true),
      sortOrder: const Value(0),
    ));

    await database.into(database.categories).insert(db.CategoriesCompanion(
      id: const Value('cat-2'),
      name: const Value('Custos fixos'),
      color: const Value(duplicateColor),
      icon: const Value('home'),
      isDefault: const Value(false),
      isExpenseDefault: const Value(true),
      sortOrder: const Value(1),
    ));

    // Executa a validação e reparação de unicidade
    await repo.ensureUniqueCategoryColors();

    final categories = await repo.getCategories();
    expect(categories.length, equals(2));

    final cat1 = categories.firstWhere((c) => c.id == 'cat-1');
    final cat2 = categories.firstWhere((c) => c.id == 'cat-2');

    // A primeira mantém a cor original
    expect(cat1.color, equals(duplicateColor));
    // A segunda categoria duplicada recebe uma nova cor distinta
    expect(cat2.color, isNot(equals(duplicateColor)));
    expect(kCategoryColors.contains(cat2.color), isTrue);
  });
}
