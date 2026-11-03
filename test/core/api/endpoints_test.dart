import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_app/core/api/endpoints.dart';

void main() {
  test('baseUrl ja inclui /api e os endpoints sao relativos', () {
    expect(ApiEndpoints.baseUrl, endsWith('/api'));

    final endpoints = [
      ApiEndpoints.authLogin,
      ApiEndpoints.authRegister,
      ApiEndpoints.authRefresh,
      ApiEndpoints.authResetPassword,
      ApiEndpoints.sync,
      ApiEndpoints.syncPartner,
      ApiEndpoints.connections,
      ApiEndpoints.categories,
      ApiEndpoints.transactions,
    ];

    for (final endpoint in endpoints) {
      expect(
        endpoint.startsWith('/api/'),
        isFalse,
        reason: '$endpoint duplicaria o prefixo /api do baseUrl',
      );
    }
  });
}
