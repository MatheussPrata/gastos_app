import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../../features/auth/ui/pages/login_page.dart';
import '../../features/auth/ui/pages/register_page.dart';
import '../../features/auth/ui/pages/forgot_password_page.dart';
import '../../features/auth/ui/pages/reset_password_page.dart';
import '../../features/dashboard/ui/pages/dashboard_page.dart';
import '../../features/transactions/ui/pages/transactions_page.dart';
import '../../features/transactions/ui/pages/transaction_form_page.dart';
import '../../features/categories/ui/pages/categories_page.dart';
import '../../features/categories/ui/pages/category_form_page.dart';
import '../../features/recurring/ui/pages/recurring_page.dart';
import '../../features/recurring/ui/pages/recurring_form_page.dart';
import '../../features/shopping/ui/pages/shopping_page.dart';
import '../../features/shopping/ui/pages/shopping_form_page.dart';
import '../../features/settings/ui/pages/settings_page.dart';
import 'package:gastos_app/features/auth/provider/auth_provider.dart';

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
  static const String shopping = '/shopping';
  static const String shoppingForm = '/shopping/form';
  static const String settings = '/settings';
}

/// GoRouter provider with auth state listening
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: RouteNames.dashboard,
    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == RouteNames.login || 
                          state.matchedLocation == RouteNames.register;
      
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
      GoRoute(
        path: RouteNames.dashboard,
        builder: (context, state) => const DashboardPage(),
      ),
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
                isEditing: extra?['isEditing'] ?? false,
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
                isEditing: extra?['isEditing'] ?? false,
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
                isEditing: extra?['isEditing'] ?? false,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.shopping,
        builder: (context, state) => const ShoppingPage(),
        routes: [
          GoRoute(
            path: 'form',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return ShoppingFormPage(
                itemId: extra?['id'] as String?,
                isEditing: extra?['isEditing'] ?? false,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Página não encontrada'),
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