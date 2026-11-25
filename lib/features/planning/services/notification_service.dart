import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:gastos_app/core/notifications/local_notifications_client.dart';
import 'package:gastos_app/core/utils/formatters.dart';
import 'package:gastos_app/features/planning/models/planning_models.dart';

/// Servico de notificacoes imediatas (alertas de orcamento e teste).
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _testNotificationId = 0x18000001;

  LocalNotificationsClient get _client => LocalNotificationsClient.instance;

  /// Configura o plugin e os canais de notificacao.
  Future<void> initialize() async {
    await _client.ensureInitialized();
  }

  /// Pede permissao para as notificacoes (Android 13+).
  Future<void> requestPermissions() async {
    try {
      await _client.ensureInitialized();
      await _client.android?.requestNotificationsPermission();
    } catch (_) {
      // Versoes antigas do Android nao exigem permissao em runtime.
    }
  }

  /// Exibe uma notificacao do sistema para [alert].
  Future<void> showBudgetAlert(BudgetAlert alert) async {
    final ready = await _client.ensureInitialized();
    if (!ready) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        LocalNotificationsClient.budgetChannelId,
        LocalNotificationsClient.budgetChannelName,
        channelDescription: LocalNotificationsClient.budgetChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: LocalNotificationsClient.smallIcon,
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
      await _client.plugin.show(
        budgetAlertNotificationId(alert.id),
        title,
        body,
        details,
        payload: 'budget_alert:${alert.id}',
      );
    } catch (error) {
      debugPrint('Falha ao exibir alerta de orcamento: $error');
    }
  }

  /// Dispara uma notificacao imediata para o utilizador testar no aparelho.
  Future<bool> showTestNotification() async {
    final ready = await _client.ensureInitialized();
    if (!ready) return false;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        LocalNotificationsClient.remindersChannelId,
        LocalNotificationsClient.remindersChannelName,
        channelDescription:
            LocalNotificationsClient.remindersChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: LocalNotificationsClient.smallIcon,
        color: Color(0xFF1E88E5),
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await _client.plugin.show(
        _testNotificationId,
        'Notificações ativas no Kuanto!',
        'Seus lembretes de vencimento, faturas e alertas de orçamento estão funcionando.',
        details,
        payload: 'test_notification',
      );
      return true;
    } catch (error) {
      debugPrint('Falha ao enviar notificacao de teste: $error');
      return false;
    }
  }

  static int budgetAlertNotificationId(String id) =>
      (id.hashCode & 0x03FFFFFF) | 0x14000000;
}
