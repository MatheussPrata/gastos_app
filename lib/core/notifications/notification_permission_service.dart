import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gastos_app/core/notifications/local_notifications_client.dart';

/// Estado das permissoes de notificacao do aparelho.
enum NotificationPermissionStatus {
  /// O sistema permite notificar.
  granted,

  /// Ainda nao foi decidido; pode-se mostrar o pedido do sistema.
  notRequested,

  /// O utilizador recusou mas o sistema ainda permite pedir outra vez.
  denied,

  /// Recusado definitivamente: so resolve nas configuracoes do aparelho.
  permanentlyDenied,

  /// Nao aplicavel (plataforma sem permissoes ou erro ao consultar).
  unknown,
}

/// Detalhe das permissoes relevantes para os lembretes.
class NotificationPermissions {
  const NotificationPermissions({
    required this.status,
    required this.canScheduleExact,
    required this.exactAlarmsSupported,
  });

  final NotificationPermissionStatus status;

  /// Se o Android permite alarmes exatos (a partir do Android 12).
  final bool canScheduleExact;

  /// Falso em versoes de Android que nao usam alarmes exatos.
  final bool exactAlarmsSupported;

  bool get canNotify => status == NotificationPermissionStatus.granted;

  /// Os lembretes chegam com tolerancia quando nao ha alarme exato.
  bool get isDegraded => canNotify && !canScheduleExact;
}

/// Consulta e pede as permissoes de notificacao no aparelho.
///
/// Centraliza as diferencas entre versoes do Android: em versoes antigas a
/// permissao e implicita; a partir do Android 13 exige pedido em runtime; e
/// desde o Android 12 os alarmes exatos tem permissao propria.
class NotificationPermissionService {
  NotificationPermissionService._();

  static final NotificationPermissionService instance =
      NotificationPermissionService._();

  static const String _promptedPrefKey =
      'notifications_initial_prompt_done_v1';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      LocalNotificationsClient.instance.android;

  /// Consulta o estado atual sem mostrar nenhum pedido.
  Future<NotificationPermissions> check() async {
    if (kIsWeb) {
      return const NotificationPermissions(
        status: NotificationPermissionStatus.unknown,
        canScheduleExact: false,
        exactAlarmsSupported: false,
      );
    }

    try {
      await LocalNotificationsClient.instance.ensureInitialized();
      final android = _android;
      if (android == null) {
        // iOS/macOS: o plugin nao expoe consulta de estado sem pedir. Assume
        // concedido; se o utilizador recusar, o proprio sistema informa.
        return const NotificationPermissions(
          status: NotificationPermissionStatus.granted,
          canScheduleExact: true,
          exactAlarmsSupported: false,
        );
      }

      final enabled = await android.areNotificationsEnabled() ?? false;
      final exact = await android.canScheduleExactNotifications() ?? true;

      if (enabled) {
        return NotificationPermissions(
          status: NotificationPermissionStatus.granted,
          canScheduleExact: exact,
          exactAlarmsSupported: true,
        );
      }

      var alreadyPrompted = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        alreadyPrompted = prefs.getBool(_promptedPrefKey) ?? false;
      } catch (_) {}

      return NotificationPermissions(
        status: alreadyPrompted
            ? NotificationPermissionStatus.denied
            : NotificationPermissionStatus.notRequested,
        canScheduleExact: exact,
        exactAlarmsSupported: true,
      );
    } catch (error) {
      debugPrint('Falha ao consultar permissoes: $error');
      return const NotificationPermissions(
        status: NotificationPermissionStatus.unknown,
        canScheduleExact: false,
        exactAlarmsSupported: false,
      );
    }
  }

  /// Pede a permissao de notificacao (Android 13+) e a de alarme exato.
  ///
  /// Devolve o estado resultante. Quando o sistema nao volta a mostrar o
  /// dialogo porque o utilizador ja recusou, devolve [permanentlyDenied] e a
  /// interface deve encaminhar para as configuracoes do aparelho.
  Future<NotificationPermissions> request() async {
    try {
      await LocalNotificationsClient.instance.ensureInitialized();
      final android = _android;
      if (android == null) {
        return check();
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_promptedPrefKey, true);
      } catch (_) {}

      final granted = await android.requestNotificationsPermission();

      if (granted == true) {
        await android.requestExactAlarmsPermission();
      }

      final permissions = await check();
      if (granted == false &&
          permissions.status != NotificationPermissionStatus.granted) {
        return NotificationPermissions(
          status: NotificationPermissionStatus.permanentlyDenied,
          canScheduleExact: permissions.canScheduleExact,
          exactAlarmsSupported: permissions.exactAlarmsSupported,
        );
      }
      return permissions;
    } catch (error) {
      debugPrint('Falha ao pedir permissoes: $error');
      return check();
    }
  }

  /// Na primeira abertura do app em aparelhos Android 13+, solicita a
  /// permissão de notificações uma única vez para que lembretes e alertas já
  /// funcionem sem obrigar o utilizador a procurar nas configurações.
  Future<NotificationPermissions> requestOnceIfNeverPrompted() async {
    final current = await check();
    if (current.canNotify) return current;

    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted = prefs.getBool(_promptedPrefKey) ?? false;
      if (alreadyPrompted) return current;
      await prefs.setBool(_promptedPrefKey, true);
    } catch (_) {
      return current;
    }

    return request();
  }

  /// Pede apenas o alarme exato, quando as notificacoes ja estao permitidas.
  Future<NotificationPermissions> requestExactAlarms() async {
    try {
      await LocalNotificationsClient.instance.ensureInitialized();
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
    return check();
  }

  /// Abre as definicoes do sistema na pagina desta aplicacao.
  ///
  /// Usado quando a permissao foi recusada definitivamente: so o utilizador
  /// pode voltar a liga-la.
  Future<void> openSystemSettings({bool exactAlarms = false}) async {
    try {
      await AppSettings.openAppSettings(
        type: exactAlarms
            ? AppSettingsType.alarm
            : AppSettingsType.notification,
      );
    } catch (error) {
      debugPrint('Falha ao abrir configuracoes do sistema: $error');
      try {
        await AppSettings.openAppSettings();
      } catch (_) {}
    }
  }
}
