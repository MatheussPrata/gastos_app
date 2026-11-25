import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';

export 'package:gastos_app/features/transactions/repository/transactions_repository.dart'
    show transactionsRepositoryProvider;

/// Selected month for the monthly dashboard view (normalized to the 1st).
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// All transactions that fall within the currently selected month.
final monthTransactionsProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactionsForMonth(month);
});

/// All transactions (used by the full list screen).
final transactionsListProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactions();
});

/// Monthly stats (income/expense/balance per month).
final monthlyStatsProvider = FutureProvider<List<MonthlyStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyStats();
});

/// Monthly income/expense with category-colored expense breakdown.
final monthlyCategoryStatsProvider =
    FutureProvider<List<MonthlyCategoryStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyCategoryStats();
});

/// Monthly stats for the full history (used by the "Tudo" report period).
final monthlyStatsAllProvider =
    FutureProvider<List<MonthlyStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyStats(months: 600);
});

/// Últimos 6 meses para o sparkline do Dashboard (consulta leve).
final recentMonthlyStatsProvider =
    FutureProvider<List<MonthlyStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  final now = DateTime.now();
  final since = DateTime(now.year, now.month - 5, 1);
  return repository.getMonthlyStats(months: 6, since: since);
});

/// Monthly income/expense (with category breakdown) for the full history.
final monthlyCategoryStatsAllProvider =
    FutureProvider<List<MonthlyCategoryStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyCategoryStats(months: 600);
});

/// Expenses grouped by category for a given date range.
final categoryExpensesProvider = FutureProvider.family<List<CategoryExpense>,
    ({DateTime start, DateTime end})>((ref, params) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getExpensesByCategory(
      startDate: params.start, endDate: params.end);
});

/// Single transaction by id.
final transactionByIdProvider =
    FutureProvider.family<Transaction?, String>((ref, id) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactionById(id);
});
