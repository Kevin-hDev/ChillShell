// =============================================================================
// FIX-013 — Documentation et durcissement des limites biométriques
// =============================================================================
// PROBLEME (GAP-013, P2):
//   La biométrie utilise `biometricOnly: true` mais sans documentation des
//   limites connues. En particulier :
//     - Pas de liveness detection dans local_auth
//     - Dépend entièrement du hardware de l'appareil
//     - Pas de CryptoObject utilisé côté Android
//     - Pas de double facteur pour les actions critiques
//
// SOLUTION:
//   BiometricHardening centralise :
//     1. La documentation des limites connues (constantes commentées)
//     2. L'évaluation du niveau de sécurité du hardware
//     3. Les avertissements à afficher à l'utilisateur dans les Settings
//     4. L'authentification double facteur pour les actions critiques
//
// INTEGRATION:
//   1. Dans biometric_service.dart : ajouter les méthodes de BiometricHardening
//   2. Afficher les warnings dans settings_screen (section sécurité)
//   3. Utiliser authenticateForCriticalAction() pour shutdown, export, delete keys
//   4. Ajouter un indicateur du niveau de sécurité dans l'UI
// =============================================================================

import 'dart:async';

// ---------------------------------------------------------------------------
// Énumérations publiques
// ---------------------------------------------------------------------------

/// Niveau de sécurité biométrique évalué selon le hardware disponible.
///
/// - [high]   : Sensor sécurisé (Face ID Apple, Secure Enclave, TEE certifié)
/// - [medium] : Empreinte digitale sur hardware standard
/// - [low]    : Seul le code PIN/schéma de l'appareil est disponible
/// - [none]   : Aucune méthode de déverrouillage biométrique disponible
enum BiometricSecurityLevel {
  high,
  medium,
  low,
  none,
}

/// Méthodes d'authentification disponibles sur l'appareil.
enum AuthMethod {
  /// Authentification biométrique seule (empreinte, face, iris).
  biometric,

  /// Code PIN ou mot de passe seul.
  pin,

  /// Les deux méthodes disponibles (mode double facteur possible).
  both,
}

// ---------------------------------------------------------------------------
// Constantes — Limites connues de local_auth
// ---------------------------------------------------------------------------
//
// Ces constantes servent de documentation technique et de référence dans les
// rapports de sécurité. Elles n'ont pas de valeur fonctionnelle à l'exécution.

/// LIMITE 1 : Absence de liveness detection.
///
/// Le plugin local_auth (Flutter) ne fait PAS de liveness detection.
/// Sur Android, certains capteurs d'empreinte ou de face ID 2D peuvent être
/// trompés par une photo de haute qualité.
/// Recommandation : informer l'utilisateur, ne pas considérer la biométrie
/// seule comme suffisante pour les actions critiques.
const String kLimite1PasDeLinenessDetection =
    'local_auth n\'implémente pas de liveness detection. '
    'Une photo haute résolution peut tromper certains capteurs.';

/// LIMITE 2 : biometricOnly:true exclut le fallback PIN.
///
/// Avec biometricOnly: true, si la biométrie échoue (doigt mouillé, etc.)
/// il n'y a PAS de fallback vers le PIN système. L'utilisateur est bloqué.
/// Pour les actions non-critiques, envisager biometricOnly: false.
const String kLimite2PasDeFallbackPin =
    'biometricOnly:true exclut le PIN de l\'appareil comme fallback. '
    'Si la biométrie échoue, l\'utilisateur est bloqué.';

/// LIMITE 3 : persistAcrossBackgrounding:false est la valeur correcte.
///
/// Ce paramètre force la re-authentification après mise en arrière-plan.
/// Ne JAMAIS passer cette valeur à true : cela laisserait l'auth valide
/// même si le téléphone est repris par quelqu'un d'autre.
const String kLimite3BackgroundingCorrect =
    'persistAcrossBackgrounding:false est correct : '
    'la re-auth est exigée après mise en arrière-plan. Ne pas changer.';

