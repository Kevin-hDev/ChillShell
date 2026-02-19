import 'package:vibeterm/core/security/secure_logger.dart';

/// Types d'événements de sécurité enregistrés dans l'audit log.
enum AuditEventType {
  sshConnect,
  sshDisconnect,
  sshAuthFail,
  sshReconnect,
  keyImport,
  keyDelete,
  pinCreated,
  pinDeleted,
  biometricFail,
  hostKeyMismatch,
  rootDetected,
  pinFail,
  raspThreatDetected,
}

/// Entrée d'audit log.
///
/// Chaque événement de sécurité produit une [AuditEntry] stockée
/// dans flutter_secure_storage (chiffré au repos par l'OS).
class AuditEntry {
  final int timestamp;
  final AuditEventType type;
  final bool success;
  final Map<String, String> details;

  const AuditEntry({
    required this.timestamp,
    required this.type,
    required this.success,
    this.details = const {},
  });

  Map<String, dynamic> toJson() => {
    't': timestamp,
    'e': type.index,
    's': success,
    if (details.isNotEmpty) 'd': details,
  };

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    final typeIndex = json['e'] as int;
    if (typeIndex >= AuditEventType.values.length) {
      SecureLogger.log('AuditEntry', 'Unknown event type index, falling back to sshConnect');
    }
    return AuditEntry(
      timestamp: json['t'] as int,
      type: typeIndex < AuditEventType.values.length
          ? AuditEventType.values[typeIndex]
          : AuditEventType.sshConnect,
      success: json['s'] as bool? ?? true,
      details: json['d'] != null
          ? Map<String, String>.from(json['d'] as Map)
          : const {},
    );
  }
}
