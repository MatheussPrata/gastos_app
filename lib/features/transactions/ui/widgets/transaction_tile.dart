import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/ui/category_icons.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart'
    hide Category;

class TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpense = transaction.isExpense;
    final flowColor = isExpense ? AppColors.expense : AppColors.income;
    final sign = isExpense ? '-' : '+';

    Category? category;
    final categories = ref.watch(categoriesListProvider).valueOrNull;
    if (categories != null && transaction.categoryId != null) {
      for (final item in categories) {
        if (item.id == transaction.categoryId) {
          category = item;
          break;
        }
      }
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: flowColor.withAlpha(38),
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: flowColor,
        ),
      ),
      title: Text(
        transaction.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(category),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign ${CurrencyFormatter.format(transaction.amount)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: flowColor),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: onDelete,
              tooltip: 'Excluir',
            ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(Category? category) {
    final details = <String>[
      DateFormatter.formatDayMonthYear(transaction.date),
      if (transaction.paymentMethod.isNotEmpty) transaction.paymentMethod,
      if (transaction.isInstallment && transaction.totalInstallments > 1)
        '${transaction.installmentNumber}/${transaction.totalInstallments}',
    ].join(' • ');

    if (category == null) {
      return Text(details);
    }

    final categoryColor = Color(category.color);

    return Row(
      children: [
        Icon(
          CategoryIcons.resolve(category.icon),
          size: 14,
          color: categoryColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: categoryColor),
          ),
        ),
        const SizedBox(width: 4),
        const Text('•'),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            details,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
