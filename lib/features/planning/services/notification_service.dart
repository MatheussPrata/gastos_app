import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';

/// Thin wrapper around flutter_local_notifications for budget alerts.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _channelId = 'budget_alerts';
  static const _channelName = 'Alertas de orçamento';
  static const _channelDescription =
      'Avisos quando uma categoria atinge o limite definido no planejamento.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Configures the plugin and asks for permission (Android 13+).
  ///
  /// Safe to call more than once; failures are ignored so the app still works
  /// on devices where notifications are unavailable.
  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('ic_stat_budget');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    try {
      await _plugin.initialize(settings);
      _initialized = true;
      // O pedido de permissao e feito pela interface, com contexto.
    } catch (_) {
      _initialized = false;
    }
  }

  /// Pede permissao para as notificacoes (Android 13+).
  Future<void> requestPermissions() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {
      // Older Android versions do not need a runtime permission.
    }
  }

  /// Shows a system notification for [alert].
  Future<void> showBudgetAlert(BudgetAlert alert) async {
    if (!_initialized) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_budget',
        color: Color(0xFF1E88E5),
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    final spent = CurrencyFormatter.format(alert.spentAmount);
    final allocated = CurrencyFormatter.format(alert.allocatedAmount);

    final title = alert.isOverBudget
        ? '${alert.categoryName}: limite estourado'
        : '${alert.categoryName} atingiu ${alert.threshold}%';
    final body = alert.isOverBudget
        ? 'Gastou $spent em um limite de $allocated.'
        : 'Usou $spent do limite de $allocated.';

    try {
      await _plugin.show(
        _notificationId(alert.id),
        title,
        body,
        details,
        payload: alert.id,
      );
    } catch (_) {
      // Never let a notification failure break the transaction flow.
    }
  }

  int _notificationId(String id) => id.hashCode & 0x7FFFFFFF;
}
