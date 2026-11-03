import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/ui/pages/budget_setup_page.dart';
import 'package:gastos_app/features/planning/ui/pages/planning_alerts_page.dart';
import 'package:gastos_app/features/planning/ui/planning_ui_helpers.dart';
import 'package:gastos_app/features/planning/ui/widgets/category_budget_dialog.dart';
import 'package:gastos_app/features/planning/ui/widgets/notification_settings_dialog.dart';
import 'package:gastos_app/features/sharing/provider/sharing_provider.dart';

/// Planning tab: monthly budget, per-category progress and alerts.
class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(monthPlanningProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejamento'),
        actions: const [
          _AlertsButton(),
          SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(monthPlanningProvider)
            ..invalidate(planningProgressProvider)
            ..invalidate(planningAlertsProvider)
            ..invalidate(monthlyIncomeProvider)
            ..invalidate(monthSpentTotalProvider);
        },
        child: planAsync.when(
          loading: () => const _LoadingView(),
          error: (error, _) => _ErrorView(
            message: 'Não foi possível carregar o planejamento.',
            onRetry: () => ref.invalidate(monthPlanningProvider),
          ),
          data: (plan) {
            if (plan == null) {
              return const _LoadingView();
            }

            final isEmpty =
                plan.monthlyBudget <= 0 && plan.allocatedPercentage <= 0;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const _ScopeSelector(),
                const _PlanMonthSelector(),
                if (isEmpty)
                  _EmptyPlanning(
                    scope: plan.scope,
                    onStart: () => _openSetup(context, plan),
                  )
                else ...[
                  const _AlertsBanner(),
                  _BudgetOverviewCard(plan: plan),
                  _SectionHeader(
                    title: 'Por categoria',
                    actionLabel: 'Editar',
                    onAction: () => _openSetup(context, plan),
                  ),
                  _CategoryProgressList(plan: plan),
                  const _ReserveCard(),
                  _SettingsTile(settings: plan.notifications),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static void _openSetup(BuildContext context, BudgetPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BudgetSetupPage(plan: plan),
      ),
    );
  }
}

class _AlertsButton extends ConsumerWidget {
  const _AlertsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadAlertCountProvider);

    return IconButton(
      tooltip: 'Alertas',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PlanningAlertsPage()),
      ),
    );
  }
}

class _ScopeSelector extends ConsumerWidget {
  const _ScopeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(selectedBudgetScopeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SegmentedButton<BudgetScope>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: BudgetScope.individual,
            icon: Icon(Icons.person_outline),
            label: Text('Individual'),
          ),
          ButtonSegment(
            value: BudgetScope.couple,
            icon: Icon(Icons.people_outline),
            label: Text('Casal'),
          ),
        ],
        selected: {scope},
        onSelectionChanged: (selection) {
          ref.read(selectedBudgetScopeProvider.notifier).state =
              selection.first;
        },
      ),
    );
  }
}

class _PlanMonthSelector extends ConsumerWidget {
  const _PlanMonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedPlanMonthProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Mês anterior',
            onPressed: () => _shift(ref, -1),
          ),
          Expanded(
            child: Center(
              child: Text(
                planningMonthLabel(month),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próximo mês',
            onPressed: () => _shift(ref, 1),
          ),
        ],
      ),
    );
  }

  void _shift(WidgetRef ref, int delta) {
    final current = ref.read(selectedPlanMonthProvider);
    ref.read(selectedPlanMonthProvider.notifier).state =
        DateTime(current.year, current.month + delta);
  }
}

class _AlertsBanner extends ConsumerWidget {
  const _AlertsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(unreadAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    final latest = alerts.first;

    return Card(
      color: AppColors.warning.withOpacity(0.12),
      elevation: 0,
      child: ListTile(
        leading:
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
        title: Text(
          alerts.length == 1
              ? '1 alerta de orçamento'
              : '${alerts.length} alertas de orçamento',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${latest.categoryName} atingiu ${latest.threshold}% do limite',
        ),
        trailing: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PlanningAlertsPage(),
            ),
          ),
          child: const Text('Ver'),
        ),
      ),
    );
  }
}

class _BudgetOverviewCard extends ConsumerWidget {
  const _BudgetOverviewCard({required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync = ref.watch(monthSpentTotalProvider);
    final incomeAsync = ref.watch(monthlyIncomeProvider);
    final reservePercent = ref.watch(unallocatedPercentageProvider);
    final reserveAmount = ref.watch(reserveAmountProvider);

    final spent = spentAsync.valueOrNull ?? 0;
    final income = incomeAsync.valueOrNull ?? 0;
    final budget = plan.monthlyBudget;
    final remaining = budget - spent;
    final consumedPercent = budget <= 0 ? 0.0 : spent / budget * 100;
    final statusColor = planningStatusColor(consumedPercent);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Orçamento do mês',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _IncomeModeChip(mode: plan.incomeMode),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              CurrencyFormatter.format(spent),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            Text(
              'gasto de ${CurrencyFormatter.format(budget)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: budget <= 0 ? 0 : (spent / budget).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${consumedPercent.toStringAsFixed(0)}% consumido',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  remaining >= 0
                      ? 'Saldo ${CurrencyFormatter.format(remaining)}'
                      : 'Excedeu ${CurrencyFormatter.format(remaining.abs())}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: remaining >= 0
                        ? AppColors.secondary
                        : AppColors.expense,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: _OverviewMetric(
                    label: 'Entradas do mês',
                    value: incomeAsync.isLoading
                        ? '...'
                        : CurrencyFormatter.format(income),
                  ),
                ),
                Expanded(
                  child: _OverviewMetric(
                    label: 'Reserva (${reservePercent.toStringAsFixed(0)}%)',
                    value: CurrencyFormatter.format(reserveAmount),
                    alignEnd: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _IncomeBreakdown(plan: plan),
          ],
        ),
      ),
    );
  }
}

