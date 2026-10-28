import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_flutter/features/auth/models/auth_models.dart';
import 'package:gastos_flutter/features/auth/repository/auth_repository.dart';
import 'package:gastos_flutter/core/api/api_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Auth state enum
enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  loading,
}

/// Auth state class
@immutable
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// Auth controller
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    
    final isLoggedIn = await _repository.isLoggedIn();
    if (isLoggedIn) {
      final user = await _repository.getStoredUser();
      if (user != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      } else {
        // Try to fetch from server
        final result = await _repository.getCurrentUser();
        if (result.isSuccess && result.data != null) {
          state = state.copyWith(status: AuthStatus.authenticated, user: result.data);
        } else {
          state = state.copyWith(status: AuthStatus.unauthenticated);
        }
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    
    final result = await _repository.login(email: email, password: ***);
    
    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.data!.user,
        error: null,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: result.message ?? 'Erro ao fazer login',
      );
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    
    final result = await _repository.register(
      email: email,
      username: username,
      password: ***,
      confirmPassword: confirmPassword,
    );
    
    if (result.isSuccess && result.data != null) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: result.data!.user,
        error: null,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: result.message ?? 'Erro ao registrar',
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> forgotPassword(String email) async {
    final result = await _repository.forgotPassword(email);
    if (!result.isSuccess) {
      state = state.copyWith(error: result.message);
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    
    final result = await _repository.resetPassword(
      token: ***,
      password: ***,
      confirmPassword: confirmPassword,
    );
    
    if (!result.isSuccess) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: result.message ?? 'Erro ao redefinir senha',
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Convenience provider for auth status
final authStateProvider = Provider<AuthState>((ref) => ref.watch(authControllerProvider));

/// Provider for current user
final currentUserProvider = Provider<User?>((ref) => ref.watch(authControllerProvider).user);

/// Provider for auth status check
final isAuthenticatedProvider = Provider<bool>((ref) => ref.watch(authControllerProvider).isAuthenticated);
