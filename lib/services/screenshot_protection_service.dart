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
    } on PlatformException {
      // Ignorer silencieusement si la plateforme ne supporte pas
    }
  }
}
