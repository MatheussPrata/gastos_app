import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:gastos_flutter/core/api/dio_client.dart';
import 'package:gastos_flutter/core/api/endpoints.dart';
import 'package:gastos_flutter/core/database/app_database.dart';
import 'package:gastos_flutter/features/settings/models/settings_models.dart';

class SettingsRepository {
  final DioClient _dioClient = DioClient();
  final AppDatabase _db = AppDatabase();

  /// Get app settings
  Future<List<AppSettings>> getSettings() async {
    final localResults = await _db.select(_db.appSettings).get();
    return localResults.map((s) => AppSettings(key: s.key, value: s.value)).toList();
  }

  /// Get a specific setting
  Future<String?> getSetting(String key) async {
    final result = await (_db.select(_db.appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return result?.value;
  }

  /// Save setting (offline-first)
  Future<void> saveSetting(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      isSynced: const Value(false),
    ));

    _syncSetting(key, value);
  }

  /// Get connections
  Future<List<Connection>> getConnections() async {
    final localResults = await _db.select(_db.connections).get();
    return localResults.map((c) => Connection(
      id: c.id,
      myUserId: c.myUserId,
      partnerUserId: c.partnerUserId,
      partnerUsername: c.partnerUsername,
      inviteCode: c.inviteCode,
      createdAt: c.createdAt,
      isActive: c.isActive,
      lastSyncedAt: c.lastSyncedAt,
    )).toList();
  }

  /// Create connection
  Future<Connection> createConnection(Connection connection) async {
    await _db.into(_db.connections).insert(ConnectionsCompanion(
      id: Value(connection.id),
      myUserId: Value(connection.myUserId),
      partnerUserId: Value(connection.partnerUserId),
      partnerUsername: Value(connection.partnerUsername),
      inviteCode: Value(connection.inviteCode),
      createdAt: Value(connection.createdAt),
      isActive: Value(connection.isActive),
      lastSyncedAt: Value(connection.lastSyncedAt),
      isSynced: const Value(false),
    ));

    _syncConnection(connection);
    return connection;
  }

  /// Sync settings with server
  Future<void> _syncSetting(String key, String value) async {
    try {
      await DioClient().dio.post(
        ApiEndpoints.settings,
        data: {'key': key, 'value': value},
      );
    } catch (_) {}
  }

  Future<void> _syncConnection(Connection connection) async {
    try {
      await DioClient().dio.post(
        ApiEndpoints.settings, // or a connections endpoint
        data: connection.toJson(),
      );
    } catch (_) {}
  }

  /// Trigger backup
  Future<bool> triggerBackup() async {
    try {
      final response = await DioClient().dio.post(ApiEndpoints.backup);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Trigger manual sync
  Future<bool> triggerSync() async {
    try {
      final response = await DioClient().dio.post(ApiEndpoints.sync);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get sync status
  Future<Map<String, dynamic>?> getSyncStatus() async {
    try {
      final response = await DioClient().dio.get(ApiEndpoints.syncStatus);
      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }
}