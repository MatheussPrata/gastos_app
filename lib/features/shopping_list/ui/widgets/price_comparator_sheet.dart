import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/shopping_list/data/price_comparator.dart';

/// Resultado retornado quando o usuario toca em "Usar este preco".
class PriceComparatorResult {
  const PriceComparatorResult({required this.name, required this.price});

  final String name;
  final double price;
}

/// Abre o comparador de precos e retorna a opcao escolhida (ou null).
Future<PriceComparatorResult?> showPriceComparatorSheet(BuildContext context) {
  return showModalBottomSheet<PriceComparatorResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const PriceComparatorSheet(),
  );
}

class PriceComparatorSheet extends StatefulWidget {
  const PriceComparatorSheet({super.key});

  @override
  State<PriceComparatorSheet> createState() => _PriceComparatorSheetState();
}

class _PriceComparatorSheetState extends State<PriceComparatorSheet> {
  final _nameAController = TextEditingController();
  final _priceAController = TextEditingController();
  final _quantityAController = TextEditingController(text: '1');
  String _unitA = 'kg';

  final _nameBController = TextEditingController();
  final _priceBController = TextEditingController();
  final _quantityBController = TextEditingController(text: '1');
  String _unitB = 'kg';

  PriceComparison? _result;
  String? _error;

  static const List<String> _units = ['g', 'kg', 'ml', 'L', 'un'];

  @override
  void dispose() {
    _nameAController.dispose();
    _priceAController.dispose();
    _quantityAController.dispose();
    _nameBController.dispose();
    _priceBController.dispose();
    _quantityBController.dispose();
    super.dispose();
  }

  double? _parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  String _nameOf(TextEditingController c, String fallback) {
    final t = c.text.trim();
    return t.isEmpty ? fallback : t;
  }

  void _compare() {
    final priceA = _parse(_priceAController.text);
    final qtyA = _parse(_quantityAController.text);
    final priceB = _parse(_priceBController.text);
    final qtyB = _parse(_quantityBController.text);

    if (priceA == null || qtyA == null || priceB == null || qtyB == null) {
      setState(() {
        _error = 'Preencha preco e quantidade dos dois produtos.';
        _result = null;
      });
      return;
    }

    final result = compareProducts(
      ProductEntry(
        name: _nameOf(_nameAController, 'Produto A'),
        price: priceA,
        quantity: qtyA,
        unit: _unitA,
      ),
      ProductEntry(
        name: _nameOf(_nameBController, 'Produto B'),
        price: priceB,
        quantity: qtyB,
        unit: _unitB,
      ),
    );

    setState(() {
      _result = result;
      _error = result == null
          ? 'As unidades precisam ser da mesma grandeza (massa, volume ou unidade).'
          : null;
    });
  }

  void _usePrice() {
    final result = _result;
    if (result == null) return;

    final winner = result.winner == 'A'
        ? ProductEntry(
            name: _nameOf(_nameAController, 'Produto A'),
            price: _parse(_priceAController.text) ?? 0,
            quantity: _parse(_quantityAController.text) ?? 1,
            unit: _unitA,
          )
        : ProductEntry(
            name: _nameOf(_nameBController, 'Produto B'),
            price: _parse(_priceBController.text) ?? 0,
            quantity: _parse(_quantityBController.text) ?? 1,
            unit: _unitB,
          );

    Navigator.of(context).pop(
      PriceComparatorResult(name: winner.name, price: winner.price),
    );
  }

  Widget _productFields({
    required String title,
    required TextEditingController name,
    required TextEditingController price,
    required TextEditingController quantity,
    required String unit,
    required ValueChanged<String> onUnitChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nome (opcional)',
            prefixIcon: Icon(Icons.shopping_basket_outlined),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Preco (R\$)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 88,
              child: DropdownButtonFormField<String>(
                value: unit,
                decoration: const InputDecoration(labelText: 'Unid.'),
                items: _units
                    .map(
                      (u) => DropdownMenuItem<String>(
                        value: u,
                        child: Text(u),
                      ),
                    )
                    .toList(),
                onChanged: (v) => onUnitChanged(v ?? unit),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final result = _result;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.compare_arrows, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Comparador de precos',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _productFields(
              title: 'Produto A',
              name: _nameAController,
              price: _priceAController,
              quantity: _quantityAController,
              unit: _unitA,
              onUnitChanged: (v) => setState(() => _unitA = v),
            ),
            const SizedBox(height: 16),
            _productFields(
              title: 'Produto B',
              name: _nameBController,
              price: _priceBController,
              quantity: _quantityBController,
              unit: _unitB,
              onUnitChanged: (v) => setState(() => _unitB = v),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _compare,
              icon: const Icon(Icons.calculate),
              label: const Text('Comparar'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(
                result: result,
                winnerName: result.winner == 'A'
                    ? _nameOf(_nameAController, 'Produto A')
                    : _nameOf(_nameBController, 'Produto B'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _usePrice,
                icon: const Icon(Icons.check),
                label: const Text('Usar este preco'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.winnerName});

  final PriceComparison result;
  final String winnerName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savings = result.savingsPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  winnerName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Preco por ' + result.baseUnit + ': ' +
                CurrencyFormatter.format(result.cheaperPricePerBase),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            savings <= 0
                ? 'Precos equivalentes.'
                : 'A opcao mais vantajosa e ' +
                    savings.toStringAsFixed(0) +
                    '% mais economica.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
