import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/features/sharing/models/sharing_models.dart';

void main() {
  group('SharingConnection', () {
    test('le a resposta do servidor com as preferencias', () {
      final connection = SharingConnection.fromJson({
        'id': 'conn-1',
        'partnerUserId': 'user-2',
        'partnerUsername': 'Maria',
        'createdAt': '2026-11-03T10:00:00.000Z',
        'lastSyncedAt': '2026-11-03T10:05:00.000Z',
        'shareTransactions': false,
      });

      expect(connection.partnerUsername, 'Maria');
      expect(connection.shareTransactions, isFalse);
      expect(connection.lastSyncedAt, isNotNull);
    });

    test('faz round-trip pelo cache local', () {
      final original = SharingConnection(
        id: 'conn-1',
        partnerUserId: 'user-2',
        partnerUsername: 'Maria',
        createdAt: DateTime.utc(2026, 11, 3),
        shareTransactions: false,
      );

      final restored = SharingConnection.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.partnerUserId, original.partnerUserId);
      expect(restored.shareTransactions, isFalse);
    });
  });

  group('SharingSyncResult', () {
    test('resume o que foi recebido do parceiro', () {
      const result = SharingSyncResult(
        partnerUsername: 'Maria',
        pulledTransactions: 3,
      );

      expect(result.hasPartner, isTrue);
      expect(result.summary, contains('3 gasto(s)'));
    });

    test('avisa quando nao existe parceiro', () {
      const result = SharingSyncResult();
      expect(result.hasPartner, isFalse);
      expect(result.summary, contains('Nenhum parceiro'));
    });
  });
}
