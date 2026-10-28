import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_models.freezed.dart';
part 'settings_models.g.dart';

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    required String key,
    required String value,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) => _$AppSettingsFromJson(json);
}

@freezed
class Connection with _$Connection {
  const factory Connection({
    required String id,
    required String myUserId,
    required String partnerUserId,
    required String partnerUsername,
    required String inviteCode,
    required DateTime createdAt,
    @Default(true) bool isActive,
    DateTime? lastSyncedAt,
  }) = _Connection;

  factory Connection.fromJson(Map<String, dynamic> json) => _$ConnectionFromJson(json);
}