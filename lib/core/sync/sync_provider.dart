import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/goals/provider/goals_provider.dart';
import 'package:gastos_app/features/home_widgets/services/home_widget_service.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/recurring/provider/recurring_provider.dart';
import 'package:gastos_app/features/sharing/provider/sharing_provider.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

/// Sincronizacao automatica disparada ao abrir a app.
///
/// 1. restaura o que o servidor tem quando o aparelho esta vazio (reinstalacao
///    ou primeiro uso noutro telefone);
/// 2. envia o que ficou pendente de sessoes anteriores.
Future<SyncOutcome> runStartupSync(WidgetRef ref) async {
  final service = ref.read(syncServiceProvider);

  // 1. Envia o que ficou pendente (rapido: so linhas nao sincronizadas).
  final pushed = await service.push();

  // 2. Restaura apenas quando o aparelho esta sem transacoes locais
  //    (primeiro uso/reinstalacao). Com dados locais, a UI abre offline-first
  //    e o restore completo fica no botao "Sincronizar agora".
  final restored = await service.restore(onlyIfEmpty: true);

  if (restored.hasChanges) {
    invalidateSyncedData(ref);
  }

  return SyncOutcome(
    pushed: pushed.pushed,
    pulled: restored.pulled,
    failed: pushed.failed,
    offline: restored.offline && pushed.offline,
    message: restored.message,
  );
}

/// Restauracao explicita, chamada pelo usuario nas configuracoes.
Future<SyncOutcome> runFullRestore(WidgetRef ref) async {
  final service = ref.read(syncServiceProvider);

  // Envia primeiro para nao perder alteracoes locais pendentes.
  final pushed = await service.push();
  final restored = await service.restore();

  if (restored.hasChanges || pushed.hasChanges) {
    invalidateSyncedData(ref);
  }

  return SyncOutcome(
    pushed: pushed.pushed,
    pulled: restored.pulled,
    failed: pushed.failed + restored.failed,
    offline: restored.offline,
    message: restored.message,
  );
}

void invalidateSyncedData(WidgetRef ref) {
  ref
    ..invalidate(categoriesListProvider)
    ..invalidate(monthTransactionsProvider)
    ..invalidate(transactionsListProvider)
    ..invalidate(monthlyStatsProvider)
    ..invalidate(recentMonthlyStatsProvider)
    ..invalidate(monthlyCategoryStatsProvider)
    ..invalidate(categoryExpensesProvider)
    ..invalidate(recurringListProvider)
    ..invalidate(goalsProvider)
    ..invalidate(monthPlanningProvider)
    ..invalidate(planningProgressProvider)
    ..invalidate(planningAlertsProvider)
    ..invalidate(unreadAlertsProvider)
    ..invalidate(monthlyIncomeProvider)
    ..invalidate(monthSpentTotalProvider)
    ..invalidate(incomeAttributionProvider)
    ..invalidate(sharingConnectionProvider)
    ..invalidate(creditCardsProvider)
    ..invalidate(cardsWithSpentProvider)
    ..invalidate(cardInvoiceAmountProvider)
    ..invalidate(cardInvoicePaidProvider)
    ..invalidate(cardForecastProvider)
    ..invalidate(allCardsTransactionsProvider);
  HomeWidgetService.instance.scheduleSync();
}
