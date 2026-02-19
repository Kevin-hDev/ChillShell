// =============================================================================
// FIX-005 — Suppression du stockage de la longueur du PIN
// =============================================================================
// Probleme corrige : GAP-005
// La longueur du PIN etait stockee en clair dans SecureStorage sous la cle
// 'vibeterm_pin_length'. Un attaquant root (ou avec acces au backup chiffre)
// pouvait lire cette valeur pour reduire drastiquement l'espace de brute-force.
// Exemple : savoir que le PIN fait 4 chiffres reduit l'espace de 10^8 a 10^4.
//
// Pourquoi la suppression est SAFE :
// Le hash PBKDF2 du PIN est calcule sur la valeur brute du PIN, pas sur sa
// longueur. La longueur stockee n'etait utilisee QUE pour l'affichage du
// clavier PIN (nombre de cases). On retourne desormais 8 par defaut.
//
// INTEGRATION:
// 1. Dans pin_service.dart:savePin(), SUPPRIMER la ligne :
//    await _storage.write(key: _pinLengthKey, value: pin.length.toString());
// 2. Modifier getPinLength() pour retourner toujours 8.
// 3. Appeler PinLengthFix.migratePinLength() au demarrage de l'app pour
//    nettoyer l'ancienne valeur si elle existe encore sur les appareils
//    mis a jour depuis une version anterieure.
// 4. L'UI du clavier PIN utilise un champ libre — pas un nombre fixe de cases.
// =============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// PinLengthFix
// ---------------------------------------------------------------------------
/// Utilitaire de migration qui supprime la fuite d'information liee au
/// stockage de la longueur du PIN.
class PinLengthFix {
  // -------------------------------------------------------------------------
  // Dependance — stockage securise
  // -------------------------------------------------------------------------
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // -------------------------------------------------------------------------
  // Cle legacy a supprimer
  // -------------------------------------------------------------------------
  /// Cle utilisee dans l'ancienne version de pin_service.dart.
  /// Cette cle ne doit plus JAMAIS etre ecrite apres la migration.
  static const String _legacyPinLengthKey = 'vibeterm_pin_length';

  // -------------------------------------------------------------------------
  // Constante de longueur par defaut
  // -------------------------------------------------------------------------
  /// Longueur par defaut retournee par [getPinLength].
  /// Ne revele aucune information sur la longueur reelle du PIN de l'utilisateur.
  static const int defaultPinLength = 8;

  // -------------------------------------------------------------------------
  // migratePinLength()
  // -------------------------------------------------------------------------
  /// Supprime la cle legacy [_legacyPinLengthKey] du stockage securise.
  ///
  /// A appeler UNE FOIS au demarrage de l'app (par exemple dans main.dart
  /// apres l'initialisation du stockage).
  ///
  /// L'appel est idempotent : si la cle n'existe pas, rien ne se passe.
  static Future<void> migratePinLength() async {
    final existing = await _storage.read(key: _legacyPinLengthKey);
    if (existing != null) {
      // Supprimer la cle — elle ne doit plus jamais exister
      await _storage.delete(key: _legacyPinLengthKey);
    }
    // Si la cle n'existe pas, l'appel est un no-op silencieux.
  }

  // -------------------------------------------------------------------------
  // getPinLength()
  // -------------------------------------------------------------------------
  /// Retourne TOUJOURS [defaultPinLength] (8).
  ///
  /// Ne lit JAMAIS le stockage. Cela empeche toute fuite d'information
  /// sur la longueur reelle du PIN de l'utilisateur.
  ///
  /// Utilisation : affichage du clavier PIN dans l'UI.
  static int getPinLength() {
    return defaultPinLength;
  }

  // -------------------------------------------------------------------------
  // verifyLegacyKeyAbsent()
  // -------------------------------------------------------------------------
  /// Methode de verification (pour les tests et l'audit).
  /// Retourne true si la cle legacy est absente du stockage.
  /// En production, cette methode ne devrait jamais retourner false apres
  /// le premier lancement post-migration.
  static Future<bool> verifyLegacyKeyAbsent() async {
    final value = await _storage.read(key: _legacyPinLengthKey);
    return value == null;
  }
}
