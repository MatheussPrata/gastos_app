/// API Endpoints constants
class ApiEndpoints {
  // Use server public IP for device/emulator testing
  static const String baseUrl = 'http://172.245.138.54:8082';
  
  // Auth endpoints
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';
  static const String authForgotPassword = '/api/auth/forgot-password';
  static const String authResetPassword = '/api/auth/reset-password';
  static const String authMe = '/api/auth/me';
  
  // Health endpoints
  static const String health = '/health';
  static const String ready = '/ready';
  static const String live = '/live';
  
  // Sync endpoints
  static const String sync = '/api/sync';
  static const String syncStatus = '/api/sync/status';
  
  // Transactions
  static const String transactions = '/api/transactions';
  static const String transactionsById = '/api/transactions/'; // + id
  static const String transactionsStats = '/api/transactions/stats';
  
  // Categories
  static const String categories = '/api/categories';
  static const String categoriesById = '/api/categories/'; // + id
  
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
}