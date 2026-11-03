import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';

void main() {
  group('BudgetPlan percentages', () {
    BudgetPlan planWith(List<CategoryBudget> categories,
        {double budget = 1000}) {
      final now = DateTime(2026, 11, 1);
      return BudgetPlan(
        id: 'plan-1',
        userId: 'user-1',
        month: now,
        monthlyBudget: budget,
        categories: categories,
        createdAt: now,
        updatedAt: now,
      );
    }

    CategoryBudget category(
      String id,
      double percentage, {
      bool active = true,
    }) {
      return CategoryBudget(
        categoryId: id,
        categoryName: 'Categoria $id',
        categoryColor: 0xFF000000,
        categoryIcon: 'category',
        percentage: percentage,
        isActive: active,
      );
    }

    test('soma percentuais apenas das categorias ativas', () {
      final plan = planWith([
        category('a', 30),
        category('b', 20),
        category('c', 50, active: false),
      ]);

      expect(plan.allocatedPercentage, 50);
      expect(plan.isValid, isTrue);
    });

    test('permite soma menor que 100 e calcula reserva', () {
      final plan = planWith([
        category('a', 30),
        category('b', 20),
      ]);

      expect(plan.allocatedPercentage, 50);
      expect(plan.unallocatedPercentage, 50);
      expect(plan.reserveAmount, 500);
      expect(plan.isValid, isTrue);
    });

    test('marca plano inválido quando a soma passa de 100', () {
      final plan = planWith([
        category('a', 60),
        category('b', 50),
      ]);

      expect(plan.allocatedPercentage, 110);
      expect(plan.unallocatedPercentage, 0);
      expect(plan.isValid, isFalse);
    });

    test('upsertCategory substitui item existente e adiciona novo', () {
      final plan = planWith([category('a', 10)]);

      final replaced = plan.upsertCategory(category('a', 25));
      expect(replaced.categories, hasLength(1));
      expect(replaced.categories.single.percentage, 25);

      final added = replaced.upsertCategory(category('b', 15));
      expect(added.categories, hasLength(2));
      expect(added.allocatedPercentage, 40);
    });

    test('amountFor deriva o valor do orçamento total', () {
      expect(category('a', 30).amountFor(2000), 600);
      expect(category('a', 0).amountFor(2000), 0);
    });
  });

  group('BudgetPlan income', () {
    final now = DateTime(2026, 11, 1);

    BudgetPlan plan(IncomeMode mode, {double manualIncome = 5000}) {
      return BudgetPlan(
        id: 'plan-1',
        userId: 'user-1',
        month: now,
        incomeMode: mode,
        manualIncome: manualIncome,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('renda manual é usada no modo manual', () {
      expect(plan(IncomeMode.manual).effectiveIncome(9999), 5000);
    });

    test('renda real é usada no modo automático', () {
      expect(plan(IncomeMode.actual).effectiveIncome(7200), 7200);
    });
  });

  group('CategoryProgress', () {
    final budget = CategoryBudget(
      categoryId: 'a',
      categoryName: 'Alimentação',
      categoryColor: 0xFF000000,
      categoryIcon: 'restaurant',
      percentage: 20,
    );

    test('calcula progresso e limite atingido', () {
      final progress = CategoryProgress(
        budget: budget,
        allocatedAmount: 500,
        spentAmount: 400,
      );

      expect(progress.progressPercent, 80);
      expect(progress.remainingAmount, 100);
      expect(progress.isOverBudget, isFalse);
      expect(progress.reachedThreshold(80), isTrue);
      expect(progress.reachedThreshold(90), isFalse);
    });

    test('detecta estouro de orçamento', () {
      final progress = CategoryProgress(
        budget: budget,
        allocatedAmount: 500,
        spentAmount: 550,
      );

      expect(progress.isOverBudget, isTrue);
      expect(progress.remainingAmount, -50);
    });

    test('alocação zero não gera divisão por zero', () {
      final progress = CategoryProgress(
        budget: budget,
        allocatedAmount: 0,
        spentAmount: 100,
      );

      expect(progress.progressPercent, 0);
      expect(progress.reachedThreshold(1), isFalse);
    });
  });

  group('NotificationSettings', () {
    test('usa thresholds padrão 80/90/100', () {
      const settings = NotificationSettings();
      expect(settings.thresholds, [80, 90, 100]);
      expect(settings.enabled, isTrue);
    });
  });
}
