import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('default values are correct', () {
      const settings = AppSettings();
      expect(settings.theme, AppTheme.warpDark);
      expect(settings.autoConnectOnStart, true);
      expect(settings.reconnectOnDisconnect, true);
      expect(settings.notifyOnDisconnect, false);
      expect(settings.biometricEnabled, false);
      expect(settings.autoLockEnabled, false);
      expect(settings.pinLockEnabled, false);
      expect(settings.fingerprintEnabled, false);
      expect(settings.autoLockMinutes, 10);
      expect(settings.wolEnabled, false);
      expect(settings.languageCode, null);
      expect(settings.terminalFontSize, TerminalFontSize.m);
    });

    test('toJson/fromJson round-trip preserves all fields', () {
      const original = AppSettings(
        theme: AppTheme.dracula,
        autoConnectOnStart: false,
        reconnectOnDisconnect: false,
        notifyOnDisconnect: true,
        biometricEnabled: true,
        autoLockEnabled: true,
        pinLockEnabled: true,
        fingerprintEnabled: true,
        autoLockMinutes: 30,
        wolEnabled: true,
        languageCode: 'fr',
        terminalFontSize: TerminalFontSize.xl,
      );

      final json = original.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.theme, original.theme);
      expect(restored.autoConnectOnStart, original.autoConnectOnStart);
      expect(restored.reconnectOnDisconnect, original.reconnectOnDisconnect);
      expect(restored.notifyOnDisconnect, original.notifyOnDisconnect);
      expect(restored.biometricEnabled, original.biometricEnabled);
      expect(restored.autoLockEnabled, original.autoLockEnabled);
      expect(restored.pinLockEnabled, original.pinLockEnabled);
      expect(restored.fingerprintEnabled, original.fingerprintEnabled);
      expect(restored.autoLockMinutes, original.autoLockMinutes);
      expect(restored.wolEnabled, original.wolEnabled);
      expect(restored.languageCode, original.languageCode);
      expect(restored.terminalFontSize, original.terminalFontSize);
    });

    test('fromJson handles missing fields with defaults', () {
      final settings = AppSettings.fromJson({});

      expect(settings.theme, AppTheme.warpDark);
      expect(settings.autoConnectOnStart, true);
      expect(settings.pinLockEnabled, false);
      expect(settings.autoLockMinutes, 10);
      expect(settings.languageCode, null);
      expect(settings.terminalFontSize, TerminalFontSize.m);
    });

    test('fromJson handles null languageCode', () {
      final settings = AppSettings.fromJson({'languageCode': null});
      expect(settings.languageCode, null);
    });

    test('copyWith updates specific fields', () {
      const original = AppSettings();
      final modified = original.copyWith(
        theme: AppTheme.nord,
        pinLockEnabled: true,
        autoLockMinutes: 5,
      );

      expect(modified.theme, AppTheme.nord);
      expect(modified.pinLockEnabled, true);
      expect(modified.autoLockMinutes, 5);
      // unchanged fields
      expect(modified.autoConnectOnStart, true);
      expect(modified.wolEnabled, false);
    });

    test('copyWith clearLanguageCode resets to null', () {
      const original = AppSettings(languageCode: 'de');
      final cleared = original.copyWith(clearLanguageCode: true);
      expect(cleared.languageCode, null);
    });

    test('copyWith preserves languageCode when clearLanguageCode is false', () {
      const original = AppSettings(languageCode: 'es');
      final unchanged = original.copyWith(theme: AppTheme.gruvbox);
      expect(unchanged.languageCode, 'es');
    });

    test('all AppTheme values survive round-trip', () {
      for (final theme in AppTheme.values) {
        final settings = AppSettings(theme: theme);
        final restored = AppSettings.fromJson(settings.toJson());
        expect(restored.theme, theme, reason: 'Theme $theme failed round-trip');
      }
    });

    test('all TerminalFontSize values survive round-trip', () {
      for (final size in TerminalFontSize.values) {
        final settings = AppSettings(terminalFontSize: size);
        final restored = AppSettings.fromJson(settings.toJson());
        expect(
          restored.terminalFontSize,
          size,
          reason: 'Font size $size failed round-trip',
        );
      }
    });
  });

  group('TerminalFontSize', () {
    test('has correct pixel sizes', () {
      expect(TerminalFontSize.xs.size, 12.0);
      expect(TerminalFontSize.s.size, 14.0);
      expect(TerminalFontSize.m.size, 17.0);
      expect(TerminalFontSize.l.size, 20.0);
      expect(TerminalFontSize.xl.size, 24.0);
    });

    test('has correct labels', () {
      expect(TerminalFontSize.xs.label, 'XS');
      expect(TerminalFontSize.m.label, 'M');
      expect(TerminalFontSize.xl.label, 'XL');
    });
  });
}
