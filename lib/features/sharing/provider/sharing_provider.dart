import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/features/sharing/models/sharing_models.dart';
import 'package:gastos_app/features/sharing/repository/sharing_repository.dart';
import 'package:gastos_app/features/shopping_list/provider/shopping_list_provider.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';

/// Conexao ativa exibida na tela de compartilhamento.
final sharingConnectionProvider =
    FutureProvider<SharingConnection?>((ref) async {
  return ref.watch(sharingRepositoryProvider).getConnection();
});

/// Sincroniza envio local + download do parceiro e atualiza as telas.
Future<SharingSyncResult> runSharingSync(WidgetRef ref) async {
  final result = await ref.read(sharingRepositoryProvider).syncNow();

  ref
    ..invalidate(monthTransactionsProvider)
    ..invalidate(transactionsListProvider)
    ..invalidate(monthlyStatsProvider)
    ..invalidate(categoryExpensesProvider)
    ..invalidate(sharingConnectionProvider);

  await ref.read(shoppingListProvider.notifier).loadItems();
  return result;
}
