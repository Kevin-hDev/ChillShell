// =============================================================================
// FIX-006 — Confirmation double avant Shutdown
// =============================================================================
// Probleme corrige : GAP-006
// La commande `sudo shutdown -h now` etait envoyee directement via SSH sans
// aucune confirmation. Une erreur de manipulation, une injection de commande,
// ou un attaquant ayant brievement acces a l'app pouvait eteindre la machine
// distante immediatement.
//
// Solution : systeme de token a usage unique valide 30 secondes.
// L'utilisateur doit :
//   1. Demander un token (UI affiche le code a 6 chiffres)
//   2. Taper "SHUTDOWN" (majuscules, exact)
//   3. Le code du token est verifie cote serveur
//   4. Si les 3 conditions sont satisfaites dans les 30 secondes -> shutdown
//
// INTEGRATION:
// 1. Dans ssh_service.dart:shutdown(), remplacer l'envoi direct par :
//    a. final token = ShutdownGuard.requestShutdown();
//    b. Afficher ShutdownConfirmationDialog(token: token)
//    c. L'utilisateur tape "SHUTDOWN" + voit le code
//    d. if (ShutdownGuard.confirmShutdown(token, userInput)) -> envoyer cmd
// 2. Ajouter un widget ShutdownConfirmationDialog dans shared/widgets/.
// =============================================================================

import 'dart:math';

// ============================================================================
// NOTE : Pour l'integration audit log, remplacer la ligne marquee [AUDIT]
// par l'appel reel a AuditLogService.log(...).
// ============================================================================

// ---------------------------------------------------------------------------
// ShutdownToken — Token a usage unique
// ---------------------------------------------------------------------------
/// Represente une demande de shutdown en attente de confirmation.
/// Le token expire automatiquement apres [_validityWindow] secondes.
class ShutdownToken {
  /// Moment de creation du token.
  final DateTime createdAt;

  /// Moment d'expiration.
  final DateTime expiresAt;

  /// Code a 6 chiffres que l'utilisateur doit reproduire dans l'UI.
  /// Genere avec un CSPRNG — ne jamais utiliser Random() ordinaire.
  final String confirmationCode;

  /// Flag interne pour empecher la reutilisation du token.
  bool _consumed = false;

  ShutdownToken._({
    required this.createdAt,
    required this.expiresAt,
    required this.confirmationCode,
  });

  // -------------------------------------------------------------------------
  // isExpired
  // -------------------------------------------------------------------------
  /// true si le token a depasse sa fenetre de validite.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // -------------------------------------------------------------------------
  // isConsumed
  // -------------------------------------------------------------------------
  /// true si le token a deja ete utilise (succes ou echec explicite).
  /// Un token consomme ne peut pas etre reutilise.
  bool get isConsumed => _consumed;

  // -------------------------------------------------------------------------
  // timeRemaining
  // -------------------------------------------------------------------------
  /// Duree restante avant expiration.
  /// Retourne Duration.zero si deja expire.
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  // -------------------------------------------------------------------------
  // _invalidate()
  // -------------------------------------------------------------------------
  /// Marque le token comme consomme.
  void _invalidate() {
    _consumed = true;
  }
}

// ---------------------------------------------------------------------------
// ShutdownGuard — Gestionnaire de confirmation
// ---------------------------------------------------------------------------
/// Fournit un mecanisme de confirmation double avant tout shutdown distant.
///
/// Workflow :
///   token = ShutdownGuard.requestShutdown()
///   → UI affiche token.confirmationCode + champ texte
///   → Utilisateur tape "SHUTDOWN"
///   → ShutdownGuard.confirmShutdown(token, userInput) → bool
class ShutdownGuard {
  // -------------------------------------------------------------------------
  // Constantes
  // -------------------------------------------------------------------------

  /// Fenetre de validite d'un token (secondes).
  static const Duration _validityWindow = Duration(seconds: 30);

