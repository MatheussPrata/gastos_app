import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuração centralizada e segura do FlutterSecureStorage.
/// No Android: EncryptedSharedPreferences (MasterKey AES-256 no Keystore do hardware).
/// No iOS: Keychain com KeychainAccessibility.first_unlock.
class SecureStorageConfig {
  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  static FlutterSecureStorage create() => const FlutterSecureStorage(
        aOptions: androidOptions,
        iOptions: iosOptions,
      );
}
