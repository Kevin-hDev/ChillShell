// =============================================================================
// FIX-024 — EmergencyKillSwitch + DuressPin
// Problème corrigé : GAP-024 — Absence de mécanisme d'urgence dans ChillShell
// Catégorie : DC (Device Control — Contrôle d'urgence)
// Priorité  : P2
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// ChillShell ne dispose d'aucun mécanisme pour effacer les données sensibles
// en urgence. Si le téléphone est saisi de force ou si l'utilisateur est sous
// contrainte, un attaquant peut accéder librement aux clés SSH, aux sessions
// actives et aux configurations des serveurs.
//
// DEUX MENACES COUVERTES :
//   1. Saisie du dispositif : l'utilisateur veut tout effacer immédiatement
//      → EmergencyKillSwitch avec triple confirmation et délai annulable
//
//   2. Contrainte physique : l'utilisateur est forcé à déverrouiller l'appli
//      → DuressPin : le "mauvais" PIN ouvre des données factices + alerte silencieuse
//
// RÈGLES DE SÉCURITÉ APPLIQUÉES :
//   - JAMAIS == pour comparer des secrets → XOR byte par byte (temps constant)
//   - Kill switch : fail CLOSED → erreur pendant l'effacement = bloquer pas passer
//   - Triple confirmation obligatoire (biométrie + saisie texte + délai 10s)
//   - Le kill switch est IRRÉVERSIBLE après le délai (point de non-retour)
//   - Log AVANT effacement (pour audit forensique)
//   - Le duress PIN doit être différent du PIN normal (validation à la création)
//
// INTÉGRATION :
//   Dans settings_screen.dart :
//     - Bouton d'urgence → EmergencyKillSwitch.requestKill(ctx)
//
//   Dans pin_entry_screen.dart :
//     - Remplacer la comparaison PIN :
//       if (entered == realPin) → DuressPin.verifyPin(entered, realPin, duressPin)
//       puis switch sur PinVerifyResult
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// =============================================================================
// MODÈLES DE DONNÉES
// =============================================================================

/// Résultat de la vérification d'un PIN.
enum PinVerifyResult {
  /// PIN correct — accès normal accordé.
  normal,

  /// PIN de contrainte — ouvre les données factices + alerte silencieuse.
  duress,

  /// PIN invalide — accès refusé.
  invalid,
}

/// Initiateur d'un kill switch.
enum KillInitiator {
  /// Déclenché manuellement par l'utilisateur.
  user,

  /// Déclenché automatiquement (trop de tentatives, délai dépassé).
  auto,

  /// Déclenché à distance (commande de l'administrateur).
  remote,
}

/// Contexte d'une demande de kill switch.
///
/// Enregistré dans le log d'audit AVANT l'effacement.
class KillContext {
  /// Qui a déclenché le kill switch.
  final KillInitiator initiator;

  /// Raison du déclenchement (texte libre, pour audit).
  final String reason;

  /// Moment exact de la demande (UTC).
  final DateTime timestamp;

  const KillContext({
    required this.initiator,
    required this.reason,
    required this.timestamp,
  });

  @override
  String toString() =>
      'KillContext(initiator=$initiator, reason=$reason, t=$timestamp)';
}

/// Progression du kill switch pendant son exécution.
class KillProgress {
  /// Numéro de l'étape courante (1 à [totalSteps]).
  final int currentStep;

  /// Nombre total d'étapes.
  final int totalSteps;

  /// Description courte de l'étape en cours.
  final String stepDescription;

  /// L'étape s'est-elle terminée avec succès ?
  final bool stepSucceeded;

  const KillProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.stepDescription,
    required this.stepSucceeded,
  });
}

// =============================================================================
// EMERGENCY KILL SWITCH
// =============================================================================

/// Mécanisme d'effacement d'urgence de ChillShell.
///
/// Séquence complète :
///   1. [requestKill] : déclenche la procédure
///   2. Triple confirmation : biométrie → saisie texte → délai 10s annulable
///   3. [executeKill] : effacement des données (point de non-retour)
///
/// Le kill switch est IRRÉVERSIBLE une fois le délai écoulé.
/// Log dans le secure log AVANT tout effacement.
class EmergencyKillSwitch {
  // Texte exact à saisir pour confirmation (en majuscules)
  // NOTE : La comparaison est faite en temps constant (XOR byte par byte)
  static const String _confirmationText = 'EFFACER';

