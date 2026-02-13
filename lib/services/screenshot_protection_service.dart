import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service pour activer/désactiver la protection contre les captures d'écran
/// via les API natives (FLAG_SECURE sur Android, privacy screen sur iOS).
class ScreenshotProtectionService {
  static const _channel = MethodChannel('com.vibeterm/security');

  /// Active ou désactive la protection contre les captures d'écran.
  /// [enabled] = true → screenshots bloqués, false → screenshots autorisés.
  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setScreenshotProtection', enabled);
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('ScreenshotProtectionService: setEnabled failed: $e');
    }
  }

  /// Vide le clipboard silencieusement via l'API native Android (clearPrimaryClip).
  /// Contrairement à Clipboard.setData(), ne déclenche PAS la notification "Copié" sur Android 13+.
  static Future<void> clearClipboard() async {
    try {
      await _channel.invokeMethod('clearClipboard');
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('ScreenshotProtectionService: clearClipboard failed: $e');
    }
  }
}
