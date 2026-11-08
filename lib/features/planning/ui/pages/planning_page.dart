import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_detail_page.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_form_page.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_cards_page.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/ui/pages/budget_setup_page.dart';
import 'package:gastos_app/features/planning/ui/pages/planning_alerts_page.dart';
import 'package:gastos_app/features/planning/ui/planning_ui_helpers.dart';
import 'package:gastos_app/features/planning/ui/widgets/category_budget_dialog.dart';
import 'package:gastos_app/features/planning/ui/widgets/notification_settings_dialog.dart';
import 'package:gastos_app/features/sharing/provider/sharing_provider.dart';

/// Planning tab: monthly budget, credit cards, per-category progress and alerts.
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
            ..invalidate(unbudgetedExpensesProvider)
            ..invalidate(planningAlertsProvider)
            ..invalidate(monthlyIncomeProvider)
            ..invalidate(monthSpentTotalProvider)
            ..invalidate(creditCardsProvider)
            ..invalidate(cardsWithSpentProvider);
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
              padding: const EdgeInsets.only(bottom: 32),
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

                  // Seção: Faturas por Cartão de Crédito
                  _SectionHeader(
                    title: 'Faturas por Cartão de Crédito',
                    actionLabel: 'Gerenciar Cartões',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreditCardsPage(),
                      ),
                    ),
                  ),
                  _CardsPlanningSection(month: plan.month),

                  // Seção: Categorias (Meta vs Realizado)
                  _SectionHeader(
                    title: 'Categorias: Meta vs Realizado',
                    actionLabel: 'Ajustar Metas',
                    onAction: () => _openSetup(context, plan),
                  ),
                  _CategoryProgressList(plan: plan),

                  // Seção: Gastos Fora do Planejamento
                  _UnbudgetedExpensesSection(plan: plan),

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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

/// Overview card showing side-by-side comparison:
/// "O que configurei" vs "Atual (Real)"
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Resumo Geral: Meta vs Real',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _IncomeModeChip(mode: plan.incomeMode),
              ],
            ),
            const SizedBox(height: 16),

            // Two-column side by side: Configurado vs Atual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  // Coluna 1: O que Configurei
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🎯', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              'O QUE CONFIGUREI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(budget),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          'Teto total planejado',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reserva (${reservePercent.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(reserveAmount),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 64,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  // Coluna 2: Atual (Real)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💳', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              'ATUAL (REAL)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.format(spent),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        Text(
                          '${consumedPercent.toStringAsFixed(0)}% do orçamento',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Entradas: ${CurrencyFormatter.format(income)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Barra de Progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: budget <= 0 ? 0 : (spent / budget).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 8),

            // Saldo Restante Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (remaining >= 0 ? AppColors.secondary : AppColors.expense)
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    remaining >= 0
                        ? 'Saldo livre restante no mês:'
                        : 'Orçamento estourado em:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: remaining >= 0
                          ? AppColors.secondary
                          : AppColors.expense,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(remaining.abs()),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: remaining >= 0
                          ? AppColors.secondary
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _IncomeBreakdown(plan: plan),
          ],
        ),
      ),
    );
  }
}

/// Seção com as faturas dos cartões de crédito no mês selecionado
class _CardsPlanningSection extends ConsumerWidget {
  const _CardsPlanningSection({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(cardsWithSpentProvider(month));

    return cardsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('Erro ao carregar cartões: $e'),
      ),
      data: (cardsSummary) {
        if (cardsSummary.isEmpty) {
          return Card(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            elevation: 0,
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.credit_card_outlined,
                      size: 32, color: Colors.grey.shade500),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nenhum cartão cadastrado',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          'Cadastre seus cartões para acompanhar as faturas.',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreditCardFormPage(),
                      ),
                    ),
                    child: const Text('Cadastrar'),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          height: 140,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: cardsSummary.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = cardsSummary[index];
              return _MiniCardTile(
                item: item,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreditCardDetailPage(card: item.card),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MiniCardTile extends StatelessWidget {
  const _MiniCardTile({
    required this.item,
    required this.onTap,
  });

  final CardWithSpent item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = item.card;
    final spent = item.spent;
    final invoiceTotal = item.invoiceTotal;
    final displayFatura = invoiceTotal > 0 ? invoiceTotal : spent;
    final difference = item.difference;

    final baseColor = card.cardColor;
    final available = card.availableLimit(displayFatura);
    final percent = card.limitUsedPercent(displayFatura);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              baseColor,
              HSLColor.fromColor(baseColor)
                  .withLightness((HSLColor.fromColor(baseColor).lightness - 0.15)
                      .clamp(0.0, 1.0))
                  .toColor(),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'Vence dia ${card.dueDay}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fatura: ${CurrencyFormatter.format(displayFatura)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (difference > 0)
                  Text(
                    'Não informado: ${CurrencyFormatter.format(difference)}',
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (card.limitAmount > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (percent / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      color: percent >= 100
                          ? Colors.redAccent.shade100
                          : percent >= 80
                              ? Colors.amberAccent
                              : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Disponível: ${CurrencyFormatter.format(available)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Erro ao carregar categorias: $error'),
      ),
      data: (items) {
        final activeItems = items.where((i) => i.budget.percentage > 0).toList();

        if (activeItems.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Card(
              elevation: 0,
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Nenhuma categoria com teto definido no orçamento.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BudgetSetupPage(plan: plan),
                        ),
                      ),
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Distribuir Metas nas Categorias'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final item in activeItems)
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
    final remaining = progress.remainingAmount;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) =>
              CategoryBudgetDialog(plan: plan, category: progress.budget),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Meta: ${CurrencyFormatter.format(progress.allocatedAmount)} (${progress.budget.percentage.toStringAsFixed(0)}%) • Gasto: ${CurrencyFormatter.format(progress.spentAmount)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${progress.progressPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        remaining >= 0
                            ? 'Sobra ${CurrencyFormatter.format(remaining)}'
                            : 'Estourou ${CurrencyFormatter.format(remaining.abs())}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: remaining >= 0
                              ? AppColors.secondary
                              : AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seção para mostrar gastos em categorias que não têm meta configurada
class _UnbudgetedExpensesSection extends ConsumerWidget {
  const _UnbudgetedExpensesSection({required this.plan});

  final BudgetPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unbudgetedAsync = ref.watch(unbudgetedExpensesProvider);

    return unbudgetedAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.warning),
                  SizedBox(width: 6),
                  Text(
                    'Gastos fora do planejamento',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            for (final item in items)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                elevation: 0,
                color: Colors.amber.shade50.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade200),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(item.categoryColor).withOpacity(0.18),
                    child: Icon(
                      categoryIcon(item.categoryIcon),
                      size: 18,
                      color: Color(item.categoryColor),
                    ),
                  ),
                  title: Text(
                    item.categoryName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Sem meta definida • Gasto: ${CurrencyFormatter.format(item.spentAmount)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () {
                      final category = CategoryBudget(
                        categoryId: item.categoryId,
                        categoryName: item.categoryName,
                        categoryColor: item.categoryColor,
                        categoryIcon: item.categoryIcon,
                        percentage: 0,
                      );
                      showDialog<void>(
                        context: context,
                        builder: (_) => CategoryBudgetDialog(
                          plan: plan,
                          category: category,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Definir Meta', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
          ],
        );
      },
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              plan.scope == BudgetScope.couple
                  ? 'Entradas registradas por pessoa:'
                  : 'Origem da renda:',
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      labelFor(item.userId),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
