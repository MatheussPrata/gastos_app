import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';

/// Month currently opened in the planning tab, normalized to the first day.
final selectedPlanMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Holds the budget plan of [selectedPlanMonthProvider].
///
/// Edits are applied optimistically to the state and persisted serially, so
/// fast slider movements can never write older plans over newer ones.
class PlanningNotifier extends StateNotifier<AsyncValue<BudgetPlan?>> {
  PlanningNotifier(this._repository, this.month)
      : super(const AsyncValue.loading()) {
    load();
  }

  final PlanningRepository _repository;

  /// Reference month this notifier is bound to.
  final DateTime month;

  Future<void> _saveQueue = Future<void>.value();
  int _revision = 0;

  BudgetPlan? get plan => state.valueOrNull;

  /// Loads (or creates) the plan for [month].
  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final loaded = await _repository.getOrCreatePlanForMonth(month);
      if (!mounted) return;
      state = AsyncValue.data(loaded);
    } catch (error, stack) {
      if (!mounted) return;
      state = AsyncValue.error(error, stack);
    }
  }

  /// Re-reads the plan (used after external changes, e.g. a new transaction).
  Future<void> refresh() => load();

  /// Switches between manual income and the real income of the month.
  Future<void> setIncomeMode(IncomeMode mode) async {
    final current = plan;
    if (current == null || current.incomeMode == mode) return;
    await _apply(current.copyWith(incomeMode: mode));
  }

  /// Updates the manual income value (used when mode is manual).
  Future<void> setManualIncome(double value) async {
    final current = plan;
    if (current == null || value < 0) return;
    await _apply(current.copyWith(manualIncome: value));
  }

  /// Updates the total monthly budget.
  Future<void> setMonthlyBudget(double value) async {
    final current = plan;
    if (current == null || value < 0) return;
    await _apply(current.copyWith(monthlyBudget: value));
  }

  /// Updates the percentage of one category, keeping the <= 100% rule.
  Future<void> updateCategoryPercentage(
    String categoryId,
    double percentage,
  ) async {
    final current = plan;
    if (current == null) return;

    final index =
        current.categories.indexWhere((item) => item.categoryId == categoryId);
    if (index < 0) return;

    final clamped = percentage.clamp(0, 100).toDouble();
    final updated = current.upsertCategory(
      current.categories[index].copyWith(percentage: clamped),
    );
    await _apply(updated);
  }

  /// Replaces/inserts a whole category budget entry.
  Future<void> upsertCategory(CategoryBudget category) async {
    final current = plan;
    if (current == null) return;
    await _apply(current.upsertCategory(category));
  }

  /// Removes a category from the plan (it stops receiving budget).
  Future<void> removeCategory(String categoryId) async {
    final current = plan;
    if (current == null) return;
    final remaining = current.categories
        .where((item) => item.categoryId != categoryId)
        .toList();
    await _apply(current.copyWith(categories: remaining));
  }

  /// Updates alert preferences (enabled flag, thresholds, channels).
  Future<void> updateNotifications(NotificationSettings notifications) async {
    final current = plan;
    if (current == null) return;
    await _apply(current.copyWith(notifications: notifications));
  }

  /// Replaces the whole plan (used by the setup screen).
  Future<void> applyPlan(BudgetPlan next) => _apply(next);

  /// Validates, applies optimistically and persists [next].
  Future<void> _apply(BudgetPlan next) async {
    if (!next.isValid) {
      throw ArgumentError(
        'A soma dos percentuais não pode ultrapassar 100% '
        '(atual: ${next.allocatedPercentage.toStringAsFixed(1)}%).',
      );
    }

    final revision = ++_revision;
    state = AsyncValue.data(next);

    final saveFuture = _saveQueue.then((_) => _repository.savePlan(next));
    _saveQueue = saveFuture.then<void>((_) {}, onError: (Object _) {});

    try {
      final saved = await saveFuture;
      if (mounted && revision == _revision) {
        state = AsyncValue.data(saved);
      }
    } catch (error, stack) {
      if (mounted && revision == _revision) {
        state = AsyncValue.error(error, stack);
      }
      rethrow;
    }
  }
}

