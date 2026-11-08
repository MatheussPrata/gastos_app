import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_form_page.dart';
import 'package:gastos_app/features/credit_cards/ui/widgets/credit_card_visual.dart';
import 'package:gastos_app/features/planning/ui/planning_ui_helpers.dart';

class CreditCardDetailPage extends ConsumerStatefulWidget {
  const CreditCardDetailPage({super.key, required this.card});

  final CreditCardItem card;

  @override
  ConsumerState<CreditCardDetailPage> createState() =>
      _CreditCardDetailPageState();
}

class _CreditCardDetailPageState extends ConsumerState<CreditCardDetailPage> {
  late DateTime _selectedMonth;
  late CreditCardItem _card;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  Future<void> _deleteCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Cartão'),
        content: Text(
          'Deseja realmente excluir o cartão "${_card.name}"?\n'
          'As transações já cadastradas não serão apagadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(creditCardsProvider.notifier).deleteCard(_card.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editCard() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreditCardFormPage(card: _card)),
    );
    if (updated == true && mounted) {
      final repo = ref.read(creditCardsRepositoryProvider);
      final refreshed = await repo.getCreditCardById(_card.id);
      if (refreshed != null && mounted) {
        setState(() => _card = refreshed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spentAsync = ref.watch(cardSpentForMonthProvider(
      (cardId: _card.id, month: _selectedMonth),
    ));
    final txsAsync = ref.watch(cardTransactionsProvider(
      (cardId: _card.id, month: _selectedMonth),
    ));

    final spent = spentAsync.valueOrNull ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_card.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editCard,
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCard,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          CreditCardVisual(card: _card, spent: spent),
          const SizedBox(height: 16),

          // Seletor de Mês
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month - 1, 1);
                  });
                },
              ),
              Text(
                'Fatura de ${planningMonthLabel(_selectedMonth)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month + 1, 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text(
            'Lançamentos nesta fatura',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          txsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro ao carregar transações: $e'),
            ),
            data: (txs) {
              if (txs.isEmpty) {
                return Card(
                  elevation: 0,
                  color: Colors.grey.shade100,
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Nenhuma compra registrada neste cartão no mês selecionado.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final tx in txs)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.expense.withOpacity(0.12),
                          child: const Icon(Icons.credit_card,
                              color: AppColors.expense),
                        ),
                        title: Text(
                          tx.description,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          tx.isInstallment && tx.totalInstallments > 1
                              ? '${DateFormatter.formatDayMonthYear(tx.date)} • Parcela ${tx.installmentNumber}/${tx.totalInstallments}'
                              : DateFormatter.formatDayMonthYear(tx.date),
                        ),
                        trailing: Text(
                          CurrencyFormatter.format(tx.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.expense,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