  // Délai avant l'exécution irréversible (en secondes)
  static const int _countdownSeconds = 10;

  // Nombre total d'étapes d'effacement
  static const int _totalKillSteps = 4;

  // Callbacks injectés à la construction (injection de dépendances)
  // → permet de tester sans opérations destructives réelles
  final Future<bool> Function() _authenticateBiometric;
  final Future<void> Function() _wipeSSHKeys;
  final Future<void> Function() _closeSessions;
  final Future<void> Function() _notifyDesktop;
  final Future<void> Function() _clearData;
  final Future<void> Function(String logEntry) _writeSecureLog;

  // État interne
  bool _killInProgress = false;
  bool _killPending = false;    // Vrai entre la confirmation et le délai
  bool _killCancelled = false;  // Peut être annulé pendant le délai uniquement

  EmergencyKillSwitch({
    required Future<bool> Function() authenticateBiometric,
    required Future<void> Function() wipeSSHKeys,
    required Future<void> Function() closeSessions,
    required Future<void> Function() notifyDesktop,
    required Future<void> Function() clearData,
    required Future<void> Function(String logEntry) writeSecureLog,
  })  : _authenticateBiometric = authenticateBiometric,
        _wipeSSHKeys = wipeSSHKeys,
        _closeSessions = closeSessions,
        _notifyDesktop = notifyDesktop,
        _clearData = clearData,
        _writeSecureLog = writeSecureLog;

  // ---------------------------------------------------------------------------
  // État public
  // ---------------------------------------------------------------------------

  /// Indique si le kill switch est en cours d'exécution.
  ///
  /// Vrai entre le démarrage de [executeKill] et la fin de la séquence.
  /// Pendant cet état, TOUTES les autres opérations doivent être bloquées.
  bool get isKillInProgress => _killInProgress;

  /// Indique si le kill switch attend la fin du délai de sécurité.
  ///
  /// Vrai entre la validation des confirmations et le lancement de l'effacement.
  /// Peut être annulé pendant cette fenêtre uniquement.
  bool get isKillPending => _killPending;

  // ---------------------------------------------------------------------------
  // Demande de kill switch
  // ---------------------------------------------------------------------------

