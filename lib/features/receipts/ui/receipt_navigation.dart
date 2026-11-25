import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';

/// Abre os detalhes do cupom fiscal (com os itens comprados) sempre que a
/// transação tiver sido cadastrada via NF — inclusive se o vínculo só existir
/// em `receipts.transaction_id` — ou abre o formulário padrão caso contrário.
Future<void> openTransactionOrReceipt(
  BuildContext context,
  WidgetRef ref, {
  required String transactionId,
  String? receiptId,
}) async {
  if (receiptId != null && receiptId.isNotEmpty) {
    if (!context.mounted) return;
    await context.push(
      RouteNames.receiptDetail,
      extra: {
        'receiptId': receiptId,
        'transactionId': transactionId,
      },
    );
    return;
  }

  try {
    final linked = await ref
        .read(receiptsRepositoryProvider)
        .getReceiptByTransactionId(transactionId);
    if (!context.mounted) return;
    if (linked != null) {
      await context.push(
        RouteNames.receiptDetail,
        extra: {
          'receiptId': linked.id,
          'transactionId': transactionId,
        },
      );
      return;
    }
  } catch (_) {}

  if (!context.mounted) return;
  await context.push(
    RouteNames.transactionForm,
    extra: {'id': transactionId, 'isEditing': true},
  );
}
