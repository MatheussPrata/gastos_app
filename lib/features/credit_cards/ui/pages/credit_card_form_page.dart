import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/planning/provider/planning_provider.dart';

class CreditCardFormPage extends ConsumerStatefulWidget {
  const CreditCardFormPage({super.key, this.card});

  final CreditCardItem? card;

  bool get isEditing => card != null;

  @override
  ConsumerState<CreditCardFormPage> createState() => _CreditCardFormPageState();
}

class _CreditCardFormPageState extends ConsumerState<CreditCardFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _limitController;
  late final TextEditingController _invoiceController;

  late int _selectedColor;
  late int _closingDay;
  late int _dueDay;
  bool _isSaving = false;

  static const List<int> _cardColors = [
    0xFF8A05BE, // Nubank roxo
    0xFFFF7A00, // Inter laranja
    0xFF1A1A1A, // Preto / Black
    0xFF003882, // Azul Itaú / Caixa
    0xFFCC092F, // Vermelho Santander / Bradesco
    0xFF00875A, // Verde Sicredi / Emerald
    0xFFD4AF37, // Dourado / Gold
    0xFF3F51B5, // Indigo
    0xFF5C6BC0, // Slate
  ];

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _nameController = TextEditingController(text: card?.name ?? '');
    _limitController = TextEditingController(
      text: (card != null && card.limitAmount > 0)
          ? FormHelper.formatBRL(card.limitAmount)
          : '',
    );
    _invoiceController = TextEditingController();

    _selectedColor = card?.color ?? _cardColors.first;
    _closingDay = card?.closingDay ?? 25;
    _dueDay = card?.dueDay ?? 5;

    if (card != null) {
      _loadCurrentInvoice(card.id);
    }
  }

  Future<void> _loadCurrentInvoice(String cardId) async {
    final now = DateTime.now();
    final repo = ref.read(creditCardsRepositoryProvider);
    final inv = await repo.getCardInvoiceAmount(cardId, now);
    if (inv > 0 && mounted) {
      _invoiceController.text = FormHelper.formatBRL(inv);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final limit = FormHelper.parseBRL(_limitController.text);
    final invoice = FormHelper.parseBRL(_invoiceController.text);

    final card = CreditCardItem(
      id: widget.card?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      color: _selectedColor,
      lastFourDigits: '',
      brand: '',
      limitAmount: limit,
      closingDay: _closingDay,
      dueDay: _dueDay,
      isActive: widget.card?.isActive ?? true,
      sortOrder: widget.card?.sortOrder ?? 0,
    );

    try {
      if (widget.isEditing) {
        await ref.read(creditCardsProvider.notifier).updateCard(card);
      } else {
        await ref.read(creditCardsProvider.notifier).createCard(card);
      }

      final repo = ref.read(creditCardsRepositoryProvider);
      final now = DateTime.now();
      await repo.setCardInvoiceAmount(card.id, now, invoice);

      ref
        ..invalidate(cardsWithSpentProvider)
        ..invalidate(cardInvoiceAmountProvider)
        ..invalidate(unbudgetedExpensesProvider)
        ..invalidate(monthPlanningProvider)
        ..invalidate(monthSpentTotalProvider);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar cartão: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Cartão' : 'Novo Cartão'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome ou Apelido do Cartão *',
                hintText: 'Ex: Nubank, Itaú, Inter...',
                prefixIcon: Icon(Icons.credit_card),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Informe o nome do cartão';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _closingDay,
                    decoration: const InputDecoration(
                      labelText: 'Dia Fechamento',
                      prefixIcon: Icon(Icons.event_busy_outlined),
                    ),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('Dia $d')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _closingDay = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _dueDay,
                    decoration: const InputDecoration(
                      labelText: 'Dia Vencimento',
                      prefixIcon: Icon(Icons.event_available_outlined),
                    ),
                    items: [
                      for (var d = 1; d <= 31; d++)
                        DropdownMenuItem(value: d, child: Text('Dia $d')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _dueDay = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _limitController,
              decoration: const InputDecoration(
                labelText: r'Limite Total (R$)',
                hintText: r'R$ 0,00',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [BRLTextInputFormatter()],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _invoiceController,
              decoration: const InputDecoration(
                labelText: r'Valor Total da Fatura Atual (R$)',
                hintText: r'R$ 0,00 (opcional)',
                prefixIcon: Icon(Icons.receipt_long_outlined),
                helperText:
                    'Se maior que as compras lançadas, a diferença fica na categoria "Não informada"',
                helperMaxLines: 2,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [BRLTextInputFormatter()],
            ),
            const SizedBox(height: 24),

            const Text(
              'Cor do Cartão',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final colorVal in _cardColors)
                  InkWell(
                    onTap: () => setState(() => _selectedColor = colorVal),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedColor == colorVal
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          if (_selectedColor == colorVal)
                            BoxShadow(
                              color: Color(colorVal).withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: _selectedColor == colorVal
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 22)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 36),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Salvar Alterações' : 'Criar Cartão'),
            ),
          ],
        ),
      ),
    );
  }
}
