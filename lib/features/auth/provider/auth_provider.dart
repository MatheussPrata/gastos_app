import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_app/core/api/api_providers.dart';
import 'package:gastos_app/core/database/database_providers.dart';
import 'package:gastos_app/features/auth/models/auth_models.dart';
import 'package:gastos_app/features/auth/repository/auth_repository.dart';

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final database = ref.watch(databaseProvider);
  return AuthRepository(apiService: apiService, database: database);
});

/// Auth state
class AuthState {
  final bool isAuthenticated;
  final User? user;
  final String? accessToken;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.accessToken,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    User? user,
    String? accessToken,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Auth state notifier
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _repository.getStoredUser();
        final token = await _repository.getAccessToken();
        state = state.copyWith(
          isAuthenticated: true,
          user: user,
          accessToken: token,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<ApiResponse<AuthResponse>> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.login(email: email, password: password);
    
    if (result.isSuccess && result.data != null) {
      final user = await _repository.getStoredUser();
      final token = await _repository.getAccessToken();
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        accessToken: token,
        isLoading: false,
        error: null,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.message);
    }
    return result;
  }

  Future<ApiResponse<AuthResponse>> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _repository.register(
      email: email,
      username: username,
      password: password,
      confirmPassword: confirmPassword,
    );
    
    if (result.isSuccess && result.data != null) {
      final user = await _repository.getStoredUser();
      final token = await _repository.getAccessToken();
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        accessToken: token,
        isLoading: false,
        error: null,
      );
    } else {
      state = state.copyWith(isLoading: false, error: result.message);
    }
    return result;
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }

  Future<ApiResponse<void>> forgotPassword(String email) async {
    return _repository.forgotPassword(email);
  }

  Future<ApiResponse<void>> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    return _repository.resetPassword(
      token: token,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  Future<void> refreshUser() async {
    final user = await _repository.getStoredUser();
    final token = await _repository.getAccessToken();
    state = state.copyWith(user: user, accessToken: token);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth controller provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Auth state provider (for router)
final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authControllerProvider);
});