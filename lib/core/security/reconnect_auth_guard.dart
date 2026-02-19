// =============================================================================
// FIX-011 — Garde de re-authentification à la reconnexion SSH
// =============================================================================
// PROBLEME (GAP-011, P1):
//   La reconnexion SSH relit la clé privée depuis SecureStorage sans aucune
//   vérification d'identité. Un attaquant qui récupère un téléphone déverrouillé
//   peut reconnecter toutes les sessions SSH sans saisir de PIN ni biométrie.
//
// SOLUTION:
//   ReconnectAuthGuard surveille le cycle de vie de l'app. Si l'app est passée
//   en arrière-plan plus de 2 minutes, la prochaine tentative de reconnexion
//   SSH exige une re-authentification (PIN ou biométrie).
//
// INTEGRATION:
//   1. Dans ssh_isolate_worker.dart:_handleReconnectTab():
//      Avant de reconnecter, envoyer un message au main isolate
//      demandant une re-auth si ReconnectAuthGuard.needsReAuthentication()
//   2. Dans main.dart ou app.dart:
//      Ajouter WidgetsBindingObserver pour tracker les changements d'état
//      AppLifecycleState.paused  → ReconnectAuthGuard.instance.onAppBackgrounded()
//      AppLifecycleState.resumed → ReconnectAuthGuard.instance.onAppResumed()
// =============================================================================

import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// Décision retournée par onReconnectRequested()
// ---------------------------------------------------------------------------

/// Résultat de l'évaluation d'une tentative de reconnexion SSH.
///
/// - [allowed]      : Reconnexion autorisée, la session peut être rétablie.
/// - [authRequired] : Une re-authentification (PIN/biométrie) est obligatoire
///                    avant de rétablir la connexion.
/// - [denied]       : Reconnexion refusée (état invalide ou lockout).
enum ReconnectDecision {
  allowed,
  authRequired,
  denied,
}

// ---------------------------------------------------------------------------
// Garde principale
// ---------------------------------------------------------------------------

/// Surveille le cycle de vie de l'application pour décider si une reconnexion
/// SSH doit être précédée d'une re-authentification.
///
/// Principe de sécurité :
///   Si l'app est restée en arrière-plan plus de [backgroundTimeout], l'état
///   d'authentification est considéré périmé. L'attaquant qui reprend le
///   téléphone ne peut pas reconnecter les sessions SSH sans s'identifier.
///
/// Usage typique :
/// ```dart
/// // Dans app.dart (initState ou didChangeDependencies) :
/// WidgetsBinding.instance.addObserver(ReconnectAuthGuard.instance);
///
/// // Dans _handleReconnectTab() côté worker :
/// final decision = ReconnectAuthGuard.instance.onReconnectRequested();
/// if (decision == ReconnectDecision.authRequired) {
///   // Demander PIN/biométrie avant de continuer
/// }
/// ```
class ReconnectAuthGuard with WidgetsBindingObserver {
  // -------------------------------------------------------------------------
  // Singleton — une seule instance pour toute l'application
  // -------------------------------------------------------------------------

  ReconnectAuthGuard._internal();

  static final ReconnectAuthGuard instance = ReconnectAuthGuard._internal();

  // -------------------------------------------------------------------------
  // Paramètres de sécurité
  // -------------------------------------------------------------------------

  /// Durée maximale en arrière-plan avant d'exiger une re-auth.
  /// Valeur par défaut : 2 minutes.
  /// Peut être modifiée pour les tests (setter protégé via [setBackgroundTimeoutForTesting]).
  Duration backgroundTimeout = const Duration(minutes: 2);

  // -------------------------------------------------------------------------
  // État interne
  // -------------------------------------------------------------------------

  /// Horodatage de la dernière authentification réussie.
  /// Null si l'utilisateur n'a jamais été authentifié dans cette session.
  DateTime? _lastAuthenticatedAt;

  /// Horodatage du moment où l'app est passée en arrière-plan.
  /// Null si l'app n'est pas (ou n'a jamais été) en arrière-plan.
  DateTime? _backgroundedAt;

  /// Indique si la session doit être re-authentifiée au prochain accès.
  /// Passé à true quand le timeout en arrière-plan est dépassé.
  bool _requiresReAuth = true;

