// =============================================================================
// FIX-012 — Gestionnaire de timeout de session SSH
// =============================================================================
// PROBLEME (GAP-012, P1):
//   Les sessions SSH restent ouvertes indéfiniment. Le keepAlive SSH existant
//   (keepAliveInterval: 30s) maintient la connexion vivante, mais ce n'est PAS
//   un timeout d'inactivité. Un téléphone posé sur une table garde toutes les
//   sessions SSH ouvertes en permanence.
//
// SOLUTION:
//   SessionTimeoutManager surveille l'activité de chaque session SSH (onglet).
//   Sans activité pendant [defaultTimeout] (15 min par défaut), la session est
//   fermée automatiquement. Un avertissement est envoyé [warningBefore] (2 min)
//   avant la fermeture pour laisser le temps à l'utilisateur de réagir.
//
// INTEGRATION:
//   1. Dans ssh_service.dart : instancier SessionTimeoutManager et passer
//      onSessionExpired = (tabId) => disconnect(tabId)
//   2. Appeler resetTimer(tabId) à chaque keypress/commande dans le terminal
//   3. Appeler startMonitoring(tabId) à l'ouverture de chaque session SSH
//   4. Appeler stopMonitoring(tabId) à la fermeture manuelle d'une session
//   5. Ajouter un réglage dans settings_screen pour configurer le timeout
// =============================================================================

import 'dart:async';

// ---------------------------------------------------------------------------
// Types de callbacks
// ---------------------------------------------------------------------------

/// Signature du callback déclenché quand une session expire.
/// [tabId] : identifiant de l'onglet SSH concerné.
typedef SessionExpiredCallback = void Function(String tabId);

/// Signature du callback déclenché pour avertir l'utilisateur.
/// [tabId] : identifiant de l'onglet SSH.
/// [remainingSeconds] : secondes restantes avant fermeture automatique.
typedef SessionWarningCallback = void Function(
  String tabId,
  int remainingSeconds,
);

// ---------------------------------------------------------------------------
// Limites de configuration acceptables
// ---------------------------------------------------------------------------

/// Durée minimale autorisée pour le timeout de session.
/// En dessous de 5 minutes, l'expérience utilisateur devient pénible.
const Duration kSessionTimeoutMin = Duration(minutes: 5);

/// Durée maximale autorisée pour le timeout de session.
const Duration kSessionTimeoutMax = Duration(hours: 2);

// ---------------------------------------------------------------------------
// Classe principale
// ---------------------------------------------------------------------------

/// Gère les timeouts d'inactivité pour les sessions SSH multi-onglets.
///
/// Chaque session SSH identifiée par un [tabId] dispose de son propre timer.
/// Dès qu'une activité est détectée (keypress, commande), [resetTimer] remet
/// le compteur à zéro. Si le timer arrive à zéro :
///   1. [onWarning] est déclenché 2 minutes avant l'expiration.
///   2. [onTimeout] coupe la session et appelle [onSessionExpired].
///
/// Exemple d'utilisation :
/// ```dart
/// final manager = SessionTimeoutManager(
///   onSessionExpired: (tabId) {
///     sshService.disconnect(tabId);
///   },
///   onWarning: (tabId, remainingSeconds) {
///     showSnackBar('Session $tabId inactive : fermeture dans ${remainingSeconds}s');
///   },
/// );
///
/// // À l'ouverture d'une session :
/// manager.startMonitoring('tab_1');
///
/// // À chaque frappe clavier :
/// manager.resetTimer('tab_1');
///
/// // À la fermeture manuelle :
/// manager.stopMonitoring('tab_1');
/// ```
class SessionTimeoutManager {
  // -------------------------------------------------------------------------
  // Configuration
  // -------------------------------------------------------------------------

  /// Durée d'inactivité avant fermeture automatique. Par défaut 15 minutes.
  Duration defaultTimeout;

  /// Délai d'avertissement avant expiration. Par défaut 2 minutes.
  /// L'avertissement est envoyé quand il reste [warningBefore] avant la fin.
  final Duration warningBefore;

  // -------------------------------------------------------------------------
  // Callbacks
  // -------------------------------------------------------------------------

  /// Appelé quand une session expire après le timeout complet.
  /// C'est ici que l'appelant doit fermer la connexion SSH.
  final SessionExpiredCallback onSessionExpired;

  /// Appelé quand il reste [warningBefore] avant l'expiration.
  /// Optionnel : si null, aucun avertissement n'est envoyé.
  final SessionWarningCallback? onWarning;

  // -------------------------------------------------------------------------
  // État interne
  // -------------------------------------------------------------------------

  /// Map des timers actifs : tabId → (timerPrincipal, timerAvertissement).
  /// Limité en taille pour éviter un OOM (voir _checkCapacity).
  final Map<String, _SessionTimers> _timers = {};

  /// Nombre maximum de sessions simultanées surveillées.
  /// Au-delà, les nouvelles sessions sont refusées pour éviter un OOM.
  static const int _maxSessions = 50;

  // -------------------------------------------------------------------------
  // Constructeur
  // -------------------------------------------------------------------------

  SessionTimeoutManager({
    this.defaultTimeout = const Duration(minutes: 15),
    this.warningBefore = const Duration(minutes: 2),
    required this.onSessionExpired,
    this.onWarning,
  }) {
    // Validation de cohérence : warningBefore doit être < defaultTimeout.
    if (warningBefore >= defaultTimeout) {
      throw ArgumentError(
        'warningBefore ($warningBefore) doit être inférieur à '
        'defaultTimeout ($defaultTimeout)',
      );
    }
  }

  // -------------------------------------------------------------------------
  // API publique
  // -------------------------------------------------------------------------

