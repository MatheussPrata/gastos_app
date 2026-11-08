import 'package:freezed_annotation/freezed_annotation.dart';

part 'planning_models.freezed.dart';
part 'planning_models.g.dart';

/// How the monthly income baseline for a budget plan is determined.
enum IncomeMode {
  /// The user types the expected income manually.
  manual,

  /// The income is computed from the real income transactions of the month.
  actual,
}

/// Who the budget plan belongs to.
enum BudgetScope {
  /// Only the signed-in user's expenses and income.
  individual,

  /// The couple's shared budget, including the partner's transactions.
  couple,
}

/// Monthly financial plan: how much to spend and how it is split per category.
///
/// Percentages are intentionally allowed to sum to **less than** 100%; the
/// remainder is treated as "Não alocado / Reserva" instead of being rejected.
@freezed
class BudgetPlan with _$BudgetPlan {
  const factory BudgetPlan({
    required String id,
    required String userId,

    /// Reference month, always normalized to the first day at 00:00.
    required DateTime month,

    /// Whether this is the individual or the couple budget.
    @Default(BudgetScope.individual) BudgetScope scope,

    /// Whether income comes from a manual value or from real transactions.
    @Default(IncomeMode.manual) IncomeMode incomeMode,

    /// Expected income when [incomeMode] is [IncomeMode.manual].
    @Default(0) double manualIncome,

    /// Total amount the user wants to spend in the month.
    @Default(0) double monthlyBudget,

    /// Per-category allocation of the budget.
    @Default(<CategoryBudget>[]) List<CategoryBudget> categories,

    /// Alert preferences for this plan.
    @Default(NotificationSettings()) NotificationSettings notifications,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool isSynced,
  }) = _BudgetPlan;

  factory BudgetPlan.fromJson(Map<String, dynamic> json) =>
      _$BudgetPlanFromJson(json);

  const BudgetPlan._();

  /// Sum of the active category percentages (may be <= 100).
  double get allocatedPercentage => categories
      .where((category) => category.isActive)
      .fold<double>(0, (sum, category) => sum + category.percentage);

  /// Percentage not assigned to any category, kept as reserve.
  double get unallocatedPercentage {
    final remaining = 100 - allocatedPercentage;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether the plan stays within the 100% ceiling.
  bool get isValid => allocatedPercentage <= 100;

  /// Amount reserved (not allocated) for the month.
  double get reserveAmount => monthlyBudget * unallocatedPercentage / 100;

  /// Income to consider for the plan. When [incomeMode] is manual, uses
  /// [manualIncome]; otherwise uses the [actualIncome] informed by the caller.
  double effectiveIncome(double actualIncome) {
    switch (incomeMode) {
      case IncomeMode.manual:
        return manualIncome;
      case IncomeMode.actual:
        return actualIncome;
    }
  }

  /// Returns a copy with a category replaced (matched by category id) or
  /// appended when it does not exist yet.
  BudgetPlan upsertCategory(CategoryBudget category) {
    final updated = [...categories];
    final index =
        updated.indexWhere((item) => item.categoryId == category.categoryId);
    if (index >= 0) {
      updated[index] = category;
    } else {
      updated.add(category);
    }
    return copyWith(categories: updated);
  }

  /// Merges a plan downloaded from the server using last-write-wins.
  ///
  /// Returns `this` when the local plan is newer, keeping its local id and
  /// sync flag. Otherwise returns the remote values with [isSynced] set.
  BudgetPlan mergeRemote(BudgetPlan remote) {
    if (updatedAt.isAfter(remote.updatedAt)) return this;
    return copyWith(
      incomeMode: remote.incomeMode,
      manualIncome: remote.manualIncome,
      monthlyBudget: remote.monthlyBudget,
      categories: remote.categories,
      notifications: remote.notifications,
      updatedAt: remote.updatedAt,
      isSynced: true,
    );
  }
}

/// Budget assigned to a single category.
///
/// The monetary amount is always derived from the plan's [BudgetPlan.monthlyBudget]
/// so it stays consistent when the budget changes.
@freezed
class CategoryBudget with _$CategoryBudget {
  const factory CategoryBudget({
    required String categoryId,
    required String categoryName,
    required int categoryColor,
    required String categoryIcon,
    @Default(0) double percentage,
    @Default(true) bool isActive,
    @Default(0) int sortOrder,
  }) = _CategoryBudget;

