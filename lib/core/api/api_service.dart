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
  Future<HttpResponse<AuthResponse>> register(@Body() Map<String, dynamic> body);

  @POST('/api/auth/login')
  Future<HttpResponse<AuthResponse>> login(@Body() Map<String, dynamic> body);

  @POST('/api/auth/refresh')
  Future<HttpResponse<AuthResponse>> refreshToken();

  @POST('/api/auth/logout')
  Future<void> logout();

  @POST('/api/auth/forgot-password')
  Future<void> forgotPassword(@Body() Map<String, dynamic> body);

  @POST('/api/auth/reset-password')
  Future<void> resetPassword(@Body() Map<String, dynamic> body);

  @GET('/api/auth/me')
  Future<HttpResponse<User>> getCurrentUser();

  // Health endpoints
  @GET('/health')
  Future<String> health();

  @GET('/ready')
  Future<String> ready();

  @GET('/live')
  Future<String> live();

  // Sync endpoints
  @POST('/api/sync')
  Future<void> sync(@Body() Map<String, dynamic> body);

  @GET('/api/sync/status')
  Future<String> syncStatus();

  // Transactions
  @GET('/api/transactions')
  Future<HttpResponse<List<Transaction>>> getTransactions({
    @Query('startDate') String? startDate,
    @Query('endDate') String? endDate,
    @Query('categoryId') String? categoryId,
    @Query('creditCardId') String? creditCardId,
    @Query('isExpense') bool? isExpense,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  });

  @POST('/api/transactions')
  Future<HttpResponse<Transaction>> createTransaction(@Body() Map<String, dynamic> body);

  @GET('/api/transactions/{id}')
  Future<HttpResponse<Transaction>> getTransaction(@Path('id') String id);

  @PUT('/api/transactions/{id}')
  Future<HttpResponse<Transaction>> updateTransaction(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/transactions/{id}')
  Future<void> deleteTransaction(@Path('id') String id);

  // Categories
  @GET('/api/categories')
  Future<HttpResponse<List<Category>>> getCategories();

  @POST('/api/categories')
  Future<HttpResponse<Category>> createCategory(@Body() Map<String, dynamic> body);

  @GET('/api/categories/{id}')
  Future<HttpResponse<Category>> getCategory(@Path('id') String id);

  @PUT('/api/categories/{id}')
  Future<HttpResponse<Category>> updateCategory(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/categories/{id}')
  Future<void> deleteCategory(@Path('id') String id);

  // Recurring Transactions
  @GET('/api/recurring')
  Future<HttpResponse<List<RecurringTransaction>>> getRecurring();

  @POST('/api/recurring')
  Future<HttpResponse<RecurringTransaction>> createRecurring(@Body() Map<String, dynamic> body);

  @GET('/api/recurring/{id}')
  Future<HttpResponse<RecurringTransaction>> getRecurringById(@Path('id') String id);

  @PUT('/api/recurring/{id}')
  Future<HttpResponse<RecurringTransaction>> updateRecurring(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/recurring/{id}')
  Future<void> deleteRecurring(@Path('id') String id);

  // Shopping Items
  @GET('/api/shopping')
  Future<HttpResponse<List<ShoppingItem>>> getShoppingItems();

  @POST('/api/shopping')
  Future<HttpResponse<ShoppingItem>> createShoppingItem(@Body() Map<String, dynamic> body);

  @GET('/api/shopping/{id}')
  Future<HttpResponse<ShoppingItem>> getShoppingItem(@Path('id') String id);

  @PUT('/api/shopping/{id}')
  Future<HttpResponse<ShoppingItem>> updateShoppingItem(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/shopping/{id}')
  Future<void> deleteShoppingItem(@Path('id') String id);

  // Settings
  @GET('/api/settings')
  Future<HttpResponse<List<AppSettings>>> getSettings();

  @POST('/api/settings')
  Future<HttpResponse<AppSettings>> saveSetting(@Body() Map<String, dynamic> body);

  // Backup
  @POST('/api/backup')
  Future<void> triggerBackup();
}