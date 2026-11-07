import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/provider/receipts_provider.dart';

class ReceiptDetailPage extends ConsumerWidget {
  final String? receiptId;
  final String? transactionId;

  const ReceiptDetailPage({
    super.key,
    this.receiptId,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Receipt?> receiptAsync;
    if (receiptId != null && receiptId!.isNotEmpty) {
      receiptAsync = ref.watch(receiptDetailsProvider(receiptId!));
    } else if (transactionId != null && transactionId!.isNotEmpty) {
      receiptAsync = ref.watch(receiptByTransactionProvider(transactionId!));
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Cupom Fiscal')),
        body: const Center(child: Text('Cupom fiscal não especificado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Compra'),
        actions: [
          receiptAsync.when(
            data: (receipt) {
              if (receipt == null || receipt.transactionId.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar Cupom e Itens',
                onPressed: () {
                  context.push(
                    RouteNames.receiptReview,
                    extra: receipt,
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: receiptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar cupom: $e')),
        data: (receipt) {
          if (receipt == null) {
            return const Center(
              child: Text('Cupom fiscal não encontrado para esta compra.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(context, receipt),
              const SizedBox(height: 16),
              _buildItemsCard(context, receipt),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Receipt receipt) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(30),
                  radius: 24,
                  child: const Icon(
                    Icons.store_mall_directory,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.establishmentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (receipt.establishmentCnpj.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'CNPJ: ${receipt.establishmentCnpj}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatter.formatDayMonthYear(receipt.issueDate),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (receipt.paymentMethod.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          receipt.paymentMethod,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Valor Total',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      CurrencyFormatter.format(receipt.totalAmount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, Receipt receipt) {
    if (receipt.items.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Nenhum item individual registrado nesta compra.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, size: 20, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Itens Comprados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${receipt.items.length} ${receipt.items.length == 1 ? "item" : "itens"}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: receipt.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = receipt.items[index];
              final unit =
                  item.unit.isNotEmpty ? item.unit.toUpperCase() : 'UN';
              final qtyFormatted = item.quantity == item.quantity.truncateToDouble()
                  ? item.quantity.toInt().toString()
                  : (unit == 'KG'
                      ? item.quantity.toStringAsFixed(3)
                      : item.quantity.toStringAsFixed(2));

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$qtyFormatted $unit ${item.unitPrice > 0 ? "× ${CurrencyFormatter.format(item.unitPrice)}" : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(item.totalPrice),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total da Compra',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(receipt.totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
