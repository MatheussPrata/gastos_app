import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';
import 'package:gastos_flutter/features/auth/models/auth_models.dart';
import 'package:gastos_flutter/features/transactions/models/transaction_models.dart';
import 'package:gastos_flutter/features/categories/models/category_models.dart';
import 'package:gastos_flutter/features/recurring/models/recurring_models.dart';
import 'package:gastos_flutter/features/shopping/models/shopping_models.dart';
import 'package:gastos_flutter/features/settings/models/settings_models.dart';

part 'api_service.g.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  // Auth endpoints
  @POST('/api/auth/register')
  Future<HttpResponse<ApiResponse<AuthResponse>>> register(@Body() Map<String, dynamic> body);

  @POST('/api/auth/login')
  Future<HttpResponse<ApiResponse<AuthResponse>>> login(@Body() Map<String, dynamic> body);

  @POST('/api/auth/refresh')
  Future<HttpResponse<ApiResponse<AuthResponse>>> refreshToken();

  @POST('/api/auth/logout')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> logout();

  @POST('/api/auth/forgot-password')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> forgotPassword(@Body() Map<String, dynamic> body);

  @POST('/api/auth/reset-password')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> resetPassword(@Body() Map<String, dynamic> body);

  @GET('/api/auth/me')
  Future<HttpResponse<ApiResponse<User>>> getCurrentUser();

  // Health endpoints
  @GET('/health')
  Future<HttpResponse<Map<String, dynamic>>> health();

  @GET('/ready')
  Future<HttpResponse<Map<String, dynamic>>> ready();

  @GET('/live')
  Future<HttpResponse<Map<String, dynamic>>> live();

  // Sync endpoints
  @POST('/api/sync')
  Future<HttpResponse<ApiResponse<Map<String, dynamic>>>> sync(@Body() Map<String, dynamic> body);

  @GET('/api/sync/status')
  Future<HttpResponse<ApiResponse<Map<String, dynamic>>>> syncStatus();

  // Transactions
  @GET('/api/transactions')
  Future<HttpResponse<ApiResponse<List<Transaction>>>> getTransactions({
    @Query('startDate') String? startDate,
    @Query('endDate') String? endDate,
    @Query('categoryId') String? categoryId,
    @Query('creditCardId') String? creditCardId,
    @Query('isExpense') bool? isExpense,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  });

  @POST('/api/transactions')
  Future<HttpResponse<ApiResponse<Transaction>>> createTransaction(@Body() Map<String, dynamic> body);

  @GET('/api/transactions/{id}')
  Future<HttpResponse<ApiResponse<Transaction>>> getTransaction(@Path('id') String id);

  @PUT('/api/transactions/{id}')
  Future<HttpResponse<ApiResponse<Transaction>>> updateTransaction(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/transactions/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteTransaction(@Path('id') String id);

  @GET('/api/transactions/stats')
  Future<HttpResponse<ApiResponse<List<MonthlyStats>>>> getTransactionStats({
    @Query('months') int? months,
  });

  @GET('/api/transactions/categories')
  Future<HttpResponse<ApiResponse<List<CategoryExpense>>>> getExpensesByCategory({
    @Query('startDate') String? startDate,
    @Query('endDate') String? endDate,
  });

  // Categories
  @GET('/api/categories')
  Future<HttpResponse<ApiResponse<List<Category>>>> getCategories();

  @POST('/api/categories')
  Future<HttpResponse<ApiResponse<Category>>> createCategory(@Body() Map<String, dynamic> body);

  @GET('/api/categories/{id}')
  Future<HttpResponse<ApiResponse<Category>>> getCategory(@Path('id') String id);

  @PUT('/api/categories/{id}')
  Future<HttpResponse<ApiResponse<Category>>> updateCategory(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/categories/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteCategory(@Path('id') String id);

  // Credit Cards
  @GET('/api/credit-cards')
  Future<HttpResponse<ApiResponse<List<CreditCard>>>> getCreditCards();

  @POST('/api/credit-cards')
  Future<HttpResponse<ApiResponse<CreditCard>>> createCreditCard(@Body() Map<String, dynamic> body);

  @GET('/api/credit-cards/{id}')
  Future<HttpResponse<ApiResponse<CreditCard>>> getCreditCard(@Path('id') String id);

  @PUT('/api/credit-cards/{id}')
  Future<HttpResponse<ApiResponse<CreditCard>>> updateCreditCard(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/credit-cards/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteCreditCard(@Path('id') String id);

  // Recurring Transactions
  @GET('/api/recurring')
  Future<HttpResponse<ApiResponse<List<RecurringTransaction>>>> getRecurring();

  @POST('/api/recurring')
  Future<HttpResponse<ApiResponse<RecurringTransaction>>> createRecurring(@Body() Map<String, dynamic> body);

  @GET('/api/recurring/{id}')
  Future<HttpResponse<ApiResponse<RecurringTransaction>>> getRecurringById(@Path('id') String id);

  @PUT('/api/recurring/{id}')
  Future<HttpResponse<ApiResponse<RecurringTransaction>>> updateRecurring(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/recurring/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteRecurring(@Path('id') String id);

  // Shopping Items
  @GET('/api/shopping')
  Future<HttpResponse<ApiResponse<List<ShoppingItem>>>> getShoppingItems();

  @POST('/api/shopping')
  Future<HttpResponse<ApiResponse<ShoppingItem>>> createShoppingItem(@Body() Map<String, dynamic> body);

  @GET('/api/shopping/{id}')
  Future<HttpResponse<ApiResponse<ShoppingItem>>> getShoppingItem(@Path('id') String id);

  @PUT('/api/shopping/{id}')
  Future<HttpResponse<ApiResponse<ShoppingItem>>> updateShoppingItem(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/shopping/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteShoppingItem(@Path('id') String id);

  // Settings
  @GET('/api/settings')
  Future<HttpResponse<ApiResponse<List<AppSettings>>>> getSettings();

  @POST('/api/settings')
  Future<HttpResponse<ApiResponse<AppSettings>>> saveSetting(@Body() Map<String, dynamic> body);

  // Backup
  @POST('/api/backup')
  Future<HttpResponse<ApiResponse<Map<String, dynamic>>>> triggerBackup();
}