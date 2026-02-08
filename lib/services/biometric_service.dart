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

  /// Authentifie l'utilisateur.
  /// [localizedReason] est affiché dans le dialogue système (traduit par l'appelant).
  static Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
    } on PlatformException catch (e) {
      // Gérer les erreurs spécifiques
      if (e.code == 'NotAvailable') {
        return false;
      }
      return false;
    }
  }

  /// Retourne un label traduit pour le type de biométrie.
  /// [fingerprintLabel], [irisLabel], [genericLabel] sont fournis par l'appelant via i18n.
  static String getBiometricLabel(
    List<BiometricType> types, {
    required String fingerprintLabel,
    required String irisLabel,
    required String genericLabel,
  }) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return fingerprintLabel;
    } else if (types.contains(BiometricType.iris)) {
      return irisLabel;
    }
    return genericLabel;
  }
}
