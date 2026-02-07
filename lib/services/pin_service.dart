import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de gestion du code PIN sécurisé.
/// Stocke un hash PBKDF2-HMAC-SHA256 salé du PIN (jamais le PIN en clair).
class PinService {
  static const _hashKey = 'vibeterm_pin_hash';
  static const _saltKey = 'vibeterm_pin_salt';
  // Ancienne clé (v1) — PIN stocké en clair, utilisé pour la migration
  static const _legacyPinKey = 'vibeterm_pin_code';
  static const _versionKey = 'vibeterm_pin_version';
  static const _currentVersion = '3';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  static final _pbkdf2 = Pbkdf2.hmacSha256(iterations: 100000, bits: 256);

  /// Migre l'ancien PIN en clair vers le nouveau format hashé.
  /// Appelé automatiquement au démarrage de l'app.
  static Future<void> migrateIfNeeded() async {
    final legacyPin = await _storage.read(key: _legacyPinKey);
    if (legacyPin == null) return; // Pas d'ancien PIN, rien à faire

    // Vérifier si le nouveau format existe déjà
    final newHash = await _storage.read(key: _hashKey);
    if (newHash != null) {
      // Déjà migré — supprimer l'ancien
      await _storage.delete(key: _legacyPinKey);
      return;
    }

    // Migrer : hasher l'ancien PIN et le stocker au nouveau format
    await savePin(legacyPin);
    await _storage.delete(key: _legacyPinKey);
  }

  /// Génère un salt aléatoire de 16 bytes
  static Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
  }

  /// Hash le PIN avec PBKDF2-HMAC-SHA256 (100k itérations)
  static Future<String> _hashPin(String pin, Uint8List salt) async {
    final secretKey = SecretKey(utf8.encode(pin));
    final derived = await _pbkdf2.deriveKey(
      secretKey: secretKey,
      nonce: salt,
    );
    return base64Encode(await derived.extractBytes());
  }

  /// Ancien hash SHA-256 (v2) — utilisé uniquement pour migration
  static Future<String> _legacyHashPin(String pin, Uint8List salt) async {
    final sha256 = Sha256();
    final data = Uint8List.fromList([...salt, ...utf8.encode(pin)]);
    final hash = await sha256.hash(data);
    return base64Encode(hash.bytes);
  }

  /// Sauvegarde le PIN (6 chiffres) hashé avec un salt aléatoire
  static Future<void> savePin(String pin) async {
    final salt = _generateSalt();
    final hash = await _hashPin(pin, salt);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: hash);
    await _storage.write(key: _versionKey, value: _currentVersion);
  }

  /// Vérifie si le PIN entré correspond au PIN stocké
  static Future<bool> verifyPin(String pin) async {
    final storedSalt = await _storage.read(key: _saltKey);
    final storedHash = await _storage.read(key: _hashKey);
    if (storedSalt == null || storedHash == null) return false;

    final salt = Uint8List.fromList(base64Decode(storedSalt));
    final version = await _storage.read(key: _versionKey);

    if (version != _currentVersion) {
      // Ancien format SHA-256 — vérifier avec l'ancien algo
      final legacyHash = await _legacyHashPin(pin, salt);
      if (legacyHash == storedHash) {
        // Migration transparente vers PBKDF2
        await savePin(pin);
        return true;
      }
      return false;
    }

    // Format actuel PBKDF2
    final hash = await _hashPin(pin, salt);
    return hash == storedHash;
  }

  /// Supprime le PIN stocké
  static Future<void> deletePin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }

  /// Vérifie si un PIN existe
  static Future<bool> hasPin() async {
    final stored = await _storage.read(key: _hashKey);
    return stored != null && stored.isNotEmpty;
  }
}
