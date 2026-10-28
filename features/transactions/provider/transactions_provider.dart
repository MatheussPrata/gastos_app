import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_flutter/features/transactions/models/transaction_models.dart';
import 'package:gastos_flutter/features/transactions/repository/transactions_repository.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) => TransactionsRepository());

/// Transaction filters state
class TransactionFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? categoryId;
  final String? creditCardId;
  final bool? isExpense;
  
  const TransactionFilters({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.creditCardId,
    this.isExpense,
  });

  TransactionFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? creditCardId,
    bool? isExpense,
  }) {
    return TransactionFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryId: categoryId ?? this.categoryId,
      creditCardId: creditCardId ?? this.creditCardId,
      isExpense: isExpense ?? this.isExpense,
    );
  }
}

/// Transaction filters notifier
class TransactionFiltersNotifier extends StateNotifier<TransactionFilters> {
  TransactionFiltersNotifier() : super(const TransactionFilters());

  void setDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void setCategory(String? categoryId) {
    state = state.copyWith(categoryId: categoryId);
  }

  void setCreditCard(String? creditCardId) {
    state = state.copyWith(creditCardId: creditCardId);
  }

  void setType(bool? isExpense) {
    state = state.copyWith(isExpense: isExpense);
  }

  void clear() {
    state = const TransactionFilters();
  }
}

final transactionFiltersProvider = StateNotifierProvider<TransactionFiltersNotifier, TransactionFilters>((ref) {
  return TransactionFiltersNotifier();
});

/// Transactions list provider
class TransactionsListNotifier extends StateNotifier<AsyncValue<List<Transaction>>> {
  final TransactionsRepository _repository;
  final Ref _ref;

  TransactionsListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    state = const AsyncValue.loading();
    
    try {
      final filters = _ref.read(transactionFiltersProvider);
      final transactions = await _repository.getTransactions(
        startDate: filters.startDate,
        endDate: filters.endDate,
        categoryId: filters.categoryId,
        creditCardId: filters.creditCardId,
        isExpense: filters.isExpense,
      );
      state = AsyncValue.data(transactions);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> createTransaction(Transaction transaction) async {
    try {
      await _repository.createTransaction(transaction);
      await loadTransactions(); // Refresh
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      await _repository.updateTransaction(transaction);
      await loadTransactions(); // Refresh
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _repository.deleteTransaction(id);
      await loadTransactions(); // Refresh
    } catch (e) {
      rethrow;
    }
  }
}

final transactionsListProvider = StateNotifierProvider<TransactionsListNotifier, AsyncValue<List<Transaction>>>((ref) {
  final repository = ref.watch(transactionsRepositoryProvider);
  return TransactionsListNotifier(repository, ref);
});

/// Monthly stats provider
final monthlyStatsProvider = FutureProvider<List<MonthlyStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyStats();
});

/// Category expenses provider
final categoryExpensesProvider = FutureProvider.family<List<CategoryExpense>, ({DateTime start, DateTime end})>((ref, params) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getExpensesByCategory(startDate: params.start, endDate: params.end);
});