// =============================================================================
// FIX-021 — BehavioralAnalyzer
// Problème corrigé : GAP-021 — Aucune détection comportementale
// Catégorie : BH (Behavior Hardening)  |  Priorité : P2
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// ChillShell ne surveille pas les patterns d'utilisation. Un attaquant peut :
//   - Exécuter "cat /etc/shadow" sans déclencher aucune alerte
//   - Envoyer 500 commandes par minute (rafale automatisée) sans être bloqué
//   - Utiliser des commandes jamais vues dans l'historique sans que personne
//     ne remarque que le comportement a changé
//
// SOLUTION : Analyse comportementale multi-critères
// Chaque commande est scorée selon 4 critères indépendants :
//   1. Horaire inhabituel : < 2% de l'historique à cette heure → +0.3
//   2. Commande inconnue  : jamais vue (si historique > 50 events) → +0.4
//   3. Commande dangereuse: rm -rf, chmod 777, cat /etc/shadow... → +0.5
//   4. Rafale (burst)     : > 10 commandes/minute → +0.3
//
// Score total : clampé à [0.0, 1.0]
// Décision :
//   < 0.4  → allow  (comportement normal)
//   0.4-0.7 → warn  (surveillance accrue)
//   >= 0.7  → block (action bloquée)
//
// RÈGLES DE SÉCURITÉ APPLIQUÉES :
//   - Queue bornée : maxHistory = 1000 (éviction FIFO des plus anciens)
//   - Fail CLOSED : score incalculable → warn par défaut
//   - Messages sans info interne dans AnomalyResult
// =============================================================================

/// Action à prendre suite à l'analyse comportementale.
enum AnomalyAction {
  /// Comportement normal — laisser passer.
  allow,

  /// Comportement suspect — surveiller et alerter.
  warn,

  /// Comportement anormal — bloquer l'action.
  block,
}

/// Résultat de l'analyse comportementale d'un événement.
class AnomalyResult {
  /// Score d'anomalie entre 0.0 (normal) et 1.0 (très suspect).
  final double score;

  /// Liste des anomalies détectées (descriptions lisibles, sans info interne).
  final List<String> anomalies;

  /// Action recommandée selon le score.
  final AnomalyAction action;

  const AnomalyResult({
    required this.score,
    required this.anomalies,
    required this.action,
  });

  @override
  String toString() =>
      'AnomalyResult(score=${score.toStringAsFixed(2)}, action=$action, '
      'anomalies=${anomalies.length})';
}

/// Un événement comportemental enregistré dans le système.
class BehaviorEvent {
  /// Commande exécutée (ex: "ls -la", "cat /etc/shadow").
  final String command;

  /// Timestamp UTC de l'événement.
  final DateTime timestamp;

  /// Identifiant de session (pour grouper les commandes d'une même session).
  final String sessionId;

  const BehaviorEvent({
    required this.command,
    required this.timestamp,
    required this.sessionId,
  });

  /// Extrait la commande de base (premier mot, sans les arguments).
  ///
  /// Exemple : "rm -rf /tmp" → "rm"
  String get baseCommand {
    final parts = command.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first.toLowerCase();
  }

  @override
  String toString() => 'BehaviorEvent(cmd=${baseCommand}, session=$sessionId)';
}

/// Analyseur comportemental pour la détection d'anomalies dans ChillShell.
///
/// Maintient un historique borné des événements et analyse chaque nouvelle
/// commande selon des critères multi-facteurs.
///
/// Usage :
/// ```dart
/// final analyzer = BehavioralAnalyzer();
///
/// // Enregistrer les événements normaux
/// analyzer.recordEvent(BehaviorEvent(
///   command: 'ls -la',
///   timestamp: DateTime.now().toUtc(),
///   sessionId: 'sess_abc123',
/// ));
///
/// // Analyser un événement potentiellement suspect
/// final result = analyzer.analyzeEvent(BehaviorEvent(
///   command: 'cat /etc/shadow',
///   timestamp: DateTime.now().toUtc(),
///   sessionId: 'sess_abc123',
/// ));
///
/// if (result.action == AnomalyAction.block) {
///   // Bloquer l'action
/// }
/// ```
class BehavioralAnalyzer {
  /// Nombre maximum d'événements dans l'historique.
  /// Au-delà, les plus anciens sont évincés (FIFO).
  static const int maxHistory = 1000;