  /// Démarre la surveillance d'inactivité pour la session [tabId].
  ///
  /// Si une surveillance est déjà active pour ce [tabId], elle est réinitialisée.
  ///
  /// Lève [StateError] si le nombre maximum de sessions est atteint.
  void startMonitoring(String tabId) {
    _validateTabId(tabId);

    // Si déjà en cours, réinitialiser proprement.
    if (_timers.containsKey(tabId)) {
      _cancelTimers(tabId);
    }

    // Vérifier la capacité pour éviter un OOM sur saisie arbitraire de tabId.
    _checkCapacity();

    _scheduleTimers(tabId, defaultTimeout);
  }

  /// Réinitialise le timer d'inactivité pour la session [tabId].
  ///
  /// À appeler à chaque frappe clavier ou commande entrée par l'utilisateur.
  /// Si la session n'est pas surveillée, cet appel est ignoré silencieusement.
  void resetTimer(String tabId) {
    _validateTabId(tabId);

    if (!_timers.containsKey(tabId)) {
      // Session non surveillée : ignorer sans erreur (peut arriver pendant
      // la phase d'initialisation).
      return;
    }

    // Annuler les timers existants et repartir de zéro.
    _cancelTimers(tabId);
    _scheduleTimers(tabId, defaultTimeout);
  }

  /// Arrête la surveillance de la session [tabId] (fermeture manuelle).
  ///
  /// À appeler quand l'utilisateur ferme l'onglet SSH manuellement.
  void stopMonitoring(String tabId) {
    _validateTabId(tabId);
    _cancelTimers(tabId);
  }

  /// Modifie le timeout par défaut pour les nouvelles sessions.
  ///
  /// [timeout] doit être compris entre [kSessionTimeoutMin] et [kSessionTimeoutMax].
  /// Les sessions déjà en cours ne sont PAS affectées : appeler [resetTimer]
  /// pour leur appliquer la nouvelle durée.
  ///
  /// Lève [RangeError] si [timeout] est hors limites.
  void setCustomTimeout(Duration timeout) {
    if (timeout < kSessionTimeoutMin || timeout > kSessionTimeoutMax) {
      throw RangeError(
        'Le timeout doit être compris entre '
        '${kSessionTimeoutMin.inMinutes} min et '
        '${kSessionTimeoutMax.inHours} h. '
        'Valeur reçue : ${timeout.inMinutes} min.',
      );
    }

    // Vérification de cohérence avec warningBefore.
    if (warningBefore >= timeout) {
      throw ArgumentError(
        'warningBefore ($warningBefore) doit rester inférieur au nouveau '
        'timeout ($timeout)',
      );
    }

    defaultTimeout = timeout;
  }

  /// Retourne la liste des identifiants de sessions actuellement surveillées.
  List<String> get activeSessions => List.unmodifiable(_timers.keys);

  /// Retourne true si la session [tabId] est actuellement surveillée.
  bool isMonitoring(String tabId) => _timers.containsKey(tabId);

  /// Libère toutes les ressources (annule tous les timers).
  ///
  /// À appeler lors de la destruction du widget/service parent.
  void dispose() {
    for (final tabId in List<String>.from(_timers.keys)) {
      _cancelTimers(tabId);
    }
  }

  // -------------------------------------------------------------------------
  // Méthodes internes
  // -------------------------------------------------------------------------

  /// Planifie les deux timers (avertissement + expiration) pour [tabId].
  void _scheduleTimers(String tabId, Duration totalTimeout) {
    final delaiAvertissement = totalTimeout - warningBefore;

    // Timer d'avertissement : déclenché [warningBefore] avant l'expiration.
    Timer? timerAvertissement;
    if (onWarning != null) {
      timerAvertissement = Timer(delaiAvertissement, () {
        onWarning!(tabId, warningBefore.inSeconds);
      });
    }

    // Timer principal : déclenché après [totalTimeout] d'inactivité.
    final timerPrincipal = Timer(totalTimeout, () {
      _onTimeout(tabId);
    });

    _timers[tabId] = _SessionTimers(
      principal: timerPrincipal,
      avertissement: timerAvertissement,
    );
  }

  /// Déclenché quand une session expire.
  void _onTimeout(String tabId) {
    // Nettoyer les timers avant d'appeler le callback (évite les appels doubles).
    _cancelTimers(tabId);

    // Notifier l'appelant pour fermer la connexion SSH.
    onSessionExpired(tabId);
  }

  /// Annule et supprime les timers associés à [tabId].
  void _cancelTimers(String tabId) {
    final timers = _timers.remove(tabId);
    timers?.cancel();
  }

  /// Valide que [tabId] est une chaîne non vide et de longueur raisonnable.
  ///
  /// Un attaquant ne doit pas pouvoir créer des sessions avec des tabId arbitraires.
  void _validateTabId(String tabId) {
    if (tabId.isEmpty) {
      throw ArgumentError('tabId ne peut pas être vide');
    }
    if (tabId.length > 128) {
      throw ArgumentError('tabId trop long (max 128 caractères)');
    }
  }

  /// Vérifie que le nombre de sessions surveillées ne dépasse pas [_maxSessions].
  ///
  /// Protège contre une attaque OOM par création massive de sessions.
  void _checkCapacity() {
    if (_timers.length >= _maxSessions) {
      throw StateError(
        'Nombre maximum de sessions simultanées atteint ($_maxSessions). '
        'Impossible de surveiller une nouvelle session.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Classe interne : conteneur pour les deux timers d'une session
// ---------------------------------------------------------------------------

class _SessionTimers {
  final Timer principal;
  final Timer? avertissement;

  _SessionTimers({required this.principal, this.avertissement});

  /// Annule les deux timers.
  void cancel() {
    principal.cancel();
    avertissement?.cancel();
  }
}
