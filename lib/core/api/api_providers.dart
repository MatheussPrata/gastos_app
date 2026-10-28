import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gastos_flutter/core/api/api_service.dart';
import 'package:gastos_flutter/core/api/dio_client.dart';
import 'package:gastos_flutter/core/api/endpoints.dart';

/// Dio client provider (singleton)
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient();
  client.init(baseUrl: ApiEndpoints.baseUrl);
  return client;
});

/// Dio instance provider
final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

/// Retrofit API service provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider), baseUrl: ApiEndpoints.baseUrl);
});
