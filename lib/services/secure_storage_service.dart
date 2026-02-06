import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/models.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keysKey = 'ssh_keys';
  static const _privateKeyPrefix = 'private_key_';

  /// Sauvegarde la liste des métadonnées des clés (sans les clés privées)
  static Future<void> saveKeyMetadata(List<SSHKey> keys) async {
    final jsonList = keys.map((k) => k.toJson()).toList();
    await _storage.write(key: _keysKey, value: jsonEncode(jsonList));
  }

  /// Charge la liste des métadonnées des clés
  static Future<List<SSHKey>> loadKeyMetadata() async {
    final jsonString = await _storage.read(key: _keysKey);
    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((j) => SSHKey.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Sauvegarde une clé privée séparément (plus sécurisé)
  static Future<void> savePrivateKey(String keyId, String privateKey) async {
    await _storage.write(key: '$_privateKeyPrefix$keyId', value: privateKey);
  }

  /// Récupère une clé privée par son ID
  static Future<String?> getPrivateKey(String keyId) async {
    return await _storage.read(key: '$_privateKeyPrefix$keyId');
  }

  /// Supprime une clé (métadonnées + clé privée)
  static Future<void> deleteKey(String keyId, List<SSHKey> currentKeys) async {
    // Supprimer la clé privée
    await _storage.delete(key: '$_privateKeyPrefix$keyId');

    // Mettre à jour la liste des métadonnées
    final updatedKeys = currentKeys.where((k) => k.id != keyId).toList();
    await saveKeyMetadata(updatedKeys);
  }

  /// Efface toutes les données
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
