import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_flutter/core/api/dio_client.dart';
import 'package:gastos_flutter/core/database/app_database.dart' as db;
import 'package:gastos_flutter/features/auth/models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final database = ref.watch(db.databaseProvider);
  return AuthRepository(dioClient, database);
});

class AuthRepository {
  AuthRepository(this._dioClient, this._db);

  final DioClient _dioClient;
  final db.AppDatabase _db;

  Future<bool> isLoggedIn() async {
    // Implementação básica de verificação
    return false;
  }

  Future<User?> getStoredUser() async {
    return null;
  }

  Future<AuthResponse> getCurrentUser() async {
    return AuthResponse(isSuccess: false);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return AuthResponse(isSuccess: false);
  }

  Future<AuthResponse> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    return AuthResponse(isSuccess: false);
  }

  Future<void> logout() async {
    // Limpeza de cache/token
  }

  Future<AuthResponse> forgotPassword(String email) async {
    return AuthResponse(isSuccess: false);
  }

  Future<AuthResponse> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    return AuthResponse(isSuccess: false);
  }
}
