import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gastos_app/core/router/app_router.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/shopping_list/data/models/shopping_item.dart';
import 'package:gastos_app/features/shopping_list/provider/shopping_list_provider.dart';
import 'package:gastos_app/features/shopping_list/ui/widgets/item_form_sheet.dart';
import 'package:gastos_app/features/shopping_list/ui/widgets/price_comparator_sheet.dart';

/// Tela principal da lista de compras com planejamento de preco e comparador
/// de custo-beneficio entre embalagens.
class ShoppingListPage extends ConsumerWidget {
  const ShoppingListPage({super.key, this.showBackButton = true});

  /// Quando a tela e usada como aba da navegacao principal, o botao de voltar
  /// da AppBar e desnecessario.
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingListProvider);
    final summary = ref.watch(shoppingListSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.dashboard);
                  }
                },
              )
            : null,
        title: const Text('Lista de Compras'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Comparador de precos',
            onPressed: () => _openComparator(context, ref),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
            onRetry: () => ref.read(shoppingListProvider.notifier).loadItems()),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyView(onAdd: () => _openForm(context));
          }

          final pending = items.where((i) => !i.isPurchased).toList();
          final purchased = items.where((i) => i.isPurchased).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _SummaryCard(summary: summary),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'A comprar',
                count: pending.length,
              ),
              if (pending.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nenhum item pendente.'),
                )
              else
                ...pending.map((item) => _ItemTile(
                      item: item,
                      onToggle: () => ref
                          .read(shoppingListProvider.notifier)
                          .togglePurchased(item.id),
                      onEdit: () => _openForm(context, item: item),
                      onDelete: () => ref
                          .read(shoppingListProvider.notifier)
                          .deleteItem(item.id),
                      onSetPrice: () => _promptActualPrice(context, ref, item),
                    )),
              const SizedBox(height: 24),
              _SectionHeader(title: 'No carrinho', count: purchased.length),
              if (purchased.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Nenhum item no carrinho ainda.'),
                )
              else
                ...purchased.map((item) => _ItemTile(
                      item: item,
                      onToggle: () => ref
                          .read(shoppingListProvider.notifier)
                          .togglePurchased(item.id),
                      onEdit: () => _openForm(context, item: item),
                      onDelete: () => ref
                          .read(shoppingListProvider.notifier)
                          .deleteItem(item.id),
                      onSetPrice: () => _promptActualPrice(context, ref, item),
                    )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo item',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openForm(BuildContext context, {ShoppingItem? item}) {
    showItemFormSheet(context, item: item);
  }

  Future<void> _openComparator(BuildContext context, WidgetRef ref) async {
    final result = await showPriceComparatorSheet(context);
    if (result != null && context.mounted) {
      showItemFormSheet(
        context,
        initialName: result.name,
        initialEstimatedPrice: result.price,
      );
    }
  }

  Future<void> _promptActualPrice(
    BuildContext context,
    WidgetRef ref,
    ShoppingItem item,
  ) async {
    final controller = TextEditingController(
      text: item.actualPrice == null
          ? ''
          : item.actualPrice!.toStringAsFixed(2).replaceAll('.', ','),
    );

    final price = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Valor pago por ' + item.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor pago (R\$)',
            hintText: '0,00',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              final parsed = text.isEmpty
                  ? null
                  : double.tryParse(text.replaceAll(',', '.'));
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (price != null) {
      await ref
          .read(shoppingListProvider.notifier)
          .setActualPrice(item.id, price);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final ShoppingListSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumo',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Total estimado',
              value: CurrencyFormatter.format(summary.estimatedTotal),
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Ja comprado',
              value: CurrencyFormatter.format(summary.purchasedTotal),
              valueColor: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              label: 'Restante',
              value: CurrencyFormatter.format(summary.remainingTotal),
              valueColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              summary.purchasedItems.toString() +
                  ' de ' +
                  summary.totalItems.toString() +
                  ' itens comprados',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text(count.toString()),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onSetPrice,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purchased = item.isPurchased;

    final priceText = purchased
        ? (item.actualPrice == null
            ? 'informar valor'
            : CurrencyFormatter.format(item.actualPrice!))
        : (item.estimatedPrice == null
            ? 'sem preco'
            : CurrencyFormatter.format(item.estimatedPrice!));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: purchased,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          item.name,
          style: purchased
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: theme.disabledColor,
                )
              : theme.textTheme.bodyLarge,
        ),
        subtitle: Text(_subtitle(item)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (purchased)
              IconButton(
                icon: const Icon(Icons.attach_money),
                tooltip: 'Informar valor pago',
                onPressed: onSetPrice,
              )
            else
              TextButton(
                onPressed: onSetPrice,
                child: Text(priceText),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _quantityUnit(ShoppingItem item) {
    final qty = item.quantity;
    final qtyText =
        qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    final unit = item.unit ?? 'un';
    return qtyText + ' ' + unit;
  }

  String _subtitle(ShoppingItem item) {
    final parts = <String>[_quantityUnit(item)];
    if (item.category != null && item.category!.isNotEmpty) {
      parts.add(item.category!);
    }
    return parts.join(' • ');
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Sua lista esta vazia',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione itens e compare precos para economizar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Nao foi possivel carregar a lista.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
