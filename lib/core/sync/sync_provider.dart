import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/sync/sync_service.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
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

  // Restaura sempre (nao so quando o banco esta vazio): cartoes e outras
  // entidades podem faltar mesmo com transacoes locais presentes.
  // O restore ignora registros locais ainda nao sincronizados.
  final restored = await service.restore();
  final pushed = await service.push();

  if (restored.hasChanges) {
    _invalidateData(ref);
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
    _invalidateData(ref);
  }

  return SyncOutcome(
    pushed: pushed.pushed,
    pulled: restored.pulled,
    failed: pushed.failed + restored.failed,
    offline: restored.offline,
    message: restored.message,
  );
}

void _invalidateData(WidgetRef ref) {
  ref
    ..invalidate(categoriesListProvider)
    ..invalidate(monthTransactionsProvider)
    ..invalidate(transactionsListProvider)
    ..invalidate(monthlyStatsProvider)
    ..invalidate(monthlyCategoryStatsProvider)
    ..invalidate(categoryExpensesProvider)
    ..invalidate(recurringListProvider)
    ..invalidate(monthPlanningProvider)
    ..invalidate(planningProgressProvider)
    ..invalidate(planningAlertsProvider)
    ..invalidate(monthlyIncomeProvider)
    ..invalidate(monthSpentTotalProvider)
    ..invalidate(incomeAttributionProvider)
    ..invalidate(sharingConnectionProvider)
    ..invalidate(creditCardsProvider)
    ..invalidate(allCardsTransactionsProvider);
}