  factory CategoryBudget.fromJson(Map<String, dynamic> json) =>
      _$CategoryBudgetFromJson(json);

  const CategoryBudget._();

  /// Amount allocated for this category for the given total budget.
  double amountFor(double monthlyBudget) => monthlyBudget * percentage / 100;
}

/// Notification preferences attached to a budget plan.
@freezed
class NotificationSettings with _$NotificationSettings {
  const factory NotificationSettings({
    @Default(true) bool enabled,

    /// Percent thresholds that trigger an alert (e.g. 80, 90, 100).
    @Default(<int>[80, 90, 100]) List<int> thresholds,

    /// Whether to show a system push notification.
    @Default(true) bool pushNotification,

    /// Whether to show an in-app banner / badge.
    @Default(true) bool inAppNotification,
  }) = _NotificationSettings;

  factory NotificationSettings.fromJson(Map<String, dynamic> json) =>
      _$NotificationSettingsFromJson(json);
}

/// Alert emitted when a category reaches one of the configured thresholds.
@freezed
class BudgetAlert with _$BudgetAlert {
  const factory BudgetAlert({
    required String id,
    required String planId,
    required String categoryId,
    required String categoryName,

    /// Whether the alert came from the individual or the couple budget.
    @Default(BudgetScope.individual) BudgetScope scope,

    /// Percentage threshold that was reached (80, 90, 100...).
    required int threshold,
    required double spentAmount,
    required double allocatedAmount,
    required DateTime triggeredAt,
    @Default(false) bool read,
    @Default(false) bool dismissed,
    @Default(false) bool isSynced,
  }) = _BudgetAlert;

  factory BudgetAlert.fromJson(Map<String, dynamic> json) =>
      _$BudgetAlertFromJson(json);

  const BudgetAlert._();

  bool get isOverBudget => spentAmount > allocatedAmount;

  double get progressPercent =>
      allocatedAmount <= 0 ? 0 : spentAmount / allocatedAmount * 100;
}

/// Runtime view that merges a category budget with the amount actually spent.
///
/// This is not persisted, therefore not a freezed/json model.
class CategoryProgress {
  const CategoryProgress({
    required this.budget,
    required this.allocatedAmount,
    required this.spentAmount,
    this.thresholds = const <int>[80, 90, 100],
  });

  final CategoryBudget budget;
  final double allocatedAmount;
  final double spentAmount;

  /// Thresholds configured in the plan, used to derive [triggeredThreshold].
  final List<int> thresholds;

  String get categoryId => budget.categoryId;
  String get categoryName => budget.categoryName;
  int get categoryColor => budget.categoryColor;
  String get categoryIcon => budget.categoryIcon;

  double get remainingAmount => allocatedAmount - spentAmount;

  /// Progress ratio (0..1+). Values above 1 mean the category is over budget.
  double get progress =>
      allocatedAmount <= 0 ? 0 : spentAmount / allocatedAmount;

  double get progressPercent => progress * 100;

  bool get isOverBudget => spentAmount > allocatedAmount;

  /// Whether the category reached [threshold] percent of its allocation.
  bool reachedThreshold(int threshold) => progressPercent >= threshold;

  /// Highest configured threshold already reached, or null when none was.
  int? get triggeredThreshold {
    int? highest;
    for (final threshold in thresholds) {
      if (reachedThreshold(threshold) &&
          (highest == null || threshold > highest)) {
        highest = threshold;
      }
    }
    return highest;
  }

  /// Whether at least one configured alert threshold was reached.
  bool get isAlert => triggeredThreshold != null;
}

/// Income received by one person in a given month.
class IncomeAttribution {
  const IncomeAttribution({
    required this.userId,
    required this.amount,
  });

  final String userId;
  final double amount;
}

/// Category spending in a month that does not have an active budget allocation.
class UnbudgetedCategoryExpense {
  const UnbudgetedCategoryExpense({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.spentAmount,
  });

  final String categoryId;
  final String categoryName;
  final int categoryColor;
  final String categoryIcon;
  final double spentAmount;
}
