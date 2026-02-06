import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/saved_connection.dart';

void main() {
  group('SavedConnection', () {
    test('default values are correct', () {
      const conn = SavedConnection(
        id: '1',
        name: 'Server',
        host: '10.0.0.1',
        username: 'admin',
        keyId: 'key-1',
      );
      expect(conn.port, 22);
      expect(conn.lastConnected, null);
      expect(conn.isQuickAccess, false);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 6);
      final original = SavedConnection(
        id: 'conn-1',
        name: 'Production',
        host: 'prod.example.com',
        port: 2222,
        username: 'deploy',
        keyId: 'key-99',
        lastConnected: now,
        isQuickAccess: true,
      );

      final json = original.toJson();
      final restored = SavedConnection.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.username, original.username);
      expect(restored.keyId, original.keyId);
      expect(restored.lastConnected, original.lastConnected);
      expect(restored.isQuickAccess, original.isQuickAccess);
    });

    test('fromJson handles missing optional fields', () {
      final conn = SavedConnection.fromJson({
        'id': '1',
        'name': 'Test',
        'host': 'h',
        'username': 'u',
        'keyId': 'k',
      });

      expect(conn.port, 22);
      expect(conn.lastConnected, null);
      expect(conn.isQuickAccess, false);
    });

    test('copyWith updates specific fields', () {
      const original = SavedConnection(
        id: '1',
        name: 'Old',
        host: 'h',
        username: 'u',
        keyId: 'k',
      );

      final modified = original.copyWith(
        name: 'New',
        isQuickAccess: true,
        port: 8022,
      );

      expect(modified.name, 'New');
      expect(modified.isQuickAccess, true);
      expect(modified.port, 8022);
      expect(modified.host, 'h');
      expect(modified.keyId, 'k');
    });
  });
}
