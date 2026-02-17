import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/audit_entry.dart';

void main() {
  group('AuditEventType', () {
    test('has raspThreatDetected value', () {
      expect(
        AuditEventType.values.contains(AuditEventType.raspThreatDetected),
        true,
      );
    });

    test('existing types preserve their index after adding raspThreatDetected',
        () {
      // Critical: existing audit logs use index-based serialization.
      // Adding to the END of the enum preserves backward compatibility.
      expect(AuditEventType.sshConnect.index, 0);
      expect(AuditEventType.sshDisconnect.index, 1);
      expect(AuditEventType.sshAuthFail.index, 2);
      expect(AuditEventType.sshReconnect.index, 3);
      expect(AuditEventType.keyImport.index, 4);
      expect(AuditEventType.keyDelete.index, 5);
      expect(AuditEventType.pinCreated.index, 6);
      expect(AuditEventType.pinDeleted.index, 7);
      expect(AuditEventType.biometricFail.index, 8);
      expect(AuditEventType.hostKeyMismatch.index, 9);
      expect(AuditEventType.rootDetected.index, 10);
      expect(AuditEventType.pinFail.index, 11);
      expect(AuditEventType.raspThreatDetected.index, 12);
    });
  });

  group('AuditEntry', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      final entry = AuditEntry(
        timestamp: 1708100000000,
        type: AuditEventType.raspThreatDetected,
        success: false,
        details: {'threat': 'root'},
      );

      final json = entry.toJson();
      final restored = AuditEntry.fromJson(json);

      expect(restored.timestamp, entry.timestamp);
      expect(restored.type, AuditEventType.raspThreatDetected);
      expect(restored.success, false);
      expect(restored.details['threat'], 'root');
    });

    test('fromJson handles old entries without new types', () {
      // Simulate an old log entry (sshConnect = index 0)
      final json = {'t': 1708100000000, 'e': 0, 's': true};
      final entry = AuditEntry.fromJson(json);
      expect(entry.type, AuditEventType.sshConnect);
    });

    test('fromJson handles unknown future type index gracefully', () {
      // Simulate a type index from a future version
      final json = {'t': 1708100000000, 'e': 999, 's': true};
      final entry = AuditEntry.fromJson(json);
      // Should fallback to sshConnect (as per existing code)
      expect(entry.type, AuditEventType.sshConnect);
    });

    test('toJson compact format', () {
      final entry = AuditEntry(
        timestamp: 1708100000000,
        type: AuditEventType.pinFail,
        success: false,
      );
      final json = entry.toJson();
      expect(json['t'], 1708100000000);
      expect(json['e'], 11); // pinFail index
      expect(json['s'], false);
      expect(json.containsKey('d'), false); // no details = no 'd' key
    });
  });
}
