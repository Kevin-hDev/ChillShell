import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/audit_entry.dart';
import '../core/security/secure_logger.dart';

/// Service d'audit logging local chiffré.
///
/// Enregistre les événements de sécurité (connexions SSH, échecs auth,
/// import/suppression de clés) dans flutter_secure_storage.
/// Les données sont chiffrées au repos par l'OS (AES/Keychain).
///
/// Rotation FIFO automatique à [_maxEntries] entrées.
class AuditLogService {
  static const _storageKey = 'vibeterm_audit_log';
  static const _maxEntries = 500;

  static const _storage = FlutterSecureStorage();

  /// Enregistre un événement de sécurité.
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
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _storage.write(key: _storageKey, value: json);
  }
}
