import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockPlanningRepository extends Mock implements PlanningRepository {}

final _month = DateTime(2026, 11);

CategoryBudget _category(
  String id,
  double percentage, {
  String name = 'Categoria',
}) {
  return CategoryBudget(
    categoryId: id,
    categoryName: name,
    categoryColor: 0xFF000000,
    categoryIcon: 'category',
    percentage: percentage,
  );
}

BudgetPlan _plan({
  DateTime? month,
  IncomeMode incomeMode = IncomeMode.manual,
  double manualIncome = 5000,
  double monthlyBudget = 1000,
  List<CategoryBudget>? categories,
  NotificationSettings notifications = const NotificationSettings(),
}) {
  return BudgetPlan(
    id: 'plan-1',
    userId: 'user-1',
    month: month ?? _month,
    incomeMode: incomeMode,
    manualIncome: manualIncome,
    monthlyBudget: monthlyBudget,
    categories: categories ??
        [
          _category('a', 30, name: 'Moradia'),
          _category('b', 20, name: 'Alimentação'),
        ],
    notifications: notifications,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

BudgetAlert _alert({
  String id = 'alert-1',
  int threshold = 80,
  bool read = false,
  bool dismissed = false,
}) {
  return BudgetAlert(
    id: id,
    planId: 'plan-1',
    categoryId: 'a',
    categoryName: 'Moradia',
    threshold: threshold,
    spentAmount: 320,
    allocatedAmount: 300,
    triggeredAt: DateTime(2026, 11, 10),
    read: read,
    dismissed: dismissed,
  );
}

void main() {
  late _MockPlanningRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(_plan());
    registerFallbackValue(DateTime(2026, 1, 1));
  });

  setUp(() {
    repository = _MockPlanningRepository();
    when(() => repository.getOrCreatePlanForMonth(any()))
        .thenAnswer((_) async => _plan());
    when(() => repository.savePlan(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as BudgetPlan,
    );
    when(() => repository.getCategoryProgress(any()))
        .thenAnswer((_) async => const <CategoryProgress>[]);
    when(() => repository.getAlerts())
        .thenAnswer((_) async => const <BudgetAlert>[]);
    when(() => repository.markAlertRead(any())).thenAnswer((_) async {});
    when(() => repository.markAllAlertsRead()).thenAnswer((_) async {});
    when(() => repository.dismissAlert(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        planningRepositoryProvider.overrideWithValue(repository),
        selectedPlanMonthProvider.overrideWith((ref) => _month),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<BudgetPlan> loadPlan() async {
    final notifier = container.read(monthPlanningProvider.notifier);
    await notifier.load();
    return container.read(monthPlanningProvider).valueOrNull!;
  }

  group('monthPlanningProvider', () {
    test('carrega o plano do mês selecionado', () async {
      final plan = await loadPlan();

      expect(plan.id, 'plan-1');
      expect(plan.month, _month);
      expect(
          container.read(monthPlanningProvider), isA<AsyncData<BudgetPlan?>>());
      verify(() => repository.getOrCreatePlanForMonth(_month))
          .called(greaterThan(0));
    });

    test('alterna o modo de renda e persiste', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.setIncomeMode(IncomeMode.actual);

      final updated = container.read(monthPlanningProvider).valueOrNull!;
      expect(updated.incomeMode, IncomeMode.actual);
      verify(() => repository.savePlan(any())).called(1);
    });

    test('atualiza renda manual', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.setManualIncome(7200);

      expect(
        container.read(monthPlanningProvider).valueOrNull!.manualIncome,
        7200,
      );
    });

    test('atualiza orçamento mensal', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.setMonthlyBudget(2500);

      expect(
        container.read(monthPlanningProvider).valueOrNull!.monthlyBudget,
        2500,
      );
    });

    test('atualiza percentual de categoria e persiste', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.updateCategoryPercentage('a', 45);

      final updated = container.read(monthPlanningProvider).valueOrNull!;
      expect(
        updated.categories.firstWhere((c) => c.categoryId == 'a').percentage,
        45,
      );
      verify(() => repository.savePlan(any())).called(1);
    });

    test('percentual é limitado ao intervalo 0..100', () async {
      when(() => repository.getOrCreatePlanForMonth(any())).thenAnswer(
        (_) async => _plan(categories: [_category('a', 30)]),
      );
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.updateCategoryPercentage('a', 150);
      await notifier.updateCategoryPercentage('a', -10);

      final updated = container.read(monthPlanningProvider).valueOrNull!;
      expect(
        updated.categories.firstWhere((c) => c.categoryId == 'a').percentage,
        0,
      );
      await notifier.updateCategoryPercentage('a', 150);
      expect(
        container
            .read(monthPlanningProvider)
            .valueOrNull!
            .categories
            .first
            .percentage,
        100,
      );
    });

    test('rejeita soma acima de 100% sem alterar o estado', () async {
      when(() => repository.getOrCreatePlanForMonth(any())).thenAnswer(
        (_) async => _plan(
          categories: [_category('a', 60), _category('b', 30)],
        ),
      );
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await expectLater(
        notifier.updateCategoryPercentage('a', 80),
        throwsA(isA<ArgumentError>()),
      );

      final state = container.read(monthPlanningProvider);
      expect(
        state.valueOrNull!.categories.first.percentage,
        60,
      );
      verifyNever(() => repository.savePlan(any()));
    });

    test('remove categoria do plano', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.removeCategory('b');

      final updated = container.read(monthPlanningProvider).valueOrNull!;
      expect(updated.categories.map((c) => c.categoryId), ['a']);
    });

    test('atualiza preferências de notificação', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.updateNotifications(
        const NotificationSettings(enabled: false, thresholds: [50]),
      );

      final updated = container.read(monthPlanningProvider).valueOrNull!;
      expect(updated.notifications.enabled, isFalse);
      expect(updated.notifications.thresholds, [50]);
    });

    test('recria o plano quando o mês selecionado muda', () async {
      await loadPlan();

      container.read(selectedPlanMonthProvider.notifier).state =
          DateTime(2026, 12);
      await container.read(monthPlanningProvider.notifier).load();

      verify(
        () => repository.getOrCreatePlanForMonth(DateTime(2026, 12)),
      ).called(greaterThan(0));
    });
  });

  group('unallocatedPercentageProvider', () {
    test('reflete a reserva após carregar o plano', () async {
      await loadPlan();

      // 30% + 20% alocados => 50% de reserva.
      expect(container.read(unallocatedPercentageProvider), 50);
      expect(container.read(reserveAmountProvider), 500);
    });

    test('atualiza reativamente ao mudar percentual', () async {
      await loadPlan();
      final notifier = container.read(monthPlanningProvider.notifier);

      await notifier.updateCategoryPercentage('b', 40);

      expect(container.read(unallocatedPercentageProvider), 30);
    });
  });

  group('planningProgressProvider', () {
    test('expõe progresso calculado pelo repositório', () async {
      await loadPlan();

      final progress = CategoryProgress(
        budget: _category('a', 30),
        allocatedAmount: 300,
        spentAmount: 330,
        thresholds: const [80, 90, 100],
      );
      when(() => repository.getCategoryProgress(any()))
          .thenAnswer((_) async => [progress]);

      final result = await container.read(planningProgressProvider.future);

      expect(result, hasLength(1));
      expect(result.single.progressPercent, closeTo(110, 0.001));
      expect(result.single.isOverBudget, isTrue);
      expect(result.single.isAlert, isTrue);
      expect(result.single.triggeredThreshold, 100);
    });

    test('retorna lista vazia quando o plano não tem categorias', () async {
      when(() => repository.getOrCreatePlanForMonth(any())).thenAnswer(
        (_) async => _plan(categories: const <CategoryBudget>[]),
      );
      await loadPlan();

      final result = await container.read(planningProgressProvider.future);
      expect(result, isEmpty);
    });
  });

  group('planningAlertsProvider', () {
    test('carrega alertas e deriva não lidos', () async {
      when(() => repository.getAlerts()).thenAnswer(
        (_) async => [
          _alert(id: 'alert-1'),
          _alert(id: 'alert-2', read: true),
        ],
      );

      final notifier = container.read(planningAlertsProvider.notifier);
      await notifier.load();

      expect(container.read(planningAlertsProvider).valueOrNull, hasLength(2));
      expect(container.read(unreadAlertsProvider), hasLength(1));
      expect(container.read(unreadAlertCountProvider), 1);
    });

    test('marca alerta como lido', () async {
      final alerts = <BudgetAlert>[_alert(id: 'alert-1')];
      when(() => repository.getAlerts()).thenAnswer((_) async => [...alerts]);
      when(() => repository.markAlertRead('alert-1')).thenAnswer((_) async {
        alerts[0] = alerts[0].copyWith(read: true);
      });

      final notifier = container.read(planningAlertsProvider.notifier);
      await notifier.load();
      await notifier.markRead('alert-1');

      verify(() => repository.markAlertRead('alert-1')).called(1);
      expect(container.read(unreadAlertCountProvider), 0);
    });

    test('dispensa alerta removendo da lista', () async {
      final alerts = <BudgetAlert>[_alert(id: 'alert-1')];
      when(() => repository.getAlerts()).thenAnswer((_) async => [...alerts]);
      when(() => repository.dismissAlert('alert-1')).thenAnswer((_) async {
        alerts.removeWhere((alert) => alert.id == 'alert-1');
      });

      final notifier = container.read(planningAlertsProvider.notifier);
      await notifier.load();
      await notifier.dismiss('alert-1');

      verify(() => repository.dismissAlert('alert-1')).called(1);
      expect(container.read(planningAlertsProvider).valueOrNull, isEmpty);
    });

    test('marca todos os alertas como lidos', () async {
      final alerts = <BudgetAlert>[
        _alert(id: 'alert-1'),
        _alert(id: 'alert-2', threshold: 90),
      ];
      when(() => repository.getAlerts()).thenAnswer((_) async => [...alerts]);
      when(() => repository.markAllAlertsRead()).thenAnswer((_) async {
        for (var i = 0; i < alerts.length; i++) {
          alerts[i] = alerts[i].copyWith(read: true);
        }
      });

      final notifier = container.read(planningAlertsProvider.notifier);
      await notifier.load();
      await notifier.markAllRead();

      expect(container.read(unreadAlertCountProvider), 0);
      verify(() => repository.markAllAlertsRead()).called(1);
    });
  });
}
