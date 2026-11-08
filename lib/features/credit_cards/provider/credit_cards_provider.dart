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

/// Total invoice amount set for a card and month.
final cardInvoiceAmountProvider = FutureProvider.family<double,
    ({String cardId, DateTime month})>((ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getCardInvoiceAmount(params.cardId, params.month);
});

/// Transactions made on a credit card.
final cardTransactionsProvider = FutureProvider.family<List<db.Transaction>,
    ({String cardId, DateTime? month})>((ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getCardTransactions(params.cardId, month: params.month);
});

typedef CardWithSpent = ({
  CreditCardItem card,
  double spent,
  double invoiceTotal,
  double difference,
  bool isPaid,
});

/// Selected card ID in the credit cards dashboard (null means 'Todos os Cartões').
final creditCardsSelectedFilterProvider = StateProvider<String?>((ref) => null);

/// Selected reference month for the credit cards dashboard.
final creditCardsSelectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Whether a specific card invoice is paid.
final cardInvoicePaidProvider =
    FutureProvider.family<bool, ({String cardId, DateTime month})>(
        (ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.isInvoicePaid(params.cardId, params.month);
});

/// All transactions across all cards for the given month cycle.
final allCardsTransactionsProvider =
    FutureProvider.family<List<db.Transaction>, DateTime>((ref, month) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getAllCardTransactions(month: month);
});

/// Category spending breakdown for a specific card or all cards.
final cardCategorySpendingProvider = FutureProvider.family<Map<String, double>,
    ({String? cardId, DateTime month})>((ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getCardSpentByCategory(
    cardId: params.cardId,
    month: params.month,
  );
});

/// Invoice forecast for the upcoming 6 months.
final cardForecastProvider = FutureProvider.family<List<InvoiceForecast>,
    ({String? cardId, DateTime startMonth})>((ref, params) async {
  final repo = ref.watch(creditCardsRepositoryProvider);
  return repo.getFutureInvoicesForecast(
    cardId: params.cardId,
    startMonth: params.startMonth,
    numberOfMonths: 6,
  );
});

/// All cards with their spending and invoice info for the reference month.
final cardsWithSpentProvider =
    FutureProvider.family<List<CardWithSpent>, DateTime>((ref, month) async {
  final cards = ref.watch(creditCardsProvider).valueOrNull ?? [];
  final repo = ref.watch(creditCardsRepositoryProvider);

  final results = <CardWithSpent>[];
  for (final card in cards) {
    final spent = await repo.getCardSpentForMonth(card.id, month);
    final invoiceTotal = await repo.getCardInvoiceAmount(card.id, month);
    final isPaid = await repo.isInvoicePaid(card.id, month);
    final diff = invoiceTotal > spent ? (invoiceTotal - spent) : 0.0;
    results.add((
      card: card,
      spent: spent,
      invoiceTotal: invoiceTotal,
      difference: diff,
      isPaid: isPaid,
    ));
  }
  return results;
});
