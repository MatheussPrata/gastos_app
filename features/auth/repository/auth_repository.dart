import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gastos_flutter/core/api/dio_client.dart';
import 'package:gastos_flutter/core/api/endpoints.dart';
import 'package:gastos_flutter/core/database/app_database.dart';
import 'package:gastos_flutter/features/auth/models/auth_models.dart';

class AuthRepository {
  final DioClient _dioClient = DioClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AppDatabase _db = AppDatabase();

  /// Register a new user
  Future<ApiResponse<AuthResponse>> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final request = RegisterRequest(
        email: email,
        username: username,
        password: password,
        confirmPassword: confirmPassword,
      );

      final response = await _dioClient.dio.post(
        ApiEndpoints.authRegister,
        data: request.toJson(),
      );

      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        await _saveAuthData(apiResponse.data!);
      }

      return apiResponse;
    } on DioException catch (e) {
      return ApiResponse.error(message: e.error?.toString() ?? 'Erro ao registrar');
    }
  }

  /// Login user
  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    try {
      final request = LoginRequest(email: email, password: password);

      final response = await _dioClient.dio.post(
        ApiEndpoints.authLogin,
        data: request.toJson(),
      );

      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        await _saveAuthData(apiResponse.data!);
      }

      return apiResponse;
    } on DioException catch (e) {
      return ApiResponse.error(message: e.error?.toString() ?? 'Erro ao fazer login');
    }
  }

  /// Refresh access token
  Future<bool> refreshToken() async {
    try {
      final response = await _dioClient.dio.post(ApiEndpoints.authRefresh);
      
      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data,
          (json) => AuthResponse.fromJson(json as Map<String, dynamic>),
        );
        
        if (apiResponse.isSuccess && apiResponse.data != null) {
          await _storage.write(key: StorageKeys.accessToken, value: apiResponse.data!.accessToken);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Get current user profile
  Future<ApiResponse<User>> getCurrentUser() async {
    try {
      final response = await _dioClient.dio.get(ApiEndpoints.authMe);
      
      final apiResponse = ApiResponse.fromJson(
        response.data,
        (json) => User.fromJson(json as Map<String, dynamic>),
      );

      if (apiResponse.isSuccess && apiResponse.data != null) {
        // Update local cache
        await _db.upsertUser(UsersCompanion(
          id: Value(apiResponse.data!.id),
          email: Value(apiResponse.data!.email),
          username: Value(apiResponse.data!.username),
          createdAt: Value(apiResponse.data!.createdAt),
          updatedAt: Value(apiResponse.data!.updatedAt),
          isActive: Value(apiResponse.data!.isActive),
          isAdmin: Value(apiResponse.data!.isAdmin),
        ));
      }

      return apiResponse;
    } on DioException catch (e) {
      return ApiResponse.error(message: e.error?.toString() ?? 'Erro ao buscar usuário');
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiEndpoints.authLogout);
    } catch (_) {}
    await _clearAuthData();
  }

  /// Forgot password
  Future<ApiResponse<void>> forgotPassword(String email) async {
    try {
      final request = ForgotPasswordRequest(email: email);
      final response = await _dioClient.dio.post(
        ApiEndpoints.authForgotPassword,
        data: request.toJson(),
      );
      
      return ApiResponse.fromJson(
        response.data,
        (_) => null,
      );
    } on DioException catch (e) {
      return ApiResponse.error(message: e.error?.toString() ?? 'Erro ao solicitar recuperação');
    }
  }

  /// Reset password
  Future<ApiResponse<void>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final request = ResetPasswordRequest(
        token: token,
        password: password,
        confirmPassword: confirmPassword,
      );
      
      final response = await _dioClient.dio.post(
        ApiEndpoints.authResetPassword,
        data: request.toJson(),
      );
      
      return ApiResponse.fromJson(
        response.data,
        (_) => null,
      );
    } on DioException catch (e) {
      return ApiResponse.error(message: e.error?.toString() ?? 'Erro ao redefinir senha');
    }
  }

  /// Save auth data to secure storage and local DB
  Future<void> _saveAuthData(AuthResponse auth) async {
    await _storage.write(key: StorageKeys.accessToken, value: auth.accessToken);
    await _storage.write(key: StorageKeys.userId, value: auth.user.id);
    await _storage.write(key: StorageKeys.userEmail, value: auth.user.email);
    await _storage.write(key: StorageKeys.username, value: auth.user.username);
    
    // Save user to local DB
    await _db.upsertUser(UsersCompanion(
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
}