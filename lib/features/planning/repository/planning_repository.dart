import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/storage/secure_storage_config.dart';
import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return PlanningRepository();
});

/// Offline-first repository for the financial planning (budget) feature.
class PlanningRepository {
  final db.AppDatabase _db;
  final FlutterSecureStorage _storage;
  final Uuid _uuid;
  final SyncService _sync;

  PlanningRepository({
    db.AppDatabase? database,
    FlutterSecureStorage? storage,
    Uuid? uuid,
    SyncService? syncService,
  })  : _db = database ?? db.AppDatabase(),
        _storage = storage ?? SecureStorageConfig.create(),
        _uuid = uuid ?? const Uuid(),
        _sync = syncService ?? SyncService();

  // ---------------------------------------------------------------- mapping

  DateTime _normalizeMonth(DateTime month) => DateTime(month.year, month.month);

  BudgetPlan _toModel(db.BudgetPlan row) {
    return BudgetPlan(
      id: row.id,
      userId: row.userId,
      month: row.month,
      scope: BudgetScope.values.firstWhere(
        (scope) => scope.name == row.scope,
        orElse: () => BudgetScope.individual,
      ),
      incomeMode: IncomeMode.values.firstWhere(
        (mode) => mode.name == row.incomeMode,
        orElse: () => IncomeMode.manual,
      ),
      manualIncome: row.manualIncome,
      monthlyBudget: row.monthlyBudget,
      categories: _decodeCategories(row.categoriesJson),
      notifications: _decodeNotifications(row.notificationsJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      isSynced: row.isSynced,
    );
  }

  db.BudgetPlansCompanion _toCompanion(BudgetPlan plan,
      {required bool synced}) {
    return db.BudgetPlansCompanion(
      id: Value(plan.id),
      userId: Value(plan.userId),
      month: Value(_normalizeMonth(plan.month)),
      scope: Value(plan.scope.name),
      incomeMode: Value(plan.incomeMode.name),
      manualIncome: Value(plan.manualIncome),
      monthlyBudget: Value(plan.monthlyBudget),
      categoriesJson: Value(jsonEncode(
        plan.categories.map((category) => category.toJson()).toList(),
      )),
      notificationsJson: Value(jsonEncode(plan.notifications.toJson())),
      createdAt: Value(plan.createdAt),
      updatedAt: Value(plan.updatedAt),
      isSynced: Value(synced),
    );
  }

  BudgetAlert _alertToModel(db.BudgetAlert row) {
    return BudgetAlert(
      id: row.id,
      planId: row.planId,
      categoryId: row.categoryId,
      categoryName: row.categoryName,
      scope: BudgetScope.values.firstWhere(
        (scope) => scope.name == row.scope,
        orElse: () => BudgetScope.individual,
      ),
      threshold: row.threshold,
      spentAmount: row.spentAmount,
      allocatedAmount: row.allocatedAmount,
      triggeredAt: row.triggeredAt,
      read: row.read,
      dismissed: row.dismissed,
      isSynced: row.isSynced,
    );
  }

  List<CategoryBudget> _decodeCategories(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CategoryBudget.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  NotificationSettings _decodeNotifications(String raw) {
    if (raw.trim().isEmpty) return const NotificationSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const NotificationSettings();
      return NotificationSettings.fromJson(decoded);
    } catch (_) {
      return const NotificationSettings();
    }
  }

  // ------------------------------------------------------------------ reads

  /// Returns the plan for [month] and [scope], or null when not configured.
  Future<BudgetPlan?> getPlanForMonth(
    DateTime month, {
    BudgetScope scope = BudgetScope.individual,
  }) async {
    final normalized = _normalizeMonth(month);
    final row = await (_db.select(_db.budgetPlans)
          ..where((plan) =>
              plan.month.equals(normalized) & plan.scope.equals(scope.name)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Returns the plan for [month], creating a default one when absent.
  ///
  /// [categories] is used to seed the plan with every expense category at 0%.
  /// When omitted, the locally stored categories are used.
  Future<BudgetPlan> getOrCreatePlanForMonth(
    DateTime month, {
    BudgetScope scope = BudgetScope.individual,
    List<Category>? categories,
    String? userId,
  }) async {
    final existing = await getPlanForMonth(month, scope: scope);
    if (existing != null) return existing;

    final seededCategories = categories ?? await _localExpenseCategories();
    final now = DateTime.now();
    final plan = BudgetPlan(
      id: _uuid.v4(),
      userId: userId ?? await _currentUserId(),
      month: _normalizeMonth(month),
      scope: scope,
      categories: [
        for (var index = 0; index < seededCategories.length; index++)
          CategoryBudget(
            categoryId: seededCategories[index].id,
            categoryName: seededCategories[index].name,
            categoryColor: seededCategories[index].color,
            categoryIcon: seededCategories[index].icon,
            sortOrder: index,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    return savePlan(plan);
  }

  /// Income transactions of [month], filtered by [scope].
  Future<List<db.Transaction>> _monthTransactions(
    DateTime month, {
    required bool isExpense,
    required BudgetScope scope,
  }) async {
    final start = _normalizeMonth(month);
    final end = DateTime(start.year, start.month + 1);

    final query = _db.select(_db.transactions)
      ..where((t) => t.isExpense.equals(isExpense))
      ..where((t) => t.date.isBiggerOrEqualValue(start))
      ..where((t) => t.date.isSmallerThanValue(end));

    if (scope == BudgetScope.individual) {
      // Partner transactions are merged locally with partnerSynced = true.
      query.where((t) => t.partnerSynced.equals(false));
    }

    return query.get();
  }

  /// Income actually received in [month], based on income transactions.
  Future<double> getActualIncomeForMonth(
    DateTime month, {
    BudgetScope scope = BudgetScope.individual,
  }) async {
    final rows = await _monthTransactions(
      month,
      isExpense: false,
      scope: scope,
    );
    return rows.fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  /// Income of [month] grouped by the person who received it.
  Future<List<IncomeAttribution>> getIncomeByOwnerForMonth(
    DateTime month, {
    BudgetScope scope = BudgetScope.individual,
  }) async {
    final rows = await _monthTransactions(
      month,
      isExpense: false,
      scope: scope,
    );

    final totals = <String, double>{};
    for (final transaction in rows) {
      final owner = transaction.ownerId?.isNotEmpty == true
          ? transaction.ownerId!
          : transaction.userId;
      totals[owner] = (totals[owner] ?? 0) + transaction.amount;
    }

    return totals.entries
        .map(
          (entry) => IncomeAttribution(
            userId: entry.key,
            amount: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Income to use for [plan], honoring its [IncomeMode].
  Future<double> resolveIncome(BudgetPlan plan) async {
    switch (plan.incomeMode) {
      case IncomeMode.manual:
        return plan.manualIncome;
      case IncomeMode.actual:
        return getActualIncomeForMonth(plan.month, scope: plan.scope);
    }
  }

  /// Expenses of [month] grouped by category id, filtered by [scope].
  Future<Map<String, double>> getSpentByCategory(
    DateTime month, {
    BudgetScope scope = BudgetScope.individual,
  }) async {
    final rows = await _monthTransactions(
      month,
      isExpense: true,
      scope: scope,
    );

    final totals = <String, double>{};
    final cardSpent = <String, double>{};

    for (final transaction in rows) {
      final key = transaction.categoryId ?? 'none';
      totals[key] = (totals[key] ?? 0) + transaction.amount;

      if (transaction.creditCardId != null &&
          transaction.creditCardId!.isNotEmpty) {
        cardSpent[transaction.creditCardId!] =
            (cardSpent[transaction.creditCardId!] ?? 0) + transaction.amount;
      }
    }

    // Se o valor total da fatura informado pelo usuário for maior que os gastos
    // lançados para o cartão, a diferença é atribuída à categoria "nao_informada".
    final cards = await (_db.select(_db.creditCards)
          ..where((c) => c.isActive.equals(true)))
        .get();

    final prefix = 'card_invoice_';
    final suffix = '_${month.year}_${month.month}';
    final settings = await _db.select(_db.appSettings).get();
    final invoiceMap = <String, double>{};

    for (final s in settings) {
      if (s.key.startsWith(prefix) &&
          !s.key.startsWith('card_invoice_paid_') &&
          s.key.endsWith(suffix)) {
        final cardId = s.key.substring(
          prefix.length,
          s.key.length - suffix.length,
        );
        final val = double.tryParse(s.value) ?? 0.0;
        if (val > 0) invoiceMap[cardId] = val;
      }
    }

    double totalDifference = 0.0;
    for (final card in cards) {
      final invoice = invoiceMap[card.id] ?? 0.0;
      final range = CreditCardCycleHelper.invoiceDateRange(
        invoiceMonth: month,
        closingDay: card.closingDay,
      );
      final cardTxs = await (_db.select(_db.transactions)
            ..where((t) =>
                t.creditCardId.equals(card.id) &
                t.isExpense.equals(true) &
                t.date.isBiggerOrEqualValue(range.start) &
                t.date.isSmallerOrEqualValue(range.end)))
          .get();
      final spent = cardTxs.fold<double>(0.0, (sum, t) => sum + t.amount);
      if (invoice > spent) {
        totalDifference += (invoice - spent);
      }
    }

    if (totalDifference > 0) {
      totals['nao_informada'] =
          (totals['nao_informada'] ?? 0) + totalDifference;
    }

    return totals;
  }

  /// Merged view of the plan allocation and the real spending.
  Future<List<CategoryProgress>> getCategoryProgress(BudgetPlan plan) async {
    final spent = await getSpentByCategory(plan.month, scope: plan.scope);
    final categories = await _db.select(_db.categories).get();
    final colorMap = {for (final c in categories) c.id: c.color};
    final nameMap = {for (final c in categories) c.id: c.name};
    final iconMap = {for (final c in categories) c.id: c.icon};

    return plan.categories
        .where((category) => category.isActive)
        .map(
          (category) {
            final liveColor = colorMap[category.categoryId];
            final liveName = nameMap[category.categoryId];
            final liveIcon = iconMap[category.categoryId];
            final updatedBudget = (liveColor != null &&
                    (liveColor != category.categoryColor ||
                        liveName != category.categoryName))
                ? category.copyWith(
                    categoryColor: liveColor,
                    categoryName: liveName ?? category.categoryName,
                    categoryIcon: liveIcon ?? category.categoryIcon,
                  )
                : category;

            return CategoryProgress(
              budget: updatedBudget,
              allocatedAmount: updatedBudget.amountFor(plan.monthlyBudget),
              spentAmount: spent[category.categoryId] ?? 0,
              thresholds: plan.notifications.thresholds,
            );
          },
        )
        .toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
  }

  Future<List<BudgetAlert>> getAlerts({
    bool unreadOnly = false,
    bool includeDismissed = false,
  }) async {
    final query = _db.select(_db.budgetAlerts)
      ..orderBy([(alert) => OrderingTerm.desc(alert.triggeredAt)]);

    if (unreadOnly) {
      query.where((alert) => alert.read.equals(false));
    }
    if (!includeDismissed) {
      query.where((alert) => alert.dismissed.equals(false));
    }

    final rows = await query.get();
    return rows.map(_alertToModel).toList();
  }

  Future<int> getUnreadAlertCount() async {
    final count = _db.budgetAlerts.id.count();
    final query = _db.selectOnly(_db.budgetAlerts)
      ..addColumns([count])
      ..where(_db.budgetAlerts.read.equals(false) &
          _db.budgetAlerts.dismissed.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ----------------------------------------------------------------- writes

  /// Persists [plan]. Percentages above 100 are rejected defensively.
  Future<BudgetPlan> savePlan(BudgetPlan plan) async {
    if (!plan.isValid) {
      throw ArgumentError(
        'A soma dos percentuais não pode ultrapassar 100% '
        '(atual: ${plan.allocatedPercentage.toStringAsFixed(1)}%).',
      );
    }

    final now = DateTime.now();
    final normalized = plan.copyWith(
      month: _normalizeMonth(plan.month),
      updatedAt: now,
      isSynced: false,
    );

    await _db
        .into(_db.budgetPlans)
        .insertOnConflictUpdate(_toCompanion(normalized, synced: false));

    unawaited(_syncPlan(normalized));

    return normalized;
  }

  Future<void> deletePlan(String id) async {
    await (_db.delete(_db.budgetPlans)..where((plan) => plan.id.equals(id)))
        .go();
    await (_db.delete(_db.budgetAlerts)
          ..where((alert) => alert.planId.equals(id)))
        .go();
  }

  /// Merges a plan downloaded from the server into the local database.
  ///
  /// The local row keeps its id; only the plan values are replaced when the
  /// remote version is newer (see [BudgetPlan.mergeRemote]).
  Future<BudgetPlan> mergeRemotePlan(BudgetPlan remote) async {
    final normalized = _normalizeMonth(remote.month);
    final local = await getPlanForMonth(normalized, scope: remote.scope);
    final merged = local == null
        ? remote.copyWith(
            month: normalized,
            userId: await _currentUserId(),
            isSynced: true,
          )
        : local.mergeRemote(remote);

    await _db.into(_db.budgetPlans).insertOnConflictUpdate(
          _toCompanion(merged, synced: merged.isSynced),
        );

    return merged;
  }

  Future<void> markAlertRead(String alertId) async {
    await (_db.update(_db.budgetAlerts)..where((a) => a.id.equals(alertId)))
        .write(const db.BudgetAlertsCompanion(
      read: Value(true),
      isSynced: Value(false),
    ));
  }

  Future<void> dismissAlert(String alertId) async {
    await (_db.update(_db.budgetAlerts)..where((a) => a.id.equals(alertId)))
        .write(const db.BudgetAlertsCompanion(
      dismissed: Value(true),
      isSynced: Value(false),
    ));
  }

  Future<void> markAllAlertsRead() async {
    await _db.update(_db.budgetAlerts).write(const db.BudgetAlertsCompanion(
          read: Value(true),
          isSynced: Value(false),
        ));
  }

  // ---------------------------------------------------------------- triggers

  /// Checks the plan of [month] against real spending and persists new alerts.
  ///
  /// Returns only the alerts created by this run so callers can display them.
  /// Alerts are deduplicated by (planId, categoryId, threshold), so a threshold
  /// never fires twice for the same plan.
  Future<List<BudgetAlert>> checkAndCreateAlerts({
    DateTime? month,
    BudgetScope scope = BudgetScope.individual,
  }) async {
    final reference = _normalizeMonth(month ?? DateTime.now());
    final plan = await getPlanForMonth(reference, scope: scope);
    if (plan == null || !plan.notifications.enabled) return const [];

    final thresholds = [...plan.notifications.thresholds]..sort();
    if (thresholds.isEmpty) return const [];

    final spentByCategory =
        await getSpentByCategory(reference, scope: plan.scope);
    final existing = await (_db.select(_db.budgetAlerts)
          ..where((alert) => alert.planId.equals(plan.id)))
        .get();
    final alreadyFired = {
      for (final alert in existing) '${alert.categoryId}:${alert.threshold}',
    };

    final created = <BudgetAlert>[];
    final now = DateTime.now();

    for (final category in plan.categories) {
      if (!category.isActive || category.percentage <= 0) continue;

      final allocated = category.amountFor(plan.monthlyBudget);
      if (allocated <= 0) continue;

      final spent = spentByCategory[category.categoryId] ?? 0;
      if (spent <= 0) continue;

      final progressPercent = spent / allocated * 100;

      for (final threshold in thresholds) {
        if (progressPercent < threshold) continue;
        if (alreadyFired.contains('${category.categoryId}:$threshold')) {
          continue;
        }

        final alert = BudgetAlert(
          id: _uuid.v4(),
          planId: plan.id,
          categoryId: category.categoryId,
          categoryName: category.categoryName,
          scope: plan.scope,
          threshold: threshold,
          spentAmount: spent,
          allocatedAmount: allocated,
          triggeredAt: now,
        );

        await _db.into(_db.budgetAlerts).insert(
              db.BudgetAlertsCompanion(
                id: Value(alert.id),
                planId: Value(alert.planId),
                categoryId: Value(alert.categoryId),
                categoryName: Value(alert.categoryName),
                scope: Value(alert.scope.name),
                threshold: Value(alert.threshold),
                spentAmount: Value(alert.spentAmount),
                allocatedAmount: Value(alert.allocatedAmount),
                triggeredAt: Value(alert.triggeredAt),
                read: Value(alert.read),
                dismissed: Value(alert.dismissed),
                isSynced: const Value(false),
              ),
            );

        alreadyFired.add('${category.categoryId}:$threshold');
        created.add(alert);
      }
    }

    if (created.isNotEmpty) {
      unawaited(_syncAlerts(created));
    }

    return created;
  }

  /// Fire-and-forget variant used by transaction flows so the UI never waits
  /// for the check before dismissing a dialog/route.
  void checkAndCreateAlertsInBackground({
    DateTime? month,
    BudgetScope scope = BudgetScope.individual,
    void Function(List<BudgetAlert> alerts)? onAlerts,
  }) {
    unawaited(() async {
      try {
        final created = await checkAndCreateAlerts(month: month, scope: scope);
        if (created.isNotEmpty) onAlerts?.call(created);
      } catch (_) {
        // Never surface background planning errors to the caller.
      }
    }());
  }

  // ------------------------------------------------------------------- sync

  /// O envio passa pelo [SyncService], que agrupa planos e alertas numa
  /// unica requisicao e trata eliminacoes pendentes.
  Future<void> _syncPlan(BudgetPlan plan) async {
    await _sync.push();
  }

  Future<void> _syncAlerts(List<BudgetAlert> alerts) async {
    await _sync.push();
  }

  Future<bool> _isGuestMode() async {
    try {
      return await _storage.read(key: StorageKeys.isGuestMode) == 'true';
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- helpers

  Future<String> _currentUserId() async {
    try {
      return await _storage.read(key: StorageKeys.userId) ?? 'local';
    } catch (_) {
      return 'local';
    }
  }

  Future<List<Category>> _localExpenseCategories() async {
    final rows = await (_db.select(_db.categories)
          ..where((category) => category.isExpenseDefault.equals(true))
          ..orderBy([(category) => OrderingTerm.asc(category.sortOrder)]))
        .get();

    return rows
        .map(
          (row) => Category(
            id: row.id,
            name: row.name,
            color: row.color,
            icon: row.icon,
            isDefault: row.isDefault,
            isExpenseDefault: row.isExpenseDefault,
            sortOrder: row.sortOrder,
          ),
        )
        .toList();
  }
}