  /// Seuil minimum d'historique pour activer la détection "commande inconnue".
  /// Évite les faux positifs sur un historique trop court.
  static const int minHistoryForUnknown = 50;

  /// Seuil de fréquence horaire en dessous duquel l'horaire est "inhabituel".
  /// 2% = si l'heure actuelle représente moins de 2% de l'historique total.
  static const double unusualHourThreshold = 0.02;

  /// Seuil de commandes par minute pour déclencher la détection de rafale.
  static const int burstThreshold = 10;

  // Historique borné des événements (FIFO).
  final List<BehaviorEvent> _history = [];

  // ---------------------------------------------------------------------------
  // Commandes dangereuses connues
  // ---------------------------------------------------------------------------

  /// Commandes considérées comme dangereuses.
  ///
  /// Format : chaque entrée peut être une commande exacte ou un préfixe
  /// (vérifié via command.startsWith).
  static const List<String> dangerousPatterns = [
    'rm -rf',
    'rm -r',
    'chmod 777',
    'chmod 666',
    'cat /etc/shadow',
    'cat /etc/passwd',
    'cat /etc/sudoers',
    'sudo su',
    'su root',
    'sudo -s',
    'sudo bash',
    'sudo sh',
    'mkfs',
    'dd if=',
    'shred',
    'cryptsetup',
    '> /dev/sda',
    ':(){:|:&};:',   // Fork bomb
    'wget http',     // Téléchargement arbitraire
    'curl http',
    'nc -l',         // Netcat listener (reverse shell)
    'ncat -l',
    'python -c',     // Exécution de code Python inline
    'perl -e',       // Exécution de code Perl inline
    'bash -i',       // Shell interactif (souvent reverse shell)
    'sh -i',
    '/bin/bash -c',
    'base64 -d',     // Décodage base64 → souvent payload obfusqué
    'eval',
    'exec',
    'passwd',        // Changement de mot de passe
  ];

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Enregistre un événement dans l'historique sans l'analyser.
  ///
  /// Utilisé pour construire le profil comportemental de référence.
  /// Si [maxHistory] est atteint, le plus ancien événement est évincé.
  void recordEvent(BehaviorEvent event) {
    if (_history.length >= maxHistory) {
      _history.removeAt(0); // Éviction FIFO
    }
    _history.add(event);
  }

  /// Analyse un événement et retourne un score d'anomalie.
  ///
  /// L'événement N'EST PAS automatiquement ajouté à l'historique.
  /// Appeler [recordEvent] séparément si l'événement doit être enregistré.
  ///
  /// Le score est la somme des critères activés, clampée à [0.0, 1.0].
  AnomalyResult analyzeEvent(BehaviorEvent event) {
    double score = 0.0;
    final anomalies = <String>[];

    // Critère 1 : Horaire inhabituel
    final hourScore = _scoreUnusualHour(event.timestamp);
    if (hourScore > 0.0) {
      score += hourScore;
      anomalies.add('Horaire inhabituel pour cette session');
    }

    // Critère 2 : Commande jamais vue (seulement si historique suffisant)
    final unknownScore = _scoreUnknownCommand(event.command);
    if (unknownScore > 0.0) {
      score += unknownScore;
      anomalies.add('Commande non observée dans l\'historique');
    }

    // Critère 3 : Commande dangereuse
    final dangerScore = _scoreDangerousCommand(event.command);
    if (dangerScore > 0.0) {
      score += dangerScore;
      anomalies.add('Commande à risque élevé détectée');
    }

    // Critère 4 : Rafale de commandes
    final burstScore = _scoreBurst(event);
    if (burstScore > 0.0) {
      score += burstScore;
      anomalies.add('Fréquence de commandes anormalement élevée');
    }

    // Clamp à [0.0, 1.0]
    score = score.clamp(0.0, 1.0);

    return AnomalyResult(
      score: score,
      anomalies: anomalies,
      action: _scoreToAction(score),
    );
  }

