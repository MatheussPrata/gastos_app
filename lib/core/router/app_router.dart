import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';
import 'package:gastos_app/features/auth/ui/pages/forgot_password_page.dart';
import 'package:gastos_app/features/auth/ui/pages/login_page.dart';
import 'package:gastos_app/features/auth/ui/pages/register_page.dart';
import 'package:gastos_app/features/auth/ui/pages/reset_password_page.dart';
import 'package:gastos_app/features/categories/ui/pages/categories_page.dart';
import 'package:gastos_app/features/categories/ui/pages/category_form_page.dart';
import 'package:gastos_app/features/navigation/ui/pages/main_shell_page.dart';
import 'package:gastos_app/features/recurring/ui/pages/recurring_form_page.dart';
import 'package:gastos_app/features/recurring/ui/pages/recurring_page.dart';
import 'package:gastos_app/features/sharing/ui/pages/sharing_page.dart';
import 'package:gastos_app/features/transactions/ui/pages/transaction_form_page.dart';
import 'package:gastos_app/features/transactions/ui/pages/transactions_page.dart';

/// Route names for type-safe navigation
class RouteNames {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String transactionForm = '/transactions/form';
  static const String categories = '/categories';
  static const String categoryForm = '/categories/form';
  static const String recurring = '/recurring';
  static const String recurringForm = '/recurring/form';
  static const String sharing = '/sharing';
}

/// GoRouter provider with auth state listening
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: RouteNames.dashboard,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == RouteNames.login ||
          state.matchedLocation == RouteNames.register ||
          state.matchedLocation == RouteNames.forgotPassword ||
          state.matchedLocation == RouteNames.resetPassword;

      // If not logged in and trying to access protected route -> redirect to login
      if (!isLoggedIn && !isAuthRoute) {
        return RouteNames.login;
      }

      // If logged in and on auth route -> redirect to dashboard
      if (isLoggedIn && isAuthRoute) {
        return RouteNames.dashboard;
      }

      return null;
    },
    routes: [
      // Auth routes (public)
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: RouteNames.resetPassword,
        builder: (context, state) => const ResetPasswordPage(),
      ),

      // Protected routes (require auth)
      // The main shell owns the four primary tabs and the bottom navigation.
      GoRoute(
        path: RouteNames.dashboard,
        builder: (context, state) => const MainShellPage(),
      ),

      // Secondary screens are pushed on top of the shell so the tab state and
      // scroll positions are preserved when the user comes back.
      GoRoute(
        path: RouteNames.transactions,
        builder: (context, state) => const TransactionsPage(),
        routes: [
          GoRoute(
            path: 'form',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return TransactionFormPage(
                transactionId: extra?['id'] as String?,
                isEditing: extra?['isEditing'] as bool? ?? false,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.categories,
        builder: (context, state) => const CategoriesPage(),
        routes: [
          GoRoute(
            path: 'form',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return CategoryFormPage(
                categoryId: extra?['id'] as String?,
                isEditing: extra?['isEditing'] as bool? ?? false,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.recurring,
        builder: (context, state) => const RecurringPage(),
        routes: [
          GoRoute(
            path: 'form',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return RecurringFormPage(
                recurringId: extra?['id'] as String?,
                isEditing: extra?['isEditing'] as bool? ?? false,
              );
            },
          ),
        ],
      ),

      GoRoute(
        path: RouteNames.sharing,
        builder: (context, state) => const SharingPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Página não encontrada'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.dashboard),
              child: const Text('Voltar ao Início'),
            ),
          ],
        ),
      ),
    ),
  );
});
