import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/receipts/models/receipt_models.dart';
import 'package:gastos_app/features/receipts/provider/receipts_provider.dart';
import 'package:gastos_app/features/receipts/repository/receipts_repository.dart';
import 'package:gastos_app/features/receipts/services/receipt_item_categorizer.dart';

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

          final summaries = ReceiptsRepository.getCategorySummaries(receipt);
          final groupedItems = <String, List<ReceiptItem>>{};
          for (final item in receipt.items) {
            groupedItems.putIfAbsent(item.category, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(context, receipt),
              const SizedBox(height: 16),
              _buildCategorySummaries(context, summaries),
              const SizedBox(height: 20),
              _buildGroupedItems(context, groupedItems),
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

  Widget _buildCategorySummaries(
    BuildContext context,
    List<ReceiptCategorySummary> summaries,
  ) {
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gastos por Categoria nesta Compra',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: summaries.map((s) {
            final color = ReceiptItemCategorizer.getColor(s.category);
            final icon = ReceiptItemCategorizer.getIcon(s.category);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.category,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: color,
                        ),
                      ),
                      Text(
                        '${CurrencyFormatter.format(s.totalAmount)} (${s.percentage}%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupedItems(
    BuildContext context,
    Map<String, List<ReceiptItem>> grouped,
  ) {
    final categories = grouped.keys.toList()
      ..sort((a, b) {
        final totalA = grouped[a]!.fold(0.0, (acc, i) => acc + i.totalPrice);
        final totalB = grouped[b]!.fold(0.0, (acc, i) => acc + i.totalPrice);
        return totalB.compareTo(totalA);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Itens Separados por Setor',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final cat in categories) ...[
          _buildCategorySection(cat, grouped[cat]!),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildCategorySection(String category, List<ReceiptItem> items) {
    final color = ReceiptItemCategorizer.getColor(category);
    final icon = ReceiptItemCategorizer.getIcon(category);
    final sectionTotal = items.fold(0.0, (acc, i) => acc + i.totalPrice);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(sectionTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                dense: true,
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  '${item.quantity.toStringAsFixed(item.unit == "KG" ? 3 : 1)} ${item.unit} x ${CurrencyFormatter.format(item.unitPrice)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                trailing: Text(
                  CurrencyFormatter.format(item.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
