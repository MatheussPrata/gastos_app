import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/theme/app_theme.dart';
import 'package:gastos_app/features/credit_cards/provider/credit_cards_provider.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_detail_page.dart';
import 'package:gastos_app/features/credit_cards/ui/pages/credit_card_form_page.dart';
import 'package:gastos_app/features/credit_cards/ui/widgets/credit_card_visual.dart';

class CreditCardsPage extends ConsumerWidget {
  const CreditCardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);
    final cardsSummaryAsync = ref.watch(cardsWithSpentProvider(currentMonth));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Cartões de Crédito'),
      ),
      body: cardsSummaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar cartões: $e')),
        data: (cardsSummary) {
          if (cardsSummary.isEmpty) {
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
                      'limites e parcelamentos no planejamento.',
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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(creditCardsProvider);
              ref.invalidate(cardsWithSpentProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: cardsSummary.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = cardsSummary[index];
                return CreditCardVisual(
                  card: item.card,
                  spent: item.spent,
                  invoiceTotal: item.invoiceTotal,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreditCardDetailPage(card: item.card),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreditCardFormPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Novo Cartão'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
