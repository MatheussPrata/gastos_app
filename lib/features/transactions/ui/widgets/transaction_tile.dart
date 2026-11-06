import 'package:flutter/material.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/utils/reminder_schedule.dart';

class TransactionTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isExpense = transaction.isExpense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    final sign = isExpense ? '-' : '+';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(38),
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
        ),
      ),
      title: Text(
        transaction.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_subtitle()),
          if (transaction.reminderAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_active_outlined,
                      size: 13, color: Colors.orange),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Lembrete ${ReminderSchedule.describe(transaction.reminderAt!)}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.orange),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign ${CurrencyFormatter.format(transaction.amount)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
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

  String _subtitle() {
    final parts = <String>[
      DateFormatter.formatDayMonthYear(transaction.date),
      if (transaction.partnerSynced) 'Parceiro',
      if (transaction.paymentMethod.isNotEmpty) transaction.paymentMethod,
      if (transaction.isInstallment && transaction.totalInstallments > 1)
        '${transaction.installmentNumber}/${transaction.totalInstallments}',
    ];
    return parts.join(' • ');
  }
}
