import 'package:flutter_test/flutter_test.dart';

import 'package:gastos_app/core/notifications/notification_permission_service.dart';

void main() {
  group('NotificationPermissions', () {
    test('so pode notificar quando a permissao foi concedida', () {
      for (final status in NotificationPermissionStatus.values) {
        final permissions = NotificationPermissions(
          status: status,
          canScheduleExact: true,
          exactAlarmsSupported: true,
        );
        expect(
          permissions.canNotify,
          status == NotificationPermissionStatus.granted,
          reason: '$status',
        );
      }
    });

    test('sem alarme exato o estado e degradado mas ainda notifica', () {
      const permissions = NotificationPermissions(
        status: NotificationPermissionStatus.granted,
        canScheduleExact: false,
        exactAlarmsSupported: true,
      );

      expect(permissions.canNotify, isTrue);
      expect(permissions.isDegraded, isTrue);
    });

    test('com alarme exato nao ha degradacao', () {
      const permissions = NotificationPermissions(
        status: NotificationPermissionStatus.granted,
        canScheduleExact: true,
        exactAlarmsSupported: true,
      );

      expect(permissions.isDegraded, isFalse);
    });

    test('permissao negada nunca conta como degradada', () {
      const permissions = NotificationPermissions(
        status: NotificationPermissionStatus.permanentlyDenied,
        canScheduleExact: false,
        exactAlarmsSupported: true,
      );

      expect(permissions.isDegraded, isFalse);
    });
  });
}
