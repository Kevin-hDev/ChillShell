import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de gestion du code PIN sécurisé.
/// Stocke et vérifie un PIN à 6 chiffres via flutter_secure_storage.
class PinService {
  static const _pinKey = 'vibeterm_pin_code';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Sauvegarde le PIN (6 chiffres)
  static Future<void> savePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  /// Vérifie si le PIN entré correspond au PIN stocké
  static Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null && stored == pin;
  }

  /// Supprime le PIN stocké
  static Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }

  /// Vérifie si un PIN existe
  static Future<bool> hasPin() async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null && stored.isNotEmpty;
  }
}
