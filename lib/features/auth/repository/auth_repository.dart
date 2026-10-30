import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/features/auth/models/auth_models.dart';

abstract class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String username = 'username';
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(dioClient: DioClient());
});

class AuthRepository {
  final DioClient _dioClient;
  final FlutterSecureStorage _storage;

  AuthRepository({
    DioClient? dioClient,
    FlutterSecureStorage? storage,
  })  : _dioClient = dioClient ?? DioClient(),
        _storage = storage ?? const FlutterSecureStorage();

  DioClient get dioClient => _dioClient;

  Future<ApiResponse<AuthResponse>> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    return const ApiResponse.error(message: 'Registo pendente de configuração da API');
  }

  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    return const ApiResponse.error(message: 'Login pendente de configuração da API');
  }

  Future<bool> refreshToken() async {
    final token = await _storage.read(key: StorageKeys.refreshToken);
    return token != null && token.isNotEmpty;
  }

  Future<ApiResponse<User>> getCurrentUser() async {
    final user = await getStoredUser();
    if (user != null) {
      return ApiResponse.success(data: user);
    }
    return const ApiResponse.error(message: 'Utilizador não encontrado');
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<ApiResponse<void>> forgotPassword(String email) async {
    return const ApiResponse.success(data: null);
  }

  Future<ApiResponse<void>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    return const ApiResponse.success(data: null);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  Future<User?> getStoredUser() async {
    final userId = await _storage.read(key: StorageKeys.userId);
    final email = await _storage.read(key: StorageKeys.userEmail);
    final username = await _storage.read(key: StorageKeys.username);

    if (userId != null && email != null && username != null) {
      return User(
        id: userId,
        email: email,
        username: username,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    return null;
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: StorageKeys.accessToken);
  }
}