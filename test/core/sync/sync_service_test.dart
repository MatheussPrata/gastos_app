import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart';
import 'package:gastos_app/core/sync/sync_service.dart';

class _FakeDio extends Mock implements Dio {}

class _FakeDioClient extends Mock implements DioClient {}

class _FakeStorage extends Mock implements FlutterSecureStorage {}

Response<dynamic> _ok(Object? data, String path) => Response<dynamic>(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );

void main() {
  late AppDatabase db;
  late _FakeDio dio;
  late _FakeDioClient dioClient;
  late _FakeStorage storage;
  late SyncService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dio = _FakeDio();
    dioClient = _FakeDioClient();
    storage = _FakeStorage();

    when(() => dioClient.dio).thenReturn(dio);
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);

    service = SyncService(
      dioClient: dioClient,
      database: db,
      storage: storage,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('push', () {
    test('envia categorias padrao e transacoes com categoria em texto',
        () async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: '1',
            name: 'Alimentação',
            color: 0xFFFF6B6B,
            icon: 'restaurant',
            isSynced: const Value(false),
          ));

      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-1',
              userId: 'user-1',
              amount: 42.5,
              description: 'Mercado',
              date: DateTime(2026, 11, 6),
              categoryId: const Value('1'),
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
              isSynced: const Value(false),
            ),
          );

      Map<String, dynamic>? sent;
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((invocation) async {
        sent = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _ok(
          {'data': {'synced': true, 'failedIds': <String>[]}},
          ApiEndpoints.sync,
        );
      });

      final outcome = await service.push();

      expect(outcome.offline, isFalse);
      expect(outcome.failed, 0);
      expect(sent, isNotNull);
      // A categoria padrao sobe com o id textual "1".
      expect((sent!['categories'] as List).first['id'], '1');
      // A transacao preserva o vinculo com a categoria.
      expect((sent!['transactions'] as List).first['categoryId'], '1');

      final pending = await (db.select(db.transactions)
            ..where((t) => t.isSynced.equals(false)))
          .get();
      expect(pending, isEmpty);
    });

    test('mantem pendente o que o servidor recusou', () async {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-bad',
              userId: 'user-1',
              amount: 1,
              description: 'Invalida',
              date: DateTime(2026, 11, 6),
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
            ),
          );

      when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => _ok(
          {
            'data': {
              'synced': false,
              'failedIds': ['tx-bad'],
            }
          },
          ApiEndpoints.sync,
        ),
      );

      final outcome = await service.push();

      expect(outcome.failed, 1);
      final pending = await (db.select(db.transactions)
            ..where((t) => t.isSynced.equals(false)))
          .get();
      expect(pending.map((t) => t.id), ['tx-bad']);
    });

    test('sem rede nao perde dados locais', () async {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-1',
              userId: 'user-1',
              amount: 3,
              description: 'Offline',
              date: DateTime(2026, 11, 6),
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
            ),
          );

      when(() => dio.post(any(), data: any(named: 'data'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.sync),
          type: DioExceptionType.connectionError,
        ),
      );

      final outcome = await service.push();

      expect(outcome.offline, isTrue);
      expect(await db.select(db.transactions).get(), hasLength(1));
    });

    test('modo convidado nunca envia nada', () async {
      when(() => storage.read(key: StorageKeys.isGuestMode))
          .thenAnswer((_) async => 'true');

      final outcome = await service.push();

      expect(outcome.skipped, isTrue);
      verifyNever(() => dio.post(any(), data: any(named: 'data')));
    });
  });

  group('restore', () {
    test('traz transacoes, categorias e planos do servidor', () async {
      final payload = {
        'data': {
          'transactions': [
            {
              'id': 'remote-1',
              'userId': 'user-1',
              'amount': 99.9,
              'description': 'Restaurada',
              'date': '2026-10-15T00:00:00.000Z',
              'categoryId': '1',
              'isExpense': true,
              'createdAt': '2026-10-15T00:00:00.000Z',
              'updatedAt': '2026-10-15T00:00:00.000Z',
            }
          ],
          'categories': [
            {
              'id': '1',
              'name': 'Alimentação',
              'color': 0xFFFF6B6B,
              'icon': 'restaurant',
              'isExpenseDefault': true,
              'sortOrder': 0,
            }
          ],
          'budgetPlans': [
            {
              'id': 'plan-1',
              'month': '2026-11-01T00:00:00.000Z',
              'scope': 'individual',
              'incomeMode': 'manual',
              'manualIncome': 5000,
              'monthlyBudget': 3000,
              'categories': const [],
              'notifications': const {},
              'createdAt': '2026-11-01T00:00:00.000Z',
              'updatedAt': '2026-11-01T00:00:00.000Z',
            }
          ],
        }
      };

      String? cache;
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async {
        return cache;
      });
      when(() => dio.get(any())).thenAnswer(
        (_) async => _ok(jsonDecode(jsonEncode(payload)), ApiEndpoints.sync),
      );

      final outcome = await service.restore();

      expect(outcome.pulled, 3);
      final transactions = await db.select(db.transactions).get();
      expect(transactions.single.description, 'Restaurada');
      expect(transactions.single.categoryId, '1');
      expect(await db.select(db.categories).get(), hasLength(1));
      expect(await db.select(db.budgetPlans).get(), hasLength(1));
    });

    test('onlyIfEmpty nao sobrepoe dados locais', () async {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'local-1',
              userId: 'user-1',
              amount: 10,
              description: 'Local',
              date: DateTime(2026, 11, 6),
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
            ),
          );

      final outcome = await service.restore(onlyIfEmpty: true);

      expect(outcome.skipped, isTrue);
      verifyNever(() => dio.get(any()));
    });

    test('respeita alteracoes locais ainda nao enviadas', () async {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-1',
              userId: 'user-1',
              amount: 10,
              description: 'Editada no celular',
              date: DateTime(2026, 11, 6),
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
              isSynced: const Value(false),
            ),
          );

      when(() => dio.get(any())).thenAnswer(
        (_) async => _ok(
          {
            'data': {
              'transactions': [
                {
                  'id': 'tx-1',
                  'amount': 10,
                  'description': 'Versao antiga',
                  'date': '2026-11-06T00:00:00.000Z',
                  'createdAt': '2026-11-06T00:00:00.000Z',
                  'updatedAt': '2026-11-06T00:00:00.000Z',
                }
              ],
            }
          },
          ApiEndpoints.sync,
        ),
      );

      await service.restore();

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals('tx-1')))
          .getSingle();
      expect(tx.description, 'Editada no celular');
    });

    test('nao ressuscita o que foi apagado offline', () async {
      await service.tombstone('transaction', 'tx-apagada');

      when(() => dio.get(any())).thenAnswer(
        (_) async => _ok(
          {
            'data': {
              'transactions': [
                {
                  'id': 'tx-apagada',
                  'amount': 5,
                  'description': 'Apagada',
                  'date': '2026-11-06T00:00:00.000Z',
                  'createdAt': '2026-11-06T00:00:00.000Z',
                  'updatedAt': '2026-11-06T00:00:00.000Z',
                }
              ],
            }
          },
          ApiEndpoints.sync,
        ),
      );

      await service.restore();

      expect(await db.select(db.transactions).get(), isEmpty);
    });
  });

  group('lembretes', () {
    test('envia reminderEnabled no push', () async {
      await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              id: 'tx-rem',
              userId: 'user-1',
              amount: 88,
              description: 'Conta de luz',
              date: DateTime(2026, 11, 20),
              createdAt: DateTime(2026, 11, 6),
              updatedAt: DateTime(2026, 11, 6),
              reminderEnabled: const Value(true),
            ),
          );

      Map<String, dynamic>? sent;
      when(() => dio.post(any(), data: any(named: 'data')))
          .thenAnswer((invocation) async {
        sent = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _ok(
          {'data': {'synced': true, 'failedIds': <String>[]}},
          ApiEndpoints.sync,
        );
      });

      await service.push();

      final json = (sent!['transactions'] as List).first as Map;
      expect(json['reminderEnabled'], isTrue);
    });

    test('restaura reminderEnabled vindo do servidor', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => _ok(
          {
            'data': {
              'transactions': [
                {
                  'id': 'tx-rem',
                  'amount': 88,
                  'description': 'Conta de luz',
                  'date': '2026-11-20T00:00:00.000Z',
                  'reminderEnabled': true,
                  'createdAt': '2026-11-06T00:00:00.000Z',
                  'updatedAt': '2026-11-06T00:00:00.000Z',
                }
              ],
            }
          },
          ApiEndpoints.sync,
        ),
      );

      await service.restore();

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals('tx-rem')))
          .getSingle();
      expect(tx.reminderEnabled, isTrue);
    });

    test('transacao sem lembrete continua valida', () async {
      when(() => dio.get(any())).thenAnswer(
        (_) async => _ok(
          {
            'data': {
              'transactions': [
                {
                  'id': 'tx-plain',
                  'amount': 10,
                  'description': 'Sem lembrete',
                  'date': '2026-11-06T00:00:00.000Z',
                  'createdAt': '2026-11-06T00:00:00.000Z',
                  'updatedAt': '2026-11-06T00:00:00.000Z',
                }
              ],
            }
          },
          ApiEndpoints.sync,
        ),
      );

      await service.restore();

      final tx = await (db.select(db.transactions)
            ..where((t) => t.id.equals('tx-plain')))
          .getSingle();
      expect(tx.reminderEnabled, isFalse);
    });
  });

  group('deletions', () {
    test('envia lapides e as remove quando o servidor confirma', () async {
      await service.tombstone('transaction', 'tx-1');

      when(() => dio.post(ApiEndpoints.syncDeletions,
              data: any(named: 'data')))
          .thenAnswer(
        (_) async => _ok(
          {
            'data': {'applied': 1, 'failed': <dynamic>[]}
          },
          ApiEndpoints.syncDeletions,
        ),
      );

      final applied = await service.push();

      expect(applied.pushed, 1);
      expect(await db.select(db.pendingDeletions).get(), isEmpty);
    });
  });
}
