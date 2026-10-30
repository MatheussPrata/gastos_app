import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/features/auth/models/auth_models.dart';
import 'package:gastos_app/features/auth/repository/auth_repository.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
  loading,
}

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

    try {
      final result = await _repository.login(email: email, password: password);
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
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
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

    try {
      final result = await _repository.register(
        email: email,
        username: username,
        password: password,
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
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _repository.forgotPassword(email);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      await _repository.resetPassword(
        token: token,
        password: password,
        confirmPassword: confirmPassword,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
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

final authStateProvider = Provider<AuthState>((ref) => ref.watch(authControllerProvider));
final currentUserProvider = Provider<User?>((ref) => ref.watch(authControllerProvider).user);
final isAuthenticatedProvider = Provider<bool>((ref) => ref.watch(authControllerProvider).isAuthenticated);