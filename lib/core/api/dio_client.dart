import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:gastos_app/core/api/endpoints.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  DioClient._internal();

  late final Dio dio;
  late final FlutterSecureStorage _storage;
  late final Connectivity _connectivity;

  void init({String baseUrl = 'https://pratadev.duckdns.org/api'}) {
    _storage = const FlutterSecureStorage();
    _connectivity = Connectivity();
    
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Configure HTTP client adapter for SSL certificate handling
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
      // Accept certificates for DuckDNS domain (pratadev.duckdns.org)
      // In production, use proper certificate pinning or valid certificates
      client.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Allow DuckDNS domain and localhost for development
        return host == 'pratadev.duckdns.org' || 
               host == 'localhost' || 
               host == '10.0.2.2' || 
               host == '127.0.0.1';
      };
      
      // Increase timeouts
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 15);
      
      return client;
    };

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Add interceptors
    dio.interceptors.addAll([
      _AuthInterceptor(this),
      _LoggingInterceptor(),
      _ErrorInterceptor(),
    ]);
  }

  // Helper to check connectivity
  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result.isNotEmpty && result.first != ConnectivityResult.none;
  }

  // Refresh the access token using the stored refresh token (sent as a cookie,
  // as the backend expects). Updates both tokens on success.
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await dio.post(
        ApiEndpoints.authRefresh,
        options: Options(headers: {'Cookie': 'refresh_token=$refreshToken'}),
      );

      if (response.statusCode == 200) {
        final data = response.data?['data'];
        if (data is Map<String, dynamic>) {
          final accessToken = data['accessToken'] as String?;
          final newRefreshToken = data['refreshToken'] as String?;
          if (accessToken != null && accessToken.isNotEmpty) {
            await _storage.write(key: StorageKeys.accessToken, value: accessToken);
            if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
              await _storage.write(key: StorageKeys.refreshToken, value: newRefreshToken);
            }
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }
}

class _AuthInterceptor extends Interceptor {
  final DioClient _client;
  _AuthInterceptor(this._client);

  static const _publicPaths = [
    '/health', '/ready', '/live',
    '/auth/login', '/auth/register', '/auth/refresh',
    '/auth/forgot-password', '/auth/reset-password',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isPublic = _publicPaths.any((path) => options.path.contains(path));
    if (!isPublic) {
      final accessToken = await _client._storage.read(key: StorageKeys.accessToken);
      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/auth/refresh')) {
      final refreshed = await _client.refreshToken();
      if (refreshed) {
        final accessToken = await _client._storage.read(key: StorageKeys.accessToken);
        err.requestOptions.headers['Authorization'] = 'Bearer $accessToken';
        try {
          final response = await Dio().fetch(err.requestOptions);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.next(err);
          return;
        }
      }
      await _client._storage.deleteAll();
    }
    handler.next(err);
  }

}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🌐 REQUEST: ${options.method} ${options.path}');
    if (options.data != null) print('📤 BODY: ${options.data}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('✅ RESPONSE: ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ ERROR: ${err.response?.statusCode} ${err.requestOptions.path}');
    if (err.response?.data != null) print('📥 ERROR BODY: ${err.response?.data}');
    handler.next(err);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Transform DioException into AppException
    String message;
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Tempo de conexão esgotado. Verifique sua internet.';
        break;
      case DioExceptionType.badResponse:
        final data = err.response?.data;
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        } else {
          message = 'Erro do servidor: ${err.response?.statusCode}';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Requisição cancelada';
        break;
      case DioExceptionType.connectionError:
        // Check if it's an SSL handshake error
        if (err.error is HandshakeException) {
          message = 'Erro de certificado SSL. Verifique se o certificado do servidor é válido.';
        } else {
          message = 'Sem conexão com o servidor. Verifique sua internet.';
        }
        break;
      default:
        message = 'Erro inesperado: ${err.message}';
    }
    err = DioException(
      requestOptions: err.requestOptions,
      error: message,
      type: err.type,
      response: err.response,
    );
    handler.next(err);
  }
}

// Exception classes for cleaner error handling
class AppException implements Exception {
  final String message;
  final int? statusCode;
  AppException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(String message) : super(message, statusCode: 401);
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message, statusCode: 0);
}

class ServerException extends AppException {
  ServerException(String message) : super(message, statusCode: 500);
}
