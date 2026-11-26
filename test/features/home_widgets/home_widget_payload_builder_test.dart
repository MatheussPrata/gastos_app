import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/home_widgets/services/home_widget_payload_builder.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late HomeWidgetPayloadBuilder builder;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    builder = HomeWidgetPayloadBuilder(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('HomeWidgetPayloadBuilder', () {
    test('gera resumo, vencimentos de 15 dias e os 5 graficos por periodo',
        () async {
      final refNow = DateTime(2026, 11, 10, 12);

      // Categorias
      await database.into(database.categories).insert(
            db.CategoriesCompanion.insert(
              id: 'cat-food',
              name: 'Alimentação',
              color: 0xFFFF6B6B,
              icon: 'restaurant',
            ),
          );
      await database.into(database.categories).insert(
            db.CategoriesCompanion.insert(
              id: 'cat-trans',
              name: 'Transporte',
              color: 0xFF4ECDC4,
              icon: 'directions_car',
            ),
          );

      // Cartoes: Inter (nao pago, vence em 5 dias) e Nubank (ja pago, vence em 3 dias)
      await database.into(database.creditCards).insert(
            db.CreditCardsCompanion.insert(
              id: 'card-inter',
              name: 'Inter',
              color: 0xFFFF7043,
              limitAmount: const Value(2000),
              closingDay: const Value(25),
              dueDay: const Value(15),
            ),
          );
      await database.into(database.creditCards).insert(
            db.CreditCardsCompanion.insert(
              id: 'card-nubank',
              name: 'Nubank',
              color: 0xFF7E57C2,
              limitAmount: const Value(3000),
              closingDay: const Value(25),
              dueDay: const Value(13),
            ),
          );
      await database.into(database.appSettings).insert(
            db.AppSettingsCompanion.insert(
              key: 'card_invoice_paid_card-nubank_2026_11',
              value: 'true',
            ),
          );

      // Plano de orcamento do mes
      await database.into(database.budgetPlans).insert(
            db.BudgetPlansCompanion.insert(
              id: 'plan-1',
              userId: 'u1',
              month: DateTime(2026, 11, 1),
              monthlyBudget: const Value(1500),
              createdAt: refNow,
              updatedAt: refNow,
            ),
          );

      // Transacoes no mes atual e mes anterior
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'tx-income',
              userId: 'u1',
              amount: 3000,
              description: 'Salário',
              date: DateTime(2026, 11, 2),
              paymentMethod: const Value(PaymentMethods.pix),
              isExpense: const Value(false),
              createdAt: refNow,
              updatedAt: refNow,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'tx-food',
              userId: 'u1',
              amount: 400,
              description: 'Supermercado',
              date: DateTime(2026, 11, 5),
              categoryId: const Value('cat-food'),
              creditCardId: const Value('card-inter'),
              paymentMethod: const Value(PaymentMethods.creditCard),
              createdAt: refNow,
              updatedAt: refNow,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'tx-nu',
              userId: 'u1',
              amount: 250,
              description: 'Farmácia',
              date: DateTime(2026, 11, 6),
              categoryId: const Value('cat-trans'),
              creditCardId: const Value('card-nubank'),
              paymentMethod: const Value(PaymentMethods.creditCard),
              isExpense: const Value(true),
              createdAt: refNow,
              updatedAt: refNow,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'tx-reminder',
              userId: 'u1',
              amount: 150,
              description: 'Conta de Luz',
              date: DateTime(2026, 11, 12),
              categoryId: const Value('cat-food'),
              paymentMethod: const Value(PaymentMethods.boleto),
              isExpense: const Value(true),
              reminderEnabled: const Value(true),
              createdAt: refNow,
              updatedAt: refNow,
            ),
          );
      await database.into(database.transactions).insert(
            db.TransactionsCompanion.insert(
              id: 'tx-prev-month',
              userId: 'u1',
              amount: 500,
              description: 'Mercado Outubro',
              date: DateTime(2026, 10, 15),
              categoryId: const Value('cat-food'),
              paymentMethod: const Value(PaymentMethods.pix),
              isExpense: const Value(true),
              createdAt: refNow,
              updatedAt: refNow,
            ),
          );

      // Recorrentes: uma dentro dos 15 dias e outra fora (25 dias)
      await database.into(database.recurringTransactions).insert(
            db.RecurringTransactionsCompanion.insert(
              id: 'rec-near',
              userId: 'u1',
              description: 'Internet Fibra',
              amount: 120,
              type: 'expense',
              frequency: 'monthly',
              dayOfMonth: 12,
              startDate: DateTime(2026, 1, 12),
              nextDueDate: DateTime(2026, 11, 12),
              createdAt: refNow,
            ),
          );
      await database.into(database.recurringTransactions).insert(
            db.RecurringTransactionsCompanion.insert(
              id: 'rec-far',
              userId: 'u1',
              description: 'IPTU Anual',
              amount: 900,
              type: 'expense',
              frequency: 'yearly',
              dayOfMonth: 5,
              startDate: DateTime(2026, 1, 5),
              nextDueDate: DateTime(2026, 12, 5),
              createdAt: refNow,
            ),
          );

      final jsonStr = await builder.build(
        themeMode: ThemeMode.dark,
        primaryColor: const Color(0xFF2563EB),
        now: refNow,
      );
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['authenticated'], isTrue);
      expect(map['themeMode'], 'dark');

      final summary = map['summary'] as Map<String, dynamic>;
      expect(summary['monthLabel'], 'Novembro 2026');
      expect((summary['income'] as num).toDouble(), 3000.0);
      expect((summary['expense'] as num).toDouble(), 800.0);
      expect((summary['balance'] as num).toDouble(), 2200.0);
      expect((summary['budgetTotal'] as num).toDouble(), 1500.0);
      expect((summary['budgetSpent'] as num).toDouble(), 800.0);

      // Vencimentos: Internet Fibra (120), Conta de Luz (150), Fatura Inter (400).
      // Nubank foi paga; IPTU esta fora do horizonte de 15 dias.
      final upcomingBills = (map['upcomingBills'] as List).cast<Map<String, dynamic>>();
      final titles = upcomingBills.map((e) => e['title']).toList();
      expect(titles, containsAll(['Internet Fibra', 'Conta de Luz', 'Fatura Inter']));
      expect(titles, isNot(contains('Fatura Nubank')));
      expect(titles, isNot(contains('IPTU Anual')));
      expect((map['upcomingTotal'] as num).toDouble(), 670.0);

      final charts = map['charts'] as Map<String, dynamic>;
      expect(charts.keys, containsAll(['month', 'quarter', 'year']));

      final monthChart = charts['month'] as Map<String, dynamic>;
      expect((monthChart['categoriesTotal'] as num).toDouble(), 800.0);
      expect((monthChart['categories'] as List).length, 2);
      expect((monthChart['balanceSeries'] as List).isNotEmpty, isTrue);
      expect((monthChart['monthlyComparison'] as List).length, 6);
      expect((monthChart['paymentMethods'] as List).length, 2);
      expect((monthChart['cards'] as List).length, 2);

      final quarterChart = charts['quarter'] as Map<String, dynamic>;
      expect((quarterChart['categoriesTotal'] as num).toDouble(), 1300.0);
      expect((quarterChart['monthlyComparison'] as List).length, 3);
    });

    test('unauthenticatedPayload limpa dados financeiros', () {
      final raw = HomeWidgetPayloadBuilder.unauthenticatedPayload(
        themeMode: ThemeMode.light,
        primaryColor: const Color(0xFF2563EB),
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;

      expect(map['authenticated'], isFalse);
      expect(map.containsKey('summary'), isFalse);
      expect(map.containsKey('upcomingBills'), isFalse);
      expect(map.containsKey('charts'), isFalse);
    });
  });
}
