import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';

class CreditCardsNotifier
    extends StateNotifier<AsyncValue<List<CreditCardItem>>> {
  CreditCardsNotifier(this._repository) : super(const AsyncValue.loading()) {
    load();
  }

  final CreditCardsRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final cards = await _repository.getCreditCards();
      state = AsyncValue.data(cards);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createCard(CreditCardItem card) async {
    await _repository.createCreditCard(card);
    await load();
  }

  Future<void> updateCard(CreditCardItem card) async {
    await _repository.updateCreditCard(card);
    await load();
  }

  Future<void> deleteCard(String id) async {
    await _repository.deleteCreditCard(id);
    await load();
  }
}

final creditCardsProvider = StateNotifierProvider<CreditCardsNotifier,
    AsyncValue<List<CreditCardItem>>>((ref) {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return CreditCardsNotifier(repo);
});

/// Total spent on a specific credit card for a given month.
final cardSpentForMonthProvider = FutureProvider.family<double,
    ({String cardId, DateTime month})>((ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getCardSpentForMonth(params.cardId, params.month);
});

/// Transactions made on a credit card.
final cardTransactionsProvider = FutureProvider.family<List<db.Transaction>,
    ({String cardId, DateTime? month})>((ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getCardTransactions(params.cardId, month: params.month);
});

typedef CardWithSpent = ({CreditCardItem card, double spent});

/// All cards with their spending for the reference month.
final cardsWithSpentProvider =
    FutureProvider.family<List<CardWithSpent>, DateTime>((ref, month) async {
  final cards = ref.watch(creditCardsProvider).valueOrNull ?? [];
  final repo = ref.watch(creditCardsRepositoryProvider);

  final results = <CardWithSpent>[];
  for (final card in cards) {
    final spent = await repo.getCardSpentForMonth(card.id, month);
    results.add((card: card, spent: spent));
  }
  return results;
});
