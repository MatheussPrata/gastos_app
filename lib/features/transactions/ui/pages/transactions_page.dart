import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/widgets/empty_state.dart';
import 'package:gastos_app/features/categories/models/category_models.dart' as cat;
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/provider/transactions_provider.dart';
import 'package:gastos_app/features/transactions/services/transactions_export_service.dart';
import 'package:gastos_app/features/transactions/ui/widgets/transaction_tile.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key, this.categoryId, this.categoryName});

  final String? categoryId;
  final String? categoryName;

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _type; // null = tudo, 'income', 'expense'
  bool _exporting = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Transaction> _filter(List<Transaction> all) {
    final query = _query.trim().toLowerCase();
    return all.where((t) {
      if (widget.categoryId != null &&
          (t.categoryId ?? 'none') != widget.categoryId) {
        return false;
      }
      if (_type == 'income' && t.isExpense) return false;
      if (_type == 'expense' && !t.isExpense) return false;
      if (query.isNotEmpty) {
        final haystack = '${t.description} ${t.notes ?? ''}'.toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _export(List<Transaction> list, List<cat.Category> categories) async {
    if (_exporting || list.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await exportTransactionsCsv(transactions: list, categories: categories);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao exportar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsListProvider);
    final categories =
        ref.watch(categoriesListProvider).valueOrNull ?? const <cat.Category>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName ?? 'Transações'),
        actions: [
          transactionsAsync.maybeWhen(
            data: (all) {
              final filtered = _filter(all);
              return IconButton(
                tooltip: 'Exportar CSV',
                onPressed: filtered.isEmpty || _exporting
                    ? null
                    : () => _export(filtered, categories),
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(transactionsAsync),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
              data: (all) {
                final filtered = _filter(all);
                if (filtered.isEmpty) {
                  final hasFilters = _query.isNotEmpty ||
                      _type != null ||
                      widget.categoryId != null;
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: hasFilters
                        ? 'Nada encontrado'
                        : 'Nenhuma transação cadastrada',
                    message: hasFilters
                        ? 'Ajuste a busca ou os filtros.'
                        : 'Toque em + para adicionar o primeiro lançamento.',
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final transaction = filtered[index];
                    return TransactionTile(
                      transaction: transaction,
                      onTap: () {
                        if (transaction.receiptId != null &&
                            transaction.receiptId!.isNotEmpty) {
                          context.push(
                            RouteNames.receiptDetail,
                            extra: {
                              'receiptId': transaction.receiptId,
                              'transactionId': transaction.id,
                            },
                          );
                        } else {
                          context.push(
                            RouteNames.transactionForm,
                            extra: {'id': transaction.id, 'isEditing': true},
                          );
                        }
                      },
                      onDelete: () => _confirmDelete(context, ref, transaction),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nova transação',
        onPressed: () => context.push(
          RouteNames.transactionForm,
          extra: {'isEditing': false},
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilters(AsyncValue<List<Transaction>> async) {
    final count = async.maybeWhen(
      data: (all) => _filter(all).length,
      orElse: () => 0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Buscar por descrição…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Tudo'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Entradas'),
                selected: _type == 'income',
                onSelected: (_) => setState(() => _type = 'income'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Saídas'),
                selected: _type == 'expense',
                onSelected: (_) => setState(() => _type = 'expense'),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transação'),
        content: Text('Deseja excluir "${transaction.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(transactionsRepositoryProvider)
          .deleteTransaction(transaction.id);
      ref.invalidate(transactionsListProvider);
      ref.invalidate(monthTransactionsProvider);
      ref.invalidate(monthlyStatsProvider);
      ref.invalidate(recentMonthlyStatsProvider);

      // Deleting changes the real spending, so refresh planning and re-check
      // thresholds without blocking the list update.
      ref
        ..invalidate(monthPlanningProvider)
        ..invalidate(planningProgressProvider)
        ..invalidate(planningAlertsProvider)
        ..invalidate(unreadAlertsProvider)
        ..invalidate(monthlyIncomeProvider)
        ..invalidate(incomeAttributionProvider)
        ..invalidate(monthSpentTotalProvider);
      for (final scope in BudgetScope.values) {
        ref.read(planningRepositoryProvider).checkAndCreateAlertsInBackground(
              month: transaction.date,
              scope: scope,
            );
      }
    }
  }
}
