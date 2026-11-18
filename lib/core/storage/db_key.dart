import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyNameV1 = 'kuanto_db_key_v1';
const _keyNameV2 = 'kuanto_db_key_v2';
const _keyPending = 'kuanto_db_key_v2_pending';
const _storage = FlutterSecureStorage();

/// Chave do banco. `isRaw` indica chave binaria (x'...'), que nao passa por
/// PBKDF2 e abre o SQLCipher imediatamente.
class DbKey {
  const DbKey(this.value, {required this.isRaw});

  final String value;
  final bool isRaw;

  /// Trecho pronto para `PRAGMA key = ...` / `KEY ...`.
  String get pragma => isRaw
      ? '"x\'$value\'"'
      : "'${value.replaceAll("'", "''")}'";
}

Future<DbKey>? _cachedKey;

Future<DbKey> getDbKey() async {
  final cached = _cachedKey;
  if (cached != null) return cached;

  final future = _loadOrCreate();
  _cachedKey = future;
  try {
    return await future;
  } catch (_) {
    _cachedKey = null;
    rethrow;
  }
}

Future<DbKey> _loadOrCreate() async {
  final raw = await _storage.read(key: _keyNameV2);
  if (raw != null && raw.length == 64) return DbKey(raw, isRaw: true);

  // Se o app caiu entre o rekey e a promocao, a chave pendente e a correta.
  final pending = await _storage.read(key: _keyPending);
  if (pending != null && pending.length == 64) {
    await promotePendingRawKey(pending);
    return DbKey(pending, isRaw: true);
  }

  final legacy = await _storage.read(key: _keyNameV1);
  if (legacy != null && legacy.isNotEmpty) {
    return DbKey(legacy, isRaw: false);
  }

  final key = generateRawKey();
  await _storage.write(key: _keyNameV2, value: key);
  return DbKey(key, isRaw: true);
}

/// Gera 256 bits em hexadecimal (64 caracteres).
String generateRawKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<void> savePendingRawKey(String hex) =>
    _storage.write(key: _keyPending, value: hex);

Future<void> promotePendingRawKey(String hex) async {
  await _storage.write(key: _keyNameV2, value: hex);
  await _storage.delete(key: _keyPending);
  await _storage.delete(key: _keyNameV1);
  _cachedKey = Future.value(DbKey(hex, isRaw: true));
}

Future<void> discardPendingRawKey() async {
  try {
    await _storage.delete(key: _keyPending);
  } catch (_) {}
}
