import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/recurring/provider/recurring_provider.dart';

/// Faixa horizontal com os próximos vencimentos (recorrentes e faturas).
class UpcomingBills extends ConsumerWidget {
  const UpcomingBills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: 7));

    final recurring = ref.watch(recurringListProvider).valueOrNull;
    final cards =
        ref.watch(cardsWithSpentProvider(DateTime(now.year, now.month)))
            .valueOrNull;

    final items = <_Bill>[];

    if (recurring != null) {
      for (final r in recurring) {
        if (!r.isActive) continue;
        final due =
            DateTime(r.nextDueDate.year, r.nextDueDate.month, r.nextDueDate.day);
        if (due.isBefore(today) || due.isAfter(horizon)) continue;
        items.add(
          _Bill(
            title: r.description,
            amount: r.amount,
            date: due,
            isExpense: r.type == 'expense',
            icon: Icons.repeat,
          ),
        );
      }
    }

    if (cards != null) {
      for (final c in cards) {
        if (!c.card.isActive || c.invoiceTotal <= 0) continue;
        final due = _nextDue(c.card.dueDay, today);
        if (due.isAfter(horizon)) continue;
        items.add(
          _Bill(
            title: 'Fatura ${c.card.name}',
            amount: c.invoiceTotal,
            date: due,
            isExpense: true,
            icon: Icons.credit_card,
          ),
        );
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    items.sort((a, b) => a.date.compareTo(b.date));
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(
              'Próximos vencimentos',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final bill = items[i];
                final color =
                    bill.isExpense ? AppColors.expense : AppColors.income;
                return Container(
                  width: 168,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(bill.icon, size: 14, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              bill.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(bill.amount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dueLabel(bill.date, today),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DateTime _nextDue(int day, DateTime today) {
    var due = DateTime(today.year, today.month, day);
    if (due.isBefore(today)) {
      due = DateTime(today.year, today.month + 1, day);
    }
    return due;
  }

  String _dueLabel(DateTime due, DateTime today) {
    final diff = due.difference(today).inDays;
    if (diff == 0) return 'Vence hoje';
    if (diff == 1) return 'Amanhã';
    return 'Em $diff dias';
  }
}

class _Bill {
  const _Bill({
    required this.title,
    required this.amount,
    required this.date,
    required this.isExpense,
    required this.icon,
  });

  final String title;
  final double amount;
  final DateTime date;
  final bool isExpense;
  final IconData icon;
}
