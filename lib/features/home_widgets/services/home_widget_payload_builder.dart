import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/credit_cards/repository/credit_cards_repository.dart';
import 'package:gastos_app/features/home_widgets/models/home_widget_models.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';
import 'package:gastos_app/features/planning/repository/planning_repository.dart';
import 'package:gastos_app/features/reports/ui/pages/reports_page.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/repository/transactions_repository.dart';

const List<String> _monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const List<String> _shortMonthNames = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

/// Constrói o snapshot JSON consumido pelos widgets nativos da tela inicial Android.
class HomeWidgetPayloadBuilder {
  /// Cria um construtor de payload ligado a [database].
  HomeWidgetPayloadBuilder({required db.AppDatabase database})
      : _db = database;

  final db.AppDatabase _db;

  /// Gera payload seguro sem dados sensíveis quando o usuário não está logado.
  static String unauthenticatedPayload({
    required ThemeMode themeMode,
    required Color primaryColor,
  }) {
    return jsonEncode({
      'version': 1,
      'authenticated': false,
      'updatedAt': DateTime.now().toIso8601String(),
      'themeMode': themeMode.name,
      'primaryColor': primaryColor.value,
    });
  }

  /// Constrói o JSON completo de resumo, vencimentos e gráficos dos 3 períodos.
  Future<String> build({
    required ThemeMode themeMode,
    required Color primaryColor,
    DateTime? now,
  }) async {
    final refNow = now ?? DateTime.now();
    final currentMonth = DateTime(refNow.year, refNow.month, 1);

    final txRepo = TransactionsRepository(database: _db);
    final planRepo = PlanningRepository(database: _db);
    final cardsRepo = CreditCardsRepository(database: _db);

    final monthTransactions = await _loadTransactionsForMonth(currentMonth);
    var monthIncome = 0.0;
    var monthExpense = 0.0;
    for (final tx in monthTransactions) {
      if (tx.isExpense) {
        monthExpense += tx.amount;
      } else {
        monthIncome += tx.amount;
      }
    }
    final monthBalance = monthIncome - monthExpense;

    final plan = await planRepo.getPlanForMonth(
      currentMonth,
      scope: BudgetScope.individual,
    );
    final budgetTotal = plan?.monthlyBudget ?? 0;
    var budgetSpent = 0.0;
    if (budgetTotal > 0) {
      final spentByCat = await planRepo.getSpentByCategory(
        currentMonth,
        scope: BudgetScope.individual,
      );
      budgetSpent = spentByCat.values.fold<double>(0, (sum, v) => sum + v);
    }

    final upcoming = await _buildUpcomingBills(
      refNow: refNow,
      cardsRepo: cardsRepo,
    );

    final monthlyStats = await txRepo.getMonthlyStats(months: 600);
    final monthlyCatStats = await txRepo.getMonthlyCategoryStats(months: 600);

    final charts = <String, dynamic>{};
    for (final period in HomeWidgetPeriod.values) {
      charts[period.key] = await _buildChartPeriodData(
        period: period,
        currentMonth: currentMonth,
        refNow: refNow,
        monthTransactions: monthTransactions,
        monthlyStats: monthlyStats,
        monthlyCatStats: monthlyCatStats,
        txRepo: txRepo,
        cardsRepo: cardsRepo,
      );
    }

    final payload = <String, dynamic>{
      'version': 1,
      'authenticated': true,
      'updatedAt': refNow.toIso8601String(),
      'themeMode': themeMode.name,
      'primaryColor': primaryColor.value,
      'summary': {
        'monthLabel': '${_monthNames[refNow.month - 1]} ${refNow.year}',
        'income': monthIncome,
        'expense': monthExpense,
        'balance': monthBalance,
        'budgetTotal': budgetTotal,
        'budgetSpent': budgetSpent,
      },
      'upcomingBills': upcoming.items,
      'upcomingTotal': upcoming.total,
      'charts': charts,
    };

    return jsonEncode(payload);
  }