  /// Déclenche la procédure de kill switch.
  ///
  /// Étapes en séquence :
  ///   1. Vérification biométrique
  ///   2. Vérification du texte de confirmation (temps constant)
  ///   3. Délai de [_countdownSeconds] secondes (annulable)
  ///   4. Si non annulé → [executeKill]
  ///
  /// Retourne [true] si la séquence a été lancée et complétée.
  /// Retourne [false] si une des confirmations a échoué ou si annulé.
  ///
  /// Lance [StateError] si un kill est déjà en cours.
  Future<bool> requestKill(
    KillContext ctx,
    String enteredText,
  ) async {
    // Fail CLOSED : ne pas démarrer si déjà en cours
    if (_killInProgress) {
      throw StateError('Un effacement est déjà en cours.');
    }

    // --- ÉTAPE 1 : Authentification biométrique ---
    bool biometricOk;
    try {
      biometricOk = await _authenticateBiometric();
    } catch (_) {
      // Fail CLOSED : erreur biométrique = blocage
      return false;
    }

    if (!biometricOk) return false;

    // --- ÉTAPE 2 : Vérification du texte en temps constant ---
    if (!_constantTimeTextCompare(enteredText, _confirmationText)) {
      return false;
    }

    // --- ÉTAPE 3 : Délai de sécurité (annulable) ---
    _killPending = true;
    _killCancelled = false;

    // Attendre [_countdownSeconds] secondes — l'utilisateur peut annuler
    await Future.delayed(Duration(seconds: _countdownSeconds));

    _killPending = false;

    // Si annulé pendant le délai → abandon
    if (_killCancelled) return false;

    // --- POINT DE NON-RETOUR : exécution de l'effacement ---
    await executeKill(ctx);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Annulation (uniquement pendant le délai)
  // ---------------------------------------------------------------------------

  /// Annule le kill switch en attente.
  ///
  /// Cette méthode n'a d'effet QUE pendant la fenêtre de délai.
  /// Une fois [executeKill] lancé, l'annulation est impossible.
  ///
  /// Retourne [true] si l'annulation a été prise en compte.
  bool cancelPendingKill() {
    if (!_killPending) return false;
    _killCancelled = true;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Exécution de l'effacement
  // ---------------------------------------------------------------------------

  /// Exécute la séquence d'effacement complète.
  ///
  /// IRRÉVERSIBLE — ne jamais appeler directement sans passer par [requestKill].
  ///
  /// Séquence garantie (même en cas d'erreur partielle) :
  ///   0. Log de l'événement dans le secure log
  ///   1. Effacement des clés SSH
  ///   2. Fermeture des sessions actives
  ///   3. Notification du desktop
  ///   4. Effacement des données restantes
  ///
  /// Chaque étape est tentée même si la précédente a échoué (best-effort).
  /// Fail CLOSED : les erreurs sont logguées mais n'interrompent pas la séquence.
  Future<List<KillProgress>> executeKill(KillContext ctx) async {
    _killInProgress = true;
    final progress = <KillProgress>[];

    // ÉTAPE 0 : Log AVANT effacement (pour audit forensique)
    // C'est intentionnellement la PREMIÈRE chose faite
    try {
      await _writeSecureLog(
        '[KILL_SWITCH] ${ctx.timestamp.toIso8601String()} '
        'initiator=${ctx.initiator} reason=${ctx.reason}',
      );
    } catch (_) {
      // Le log a échoué — on continue quand même l'effacement
      // Ne pas bloquer le kill switch à cause d'un échec de log
    }

    // ÉTAPE 1 : Effacement des clés SSH
    progress.add(await _runKillStep(
      step: 1,
      description: 'Effacement clés SSH',
      action: _wipeSSHKeys,
    ));

    // ÉTAPE 2 : Fermeture des sessions
    progress.add(await _runKillStep(
      step: 2,
      description: 'Fermeture sessions',
      action: _closeSessions,
    ));

    // ÉTAPE 3 : Notification desktop
    progress.add(await _runKillStep(
      step: 3,
      description: 'Notification desktop',
      action: _notifyDesktop,
    ));

    // ÉTAPE 4 : Effacement données restantes
    progress.add(await _runKillStep(
      step: 4,
      description: 'Effacement données',
      action: _clearData,
    ));

    _killInProgress = false;
    return progress;
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées
  // ---------------------------------------------------------------------------

  /// Exécute une étape de l'effacement en capturant les erreurs.
  Future<KillProgress> _runKillStep({
    required int step,
    required String description,
    required Future<void> Function() action,
  }) async {
    bool succeeded = false;
    try {
      await action();
      succeeded = true;
    } catch (_) {
      // Fail CLOSED : erreur logguée, on continue (best-effort sur l'effacement)
      succeeded = false;
    }

    return KillProgress(
      currentStep: step,
      totalSteps: _totalKillSteps,
      stepDescription: description,
      stepSucceeded: succeeded,
    );
  }

  /// Compare deux chaînes de texte en temps constant (protection timing attack).
  ///
  /// Utilise XOR byte par byte sur les représentations UTF-8.
  /// La durée de la comparaison ne révèle pas à quel octet les chaînes diffèrent.
  ///
  /// ATTENTION : Dart peut théoriquement short-circuit les opérateurs logiques.
  /// On accumule le résultat XOR dans un int pour forcer l'évaluation complète.
  static bool _constantTimeTextCompare(String a, String b) {
    final bytesA = Uint8List.fromList(utf8.encode(a));
    final bytesB = Uint8List.fromList(utf8.encode(b));

    // Si les longueurs diffèrent, on compare quand même les N premiers bytes
    // pour ne pas révéler la longueur trop rapidement
    final maxLen = bytesA.length > bytesB.length ? bytesA.length : bytesB.length;

    int diff = bytesA.length ^ bytesB.length; // Intègre la différence de longueur

    for (int i = 0; i < maxLen; i++) {
      final byteA = i < bytesA.length ? bytesA[i] : 0;
      final byteB = i < bytesB.length ? bytesB[i] : 0;
      diff |= byteA ^ byteB;
    }

    // Zero les buffers après usage
    for (int i = 0; i < bytesA.length; i++) bytesA[i] = 0;
    for (int i = 0; i < bytesB.length; i++) bytesB[i] = 0;

    return diff == 0;
  }
}

// =============================================================================
// DURESS PIN
// =============================================================================

/// Gestion du PIN avec mécanisme de contrainte (duress PIN).
///
/// Deux PINs sont définis :
///   - PIN normal  : accès complet aux données réelles
///   - PIN duress  : ouvre des données factices + alerte silencieuse (admin)
///
/// Si un attaquant force l'utilisateur à déverrouiller, le PIN duress lui
/// donne accès à des données factices sans révéler les vraies.
///
/// RÈGLE ABSOLUE : La comparaison des PINs utilise toujours XOR byte par byte.
/// Jamais de `==` pour éviter les timing attacks.
class DuressPin {
  // Longueur minimale d'un PIN valide
  static const int _minPinLength = 4;
  static const int _maxPinLength = 12;

  // Constructeur privé : on n'instancie pas cette classe.
  DuressPin._();

  // ---------------------------------------------------------------------------
  // Validation à la création
  // ---------------------------------------------------------------------------

  /// Valide qu'un PIN normal et un PIN duress peuvent être définis ensemble.
  ///
  /// Conditions :
  ///   - Les deux PINs doivent avoir une longueur entre [_minPinLength] et [_maxPinLength]
  ///   - Les deux PINs doivent être DIFFÉRENTS (un PIN duress identique au PIN
  ///     normal ne protège pas contre la contrainte)
  ///
  /// Retourne [true] si la paire est valide.
  static bool validatePinPair(String normalPin, String duressPin) {
    if (normalPin.length < _minPinLength || normalPin.length > _maxPinLength) {
      return false;
    }
    if (duressPin.length < _minPinLength || duressPin.length > _maxPinLength) {
      return false;
    }
    // Les deux PINs doivent être DIFFÉRENTS
    // On utilise la comparaison en temps constant même ici
    // (si diff == 0, ils sont identiques → invalide)
    return !_constantTimeCompare(normalPin, duressPin);
  }

  // ---------------------------------------------------------------------------
  // Vérification du PIN
  // ---------------------------------------------------------------------------

  /// Vérifie un PIN entré contre le PIN normal et le PIN duress.
  ///
  /// Retourne :
  ///   - [PinVerifyResult.normal]  : [entered] correspond à [realPin]
  ///   - [PinVerifyResult.duress]  : [entered] correspond à [duressPin]
  ///   - [PinVerifyResult.invalid] : ne correspond à aucun des deux
  ///
  /// La comparaison des DEUX PINs se fait en temps constant, y compris
  /// lorsqu'un des deux a déjà correspondu. Cela évite de révéler lequel
  /// des deux PINs a été trouvé en premier via le timing.
  static PinVerifyResult verifyPin(
    String entered,
    String realPin,
    String duressPin,
  ) {
    // Comparer avec les deux PINs EN TEMPS CONSTANT
    // On évalue TOUJOURS les deux comparaisons avant de décider
    final matchesReal = _constantTimeCompare(entered, realPin);
    final matchesDuress = _constantTimeCompare(entered, duressPin);

    // Ordre de priorité : normal > duress > invalid
    // En cas de collision (PIN normal == PIN duress), on retourne normal
    // mais validatePinPair interdit cette situation
    if (matchesReal) return PinVerifyResult.normal;
    if (matchesDuress) return PinVerifyResult.duress;
    return PinVerifyResult.invalid;
  }

  // ---------------------------------------------------------------------------
  // Comparaison en temps constant (XOR byte par byte)
  // ---------------------------------------------------------------------------

  /// Compare deux PINs en temps constant pour éviter les timing attacks.
  ///
  /// La durée de comparaison est identique quelle que soit la position
  /// du premier octet différent. Un attaquant ne peut pas déduire le PIN
  /// en mesurant le temps de réponse.
  static bool _constantTimeCompare(String a, String b) {
    final bytesA = Uint8List.fromList(utf8.encode(a));
    final bytesB = Uint8List.fromList(utf8.encode(b));

    final maxLen = bytesA.length > bytesB.length ? bytesA.length : bytesB.length;
    int diff = bytesA.length ^ bytesB.length;

    for (int i = 0; i < maxLen; i++) {
      final byteA = i < bytesA.length ? bytesA[i] : 0;
      final byteB = i < bytesB.length ? bytesB[i] : 0;
      diff |= byteA ^ byteB;
    }

    // Zeroïser les buffers après usage
    for (int i = 0; i < bytesA.length; i++) bytesA[i] = 0;
    for (int i = 0; i < bytesB.length; i++) bytesB[i] = 0;

    return diff == 0;
  }
}
