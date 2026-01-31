import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Vérifie si l'appareil supporte la biométrie
  static Future<bool> isAvailable() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheckBiometrics || isDeviceSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Récupère les types de biométrie disponibles
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Authentifie l'utilisateur
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Déverrouillez VibeTerm pour accéder à vos sessions SSH',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permet aussi PIN/pattern si biométrie échoue
        ),
      );
    } on PlatformException catch (e) {
      // Gérer les erreurs spécifiques
      if (e.code == 'NotAvailable') {
        return false;
      }
      return false;
    }
  }

  /// Retourne un label pour le type de biométrie
  static String getBiometricLabel(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Empreinte digitale';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biométrie';
  }
}
