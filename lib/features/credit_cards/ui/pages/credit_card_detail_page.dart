import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_form_page.dart';
import 'package:gastos_app/features/credit_cards/ui/widgets/credit_card_visual.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
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

  Future<void> _openInvoiceDialog({
    required double current,
    required double spent,
  }) async {
    final controller = TextEditingController(
      text: current > 0 ? FormHelper.formatBRL(current) : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final typedAmount = FormHelper.parseBRL(controller.text);
          final hasText = controller.text.trim().isNotEmpty;
          final isBelowSpent =
              spent > 0 && hasText && typedAmount > 0 && typedAmount < (spent - 0.009);
          final diff = typedAmount > spent ? (typedAmount - spent) : 0.0;
          final canSave = !isBelowSpent && typedAmount > 0;

          return AlertDialog(
            title: const Text('Valor Total da Fatura'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_card.name} • Fatura de ${planningMonthLabel(_selectedMonth)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Informe o valor total da fatura deste cartão. A fatura deve ser no mínimo o valor das compras já lançadas.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  if (spent > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Total já lançado neste cartão: ${CurrencyFormatter.format(spent)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [BRLTextInputFormatter()],
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: r'Valor da Fatura (R$)',
                      hintText: r'R$ 0,00',
                      prefixIcon: const Icon(Icons.receipt_long),
                      errorText: isBelowSpent
                          ? 'Mínimo de ${CurrencyFormatter.format(spent)} (já lançado)'
                          : null,
                    ),
                  ),
                  if (isBelowSpent) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.block, size: 16, color: AppColors.expense),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'A fatura não pode ser menor que o total já lançado (${CurrencyFormatter.format(spent)}).',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.expense,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (diff > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFF8D6E63)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Diferença de ${CurrencyFormatter.format(diff)} será somada aos gastos na categoria "Não informada".',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (current > 0)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                  onPressed: () {
                    controller.text = '';
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Remover'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: canSave ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      final amount = FormHelper.parseBRL(controller.text);
      final repo = ref.read(creditCardsRepositoryProvider);
      await repo.setCardInvoiceAmount(_card.id, _selectedMonth, amount);

      ref
        ..invalidate(cardInvoiceAmountProvider(
          (cardId: _card.id, month: _selectedMonth),
        ))
        ..invalidate(cardsWithSpentProvider)
        ..invalidate(unbudgetedExpensesProvider)
        ..invalidate(monthPlanningProvider)
        ..invalidate(monthSpentTotalProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spentAsync = ref.watch(cardSpentForMonthProvider(
      (cardId: _card.id, month: _selectedMonth),
    ));
    final invoiceAsync = ref.watch(cardInvoiceAmountProvider(
      (cardId: _card.id, month: _selectedMonth),
    ));
    final txsAsync = ref.watch(cardTransactionsProvider(
      (cardId: _card.id, month: _selectedMonth),
    ));
    final paidAsync = ref.watch(cardInvoicePaidProvider(
      (cardId: _card.id, month: _selectedMonth),
    ));

    final spent = spentAsync.valueOrNull ?? 0.0;
    final invoiceTotal = invoiceAsync.valueOrNull ?? 0.0;
    final isPaid = paidAsync.valueOrNull ?? false;
    final difference = invoiceTotal > spent ? (invoiceTotal - spent) : 0.0;
    final effectiveInvoice = invoiceTotal > spent ? invoiceTotal : spent;
    final isInvoiceExceeded = invoiceTotal > 0 && spent > invoiceTotal;
    final bestDay = CreditCardCycleHelper.bestDayToBuy(_card.closingDay);

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
          CreditCardVisual(
            card: _card,
            spent: spent,
            invoiceTotal: invoiceTotal,
          ),
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

          // Badges: Melhor dia de compra & Status da Fatura
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 16, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Melhor dia: dia $bestDay (fecha dia ${_card.closingDay})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final repo = ref.read(creditCardsRepositoryProvider);
                  await repo.setInvoicePaid(_card.id, _selectedMonth, !isPaid);
                  ref
                    ..invalidate(cardInvoicePaidProvider(
                      (cardId: _card.id, month: _selectedMonth),
                    ))
                    ..invalidate(cardsWithSpentProvider)
                    ..invalidate(cardForecastProvider);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        isPaid ? Colors.green.shade600 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid
                          ? Colors.green.shade700
                          : Colors.orange.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPaid
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isPaid ? Colors.white : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaid ? 'Fatura Paga' : 'Marcar Paga',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.white : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Card: Valor Total da Fatura
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: difference > 0
                    ? Colors.amber.shade400
                    : Colors.grey.shade300,
                width: difference > 0 ? 1.5 : 1.0,
              ),
            ),
            color: difference > 0
                ? Colors.amber.shade50.withOpacity(0.6)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 22,
                            color: difference > 0
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Valor Total da Fatura',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Editar valor da fatura',
                        onPressed: () => _openInvoiceDialog(
                          current: invoiceTotal,
                          spent: spent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (invoiceTotal > 0 || spent > 0) ...[
                    Text(
                      CurrencyFormatter.format(effectiveInvoice),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.expense,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Lançamentos registrados: ${CurrencyFormatter.format(spent)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (isInvoiceExceeded) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 20, color: Color(0xFFE65100)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Lançamentos superaram a fatura',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Os lançamentos (${CurrencyFormatter.format(spent)}) superaram a fatura configurada de ${CurrencyFormatter.format(invoiceTotal)}. O app está considerando o valor real dos lançamentos.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.brown.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (difference > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.help_outline,
                                size: 18, color: AppColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Diferença: ${CurrencyFormatter.format(difference)} atribuída à categoria "Não informada" (apenas este valor é somado aos gastos)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8D6E63),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (invoiceTotal > 0 && invoiceTotal == spent) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 18, color: Color(0xFF2E7D32)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '100% da fatura detalhada em compras lançadas.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Não informado.\nLançados: ${CurrencyFormatter.format(spent)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openInvoiceDialog(
                            current: 0,
                            spent: spent,
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Informar Total'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Text(
            'Lançamentos nesta fatura',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (isInvoiceExceeded)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.amber.shade300),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFECB3),
                  child: Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFE65100)),
                ),
                title: const Text(
                  'Lançamentos superaram a fatura configurada',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                subtitle: Text(
                  'Fatura informada: ${CurrencyFormatter.format(invoiceTotal)} • Total lançado: ${CurrencyFormatter.format(spent)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: TextButton(
                  onPressed: () => _openInvoiceDialog(
                    current: invoiceTotal,
                    spent: spent,
                  ),
                  child: const Text('Ajustar'),
                ),
              ),
            ),

          if (difference > 0)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: Colors.amber.shade50.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.amber.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.amber.shade100,
                  child: const Icon(Icons.help_outline,
                      color: AppColors.warning),
                ),
                title: const Text(
                  'Gastos não informados (Diferença)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Categoria: Não informada (compras não cadastradas)',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  CurrencyFormatter.format(difference),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ),

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
              if (txs.isEmpty && difference <= 0) {
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
