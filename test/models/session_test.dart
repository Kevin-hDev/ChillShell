import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/session.dart';

void main() {
  group('Session', () {
    test('default values are correct', () {
      final session = Session(
        id: '1',
        name: 'Test',
        host: '192.168.1.1',
        username: 'user',
      );
      expect(session.port, 22);
      expect(session.status, ConnectionStatus.disconnected);
      expect(session.tmuxSession, null);
      expect(session.lastConnected, null);
      expect(session.isQuickAccess, true);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      final now = DateTime(2026, 2, 6, 12, 30);
      final original = Session(
        id: 'abc-123',
        name: 'My Server',
        host: '10.0.0.1',
        port: 2222,
        username: 'admin',
        tmuxSession: 'main',
        lastConnected: now,
        isQuickAccess: false,
      );

      final json = original.toJson();
      final restored = Session.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.host, original.host);
      expect(restored.port, original.port);
      expect(restored.username, original.username);
      expect(restored.tmuxSession, original.tmuxSession);
      expect(restored.lastConnected, original.lastConnected);
      expect(restored.isQuickAccess, original.isQuickAccess);
    });

    test('fromJson handles missing optional fields', () {
      final session = Session.fromJson({
        'id': '1',
        'name': 'Test',
        'host': 'localhost',
        'username': 'root',
      });

      expect(session.port, 22);
      expect(session.tmuxSession, null);
      expect(session.lastConnected, null);
      expect(session.isQuickAccess, true);
    });

    test('toJson does not include status (runtime only)', () {
      final session = Session(
        id: '1',
        name: 'Test',
        host: 'host',
        username: 'user',
        status: ConnectionStatus.connected,
      );

      final json = session.toJson();
      expect(json.containsKey('status'), false);
    });

    test('copyWith updates specific fields', () {
      final original = Session(
        id: '1',
        name: 'Original',
        host: 'host',
        username: 'user',
      );

      final modified = original.copyWith(
        name: 'Modified',
        status: ConnectionStatus.connected,
        port: 8022,
      );

      expect(modified.name, 'Modified');
      expect(modified.status, ConnectionStatus.connected);
      expect(modified.port, 8022);
      expect(modified.id, '1');
      expect(modified.host, 'host');
      expect(modified.username, 'user');
    });
  });
}