/// LIMITE 4 : Absence de CryptoObject sur Android.
///
/// Sur Android, local_auth peut être utilisé avec BiometricPrompt + CryptoObject
/// pour lier cryptographiquement l'authentification à une opération spécifique
/// (déchiffrement d'une clé). Sans CryptoObject, la biométrie déverrouille
/// seulement l'interface : un attaquant avec accès root peut court-circuiter
/// l'UI et lire la clé directement.
/// Recommandation : utiliser BiometricPrompt avec CryptoObject via un plugin
/// natif ou un MethodChannel.
const String kLimite4PasDeCryptoObject =
    'Android: CryptoObject non utilisé. '
    'La biométrie déverrouille l\'UI, pas un objet crypto. '
    'Un attaquant root peut court-circuiter cette protection.';

// ---------------------------------------------------------------------------
// Interface abstraite pour l'injection de dépendance (testabilité)
// ---------------------------------------------------------------------------

/// Interface pour les services d'authentification biométrique.
/// Permet d'injecter un mock dans les tests sans dépendre du hardware.
abstract class BiometricAuthProvider {
  /// Retourne true si la biométrie est disponible sur cet appareil.
  Future<bool> isBiometricAvailable();

  /// Retourne true si un PIN/mot de passe est configuré sur l'appareil.
  Future<bool> isPinAvailable();

  /// Démarre une authentification biométrique.
  /// [reason] : texte affiché à l'utilisateur dans la boîte de dialogue.
  Future<bool> authenticateWithBiometric(String reason);

  /// Démarre une authentification par PIN.
  /// [reason] : texte affiché à l'utilisateur.
  Future<bool> authenticateWithPin(String reason);
}

// ---------------------------------------------------------------------------
// Implémentation principale
// ---------------------------------------------------------------------------

/// Module de durcissement biométrique pour ChillShell.
///
/// Centralise :
///   - L'évaluation du niveau de sécurité hardware
///   - Les avertissements à afficher dans les paramètres
///   - L'authentification double facteur pour les actions critiques
class BiometricHardening {
  // -------------------------------------------------------------------------
  // Dépendance injectée
  // -------------------------------------------------------------------------

  final BiometricAuthProvider _authProvider;

  BiometricHardening({required BiometricAuthProvider authProvider})
      : _authProvider = authProvider;

  // -------------------------------------------------------------------------
  // Niveau de sécurité
  // -------------------------------------------------------------------------

  /// Évalue le niveau de sécurité biométrique disponible sur l'appareil.
  ///
  /// Logique d'évaluation :
  ///   - Biométrie + PIN disponibles → [BiometricSecurityLevel.high]
  ///     (le double facteur est possible)
  ///   - Biométrie seule disponible → [BiometricSecurityLevel.medium]
  ///     (protection présente mais pas de double facteur)
  ///   - PIN seul disponible → [BiometricSecurityLevel.low]
  ///     (protection basique, pas de biométrie)
  ///   - Rien → [BiometricSecurityLevel.none]
  ///
  /// Note : ce classement est conservateur. Même "high" a les limites
  /// documentées dans les constantes kLimite*.
  Future<BiometricSecurityLevel> getSecurityLevel() async {
    final biometrieDisponible = await _authProvider.isBiometricAvailable();
    final pinDisponible = await _authProvider.isPinAvailable();

    if (biometrieDisponible && pinDisponible) {
      return BiometricSecurityLevel.high;
    } else if (biometrieDisponible) {
      return BiometricSecurityLevel.medium;
    } else if (pinDisponible) {
      return BiometricSecurityLevel.low;
    } else {
      return BiometricSecurityLevel.none;
    }
  }

  // -------------------------------------------------------------------------
  // Méthodes disponibles
  // -------------------------------------------------------------------------

