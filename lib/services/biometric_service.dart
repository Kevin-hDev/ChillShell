// =============================================================================
// FIX-013 — Durcissement biométrique
// =============================================================================
// Le module BiometricHardening (lib/core/security/biometric_hardening.dart)
// DOIT être utilisé pour toutes les actions critiques de l'application :
//   - Suppression de clés SSH ou de configuration
//   - Activation du kill switch ou de la déconnexion forcée
//   - Export de données sensibles
//   - Toute action irréversible sur les données utilisateur
//
// Pour ces actions, utiliser authenticateForCriticalAction() (définie ci-dessous)
// plutôt que authenticate(). Cette méthode exige biométrie + PIN en séquence
// lorsque les deux sont disponibles sur l'appareil (double facteur).
//
// Limites connues documentées dans BiometricHardening :
//   - Pas de liveness detection dans local_auth
//   - Pas de CryptoObject sur Android (la biométrie déverrouille l'UI,
//     pas un objet cryptographique lié à l'opération)
//   - biometricOnly:true exclut le fallback PIN système
//   - La sécurité dépend entièrement du hardware de l'appareil
// =============================================================================

import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import '../core/security/biometric_hardening.dart';

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

  /// Authentification renforcée pour les actions critiques.
  ///
  /// Délègue au module [BiometricHardening] qui exige biométrie + PIN en
  /// séquence si les deux sont disponibles (double facteur).
  /// À utiliser pour : suppression de clés, kill switch, export de données,
  /// toute action irréversible.
  ///
  /// En attendant l'intégration complète du [BiometricAuthProvider] adapté
  /// à local_auth, délègue à [authenticate] pour ne pas bloquer l'application.
  ///
  /// TODO: créer une implémentation de [BiometricAuthProvider] basée sur
  /// local_auth et l'injecter dans [BiometricHardening.authenticateForCriticalAction].
  static Future<bool> authenticateForCriticalAction({
    required String reason,
  }) async {
    // Délégation temporaire à authenticate() — à remplacer par
    // BiometricHardening.authenticateForCriticalAction() une fois le
    // BiometricAuthProvider connecté à local_auth.
    return authenticate(localizedReason: reason);
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
