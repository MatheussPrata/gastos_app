import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/categories/models/category_models.dart' as cat;
import 'package:gastos_app/features/credit_cards/models/credit_card_model.dart';
import 'package:gastos_app/features/transactions/models/transaction_models.dart';
import 'package:gastos_app/features/transactions/services/transactions_export_service.dart';

void main() {
  group('buildTransactionsCsv', () {
    test('exporta o nome do cartão em vez do UUID e trata cartão removido', () {
      const cardId = '550e8400-e29b-41d4-a716-446655440000';
      const missingCardId = '660e8400-e29b-41d4-a716-446655449999';

      final categories = [
        const cat.Category(
          id: 'cat-1',
          name: 'Alimentação',
          color: 0xFFFF6B6B,
          icon: 'restaurant',
        ),
      ];

      final cards = [
        const CreditCardItem(
          id: cardId,
          name: 'Nubank Ultravioleta',
          color: 0xFF8A05BE,
        ),
      ];

      final transactions = [
        Transaction(
          id: 'tx-1',
          userId: 'u1',
          amount: 120.50,
          description: 'Jantar',
          date: DateTime(2026, 11, 18),
          categoryId: 'cat-1',
          creditCardId: cardId,
          paymentMethod: 'Cartão de Crédito',
          createdAt: DateTime(2026, 11, 18),
          updatedAt: DateTime(2026, 11, 18),
        ),
        Transaction(
          id: 'tx-2',
          userId: 'u1',
          amount: 45.0,
          description: 'Lanche',
          date: DateTime(2026, 11, 19),
          creditCardId: missingCardId,
          paymentMethod: 'Cartão de Crédito',
          createdAt: DateTime(2026, 11, 19),
          updatedAt: DateTime(2026, 11, 19),
        ),
        Transaction(
          id: 'tx-3',
          userId: 'u1',
          amount: 15.0,
          description: 'Café',
          date: DateTime(2026, 11, 20),
          paymentMethod: 'PIX',
          createdAt: DateTime(2026, 11, 20),
          updatedAt: DateTime(2026, 11, 20),
        ),
      ];

      final csv = buildTransactionsCsv(
        transactions: transactions,
        categories: categories,
        creditCards: cards,
      );

      expect(csv, isNot(contains(cardId)));
      expect(csv, isNot(contains(missingCardId)));
      expect(csv, contains('Nubank Ultravioleta'));
      expect(csv, contains('Cartão removido'));
      expect(csv, contains('18/11/2026;Jantar;Saída;120,50;Alimentação;Nubank Ultravioleta;Cartão de Crédito;'));
      expect(csv, contains('20/11/2026;Café;Saída;15,00;Sem categoria;;PIX;'));
    });
  });
}
