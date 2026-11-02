/// API Endpoints constants
class ApiEndpoints {
  static const String baseUrl = 'https://pratadev.duckdns.org/api';
  
  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authResetPassword = '/auth/auth/reset-password';
  static const String authMe = '/auth/me';
  
  // Health endpoints
  static const String health = '/health';
  static const String ready = '/ready';
  static const String live = '/live';
  
  // Sync endpoints
  static const String sync = '/sync';
  static const String syncStatus = '/sync/status';
  
  // Transactions (baseUrl already includes /api)
  static const String transactions = '/transactions';
  static const String transactionsById = '/transactions/'; // + id
  static const String transactionsStats = '/transactions/stats';
  
  // Categories
  static const String categories = '/categories';
  static const String categoriesById = '/categories/'; // + id
  
  // Credit Cards
  static const String creditCards = '/api/credit-cards';
  static const String creditCardsById = '/api/credit-cards/'; // + id
  
  // Recurring
  static const String recurring = '/api/recurring';
  static const String recurringById = '/api/recurring/'; // + id
  
  // Shopping
  static const String shopping = '/api/shopping';
  static const String shoppingById = '/api/shopping/'; // + id
  
  // Settings
  static const String settings = '/api/settings';
  
  // Backup
  static const String backup = '/api/backup';
}

// Storage keys
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String username = 'username';
  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String currency = 'currency';
  static const String firstLaunch = 'first_launch';
  static const String biometricEnabled = 'biometric_enabled';
  static const String isGuestMode = 'is_guest_mode';
}
