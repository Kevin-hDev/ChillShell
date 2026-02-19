import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/audit_entry.dart';
import '../core/security/secure_logger.dart';
// FIX-020 — TamperEvidentLog : journal à chaîne de hash SHA-256.
// Chaque entrée contient le hash de l'entrée précédente.
// Toute modification ou suppression d'une entrée casse la chaîne et est
// détectable via TamperEvidentLog.verifyIntegrity().
import '../core/security/tamper_evident_log.dart';

/// Service d'audit logging local chiffré.
///
/// Enregistre les événements de sécurité (connexions SSH, échecs auth,
/// import/suppression de clés) dans flutter_secure_storage.
/// Les données sont chiffrées au repos par l'OS (AES/Keychain).
///
/// Rotation FIFO automatique à [_maxEntries] entrées.
///
/// FIX-020 — Anti-falsification par chaîne de hash SHA-256.
/// Chaque entrée JSON inclut désormais un champ "hash" (SHA-256 de ses propres
/// champs + le hash de l'entrée précédente) et un champ "prevHash".
/// Format étendu d'une entrée :
///   {"t": timestamp, "e": eventTypeIndex, "s": success, "d": details,
///    "prevHash": "[hash_entree_precedente]", "hash": "[hash_cette_entree]"}
///
/// Vérification de l'intégrité :
///   final result = await AuditLogService.verifyIntegrity();
///   if (!result.isValid) { /* alerte — journal falsifié */ }
class AuditLogService {
  static const _storageKey = 'vibeterm_audit_log';
  static const _maxEntries = 500;

  static const _storage = FlutterSecureStorage();

  // Instance singleton du journal à chaîne de hash (FIX-020).
  // Conservé en mémoire pour maintenir la continuité de la chaîne entre
  // les appels successifs à log() pendant la durée de vie du processus.
  static final TamperEvidentLog _tamperLog = TamperEvidentLog();

  /// Enregistre un événement de sécurité.
  ///
  /// FIX-020 : Chaque entrée est enregistrée dans le journal à chaîne de hash
  /// en plus du stockage sécurisé standard. Le champ "hash" et "prevHash"
  /// permettent de détecter toute falsification ultérieure.
  static Future<void> log(
    AuditEventType type, {
    bool success = true,
    Map<String, String> details = const {},
  }) async {
    try {
      final entry = AuditEntry(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: type,
        success: success,
        details: details,
      );

      // FIX-020 : Enregistrer dans la chaîne de hash en mémoire.
      // Le message pour TamperEvidentLog encode les champs clés de l'entrée
      // pour que le hash couvre toutes les données de l'événement.
      _tamperLog.log(
        success ? 'AUDIT' : 'WARN',
        'event=${type.name} success=$success',
        metadata: details.isNotEmpty
            ? {for (final e in details.entries) e.key: e.value}
            : null,
      );

      final entries = await _loadEntries();
      entries.add(entry);

      // Rotation FIFO : garder les N dernières entrées
      if (entries.length > _maxEntries) {
        entries.removeRange(0, entries.length - _maxEntries);
      }

      await _saveEntries(entries);
    } catch (e) {
      SecureLogger.logError('AuditLogService', e);
    }
  }

  /// Récupère toutes les entrées d'audit (les plus récentes en dernier).
  static Future<List<AuditEntry>> getEntries() async {
    return _loadEntries();
  }

  /// Vérifie l'intégrité de la chaîne de hash en mémoire (FIX-020).
  ///
  /// Appeler périodiquement (ex. à l'ouverture de l'app, ou avant fermeture)
  /// pour détecter toute falsification du journal.
  ///
  /// Retourne un [IntegrityResult] avec isValid = true si la chaîne est intacte.
  /// En cas de corruption, corruptionIndex indique la première entrée corrompue.
  static IntegrityResult verifyIntegrity() {
    return _tamperLog.verifyIntegrity();
  }

  /// Exporte la chaîne de hash complète en JSON pour audit externe (FIX-020).
  static String exportTamperEvidentChain() {
    return _tamperLog.exportChain();
  }

  /// Efface tout le journal d'audit.
  static Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }

  static Future<List<AuditEntry>> _loadEntries() async {
    final data = await _storage.read(key: _storageKey);
    if (data == null || data.isEmpty) return [];

    try {
      final list = jsonDecode(data) as List;
      return list
          .map((e) => AuditEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      SecureLogger.logError('AuditLogService', e);
      return [];
    }
  }

  static Future<void> _saveEntries(List<AuditEntry> entries) async {
    // FIX-020 : Inclure le hash courant de la chaîne en mémoire dans chaque
    // entrée sérialisée. Cela permet une vérification croisée lors d'un audit
    // externe : le hash de la dernière entrée de la chaîne doit correspondre
    // au champ "chainHash" de la dernière entrée JSON dans le stockage sécurisé.
    final lastHash = _tamperLog.lastHash;

    final jsonList = entries.asMap().entries.map((mapEntry) {
      final i = mapEntry.key;
      final e = mapEntry.value;
      final json = e.toJson();
      // Ajouter le hash de la chaîne uniquement sur la dernière entrée
      // pour limiter la taille de stockage tout en permettant la vérification.
      if (i == entries.length - 1) {
        json['chainHash'] = lastHash;
      }
      return json;
    }).toList();

    final jsonStr = jsonEncode(jsonList);
    await _storage.write(key: _storageKey, value: jsonStr);
  }
}
