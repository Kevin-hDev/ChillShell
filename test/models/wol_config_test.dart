import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/wol_config.dart';

void main() {
  group('WolConfig', () {
    test('default values are correct', () {
      const config = WolConfig(
        id: '1',
        name: 'PC',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        sshConnectionId: 'conn-1',
      );
      expect(config.broadcastAddress, '255.255.255.255');
      expect(config.port, 9);
      expect(config.detectedOS, null);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      const original = WolConfig(
        id: 'wol-1',
        name: 'Bureau',
        macAddress: '11:22:33:44:55:66',
        sshConnectionId: 'conn-1',
        broadcastAddress: '192.168.1.255',
        port: 7,
        detectedOS: 'linux',
      );

      final json = original.toJson();
      final restored = WolConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.macAddress, original.macAddress);
      expect(restored.sshConnectionId, original.sshConnectionId);
      expect(restored.broadcastAddress, original.broadcastAddress);
      expect(restored.port, original.port);
      expect(restored.detectedOS, original.detectedOS);
    });

    test('fromJson handles missing optional fields', () {
      final config = WolConfig.fromJson({
        'id': '1',
        'name': 'Test',
        'macAddress': 'AA:BB:CC:DD:EE:FF',
        'sshConnectionId': 'c1',
      });

      expect(config.broadcastAddress, '255.255.255.255');
      expect(config.port, 9);
      expect(config.detectedOS, null);
    });

    test('copyWith updates specific fields', () {
      const original = WolConfig(
        id: '1',
        name: 'Old',
        macAddress: 'AA:BB:CC:DD:EE:FF',
        sshConnectionId: 'c1',
      );

      final modified = original.copyWith(
        name: 'New',
        detectedOS: 'windows',
        port: 7,
      );

      expect(modified.name, 'New');
      expect(modified.detectedOS, 'windows');
      expect(modified.port, 7);
      expect(modified.macAddress, 'AA:BB:CC:DD:EE:FF');
    });
  });
}
