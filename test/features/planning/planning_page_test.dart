import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/planning/ui/pages/planning_page.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanningRepository extends Mock implements PlanningRepository {}

void main() {
  late _MockPlanningRepository repository;

  final month = DateTime(2026, 11);
  final now = DateTime(2026, 11, 1);

  final moradia = const CategoryBudget(
    categoryId: 'a',
    categoryName: 'Moradia',
    categoryColor: 0xFFFFB347,
    categoryIcon: 'home',
    percentage: 30,
  );
  final alimentacao = const CategoryBudget(
    categoryId: 'b',
    categoryName: 'Alimentação',
    categoryColor: 0xFFFF6B6B,
    categoryIcon: 'restaurant',
    percentage: 20,
  );

  final plan = BudgetPlan(
    id: 'plan-1',
    userId: 'user-1',
    month: month,
    monthlyBudget: 1000,
    manualIncome: 5000,
    categories: [moradia, alimentacao],
    createdAt: now,
    updatedAt: now,
  );

  setUpAll(() {
    registerFallbackValue(plan);
    registerFallbackValue(DateTime(2026, 1, 1));
    registerFallbackValue(BudgetScope.individual);
  });

  setUp(() {
    repository = _MockPlanningRepository();
    when(
      () => repository.getOrCreatePlanForMonth(
        any(),
        scope: any(named: 'scope'),
      ),
    ).thenAnswer((_) async => plan);
    when(
      () => repository.getSpentByCategory(
        any(),
        scope: any(named: 'scope'),
      ),
    ).thenAnswer(
      (_) async => {'a': 150.0, 'b': 250.0},
    );
    when(() => repository.getCategoryProgress(any())).thenAnswer(
      (_) async => [
        CategoryProgress(
          budget: alimentacao,
          allocatedAmount: 200,
          spentAmount: 250,
        ),
        CategoryProgress(
          budget: moradia,
          allocatedAmount: 300,
          spentAmount: 150,
        ),
      ],
    );
    when(() => repository.getAlerts())
        .thenAnswer((_) async => const <BudgetAlert>[]);
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        planningRepositoryProvider.overrideWithValue(repository),
        selectedPlanMonthProvider.overrideWith((ref) => month),
      ],
      child: const MaterialApp(home: PlanningPage()),
    );
  }

  testWidgets('mostra resumo, categorias e reserva', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('Planejamento'), findsOneWidget);
    expect(find.text('Moradia'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);

    // Gasto total do mês e saldo/reserva.
    expect(find.textContaining('400,00'), findsOneWidget);
    expect(find.textContaining('500,00'), findsWidgets);
    expect(find.text('Reserva (50%)'), findsOneWidget);

    // Estouro de categoria.
    expect(find.text('125%'), findsOneWidget);
  });

  testWidgets('abre o diálogo de edição da categoria', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Moradia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moradia'));
    await tester.pumpAndSettle();

    expect(find.text('Salvar'), findsOneWidget);
    expect(
        find.textContaining('disponível para esta categoria'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar'), findsNothing);
  });
}
