import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/planning/services/notification_service.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/sharing/models/sharing_models.dart';
import 'package:gastos_app/features/sharing/repository/sharing_repository.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

/// Conexao ativa exibida na tela de compartilhamento.
final sharingConnectionProvider =
    FutureProvider<SharingConnection?>((ref) async {
  return ref.watch(sharingRepositoryProvider).getConnection();
});

/// Sincroniza envio local + download do parceiro e atualiza as telas.
Future<SharingSyncResult> runSharingSync(WidgetRef ref) async {
  final result = await ref.read(sharingRepositoryProvider).syncNow(
        planMonth: ref.read(selectedPlanMonthProvider),
      );

  // Os gastos do parceiro entram no progresso do planejamento e podem cruzar
  // limites, então reavaliamos o mês aberto depois da sincronização.
  try {
    final planMonth = ref.read(selectedPlanMonthProvider);
    final alerts = await ref
        .read(planningRepositoryProvider)
        .checkAndCreateAlerts(month: planMonth, scope: BudgetScope.couple);
    for (final alert in alerts) {
      unawaited(NotificationService.instance.showBudgetAlert(alert));
    }
  } catch (_) {
    // Planejamento nunca deve impedir a sincronização com o parceiro.
  }

  ref
    ..invalidate(monthTransactionsProvider)
    ..invalidate(transactionsListProvider)
    ..invalidate(monthlyStatsProvider)
    ..invalidate(categoryExpensesProvider)
    ..invalidate(sharingConnectionProvider)
    ..invalidate(monthPlanningProvider)
    ..invalidate(planningProgressProvider)
    ..invalidate(planningAlertsProvider)
    ..invalidate(monthlyIncomeProvider)
    ..invalidate(monthSpentTotalProvider)
    ..invalidate(incomeAttributionProvider);

  return result;
}