  Future<List<Transaction>> _loadTransactionsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start))
          ..where((t) => t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();

    return rows.map(_txToModel).toList();
  }

  Future<({List<Map<String, dynamic>> items, double total})>
      _buildUpcomingBills({
    required DateTime refNow,
    required CreditCardsRepository cardsRepo,
  }) async {
    final today = DateTime(refNow.year, refNow.month, refNow.day);
    final horizon = today.add(const Duration(days: 15));
    final bills = <_UpcomingBillItem>[];

    final recurringRows = await (_db.select(_db.recurringTransactions)
          ..where((r) => r.isActive.equals(true)))
        .get();
    for (final r in recurringRows) {
      final due = DateTime(
        r.nextDueDate.year,
        r.nextDueDate.month,
        r.nextDueDate.day,
      );
      if (due.isBefore(today) || due.isAfter(horizon)) continue;
      bills.add(
        _UpcomingBillItem(
          title: r.description,
          amount: r.amount,
          dueDate: due,
          isExpense: r.type == 'expense',
        ),
      );
    }

    final cards = await cardsRepo.getCreditCards();
    final refMonth = DateTime(refNow.year, refNow.month, 1);
    for (final card in cards) {
      final due = _nextCardDue(card.dueDay, today);
      if (due.isAfter(horizon)) continue;
      final isPaid = await cardsRepo.isInvoicePaid(card.id, refMonth);
      if (isPaid) continue;
      final invoiceAmount =
          await cardsRepo.getCardInvoiceAmount(card.id, refMonth);
      final spent = await cardsRepo.getCardSpentForMonth(card.id, refMonth);
      final amount = invoiceAmount > 0 ? invoiceAmount : spent;
      if (amount <= 0) continue;
      bills.add(
        _UpcomingBillItem(
          title: 'Fatura ${card.name}',
          amount: amount,
          dueDate: due,
          isExpense: true,
        ),
      );
    }

    final reminderEnd = horizon.add(const Duration(days: 1));
    final reminderRows = await (_db.select(_db.transactions)
          ..where((t) => t.isExpense.equals(true))
          ..where((t) => t.reminderEnabled.equals(true))
          ..where((t) => t.date.isBiggerOrEqualValue(today))
          ..where((t) => t.date.isSmallerThanValue(reminderEnd)))
        .get();
    for (final t in reminderRows) {
      final due = DateTime(t.date.year, t.date.month, t.date.day);
      bills.add(
        _UpcomingBillItem(
          title: t.description,
          amount: t.amount,
          dueDate: due,
          isExpense: true,
        ),
      );
    }

    bills.sort((a, b) {
      final cmp = a.dueDate.compareTo(b.dueDate);
      if (cmp != 0) return cmp;
      return b.amount.compareTo(a.amount);
    });

    final total = bills
        .where((b) => b.isExpense)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final serialized = [
      for (final item in bills.take(6))
        () {
          final daysUntil = item.dueDate.difference(today).inDays;
          final dueLabel = switch (daysUntil) {
            0 => 'Hoje',
            1 => 'Amanhã',
            _ => 'Em ${daysUntil}d',
          };
          return {
            'title': item.title,
            'amount': item.amount,
            'dueLabel': dueLabel,
            'daysUntil': daysUntil,
            'isExpense': item.isExpense,
          };
        }(),
    ];

    return (items: serialized, total: total);
  }

  Future<Map<String, dynamic>> _buildChartPeriodData({
    required HomeWidgetPeriod period,
    required DateTime currentMonth,
    required DateTime refNow,
    required List<Transaction> monthTransactions,
    required List<MonthlyStats> monthlyStats,
    required List<MonthlyCategoryStats> monthlyCatStats,
    required TransactionsRepository txRepo,
    required CreditCardsRepository cardsRepo,
  }) async {
    final range = _rangeFor(period, currentMonth, refNow);
    final periodLabel = _periodLabel(period, currentMonth);

    // 1. Categorias
    final rawCategories = await txRepo.getExpensesByCategory(
      startDate: range.start,
      endDate: range.end,
    );
    final visibleCategories = rawCategories.where((c) => c.total > 0).toList();
    final categoriesTotal = visibleCategories.fold<double>(
      0,
      (sum, c) => sum + c.total,
    );
    final categoryColors = resolveCategoryChartColors(visibleCategories);
    final categorySlices = _compactCategories(
      visibleCategories,
      categoryColors,
    );

    // 2. Evolução de saldo
    final List<Map<String, dynamic>> balanceSeries;
    if (period == HomeWidgetPeriod.month) {
      final dailyPoints = buildDailyCumulativeBalancePoints(
        monthTransactions,
        currentMonth,
        now: refNow,
      );
      balanceSeries = [
        for (final pt in dailyPoints)
          {'label': '${pt.day}', 'value': pt.balance},
      ];
    } else {
      final continuous = _continuousMonthlyStats(
        monthlyStats,
        range.start,
        range.end,
      );
      balanceSeries = [
        for (final stat in continuous)
          {'label': _shortMonth(stat.month), 'value': stat.balance},
      ];
    }

    // 3. Comparativo mensal
    final comparison = buildMonthlyComparisonSeries(
      monthlyCatStats,
      period.toReportPeriod(),
      currentMonth,
      now: refNow,
    );
    final monthlyComparison = [
      for (final stat in comparison)
        {
          'label': _shortMonth(stat.month),
          'income': stat.income,
          'expense': stat.expense,
        },
    ];

    // 4. Formas de pagamento
    final rawMethods = await txRepo.getExpensesByPaymentMethod(
      startDate: range.start,
      endDate: range.end,
    );
    final visibleMethods = rawMethods.where((m) => m.total > 0).toList();
    final paymentTotal = visibleMethods.fold<double>(
      0,
      (sum, m) => sum + m.total,
    );
    final paymentMethods = [
      for (final m in visibleMethods)
        {
          'method': m.method,
          'total': m.total,
          'count': m.count,
          'color': _paymentMethodColor(m.method),
        },
    ];

    // 5. Cartões de crédito
    final List<Map<String, dynamic>> cardsList;
    if (period == HomeWidgetPeriod.month) {
      final cards = await cardsRepo.getCreditCards();
      final cardEntries = <Map<String, dynamic>>[];
      for (final card in cards) {
        final spent = await cardsRepo.getCardSpentForMonth(
          card.id,
          currentMonth,
        );
        final invoiceTotal = await cardsRepo.getCardInvoiceAmount(
          card.id,
          currentMonth,
        );
        final isPaid = await cardsRepo.isInvoicePaid(card.id, currentMonth);
        final used = math.max(spent, invoiceTotal);
        if (used <= 0) continue;
        cardEntries.add({
          'name': card.name,
          'spent': used,
          'limit': card.limitAmount,
          'color': card.color,
          'isPaid': isPaid,
        });
      }
      cardEntries.sort(
        (a, b) => (b['spent'] as double).compareTo(a['spent'] as double),
      );
      cardsList = cardEntries;
    } else {
      final cards = await cardsRepo.getCreditCards();
      final totals = await cardsRepo.getCardsSpentInRange(
        startDate: range.start,
        endDate: range.end,
      );
      final cardEntries = <Map<String, dynamic>>[
        for (final card in cards)
          if ((totals[card.id] ?? 0) > 0)
            {
              'name': card.name,
              'spent': totals[card.id] ?? 0,
              'limit': 0.0,
              'color': card.color,
              'isPaid': false,
            },
      ]..sort(
          (a, b) => (b['spent'] as double).compareTo(a['spent'] as double),
        );
      cardsList = cardEntries;
    }

    return {
      'periodLabel': periodLabel,
      'categories': categorySlices,
      'categoriesTotal': categoriesTotal,
      'balanceSeries': balanceSeries,
      'monthlyComparison': monthlyComparison,
      'paymentMethods': paymentMethods,
      'paymentTotal': paymentTotal,
      'cards': cardsList,
    };
  }

  List<Map<String, dynamic>> _compactCategories(
    List<CategoryExpense> visible,
    Map<String, Color> colors,
  ) {
    if (visible.length <= 8) {
      return [
        for (final c in visible)
          {
            'name': c.categoryName,
            'total': c.total,
            'color': (colors[c.categoryId] ?? Color(c.categoryColor)).value,
          },
      ];
    }

    final top = visible.take(7).toList();
    final restTotal = visible.skip(7).fold<double>(
          0,
          (sum, c) => sum + c.total,
        );

    return [
      for (final c in top)
        {
          'name': c.categoryName,
          'total': c.total,
          'color': (colors[c.categoryId] ?? Color(c.categoryColor)).value,
        },
      {
        'name': 'Outros',
        'total': restTotal,
        'color': 0xFF94A3B8,
      },
    ];
  }

  ({DateTime start, DateTime end}) _rangeFor(
    HomeWidgetPeriod period,
    DateTime currentMonth,
    DateTime refNow,
  ) {
    switch (period) {
      case HomeWidgetPeriod.month:
        return (
          start: DateTime(currentMonth.year, currentMonth.month, 1),
          end: DateTime(
            currentMonth.year,
            currentMonth.month + 1,
            0,
            23,
            59,
            59,
          ),
        );
      case HomeWidgetPeriod.quarter:
        return (
          start: DateTime(currentMonth.year, currentMonth.month - 2, 1),
          end: DateTime(
            currentMonth.year,
            currentMonth.month + 1,
            0,
            23,
            59,
            59,
          ),
        );
      case HomeWidgetPeriod.year:
        return (
          start: DateTime(refNow.year, 1, 1),
          end: DateTime(refNow.year, refNow.month + 1, 0, 23, 59, 59),
        );
    }
  }

  String _periodLabel(HomeWidgetPeriod period, DateTime currentMonth) {
    switch (period) {
      case HomeWidgetPeriod.month:
        return '${_shortMonthNames[currentMonth.month - 1]}/${currentMonth.year}';
      case HomeWidgetPeriod.quarter:
        final start = DateTime(currentMonth.year, currentMonth.month - 2, 1);
        return '${_shortMonthNames[start.month - 1]}–'
            '${_shortMonthNames[currentMonth.month - 1]}';
      case HomeWidgetPeriod.year:
        return '${currentMonth.year}';
    }
  }

  List<MonthlyStats> _continuousMonthlyStats(
    List<MonthlyStats> raw,
    DateTime start,
    DateTime end,
  ) {
    final byMonth = {for (final s in raw) s.month: s};
    final result = <MonthlyStats>[];
    var cursor = DateTime(start.year, start.month, 1);
    final limit = DateTime(end.year, end.month, 1);
    while (!cursor.isAfter(limit)) {
      final key =
          '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}';
      result.add(
        byMonth[key] ??
            MonthlyStats(month: key, income: 0, expense: 0, balance: 0),
      );
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }

  DateTime _nextCardDue(int dueDay, DateTime today) {
    final safeDay = dueDay.clamp(1, 31);
    final daysInThisMonth = DateTime(today.year, today.month + 1, 0).day;
    var due = DateTime(
      today.year,
      today.month,
      math.min(safeDay, daysInThisMonth),
    );
    if (due.isBefore(today)) {
      final nextMonth = DateTime(today.year, today.month + 1, 1);
      final daysInNextMonth =
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
      due = DateTime(
        nextMonth.year,
        nextMonth.month,
        math.min(safeDay, daysInNextMonth),
      );
    }
    return due;
  }

  String _shortMonth(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return key;
    return _shortMonthNames[month - 1];
  }

  int _paymentMethodColor(String method) {
    switch (method) {
      case PaymentMethods.pix:
        return 0xFF00BFA5;
      case PaymentMethods.creditCard:
        return 0xFF7E57C2;
      case PaymentMethods.debitCard:
        return 0xFF29B6F6;
      case PaymentMethods.money:
        return 0xFF6BCB77;
      case PaymentMethods.boleto:
        return 0xFFFFB347;
      default:
        return 0xFF78909C;
    }
  }

  Transaction _txToModel(db.Transaction t) => Transaction(
        id: t.id,
        userId: t.userId,
        amount: t.amount,
        description: t.description,
        date: t.date,
        categoryId: t.categoryId,
        subcategoryId: t.subcategoryId,
        creditCardId: t.creditCardId,
        paymentMethod: t.paymentMethod,
        isExpense: t.isExpense,
        isInstallment: t.isInstallment,
        installmentNumber: t.installmentNumber,
        totalInstallments: t.totalInstallments,
        installmentGroupId: t.installmentGroupId,
        notes: t.notes,
        ownerId: t.ownerId,
        partnerSynced: t.partnerSynced,
        isSynced: t.isSynced,
        reminderEnabled: t.reminderEnabled,
        receiptId: t.receiptId,
        createdAt: t.createdAt,
        updatedAt: t.updatedAt,
      );
}

class _UpcomingBillItem {
  const _UpcomingBillItem({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isExpense,
  });

  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isExpense;
}
