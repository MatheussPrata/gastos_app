import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gastos_app/core/api/api_service.dart';
import 'package:gastos_app/core/api/endpoints.dart';
import 'package:gastos_app/core/database/app_database.dart' as db;
import 'package:gastos_app/features/auth/models/auth_models.dart';

class AuthRepository {
  final ApiService _apiService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final db.AppDatabase _db;

  AuthRepository({required ApiService apiService, required db.AppDatabase database})
      : _apiService = apiService,
        _db = database;

  /// Register a new user
  Future<ApiResponse<AuthResponse>> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final authResponse = await _apiService.register(
        email: email,
        username: username,
        password: password,
        confirmPassword: confirmPassword,
      );
      
      await _saveAuthData(authResponse);
      return ApiResponse.success(data: authResponse);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Login user
  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final authResponse = await _apiService.login(email, password);
      
      await _saveAuthData(authResponse);
      return ApiResponse.success(data: authResponse);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      await _apiService.refreshToken();
      return true;
    } catch (_) {}
    return false;
  }

  /// Get current user profile
  Future<ApiResponse<User>> getCurrentUser() async {
    try {
      final user = await _apiService.getCurrentUser();

      // Update local cache
      await _db.upsertUser(db.UsersCompanion(
        id: Value(user.id),
        email: Value(user.email),
        username: Value(user.username),
        createdAt: Value(user.createdAt),
        updatedAt: Value(user.updatedAt),
        isActive: Value(user.isActive),
        isAdmin: Value(user.isAdmin),
      ));

      return ApiResponse.success(data: user);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {}
    await _clearAuthData();
  }

  /// Forgot password
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      await _apiService.forgotPassword(email);
      return ApiResponse.success(data: null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Reset password
  Future<ApiResponse<void>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      await _apiService.resetPassword(
        token: token,
        password: password,
        confirmPassword: confirmPassword,
      );
      return ApiResponse.success(data: null);
    } on DioException catch (e) {
      return _handleDioError(e);
    }
  }

  /// Save auth data to secure storage and local DB
  Future<void> _saveAuthData(AuthResponse auth) async {
    await _storage.write(key: StorageKeys.accessToken, value: auth.accessToken);
    await _storage.write(key: StorageKeys.userId, value: auth.user.id);
    await _storage.write(key: StorageKeys.userEmail, value: auth.user.email);
    await _storage.write(key: StorageKeys.username, value: auth.user.username);
    
    // Save user to local DB
    await _db.upsertUser(db.UsersCompanion(
      id: Value(auth.user.id),
      email: Value(auth.user.email),
      username: Value(auth.user.username),
      createdAt: Value(auth.user.createdAt),
      updatedAt: Value(auth.user.updatedAt),
      isActive: Value(auth.user.isActive),
      isAdmin: Value(auth.user.isAdmin),
    ));
  }

  /// Clear all auth data
  Future<void> _clearAuthData() async {
    await _storage.deleteAll();
    await _db.clearAllData();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  /// Get stored user
  Future<User?> getStoredUser() async {
    final userData = await _db.getCurrentUser();
    if (userData != null) {
      return User(
        id: userData.id,
        email: userData.email,
        username: userData.username,
        createdAt: userData.createdAt,
        updatedAt: userData.updatedAt,
        isActive: userData.isActive,
        isAdmin: userData.isAdmin,
      );
    }
    return null;
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    return _storage.read(key: StorageKeys.accessToken);
  }

  /// Save guest user (offline only)
  Future<void> saveGuestUser(User user) async {
    await _db.upsertUser(db.UsersCompanion(
      id: Value(user.id),
      email: Value(user.email),
      username: Value(user.username),
      createdAt: Value(user.createdAt),
      updatedAt: Value(user.updatedAt),
      isActive: Value(user.isActive),
      isAdmin: Value(user.isAdmin),
    ));
    
    // Save guest token to secure storage
    await _storage.write(key: StorageKeys.accessToken, value: 'guest_token');
    await _storage.write(key: StorageKeys.userId, value: user.id);
    await _storage.write(key: StorageKeys.userEmail, value: user.email);
    await _storage.write(key: StorageKeys.username, value: user.username);
  }

  ApiResponse<T> _handleDioError<T>(DioException e) {
    String message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Tempo de conexão esgotado. Verifique sua internet.';
        break;
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else {
          message = 'Erro do servidor: ${e.response?.statusCode}';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Requisição cancelada';
        break;
      case DioExceptionType.connectionError:
        message = 'Sem conexão com o servidor. Verifique sua internet.';
        break;
      default:
        message = 'Erro inesperado: ${e.message}';
    }
    return ApiResponse.error(message: message);
  }
}