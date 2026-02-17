import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/services/rasp_service.dart';

void main() {
  group('RaspThreatType', () {
    test('enum has all expected threat types', () {
      // Verify all expected values exist and are accessible.
      final expectedNames = [
        'privilegedAccess',
        'hook',
        'debugger',
        'emulator',
        'tampering',
        'unofficialStore',
        'deviceBinding',
        'obfuscation',
        'passcode',
        'secureHardware',
        'devMode',
        'adbEnabled',
      ];

      expect(RaspThreatType.values.length, expectedNames.length);

      for (final name in expectedNames) {
        expect(
          RaspThreatType.values.any((v) => v.name == name),
          isTrue,
          reason: 'Missing RaspThreatType.$name',
        );
      }
    });

    test('enum values are distinct', () {
      final indices = RaspThreatType.values.map((v) => v.index).toSet();
      expect(indices.length, RaspThreatType.values.length);
    });
  });

  group('RaspService', () {
    tearDown(() {
      RaspService.reset();
    });

    test('reset() does not throw', () {
      expect(() => RaspService.reset(), returnsNormally);
    });

    test('reset() can be called multiple times safely', () {
      RaspService.reset();
      RaspService.reset();
      expect(() => RaspService.reset(), returnsNormally);
    });

    test('isInitialized is false after reset', () {
      expect(RaspService.isInitialized, isFalse);
    });

    test('initialize() is a no-op in debug mode (does not crash)', () async {
      // In test/debug mode, freeRASP initialization is skipped.
      // This verifies the guard clause works and no exception is thrown.
      await RaspService.initialize();

      // Should NOT be marked as initialized (debug mode skips).
      expect(RaspService.isInitialized, isFalse);
    });

    test('initialize() accepts optional onThreatDetected callback', () async {
      // Verify the callback parameter is accepted without error.
      await RaspService.initialize(
        onThreatDetected: (threat) {
          // no-op for test
        },
      );
      expect(RaspService.isInitialized, isFalse); // debug mode → skipped
    });
  });
}
