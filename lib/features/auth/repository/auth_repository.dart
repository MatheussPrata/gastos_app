import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gastos_app/core/api/dio_client.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/features/auth/models/auth_models.dart';

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
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.authRegister,
        data: {
          'email': email,
          'username': username,
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );
      return _handleAuthResponse(response);
    } on DioException catch (e) {
      return ApiResponse.error(message: _formatDioError(e));
    } catch (e) {
      return ApiResponse.error(message: 'Erro inesperado: $e');
    }
  }

  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.authLogin,
        data: {'email': email, 'password': password},
      );
      return _handleAuthResponse(response);
    } on DioException catch (e) {
      return ApiResponse.error(message: _formatDioError(e));
    } catch (e) {
      return ApiResponse.error(message: 'Erro inesperado: $e');
    }
  }

  /// Creates a local guest session WITHOUT any network call.
  /// Use for offline/guest mode - data stays local only.
  Future<ApiResponse<AuthResponse>> guestLogin() async {
    try {
      // Generate a local guest user ID
      final guestUserId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      final guestEmail = 'guest_$guestUserId@local';
      final guestUsername = 'Convidado_${guestUserId.substring(guestUserId.length - 4)}';

      // Create a mock AuthResponse for local session
      final authResponse = AuthResponse(
        accessToken: 'guest_token_$guestUserId',
        refreshToken: 'guest_refresh_$guestUserId',
        user: User(
          id: guestUserId,
          email: guestEmail,
          username: guestUsername,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Persist locally only - NO network call
      await _persistGuestSession(authResponse);

      return ApiResponse.success(
        data: authResponse,
        message: 'Modo convidado ativado (offline)',
      );
    } catch (e) {
      return ApiResponse.error(message: 'Erro inesperado: $e');
    }
  }

  Future<void> _persistGuestSession(AuthResponse authResponse) async {
    await _storage.write(key: StorageKeys.accessToken, value: authResponse.accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: authResponse.refreshToken);
    await _storage.write(key: StorageKeys.userId, value: authResponse.user.id);
    await _storage.write(key: StorageKeys.userEmail, value: authResponse.user.email);
    await _storage.write(key: StorageKeys.username, value: authResponse.user.username);
    // Mark as guest mode
    await _storage.write(key: StorageKeys.isGuestMode, value: 'true');
  }

  Future<ApiResponse<AuthResponse>> _handleAuthResponse(Response response) async {
    final body = response.data;
    if (body is Map<String, dynamic> && body['data'] is Map<String, dynamic>) {
      final authResponse = AuthResponse.fromJson(body['data'] as Map<String, dynamic>);
      await _persistSession(authResponse);
      return ApiResponse.success(
        data: authResponse,
        message: body['message'] as String?,
      );
    }
    return const ApiResponse.error(message: 'Resposta inválida do servidor');
  }

  Future<void> _persistSession(AuthResponse authResponse) async {
    await _storage.write(key: StorageKeys.accessToken, value: authResponse.accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: authResponse.refreshToken);
    await _storage.write(key: StorageKeys.userId, value: authResponse.user.id);
    await _storage.write(key: StorageKeys.userEmail, value: authResponse.user.email);
    await _storage.write(key: StorageKeys.username, value: authResponse.user.username);
  }

  String _formatDioError(DioException e) {
    final buffer = StringBuffer();
    buffer.writeln('DioException: ${e.type.name}');
    if (e.response != null) {
      buffer.writeln('Status: ${e.response?.statusCode}');
      buffer.writeln('Response: ${e.response?.data}');
    }
    if (e.message != null && e.message!.isNotEmpty) {
      buffer.writeln('Message: ${e.message}');
    }
    if (e.error != null) {
      buffer.writeln('Error: ${e.error}');
    }
    return buffer.toString();
  }

  Future<bool> refreshToken() => _dioClient.refreshToken();

  Future<ApiResponse<User>> getCurrentUser() async {
    final user = await getStoredUser();
    if (user != null) {
      return ApiResponse.success(data: user);
    }
    return const ApiResponse.error(message: 'Utilizador não encontrado');
  }

  Future<void> logout() async {
    try {
      final isGuest = await isGuestMode();
      if (!isGuest) {
        final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
        await _dioClient.dio.post(
          ApiEndpoints.authLogout,
          data: {'refreshToken': refreshToken ?? ''},
        );
      }
    } catch (_) {
      // Best effort: always clear the local session even if the network call fails.
    }
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

  /// Check if current session is in guest/offline mode
  Future<bool> isGuestMode() async {
    final guestMode = await _storage.read(key: StorageKeys.isGuestMode);
    return guestMode == 'true';
  }
}
