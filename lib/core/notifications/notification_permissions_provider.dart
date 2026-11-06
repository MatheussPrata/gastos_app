import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gastos_app/core/notifications/notification_permission_service.dart';

/// Estado das permissoes de notificacao, consultado ao abrir a tela.
final notificationPermissionsProvider =
    FutureProvider<NotificationPermissions>((ref) async {
  return NotificationPermissionService.instance.check();
});
