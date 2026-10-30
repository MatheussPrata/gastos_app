import 'package:dio/dio.dart';
import 'package:gastos_app/features/auth/models/auth_models.dart';

class ApiService {
  final Dio _dio;
  final String _baseUrl;

  ApiService(this._dio, {String baseUrl = 'http://10.0.2.2:8082'}) : _baseUrl = baseUrl;

  String get _url => _baseUrl;

  // ============ Auth endpoints ============
  Future<AuthResponse> login(String email, String password) async {
    final response = await _dio.post(
      '$_url/api/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(response.data['data']);
  }

  Future<User> getCurrentUser() async {
    final response = await _dio.get('$_url/api/auth/me');
    return User.fromJson(response.data['data']);
  }

  Future<AuthResponse> register({
    required String email,
    required String username,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _dio.post(
      '$_url/api/auth/register',
      data: {
        'email': email,
        'username': username,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return AuthResponse.fromJson(response.data['data']);
  }

  Future<void> logout() async {
    await _dio.post('$_url/api/auth/logout');
  }

  Future<void> refreshToken() async {
    await _dio.post('$_url/api/auth/refresh');
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(
      '$_url/api/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> resetPassword({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    await _dio.post(
      '$_url/api/auth/reset-password',
      data: {
        'token': token,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }

  // ============ Health endpoints ============
  Future<String> health() async {
    final response = await _dio.get('$_url/health');
    return response.data;
  }

  Future<String> ready() async {
    final response = await _dio.get('$_url/ready');
    return response.data;
  }

  Future<String> live() async {
    final response = await _dio.get('$_url/live');
    return response.data;
  }

  // ============ Sync endpoints ============
  Future<Map<String, dynamic>> sync(Map<String, dynamic> body) async {
    final response = await _dio.post('$_url/api/sync', data: body);
    return response.data;
  }

  Future<Map<String, dynamic>> syncStatus() async {
    final response = await _dio.get('$_url/api/sync/status');
    return response.data;
  }
}