/// Current plan of the selected month, auto-created on first access.
final monthPlanningProvider =
    StateNotifierProvider<PlanningNotifier, AsyncValue<BudgetPlan?>>((ref) {
  final month = ref.watch(selectedPlanMonthProvider);
  final repository = ref.watch(planningRepositoryProvider);
  return PlanningNotifier(repository, month);
});

/// Real spending merged with the plan allocation, per category.
final planningProgressProvider =
    FutureProvider<List<CategoryProgress>>((ref) async {
  final plan = ref.watch(monthPlanningProvider).valueOrNull;
  if (plan == null) return const <CategoryProgress>[];

  final repository = ref.watch(planningRepositoryProvider);
  return repository.getCategoryProgress(plan);
});

/// Percentage still not allocated to any category (kept as reserve).
final unallocatedPercentageProvider = Provider<double>((ref) {
  final plan = ref.watch(monthPlanningProvider).valueOrNull;
  return plan?.unallocatedPercentage ?? 100;
});

/// Amount in R$ kept as reserve for the selected month.
final reserveAmountProvider = Provider<double>((ref) {
  final plan = ref.watch(monthPlanningProvider).valueOrNull;
  return plan?.reserveAmount ?? 0;
});

/// Income transactions of a given month (real income).
final actualIncomeForMonthProvider =
    FutureProvider.family<double, DateTime>((ref, month) async {
  final repository = ref.watch(planningRepositoryProvider);
  return repository.getActualIncomeForMonth(month);
});

/// Income considered for the selected month, according to the plan mode.
final monthlyIncomeProvider = FutureProvider<double>((ref) async {
  final plan = ref.watch(monthPlanningProvider).valueOrNull;
  if (plan == null) return 0;
  if (plan.incomeMode == IncomeMode.manual) return plan.manualIncome;
  return ref.watch(actualIncomeForMonthProvider(plan.month).future);
});

/// Total expenses of the plan month (including uncategorized ones).
final monthSpentTotalProvider = FutureProvider<double>((ref) async {
  final plan = ref.watch(monthPlanningProvider).valueOrNull;
  if (plan == null) return 0;
  final repository = ref.watch(planningRepositoryProvider);
  final spent = await repository.getSpentByCategory(plan.month);
  return spent.values.fold<double>(0, (sum, value) => sum + value);
});

/// Manages the list of non-dismissed budget alerts.
class PlanningAlertsNotifier
    extends StateNotifier<AsyncValue<List<BudgetAlert>>> {
  PlanningAlertsNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final PlanningRepository _repository;

  /// Loads active (non-dismissed) alerts, newest first.
  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final alerts = await _repository.getAlerts();
      if (!mounted) return;
      state = AsyncValue.data(alerts);
    } catch (error, stack) {
      if (!mounted) return;
      state = AsyncValue.error(error, stack);
    }
  }

  /// Marks one alert as read.
  Future<void> markRead(String alertId) async {
    await _repository.markAlertRead(alertId);
    if (!mounted) return;
    await load();
  }

  /// Marks every alert as read.
  Future<void> markAllRead() async {
    await _repository.markAllAlertsRead();
    if (!mounted) return;
    await load();
  }

  /// Dismisses an alert so it is no longer listed.
  Future<void> dismiss(String alertId) async {
    await _repository.dismissAlert(alertId);
    if (!mounted) return;
    await load();
  }
}

/// Active budget alerts.
final planningAlertsProvider = StateNotifierProvider<PlanningAlertsNotifier,
    AsyncValue<List<BudgetAlert>>>((ref) {
  final repository = ref.watch(planningRepositoryProvider);
  return PlanningAlertsNotifier(repository);
});

/// Alerts that were not read yet.
final unreadAlertsProvider = Provider<List<BudgetAlert>>((ref) {
  final alerts = ref.watch(planningAlertsProvider).valueOrNull ?? const [];
  return alerts.where((alert) => !alert.read && !alert.dismissed).toList();
});

/// Number of unread alerts, used for the tab badge.
final unreadAlertCountProvider = Provider<int>((ref) {
  return ref.watch(unreadAlertsProvider).length;
});
