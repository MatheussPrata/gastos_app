import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/categories/models/category_models.dart';
import 'package:gastos_app/features/categories/provider/categories_provider.dart';
import 'package:gastos_app/features/categories/utils/category_icons.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_detail_page.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_form_page.dart';
import 'package:gastos_app/features/credit_cards/ui/widgets/credit_card_visual.dart';
import 'package:gastos_app/features/credit_cards/utils/credit_card_cycle_helper.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';
import 'package:gastos_app/features/planning/ui/planning_ui_helpers.dart';
import 'package:gastos_app/features/transactions/ui/pages/transaction_form_page.dart';

class CreditCardsPage extends ConsumerStatefulWidget {
  const CreditCardsPage({super.key});

  @override
  ConsumerState<CreditCardsPage> createState() => _CreditCardsPageState();
}

class _CreditCardsPageState extends ConsumerState<CreditCardsPage> {
  Future<void> _openInvoiceDialog(
    CreditCardItem card,
    DateTime month,
    double current,
  ) async {
    final controller = TextEditingController(
      text: current > 0 ? FormHelper.formatBRL(current) : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valor Total da Fatura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${card.name} • ${planningMonthLabel(month)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Informe o valor total da fatura deste mês. '
              'Se houver diferença para as compras lançadas, o restante ficará na categoria "Não informada".',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [BRLTextInputFormatter()],
              decoration: const InputDecoration(
                labelText: r'Valor da Fatura (R$)',
                hintText: r'R$ 0,00',
                prefixIcon: Icon(Icons.receipt_long),
              ),
            ),
          ],
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
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final amount = FormHelper.parseBRL(controller.text);
      final repo = ref.read(creditCardsRepositoryProvider);
      await repo.setCardInvoiceAmount(card.id, month, amount);

      ref
        ..invalidate(cardInvoiceAmountProvider(
          (cardId: card.id, month: month),
        ))
        ..invalidate(cardsWithSpentProvider)
        ..invalidate(cardCategorySpendingProvider)
        ..invalidate(cardForecastProvider)
        ..invalidate(unbudgetedExpensesProvider)
        ..invalidate(monthPlanningProvider)
        ..invalidate(monthSpentTotalProvider);
    }
  }

  Future<void> _togglePaidStatus(
    CreditCardItem card,
    DateTime month,
    bool currentPaid,
  ) async {
    final repo = ref.read(creditCardsRepositoryProvider);
    await repo.setInvoicePaid(card.id, month, !currentPaid);

    ref
      ..invalidate(cardInvoicePaidProvider((cardId: card.id, month: month)))
      ..invalidate(cardsWithSpentProvider)
      ..invalidate(cardForecastProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(creditCardsSelectedMonthProvider);
    final selectedCardId = ref.watch(creditCardsSelectedFilterProvider);
    final cardsAsync = ref.watch(creditCardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões de Crédito'),
        actions: [
          IconButton(
            tooltip: 'Novo Cartão',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditCardFormPage()),
            ),
          ),
        ],
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar cartões: $e')),
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card_outlined,
                      size: 72,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhum cartão cadastrado',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cadastre seus cartões de crédito para acompanhar faturas, '
                      'ciclos de fechamento, melhor dia de compra e parcelamentos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreditCardFormPage(),
                        ),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Primeiro Cartão'),
                    ),
                  ],
                ),
              ),
            );
          }

          CreditCardItem? currentCard;
          if (selectedCardId != null) {
            currentCard = cards.cast<CreditCardItem?>().firstWhere(
                  (c) => c?.id == selectedCardId,
                  orElse: () => null,
                );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creditCardsProvider);
              ref.invalidate(cardsWithSpentProvider);
              ref.invalidate(cardCategorySpendingProvider);
              ref.invalidate(cardForecastProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _buildMonthSelector(selectedMonth),
                const SizedBox(height: 12),
                _buildFilterChips(cards, currentCard),
                const SizedBox(height: 16),
                if (currentCard != null) ...[
                  _buildSingleCardView(currentCard, selectedMonth),
                ] else ...[
                  _buildAllCardsView(cards, selectedMonth),
                ],
                const SizedBox(height: 20),
                _buildForecastSection(currentCard?.id, selectedMonth),
                const SizedBox(height: 20),
                _buildCategorySpendingSection(
                  currentCard?.id,
                  selectedMonth,
                ),
                const SizedBox(height: 20),
                _buildTransactionsSection(currentCard, selectedMonth),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TransactionFormPage(isEditing: false),
          ),
        ),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Novo Gasto'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMonthSelector(DateTime selectedMonth) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mês anterior',
              onPressed: () {
                ref.read(creditCardsSelectedMonthProvider.notifier).state =
                    DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
              },
            ),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Fatura de ${planningMonthLabel(selectedMonth)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próximo mês',
              onPressed: () {
                ref.read(creditCardsSelectedMonthProvider.notifier).state =
                    DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    List<CreditCardItem> cards,
    CreditCardItem? currentCard,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dashboard_outlined, size: 16),
                SizedBox(width: 6),
                Text('Todos os Cartões'),
              ],
            ),
            selected: currentCard == null,
            onSelected: (selected) {
              if (selected) {
                ref.read(creditCardsSelectedFilterProvider.notifier).state =
                    null;
              }
            },
          ),
          const SizedBox(width: 8),
          for (final card in cards) ...[
            ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: card.cardColor,
                radius: 6,
              ),
              label: Text(card.displayName),
              selected: currentCard?.id == card.id,
              onSelected: (selected) {
                ref.read(creditCardsSelectedFilterProvider.notifier).state =
                    selected ? card.id : null;
              },
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Novo'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditCardFormPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCardView(CreditCardItem card, DateTime month) {
    final spentAsync = ref.watch(cardSpentForMonthProvider(
      (cardId: card.id, month: month),
    ));
    final invoiceAsync = ref.watch(cardInvoiceAmountProvider(
      (cardId: card.id, month: month),
    ));
    final paidAsync = ref.watch(cardInvoicePaidProvider(
      (cardId: card.id, month: month),
    ));

    final spent = spentAsync.valueOrNull ?? 0.0;
    final invoiceTotal = invoiceAsync.valueOrNull ?? 0.0;
    final isPaid = paidAsync.valueOrNull ?? false;
    final difference = invoiceTotal > spent ? (invoiceTotal - spent) : 0.0;
    final effectiveInvoice = invoiceTotal > spent ? invoiceTotal : spent;
    final available = card.availableLimit(effectiveInvoice);
    final bestDay = CreditCardCycleHelper.bestDayToBuy(card.closingDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CreditCardVisual(
          card: card,
          spent: spent,
          invoiceTotal: invoiceTotal,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CreditCardDetailPage(card: card),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Badges: Melhor dia de compra & Status da Fatura
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        'Melhor dia: dia $bestDay (fecha dia ${card.closingDay})',
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
              onTap: () => _togglePaidStatus(card, month, isPaid),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green.shade600 : Colors.orange.shade50,
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
                      isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
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

        // Summary Card
        Card(
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
              ? Colors.amber.shade50.withOpacity(0.5)
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
                          size: 20,
                          color: difference > 0
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Valor da Fatura',
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
                      onPressed: () => _openInvoiceDialog(card, month, invoiceTotal),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(effectiveInvoice),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lançamentos: ${CurrencyFormatter.format(spent)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    if (card.limitAmount > 0)
                      Text(
                        'Disp.: ${CurrencyFormatter.format(available)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.income,
                        ),
                      ),
                  ],
                ),
                if (difference > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                            'Diferença: ${CurrencyFormatter.format(difference)} atribuída à categoria "Não informada"',
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
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCardsView(List<CreditCardItem> cards, DateTime month) {
    final cardsSummaryAsync = ref.watch(cardsWithSpentProvider(month));

    return cardsSummaryAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Erro ao carregar resumo: $e'),
      data: (summaries) {
        var totalInvoice = 0.0;
        var totalSpent = 0.0;
        var totalDifference = 0.0;
        var totalLimit = 0.0;

        for (final item in summaries) {
          final effective =
              item.invoiceTotal > item.spent ? item.invoiceTotal : item.spent;
          totalInvoice += effective;
          totalSpent += item.spent;
          totalDifference += item.difference;
          totalLimit += item.card.limitAmount;
        }

        final availableLimit =
            (totalLimit - totalInvoice).clamp(0.0, double.infinity);

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.credit_card, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Resumo de Todos os Cartões',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${cards.length} cartões',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Faturas Totais',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(totalInvoice),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Lançado',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(totalSpent),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (totalDifference > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.help_outline,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Diferença total não informada: ${CurrencyFormatter.format(totalDifference)}',
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
                ],
                if (totalLimit > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Limite Disponível Somado',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      Text(
                        '${CurrencyFormatter.format(availableLimit)} / ${CurrencyFormatter.format(totalLimit)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildForecastSection(String? cardId, DateTime startMonth) {
    final forecastAsync = ref.watch(cardForecastProvider(
      (cardId: cardId, startMonth: startMonth),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Previsão das Próximas Faturas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        forecastAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text('Erro ao calcular previsão: $e'),
          data: (forecastList) {
            return SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: forecastList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = forecastList[index];
                  final isCurrentMonth = index == 0;

                  return Container(
                    width: 130,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentMonth
                          ? AppColors.primary.withOpacity(0.08)
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentMonth
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: isCurrentMonth ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              planningMonthLabel(item.month),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isCurrentMonth
                                    ? AppColors.primary
                                    : Colors.black87,
                              ),
                            ),
                            if (item.isPaid)
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppColors.income),
                          ],
                        ),
                        Text(
                          CurrencyFormatter.format(item.effectiveTotal),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: item.effectiveTotal > 0
                                ? AppColors.expense
                                : Colors.grey,
                          ),
                        ),
                        Text(
                          item.transactionCount > 0
                              ? '${item.transactionCount} lançamentos'
                              : 'Sem lançamentos',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategorySpendingSection(String? cardId, DateTime month) {
    final spendingAsync = ref.watch(cardCategorySpendingProvider(
      (cardId: cardId, month: month),
    ));
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pie_chart_outline,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Gastos por Categoria no Cartão',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        spendingAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro: $e'),
          data: (categoriesMap) {
            if (categoriesMap.isEmpty) {
              return Card(
                elevation: 0,
                color: Colors.grey.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Nenhum gasto registrado por categoria.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              );
            }

            final totalSpent = categoriesMap.values.fold<double>(
              0.0,
              (sum, v) => sum + v,
            );
            final categoriesList =
                categoriesAsync.valueOrNull ?? const <Category>[];

            final sortedEntries = categoriesMap.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    for (final entry in sortedEntries) ...[
                      _buildCategoryRow(
                        categoryId: entry.key,
                        amount: entry.value,
                        totalSpent: totalSpent,
                        categories: categoriesList,
                      ),
                      if (entry.key != sortedEntries.last.key)
                        const Divider(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryRow({
    required String categoryId,
    required double amount,
    required double totalSpent,
    required List<Category> categories,
  }) {
    final percent = totalSpent > 0 ? (amount / totalSpent * 100) : 0.0;

    if (categoryId == 'nao_informada') {
      return Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.amber.shade100,
            child: const Icon(Icons.help_outline,
                size: 18, color: AppColors.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Não informada (Diferença)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                Text(
                  '${percent.toStringAsFixed(1)}% da fatura',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.warning,
            ),
          ),
        ],
      );
    }

    final cat = categories.cast<Category?>().firstWhere(
          (c) => c?.id == categoryId,
          orElse: () => null,
        );
    final name = cat?.name ?? 'Outros';
    final iconData = categoryIcon(cat?.icon ?? 'category');
    final color = cat != null && cat.color != 0
        ? Color(cat.color)
        : AppColors.primary;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(iconData, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              Text(
                '${percent.toStringAsFixed(1)}% da fatura',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.expense,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(CreditCardItem? card, DateTime month) {
    final invoiceAsync = card != null
        ? ref.watch(cardInvoiceAmountProvider(
            (cardId: card.id, month: month),
          ))
        : const AsyncValue.data(0.0);
    final spentAsync = card != null
        ? ref.watch(cardSpentForMonthProvider(
            (cardId: card.id, month: month),
          ))
        : const AsyncValue.data(0.0);

    final invoiceTotal = invoiceAsync.valueOrNull ?? 0.0;
    final spent = spentAsync.valueOrNull ?? 0.0;
    final difference = invoiceTotal > spent ? (invoiceTotal - spent) : 0.0;

    final AsyncValue<List<db.Transaction>> txsAsync = card != null
        ? ref.watch(cardTransactionsProvider(
            (cardId: card.id, month: month),
          ))
        : ref.watch(allCardsTransactionsProvider(month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.format_list_bulleted,
                size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Lançamentos nesta Fatura',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (difference > 0)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.amber.shade50.withOpacity(0.7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.amber.shade200),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.amber.shade100,
                child: const Icon(Icons.help_outline, color: AppColors.warning),
              ),
              title: const Text(
                'Gastos não informados (Diferença)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Compras não cadastradas nesta fatura',
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
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro ao carregar lançamentos: $e'),
          data: (txs) {
            if (txs.isEmpty && difference <= 0) {
              return Card(
                elevation: 0,
                color: Colors.grey.shade100,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Nenhum lançamento registrado nesta fatura.',
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
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TransactionFormPage(
                            transactionId: tx.id,
                            isEditing: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