class _IncomeBreakdown extends ConsumerWidget {
  const _IncomeBreakdown({required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plan.incomeMode == IncomeMode.manual) {
      return Text(
        'Renda informada manualmente: '
        '${CurrencyFormatter.format(plan.manualIncome)}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    final incomeAsync = ref.watch(incomeAttributionProvider);
    final currentUser = ref.watch(currentUserProvider);
    final connection = ref.watch(sharingConnectionProvider).valueOrNull;

    String labelFor(String userId) {
      if (plan.scope == BudgetScope.individual) {
        final name = currentUser?.username;
        return name == null || name.isEmpty ? 'Eu' : 'Eu ($name)';
      }
      if (userId == currentUser?.id) {
        final name = currentUser?.username;
        return name == null || name.isEmpty ? 'Eu' : 'Eu ($name)';
      }
      if (userId == connection?.partnerUserId) {
        return connection?.partnerUsername ?? 'Parceiro';
      }
      return 'Outro';
    }

    return incomeAsync.when(
      loading: () => const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Text(
        'Não foi possível carregar as entradas.',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'Nenhuma entrada registrada no mês.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entradas por pessoa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        labelFor(item.userId),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.amount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _IncomeModeChip extends StatelessWidget {
  const _IncomeModeChip({required this.mode});

  final IncomeMode mode;

  @override
  Widget build(BuildContext context) {
    final isManual = mode == IncomeMode.manual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isManual ? AppColors.primary : AppColors.secondary)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isManual ? 'Renda manual' : 'Renda real',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isManual ? AppColors.primary : AppColors.secondary,
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _CategoryProgressList extends ConsumerWidget {
  const _CategoryProgressList({required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(planningProgressProvider);

    return progressAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Erro ao carregar categorias: $error'),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Nenhuma categoria com percentual definido. Toque em "Editar" '
              'para distribuir o orçamento.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Column(
          children: [
            for (final item in items)
              _CategoryProgressTile(plan: plan, progress: item),
          ],
        );
      },
    );
  }
}

class _CategoryProgressTile extends StatelessWidget {
  const _CategoryProgressTile({
    required this.plan,
    required this.progress,
  });

  final BudgetPlan plan;
  final CategoryProgress progress;

  @override
  Widget build(BuildContext context) {
    final categoryColor = progress.categoryColor == 0
        ? Colors.grey
        : Color(progress.categoryColor);
    final statusColor = planningStatusColor(progress.progressPercent);
    final over = progress.isOverBudget;

    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) =>
            CategoryBudgetDialog(plan: plan, category: progress.budget),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: categoryColor.withOpacity(0.16),
                  child: Icon(
                    categoryIcon(progress.categoryIcon),
                    size: 18,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        progress.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.format(progress.spentAmount)} '
                        'de ${CurrencyFormatter.format(progress.allocatedAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${progress.progressPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: statusColor,
                  ),
                ),
                if (over)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.expense,
                    ),
                  )
                else if (progress.isAlert)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress.progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReserveCard extends ConsumerWidget {
  const _ReserveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final percent = ref.watch(unallocatedPercentageProvider);
    final amount = ref.watch(reserveAmountProvider);

    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: ListTile(
        leading: Icon(Icons.savings_outlined, color: Colors.grey.shade700),
        title: const Text(
          'Não alocado / Reserva',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text('${percent.toStringAsFixed(0)}% do orçamento'),
        trailing: Text(
          CurrencyFormatter.format(amount),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SettingsTile extends ConsumerWidget {
  const _SettingsTile({required this.settings});

  final NotificationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () async {
          final result = await showDialog<NotificationSettings>(
            context: context,
            builder: (_) => NotificationSettingsDialog(settings: settings),
          );
          if (result == null) return;
          await ref
              .read(monthPlanningProvider.notifier)
              .updateNotifications(result);
        },
        icon: const Icon(Icons.notifications_active_outlined),
        label: const Text('Alertas de limite'),
      ),
    );
  }
}

class _EmptyPlanning extends StatelessWidget {
  const _EmptyPlanning({required this.scope, required this.onStart});

  final BudgetScope scope;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 72,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            scope == BudgetScope.couple
                ? 'Planeje o mês do casal'
                : 'Planeje seu mês',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            scope == BudgetScope.couple
                ? 'Defina o orçamento compartilhado e distribua percentuais '
                    'por categoria. As entradas e gastos dos dois entram na '
                    'conta, com alerta ao chegar no limite.'
                : 'Defina quanto quer gastar no mês e distribua percentuais '
                    'por categoria. Você recebe um alerta ao chegar no limite.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.tune),
            label: const Text('Configurar orçamento'),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.error_outline, size: 56, color: Colors.grey.shade500),
        const SizedBox(height: 12),
        Center(child: Text(message)),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ),
      ],
    );
  }
}
