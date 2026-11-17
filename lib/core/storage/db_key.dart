import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyName = 'kuanto_db_key_v1';
const _storage = FlutterSecureStorage();

/// Chave de criptografia do banco local (256 bits), guardada no cofre do
/// aparelho (Android Keystore / iOS Keychain).
Future<String> getOrCreateDbKey() async {
  final existing = await _storage.read(key: _keyName);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = base64UrlEncode(bytes);
  await _storage.write(key: _keyName, value: key);
  return key;
}
