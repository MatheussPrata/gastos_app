import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/features/auth/repository/auth_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockDioClient extends Mock implements DioClient {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockDio dio;
  late _MockDioClient dioClient;
  late _MockStorage storage;
  late AuthRepository repository;

  setUp(() {
    dio = _MockDio();
    dioClient = _MockDioClient();
    storage = _MockStorage();

    when(() => dioClient.dio).thenReturn(dio);
    when(() => storage.deleteAll()).thenAnswer((_) async {});

    repository = AuthRepository(dioClient: dioClient, storage: storage);
  });

  group('AuthRepository.deleteAccount', () {
    test('chama DELETE /auth/me e limpa storage quando autenticado', () async {
      when(() => storage.read(key: StorageKeys.isGuestMode))
          .thenAnswer((_) async => null);
      when(() => dio.delete(ApiEndpoints.authMe)).thenAnswer(
        (_) async => Response<dynamic>(
          statusCode: 200,
          data: {'success': true},
          requestOptions: RequestOptions(path: ApiEndpoints.authMe),
        ),
      );

      final result = await repository.deleteAccount();

      expect(result.isSuccess, isTrue);
      verify(() => dio.delete(ApiEndpoints.authMe)).called(1);
      verify(() => storage.deleteAll()).called(1);
    });

    test('apenas limpa storage local quando em modo convidado', () async {
      when(() => storage.read(key: StorageKeys.isGuestMode))
          .thenAnswer((_) async => 'true');

      final result = await repository.deleteAccount();

      expect(result.isSuccess, isTrue);
      verifyNever(() => dio.delete(any()));
      verify(() => storage.deleteAll()).called(1);
    });

    test('nao limpa storage e retorna erro se falhar no servidor', () async {
      when(() => storage.read(key: StorageKeys.isGuestMode))
          .thenAnswer((_) async => null);
      when(() => dio.delete(ApiEndpoints.authMe)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ApiEndpoints.authMe),
          error: 'Sem conexão com o servidor.',
          type: DioExceptionType.connectionError,
        ),
      );

      final result = await repository.deleteAccount();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Sem conexão'));
      verifyNever(() => storage.deleteAll());
    });
  });
}
