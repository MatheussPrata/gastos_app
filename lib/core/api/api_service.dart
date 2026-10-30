import 'package:retrofit/retrofit.dart';
import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gastos_flutter/features/auth/models/auth_models.dart';
import 'package:gastos_flutter/features/transactions/models/transaction_models.dart' as txn_models;
import 'package:gastos_flutter/features/categories/models/category_models.dart' as cat_models;
import 'package:gastos_flutter/features/recurring/models/recurring_models.dart' as rec_models;
import 'package:gastos_flutter/features/shopping/models/shopping_models.dart' as shop_models;
import 'package:gastos_flutter/features/settings/models/settings_models.dart' as set_models;

part 'api_service.g.dart';
part 'api_service.freezed.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  // ============ Auth endpoints ============
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

  // ============ Health endpoints ============
  @GET('/health')
  Future<HttpResponse<String>> health();

  @GET('/ready')
  Future<HttpResponse<String>> ready();

  @GET('/live')
  Future<HttpResponse<String>> live();

  // ============ Sync endpoints ============
  @POST('/api/sync')
  Future<HttpResponse<ApiResponse<Map<String, dynamic>>>> sync(@Body() Map<String, dynamic> body);

  @GET('/api/sync/status')
  Future<HttpResponse<ApiResponse<Map<String, dynamic>>>> syncStatus();

  // ============ Transactions ============
  @GET('/api/transactions')
  Future<HttpResponse<ApiResponse<List<txn_models.Transaction>>>> getTransactions({
    @Query('startDate') String? startDate,
    @Query('endDate') String? endDate,
    @Query('categoryId') String? categoryId,
    @Query('creditCardId') String? creditCardId,
    @Query('isExpense') bool? isExpense,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
  });

  @POST('/api/transactions')
  Future<HttpResponse<ApiResponse<txn_models.Transaction>>> createTransaction(@Body() Map<String, dynamic> body);

  @GET('/api/transactions/{id}')
  Future<HttpResponse<ApiResponse<txn_models.Transaction>>> getTransaction(@Path('id') String id);

  @PUT('/api/transactions/{id}')
  Future<HttpResponse<ApiResponse<txn_models.Transaction>>> updateTransaction(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/transactions/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteTransaction(@Path('id') String id);

  @GET('/api/transactions/stats')
  Future<HttpResponse<ApiResponse<List<txn_models.MonthlyStats>>>> getTransactionStats({
    @Query('months') int? months,
  });

  @GET('/api/transactions/categories')
  Future<HttpResponse<ApiResponse<List<txn_models.CategoryExpense>>>> getExpensesByCategory({
    @Query('startDate') String? startDate,
    @Query('endDate') String? endDate,
  });

  // ============ Categories ============
  @GET('/api/categories')
  Future<HttpResponse<ApiResponse<List<cat_models.Category>>>> getCategories();

  @POST('/api/categories')
  Future<HttpResponse<ApiResponse<cat_models.Category>>> createCategory(@Body() Map<String, dynamic> body);

  @GET('/api/categories/{id}')
  Future<HttpResponse<ApiResponse<cat_models.Category>>> getCategory(@Path('id') String id);

  @PUT('/api/categories/{id}')
  Future<HttpResponse<ApiResponse<cat_models.Category>>> updateCategory(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/categories/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteCategory(@Path('id') String id);

  // ============ Credit Cards ============
  @GET('/api/credit-cards')
  Future<HttpResponse<ApiResponse<List<txn_models.CreditCard>>>> getCreditCards();

  @POST('/api/credit-cards')
  Future<HttpResponse<ApiResponse<txn_models.CreditCard>>> createCreditCard(@Body() Map<String, dynamic> body);

  @GET('/api/credit-cards/{id}')
  Future<HttpResponse<ApiResponse<txn_models.CreditCard>>> getCreditCard(@Path('id') String id);

  @PUT('/api/credit-cards/{id}')
  Future<HttpResponse<ApiResponse<txn_models.CreditCard>>> updateCreditCard(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/credit-cards/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteCreditCard(@Path('id') String id);

  // ============ Recurring Transactions ============
  @GET('/api/recurring')
  Future<HttpResponse<ApiResponse<List<rec_models.RecurringTransaction>>>> getRecurring();

  @POST('/api/recurring')
  Future<HttpResponse<ApiResponse<rec_models.RecurringTransaction>>> createRecurring(@Body() Map<String, dynamic> body);

  @GET('/api/recurring/{id}')
  Future<HttpResponse<ApiResponse<rec_models.RecurringTransaction>>> getRecurringById(@Path('id') String id);

  @PUT('/api/recurring/{id}')
  Future<HttpResponse<ApiResponse<rec_models.RecurringTransaction>>> updateRecurring(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/recurring/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteRecurring(@Path('id') String id);

  // ============ Shopping Items ============
  @GET('/api/shopping')
  Future<HttpResponse<ApiResponse<List<shop_models.ShoppingItem>>>> getShoppingItems();

  @POST('/api/shopping')
  Future<HttpResponse<ApiResponse<shop_models.ShoppingItem>>> createShoppingItem(@Body() Map<String, dynamic> body);

  @GET('/api/shopping/{id}')
  Future<HttpResponse<ApiResponse<shop_models.ShoppingItem>>> getShoppingItem(@Path('id') String id);

  @PUT('/api/shopping/{id}')
  Future<HttpResponse<ApiResponse<shop_models.ShoppingItem>>> updateShoppingItem(@Path('id') String id, @Body() Map<String, dynamic> body);

  @DELETE('/api/shopping/{id}')
  Future<HttpResponse<ApiResponse<EmptyResponse>>> deleteShoppingItem(@Path('id') String id);

  // ============ Settings ============
  @GET('/api/settings')
  Future<HttpResponse<ApiResponse<List<set_models.AppSettings>>>> getSettings();

  @POST('/api/settings')
  Future<HttpResponse<ApiResponse<set_models.AppSettings>>> saveSetting(@Body() Map<String, dynamic> body);

  // ============ Backup ============
  @POST('/api/backup')
  Future<HttpResponse<ApiResponse<Map<String, dynamic>>>> triggerBackup();
}

@freezed
class EmptyResponse with _$EmptyResponse {
  const factory EmptyResponse() = _EmptyResponse;
  factory EmptyResponse.fromJson(Map<String, dynamic> json) => _$EmptyResponseFromJson(json);
}