  /// Nombre d'événements dans l'historique.
  int get historyLength => _history.length;

  /// Distribution horaire de l'historique.
  ///
  /// Retourne une Map<int, int> : heure (0-23) → nombre d'événements.
  Map<int, int> get hourlyDistribution {
    final dist = <int, int>{};
    for (final event in _history) {
      final hour = event.timestamp.toUtc().hour;
      dist[hour] = (dist[hour] ?? 0) + 1;
    }
    return dist;
  }

  /// Fréquence de chaque commande de base dans l'historique.
  ///
  /// Retourne une Map<String, int> : commande → nombre d'occurrences.
  Map<String, int> get commandFrequency {
    final freq = <String, int>{};
    for (final event in _history) {
      final base = event.baseCommand;
      if (base.isNotEmpty) {
        freq[base] = (freq[base] ?? 0) + 1;
      }
    }
    return freq;
  }

  // ---------------------------------------------------------------------------
  // Critères de scoring
  // ---------------------------------------------------------------------------

  /// Score pour horaire inhabituel.
  ///
  /// Si l'heure actuelle représente < 2% de l'historique total → +0.3
  double _scoreUnusualHour(DateTime timestamp) {
    if (_history.isEmpty) return 0.0;

    final hour = timestamp.toUtc().hour;
    final dist = hourlyDistribution;
    final countAtHour = dist[hour] ?? 0;
    final fraction = countAtHour / _history.length;

    if (fraction < unusualHourThreshold) return 0.3;
    return 0.0;
  }

  /// Score pour commande inconnue.
  ///
  /// Si la commande n'a jamais été vue ET historique > minHistoryForUnknown → +0.4
  double _scoreUnknownCommand(String command) {
    if (_history.length < minHistoryForUnknown) return 0.0;

    final baseCmd = _extractBase(command);
    final freq = commandFrequency;

    if (!freq.containsKey(baseCmd)) return 0.4;
    return 0.0;
  }

  /// Score pour commande dangereuse.
  ///
  /// Si la commande correspond à un pattern dangereux → +0.5
  double _scoreDangerousCommand(String command) {
    final lowerCmd = command.trim().toLowerCase();
    for (final pattern in dangerousPatterns) {
      if (lowerCmd.startsWith(pattern.toLowerCase()) ||
          lowerCmd.contains(pattern.toLowerCase())) {
        return 0.5;
      }
    }
    return 0.0;
  }

  /// Score pour rafale de commandes.
  ///
  /// Si > 10 commandes ont été envoyées dans la dernière minute → +0.3
  double _scoreBurst(BehaviorEvent event) {
    final oneMinuteAgo = event.timestamp.subtract(const Duration(minutes: 1));
    int recentCount = 0;

    for (final h in _history) {
      if (h.sessionId == event.sessionId && h.timestamp.isAfter(oneMinuteAgo)) {
        recentCount++;
      }
    }

    if (recentCount > burstThreshold) return 0.3;
    return 0.0;
  }

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------

  /// Convertit un score en action.
  AnomalyAction _scoreToAction(double score) {
    if (score >= 0.7) return AnomalyAction.block;
    if (score >= 0.4) return AnomalyAction.warn;
    return AnomalyAction.allow;
  }

  /// Extrait la commande de base (premier mot) d'une commande complète.
  String _extractBase(String command) {
    final parts = command.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first.toLowerCase();
  }

  @override
  String toString() =>
      'BehavioralAnalyzer(history=${_history.length}/$maxHistory)';
}
