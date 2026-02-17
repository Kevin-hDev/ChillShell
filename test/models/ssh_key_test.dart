import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/ssh_key.dart';

void main() {
  group('SSHKey', () {
    test('toJson/fromJson round-trip preserves metadata (not privateKey)', () {
      final now = DateTime(2026, 2, 6, 10, 0);
      final lastUsed = DateTime(2026, 2, 6, 12, 0);
      final original = SSHKey(
        id: 'key-1',
        name: 'My Key',
        host: '192.168.1.100',
        type: SSHKeyType.ed25519,
        privateKey:
            '-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----',
        createdAt: now,
        lastUsed: lastUsed,
      );

      final json = original.toJson();
      final restored = SSHKey.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.host, original.host);
      expect(restored.type, original.type);
      // Sécurité: privateKey ne doit PAS être sérialisé dans toJson()
      expect(json.containsKey('privateKey'), isFalse);
      expect(restored.privateKey, '');
      expect(restored.createdAt, original.createdAt);
      expect(restored.lastUsed, original.lastUsed);
    });

    test('fromJson handles legacy data with privateKey field', () {
      final json = {
        'id': 'key-1',
        'name': 'Legacy Key',
        'host': '192.168.1.100',
        'type': 'ed25519',
        'privateKey': 'old-private-key-data',
        'createdAt': '2026-02-06T10:00:00.000',
      };
      final restored = SSHKey.fromJson(json);
      // Rétrocompatibilité: accepte l'ancien format sans crasher
      expect(restored.privateKey, 'old-private-key-data');
    });

    test('fromJson handles null lastUsed', () {
      final key = SSHKey.fromJson({
        'id': '1',
        'name': 'Key',
        'host': 'host',
        'type': 'rsa',
        'privateKey': 'pk',
        'createdAt': '2026-02-06T10:00:00.000',
      });

      expect(key.lastUsed, null);
      expect(key.type, SSHKeyType.rsa);
    });

    test('typeLabel returns correct labels', () {
      final ed = SSHKey(
        id: '1',
        name: 'k',
        host: 'h',
        type: SSHKeyType.ed25519,
        privateKey: 'pk',
        createdAt: DateTime.now(),
      );
      expect(ed.typeLabel, 'ED25519');

      final rsa = SSHKey(
        id: '2',
        name: 'k',
        host: 'h',
        type: SSHKeyType.rsa,
        privateKey: 'pk',
        createdAt: DateTime.now(),
      );
      expect(rsa.typeLabel, 'RSA');
    });

    test('all SSHKeyType values survive round-trip', () {
      for (final type in SSHKeyType.values) {
        final key = SSHKey(
          id: '1',
          name: 'k',
          host: 'h',
          type: type,
          privateKey: 'pk',
          createdAt: DateTime(2026),
        );
        final restored = SSHKey.fromJson(key.toJson());
        expect(restored.type, type);
      }
    });

    test('copyWith updates specific fields', () {
      final original = SSHKey(
        id: '1',
        name: 'Old',
        host: 'old.host',
        type: SSHKeyType.rsa,
        privateKey: 'old-pk',
        createdAt: DateTime(2026),
      );

      final modified = original.copyWith(name: 'New', host: 'new.host');
      expect(modified.name, 'New');
      expect(modified.host, 'new.host');
      expect(modified.type, SSHKeyType.rsa);
      expect(modified.privateKey, 'old-pk');
    });
  });
}