  /// Retourne la liste des méthodes d'authentification disponibles sur l'appareil.
  Future<List<AuthMethod>> getAvailableAuthMethods() async {
    final biometrieDisponible = await _authProvider.isBiometricAvailable();
    final pinDisponible = await _authProvider.isPinAvailable();

    if (biometrieDisponible && pinDisponible) {
      return [AuthMethod.both, AuthMethod.biometric, AuthMethod.pin];
    } else if (biometrieDisponible) {
      return [AuthMethod.biometric];
    } else if (pinDisponible) {
      return [AuthMethod.pin];
    } else {
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // Avertissements de sécurité
  // -------------------------------------------------------------------------

  /// Retourne la liste des avertissements à afficher dans les paramètres.
  ///
  /// Ces avertissements informent l'utilisateur des limites connues.
  /// Ils doivent être affichés dans la section "Sécurité" des paramètres,
  /// idéalement dans un panneau déroulant "Informations avancées".
  List<String> getSecurityWarnings() {
    return [
      'La biométrie dépend entièrement du matériel de votre appareil. '
          'Tous les capteurs n\'ont pas le même niveau de protection.',
      'Pas de détection de vivant (liveness detection) : '
          'certains capteurs peuvent être trompés par une photo haute résolution.',
      'Recommandé : combiner biométrie + PIN pour les actions critiques '
          '(suppression de clés, déconnexion forcée).',
      'Les données biométriques sont gérées par l\'OS, jamais par l\'application. '
          'ChillShell ne stocke aucune empreinte ni image faciale.',
      kLimite4PasDeCryptoObject,
    ];
  }

  // -------------------------------------------------------------------------
  // Authentification pour actions critiques (double facteur)
  // -------------------------------------------------------------------------

  /// Authentifie l'utilisateur avant une action critique (suppression de clés,
  /// export, shutdown forcé, etc.).
  ///
  /// Stratégie double facteur :
  ///   - Si biométrie ET PIN disponibles → les deux sont exigés en séquence.
  ///   - Si biométrie seule → biométrie seule (avec avertissement niveau moyen).
  ///   - Si PIN seul → PIN seul.
  ///   - Si rien → accès refusé (fail CLOSED).
  ///
  /// [reason] : description de l'action affichée à l'utilisateur.
  ///
  /// Retourne true si l'authentification est validée, false sinon.
  ///
  /// Principe sécurité : fail CLOSED — en cas d'erreur, on refuse l'accès.
  Future<bool> authenticateForCriticalAction(String reason) async {
    // Récupérer les méthodes disponibles.
    final methods = await getAvailableAuthMethods();

    // Aucune méthode disponible → refus immédiat (fail CLOSED).
    if (methods.isEmpty) {
      return false;
    }

    final biometrieDisponible = methods.contains(AuthMethod.biometric) ||
        methods.contains(AuthMethod.both);
    final pinDisponible =
        methods.contains(AuthMethod.pin) || methods.contains(AuthMethod.both);

    try {
      if (biometrieDisponible && pinDisponible) {
        // Double facteur : biométrie en premier.
        final biometrieOk = await _authProvider.authenticateWithBiometric(
          'Étape 1/2 — Biométrie : $reason',
        );
        if (!biometrieOk) {
          // Biométrie échouée → refus immédiat, pas de fallback sur PIN seul.
          return false;
        }

        // Double facteur : PIN en second.
        final pinOk = await _authProvider.authenticateWithPin(
          'Étape 2/2 — PIN : $reason',
        );
        return pinOk;
      } else if (biometrieDisponible) {
        // Biométrie seule : acceptable mais niveau moyen.
        return await _authProvider.authenticateWithBiometric(reason);
      } else {
        // PIN seul.
        return await _authProvider.authenticateWithPin(reason);
      }
    } catch (_) {
      // Toute erreur inattendue → fail CLOSED.
      // On ne laisse jamais une exception provoquer un accès non authentifié.
      return false;
    }
  }
}