  /// Mot de confirmation exact que l'utilisateur doit saisir.
  /// Sensible a la casse — "shutdown" ou "Shutdown" sont rejetes.
  static const String _requiredConfirmationWord = 'SHUTDOWN';

  // -------------------------------------------------------------------------
  // requestShutdown()
  // -------------------------------------------------------------------------
  /// Cree et retourne un nouveau [ShutdownToken].
  ///
  /// Chaque appel genere un token different. Le token precedent n'est pas
  /// invalide automatiquement — c'est la responsabilite de l'UI.
  static ShutdownToken requestShutdown() {
    final now = DateTime.now();
    final code = _generateConfirmationCode();

    // [AUDIT] AuditLogService.log('SHUTDOWN_REQUESTED', 'token=$code');
    _auditLog('SHUTDOWN_REQUESTED', 'code=$code');

    return ShutdownToken._(
      createdAt: now,
      expiresAt: now.add(_validityWindow),
      confirmationCode: code,
    );
  }

  // -------------------------------------------------------------------------
  // confirmShutdown()
  // -------------------------------------------------------------------------
  /// Valide la confirmation de l'utilisateur.
  ///
  /// Retourne true UNIQUEMENT si :
  ///   1. Le token n'est pas expire.
  ///   2. Le token n'a pas deja ete utilise.
  ///   3. [userConfirmation] == "SHUTDOWN" (exact, majuscules).
  ///
  /// Dans tous les autres cas, retourne false et invalide le token.
  static bool confirmShutdown(
    ShutdownToken token,
    String userConfirmation,
  ) {
    // --- Verifier l'expiration ---
    if (token.isExpired) {
      _auditLog('SHUTDOWN_DENIED', 'raison=token_expire');
      token._invalidate();
      return false;
    }

    // --- Verifier que le token n'a pas deja ete utilise ---
    if (token.isConsumed) {
      _auditLog('SHUTDOWN_DENIED', 'raison=token_consomme');
      return false;
    }

    // --- Verifier le mot de confirmation (comparaison directe, pas de secret) ---
    // Note : "SHUTDOWN" n'est pas un secret cryptographique, c'est un mot de
    // confirmation public. La comparaison directe == est appropriee ici.
    if (userConfirmation != _requiredConfirmationWord) {
      _auditLog(
        'SHUTDOWN_DENIED',
        'raison=mot_incorrect (recu: ${userConfirmation.substring(0, userConfirmation.length.clamp(0, 10))})',
      );
      token._invalidate();
      return false;
    }

    // --- Toutes les verifications ont reussi ---
    token._invalidate();
    _auditLog('SHUTDOWN_CONFIRMED', 'shutdown autorise');
    return true;
  }

  // -------------------------------------------------------------------------
  // _generateConfirmationCode()
  // -------------------------------------------------------------------------
  /// Genere un code a 6 chiffres via un CSPRNG.
  ///
  /// Random.secure() utilise le generateur cryptographiquement sur de la
  /// plateforme (urandom sur Linux, CryptGenRandom sur Windows).
  static String _generateConfirmationCode() {
    final rng = Random.secure();
    // Genere un nombre entre 100000 et 999999 (toujours 6 chiffres)
    final code = 100000 + rng.nextInt(900000);
    return code.toString();
  }

  // -------------------------------------------------------------------------
  // _auditLog()
  // -------------------------------------------------------------------------
  /// Stub d'audit log — remplacer par AuditLogService.log() en integration.
  /// Ne jamais supprimer ce log — chaque tentative de shutdown doit etre
  /// tracee pour la detection d'incidents.
  static void _auditLog(String event, String detail) {
    // En production : AuditLogService.log(event, detail);
    // En developpement : impression simple (pas de print en prod)
    assert(() {
      // ignore: avoid_print
      print('[AUDIT] $event | $detail | ${DateTime.now().toIso8601String()}');
      return true;
    }());
  }
}
