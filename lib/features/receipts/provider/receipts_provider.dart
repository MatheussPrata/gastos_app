import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';
import 'package:gastos_app/features/receipts/services/nfce_pr_parser_service.dart';

final nfceParserServiceProvider = Provider<NfcePrParserService>((ref) {
  return NfcePrParserService();
});

final receiptByTransactionProvider =
    FutureProvider.family<Receipt?, String>((ref, transactionId) async {
  final repo = ref.watch(receiptsRepositoryProvider);
  return repo.getReceiptByTransactionId(transactionId);
});

final receiptDetailsProvider =
    FutureProvider.family<Receipt?, String>((ref, receiptId) async {
  final repo = ref.watch(receiptsRepositoryProvider);
  return repo.getReceiptById(receiptId);
});