  // -------------------------------------------------------------------------
  // Accesseurs lecture seule (utiles pour les tests et l'UI)
  // -------------------------------------------------------------------------

  /// Horodatage de la dernière auth réussie. Null si jamais authentifié.
  DateTime? get lastAuthenticatedAt => _lastAuthenticatedAt;

  /// True si une re-authentification est nécessaire.
  bool get requiresReAuth => _requiresReAuth;

  // -------------------------------------------------------------------------
  // API publique
  // -------------------------------------------------------------------------

  /// Indique si une re-authentification est requise avant toute reconnexion SSH.
  ///
  /// Retourne true dans deux cas :
  ///   1. L'utilisateur n'a jamais été authentifié ([_lastAuthenticatedAt] est null).
  ///   2. L'app a été en arrière-plan pendant plus de [backgroundTimeout].
  bool needsReAuthentication() {
    // Cas 1 : jamais authentifié.
    if (_lastAuthenticatedAt == null) {
      return true;
    }

    // Cas 2 : flag levé explicitement (ex. après retour d'arrière-plan long).
    if (_requiresReAuth) {
      return true;
    }

    return false;
  }

  /// Évalue si une reconnexion SSH est autorisée.
  ///
  /// À appeler depuis [_handleReconnectTab] avant de relire la clé privée.
  ReconnectDecision onReconnectRequested() {
    if (needsReAuthentication()) {
      return ReconnectDecision.authRequired;
    }
    return ReconnectDecision.allowed;
  }

  /// Enregistre une authentification réussie (PIN validé ou biométrie OK).
  ///
  /// Réinitialise le flag [_requiresReAuth] et met à jour [_lastAuthenticatedAt].
  /// À appeler après une authentification réussie côté UI.
  void recordAuthentication() {
    _lastAuthenticatedAt = DateTime.now();
    _requiresReAuth = false;
  }

  /// Appelé lorsque l'app passe en arrière-plan (AppLifecycleState.paused).
  ///
  /// Enregistre l'horodatage de mise en arrière-plan pour calcul du timeout.
  void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  /// Appelé lorsque l'app revient au premier plan (AppLifecycleState.resumed).
  ///
  /// Compare le temps écoulé depuis la mise en arrière-plan avec [backgroundTimeout].
  /// Si le timeout est dépassé, [_requiresReAuth] est levé.
  void onAppResumed() {
    if (_backgroundedAt == null) {
      // L'app n'avait pas été mise en arrière-plan : rien à faire.
      return;
    }

    final elapsed = DateTime.now().difference(_backgroundedAt!);

    if (elapsed >= backgroundTimeout) {
      // Le téléphone a été laissé de côté trop longtemps.
      // La prochaine reconnexion SSH devra être re-authentifiée.
      _requiresReAuth = true;
    }

    // On efface le timestamp d'arrière-plan dans tous les cas.
    _backgroundedAt = null;
  }

  // -------------------------------------------------------------------------
  // Implémentation de WidgetsBindingObserver
  // -------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // L'app quitte le premier plan : démarrer le chronomètre.
        onAppBackgrounded();
        break;

      case AppLifecycleState.resumed:
        // L'app revient au premier plan : vérifier le timeout.
        onAppResumed();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // L'app est en cours de fermeture ou cachée (Flutter 3.13+).
        // On marque la session comme nécessitant re-auth par sécurité.
        _requiresReAuth = true;
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Utilitaire pour les tests
  // -------------------------------------------------------------------------

  /// Réinitialise l'état interne. Réservé aux tests unitaires.
  ///
  /// NE PAS appeler en production.
  // ignore: invalid_use_of_visible_for_testing_member
  void resetForTesting() {
    _lastAuthenticatedAt = null;
    _backgroundedAt = null;
    _requiresReAuth = true;
    backgroundTimeout = const Duration(minutes: 2);
  }

  /// Modifie le timeout en arrière-plan. Réservé aux tests unitaires.
  // ignore: invalid_use_of_visible_for_testing_member
  void setBackgroundTimeoutForTesting(Duration timeout) {
    backgroundTimeout = timeout;
  }

  /// Injecte directement l'horodatage de mise en arrière-plan. Réservé aux tests.
  // ignore: invalid_use_of_visible_for_testing_member
  void setBackgroundedAtForTesting(DateTime? dt) {
    _backgroundedAt = dt;
  }
}
