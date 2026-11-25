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
  return repository.getMonthlyStats(months: 600);
});

/// Monthly income/expense with category-colored expense breakdown.
final monthlyCategoryStatsProvider =
    FutureProvider<List<MonthlyCategoryStats>>((ref) async {
  ref.watch(monthlyStatsProvider);
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyCategoryStats(months: 600);
});

/// Monthly stats for the full history (used by the "Tudo" report period).
final monthlyStatsAllProvider =
    FutureProvider<List<MonthlyStats>>((ref) async {
  ref.watch(monthlyStatsProvider);
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyStats(months: 600);
});

/// Últimos 6 meses contínuos até o mês atual para o sparkline do Dashboard.
final recentMonthlyStatsProvider =
    FutureProvider<List<MonthlyStats>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  final now = DateTime.now();
  final since = DateTime(now.year, now.month - 5, 1);
  final until = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  final raw = await repository.getMonthlyStats(
    months: 6,
    since: since,
    until: until,
  );
  if (raw.isEmpty) return const <MonthlyStats>[];

  final byMonth = {for (final s in raw) s.month: s};
  return [
    for (var offset = 5; offset >= 0; offset--)
      () {
        final d = DateTime(now.year, now.month - offset, 1);
        final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
        return byMonth[key] ??
            MonthlyStats(month: key, income: 0, expense: 0, balance: 0);
      }(),
  ];
});

/// Monthly income/expense (with category breakdown) for the full history.
final monthlyCategoryStatsAllProvider =
    FutureProvider<List<MonthlyCategoryStats>>((ref) async {
  ref.watch(monthlyStatsProvider);
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getMonthlyCategoryStats(months: 600);
});

/// Expenses grouped by category for a given date range.
final categoryExpensesProvider = FutureProvider.family<List<CategoryExpense>,
    ({DateTime start, DateTime end})>((ref, params) async {
  ref.watch(monthlyStatsProvider);
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getExpensesByCategory(
      startDate: params.start, endDate: params.end);
});

/// Expenses grouped by payment method for a given date range.
final paymentMethodExpensesProvider = FutureProvider.family<
    List<PaymentMethodExpense>, ({DateTime start, DateTime end})>(
  (ref, params) async {
    ref.watch(monthlyStatsProvider);
    final repository = ref.watch(transactionsRepositoryProvider);
    return repository.getExpensesByPaymentMethod(
      startDate: params.start,
      endDate: params.end,
    );
  },
);

/// Single transaction by id.
final transactionByIdProvider =
    FutureProvider.family<Transaction?, String>((ref, id) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  return repository.getTransactionById(id);
});
