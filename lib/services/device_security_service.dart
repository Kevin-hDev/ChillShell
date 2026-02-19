import 'dart:io';

import '../core/security/secure_logger.dart';

/// Résultat de la vérification de sécurité de l'appareil.
enum DeviceSecurityStatus { secure, rooted, unknown }

/// Service de détection root/jailbreak.
///
/// Effectue des vérifications basiques sans dépendance externe :
/// - Android : recherche de binaires su, fichiers Superuser, etc.
/// - iOS : recherche de Cydia, ssh, fichiers jailbreak courants.
///
/// Limitation connue : ces vérifications sont contournables par
/// des outils comme Magisk Hide. C'est une mesure dissuasive,
/// pas préventive.
class DeviceSecurityService {
  static DeviceSecurityStatus? _cachedStatus;

  /// Vérifie si l'appareil est rooté/jailbreaké.
  /// Le résultat est mis en cache pour éviter les vérifications répétées.
  static Future<DeviceSecurityStatus> checkDeviceSecurity() async {
    if (_cachedStatus != null) return _cachedStatus!;

    try {
      if (Platform.isAndroid) {
        _cachedStatus = await _checkAndroid();
      } else if (Platform.isIOS) {
        _cachedStatus = _checkIOS();
      } else {
        _cachedStatus = DeviceSecurityStatus.secure;
      }
    } catch (e) {
      SecureLogger.logError('DeviceSecurityService', e);
      _cachedStatus = DeviceSecurityStatus.unknown;
    }

    return _cachedStatus!;
  }

  /// Réinitialise le cache (utile pour les tests).
  static void resetCache() => _cachedStatus = null;

  static Future<DeviceSecurityStatus> _checkAndroid() async {
    // Chemins courants des binaires su sur Android
    const suPaths = [
      '/system/xbin/su',
      '/system/bin/su',
      '/sbin/su',
      '/system/su',
      '/system/bin/.ext/.su',
      '/system/usr/we-need-root/su-backup',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
    ];

    // Chemins indiquant un root management app
    const rootAppPaths = [
      '/system/app/Superuser.apk',
      '/system/app/SuperSU.apk',
      '/system/app/Superuser',
      '/system/app/SuperSU',
    ];

    for (final path in [...suPaths, ...rootAppPaths]) {
      if (await File(path).exists()) {
        SecureLogger.log('DeviceSecurityService', 'Root indicator found');
        return DeviceSecurityStatus.rooted;
      }
    }

    // Vérifier les build tags (test-keys = ROM custom)
    try {
      final result = await Process.run('getprop', ['ro.build.tags']);
      final tags = result.stdout.toString().trim().toLowerCase();
      if (tags.contains('test-keys')) {
        SecureLogger.log('DeviceSecurityService', 'test-keys detected in build tags');
        return DeviceSecurityStatus.rooted;
      }
    } catch (_) {
      // getprop non disponible — ignorer
    }

    return DeviceSecurityStatus.secure;
  }

  static DeviceSecurityStatus _checkIOS() {
    // Chemins courants sur iOS jailbreaké
    const jailbreakPaths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
      '/usr/bin/ssh',
    ];

    for (final path in jailbreakPaths) {
      if (File(path).existsSync()) {
        SecureLogger.log('DeviceSecurityService', 'Jailbreak indicator found');
        return DeviceSecurityStatus.rooted;
      }
    }

    return DeviceSecurityStatus.secure;
  }
}
