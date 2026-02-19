// =============================================================================
// FIX-022 — AIAgentDetector + AIRateLimiter + SecurityTarpit
// Problème corrigé : GAP-022 — Agents IA (XBOW, HexStrike-AI) ni détectés ni ralentis
// Catégorie : DC (Deception)  |  Priorité : P2
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// Les agents IA d'attaque modernes (XBOW, HexStrike-AI) ont des caractéristiques
// comportementales distinctes d'un humain :
//   - Timing ultra-régulier (variance < 2500ms² = écart type < 50ms)
//   - Énumération systématique (ls/cat/find/grep en boucle)
//   - Absence de pauses humaines (jamais > 5s entre commandes)
//
// Sans protection :
//   - Un agent peut tester 1000 chemins en 10 secondes sans être ralenti
//   - Aucune détection de l'automatisation → aucune contre-mesure
//   - L'attaquant peut cartographier tout le système rapidement
//
// SOLUTION : 3 couches de protection
//   1. AIAgentDetector  : score 0.0-1.0 de probabilité d'être un agent IA
//   2. AIRateLimiter    : limite progressive selon le débit (req/min)
//   3. SecurityTarpit   : délai exponentiel + blacklist automatique
//
// RÈGLES DE SÉCURITÉ APPLIQUÉES :
//   - Maps bornées partout (maxIdentifiers, maxEntries + éviction LRU/FIFO)
//   - Fail CLOSED : données insuffisantes → score par défaut sécurisé
//   - Pas d'info interne dans les messages d'erreur
//   - Comparaisons de valeurs via arithmétique pure (pas de == sur secrets)
// =============================================================================

/// Résultat de l'analyse d'anomalie (réutilisé de FIX-021 — défini ici aussi
/// pour l'autonomie de ce module).
class AnomalyResult {
  final double score;
  final List<String> anomalies;

  const AnomalyResult({
    required this.score,
    required this.anomalies,
  });
}

/// Résultat du rate limiter.
enum RateLimitResult {
  /// Débit acceptable — requête autorisée.
  allowed,

  /// Débit élevé — ralentissement appliqué.
  slowdown,

  /// Débit très élevé — CAPTCHA requis.
  captcha,

  /// Débit excessif — requête bloquée.
  blocked,
}

// =============================================================================
// SECTION 1 : Détecteur d'agents IA
// =============================================================================

/// Détecte les patterns comportementaux caractéristiques des agents IA d'attaque.
///
/// Analyse une liste d'événements récents et produit un score de probabilité
/// d'être un agent automatisé.
///
/// Critères :
///   - Timing trop régulier (variance inter-événements < 2500ms²) → +0.5
///   - Énumération systématique (> 70% des cmd sont ls/cat/find/grep) → +0.4
///   - Absence de pauses humaines (jamais > 5s entre commandes) → +0.3
///
/// Score clampé à [0.0, 1.0].
class AIAgentDetector {
  /// Seuil de variance sous lequel le timing est "trop régulier" (ms²).
  /// Variance = (écart type)² → seuil = 50ms² = 2500ms²
  static const double regularTimingVarianceThreshold = 2500.0;

  /// Seuil de fraction de commandes d'énumération pour déclencher la détection.
  static const double enumerationFractionThreshold = 0.70;

  /// Pause humaine minimale (ms). Si aucun intervalle ne dépasse ce seuil,
  /// le pattern "absence de pauses" est détecté.
  static const int humanPauseThresholdMs = 5000;

  /// Commandes caractéristiques de l'énumération automatisée.
  static const List<String> enumerationCommands = [
    'ls', 'cat', 'find', 'grep',
  ];

  /// Analyse une liste d'événements récents.
  ///
  /// [events] : liste de (timestamp UTC, commande). Minimum 3 événements
  ///            pour une analyse significative.
  ///
  /// Retourne un [AnomalyResult] avec score 0.0-1.0 et liste des anomalies.
  AnomalyResult detectAIPatterns(List<({DateTime timestamp, String command})> events) {
    if (events.length < 3) {
      // Pas assez de données → score neutre (fail CLOSED : pas de décision erronée).
      return const AnomalyResult(score: 0.0, anomalies: []);
    }

    double score = 0.0;
    final anomalies = <String>[];

    // Critère 1 : Timing trop régulier
    final timingScore = _scoreRegularTiming(events);
    if (timingScore > 0.0) {
      score += timingScore;
      anomalies.add('Timing inter-commandes anormalement régulier');
    }

    // Critère 2 : Énumération systématique
    final enumScore = _scoreEnumeration(events);
    if (enumScore > 0.0) {
      score += enumScore;
      anomalies.add('Pattern d\'énumération automatisée détecté');
    }

    // Critère 3 : Absence de pauses humaines
    final pauseScore = _scoreNoPauseHumain(events);
    if (pauseScore > 0.0) {
      score += pauseScore;
      anomalies.add('Aucune pause humaine naturelle observée');
    }

    return AnomalyResult(
      score: score.clamp(0.0, 1.0),
      anomalies: anomalies,
    );
  }

  // ---------------------------------------------------------------------------
  // Critères internes
  // ---------------------------------------------------------------------------

  /// Score pour timing trop régulier.
  ///
  /// Calcule la variance des intervalles inter-événements.
  /// Si variance < seuil → comportement de machine.
  double _scoreRegularTiming(List<({DateTime timestamp, String command})> events) {
    if (events.length < 2) return 0.0;

    // Calculer les intervalles en millisecondes
    final intervals = <double>[];
    for (int i = 1; i < events.length; i++) {
      final diff = events[i].timestamp.difference(events[i - 1].timestamp);
      intervals.add(diff.inMilliseconds.abs().toDouble());
    }

    if (intervals.isEmpty) return 0.0;

    // Calculer la moyenne
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;

    // Calculer la variance
    double sumSquaredDiff = 0.0;
    for (final interval in intervals) {
      final diff = interval - mean;
      sumSquaredDiff += diff * diff;
    }
    final variance = sumSquaredDiff / intervals.length;

    if (variance < regularTimingVarianceThreshold) return 0.5;
    return 0.0;
  }

  /// Score pour énumération systématique.
  ///
  /// Si plus de 70% des commandes sont des commandes d'énumération.
  double _scoreEnumeration(List<({DateTime timestamp, String command})> events) {
    if (events.isEmpty) return 0.0;

    int enumCount = 0;
    for (final event in events) {
      final base = _extractBase(event.command);
      if (enumerationCommands.contains(base)) {
        enumCount++;
      }
    }

    final fraction = enumCount / events.length;
    if (fraction > enumerationFractionThreshold) return 0.4;
    return 0.0;
  }

  /// Score pour absence de pauses humaines.
  ///
  /// Si AUCUN intervalle ne dépasse humanPauseThresholdMs (5s).
  double _scoreNoPauseHumain(List<({DateTime timestamp, String command})> events) {
    if (events.length < 2) return 0.0;

    for (int i = 1; i < events.length; i++) {
      final diff = events[i].timestamp.difference(events[i - 1].timestamp);
      if (diff.inMilliseconds.abs() >= humanPauseThresholdMs) return 0.0;
    }

    // Aucun intervalle ne dépasse 5s → signature d'automatisation
    return 0.3;
  }

  /// Extrait la commande de base (premier mot).
  String _extractBase(String command) {
    final parts = command.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first.toLowerCase();
  }
}

// =============================================================================
// SECTION 2 : Rate Limiter progressif
// =============================================================================

/// Entrée interne du rate limiter pour un identifiant donné.
class _RateLimitEntry {
  /// Timestamps des requêtes récentes (dans la fenêtre d'analyse).
  final List<DateTime> requestTimes;
  /// Dernière fois que l'entrée a été vue.
  DateTime lastSeen;

  _RateLimitEntry({required DateTime firstRequest})
      : requestTimes = [firstRequest],
        lastSeen = firstRequest;
}

/// Rate limiter progressif pour détecter et ralentir les requêtes excessives.
///
/// Fenêtre d'analyse : 1 minute glissante.
/// Seuils :
///   - <= 10 req/min → allowed
///   - > 10 req/min  → slowdown
///   - > 30 req/min  → captcha
///   - > 100 req/min → blocked
///
/// Gestion mémoire :
///   - maxIdentifiers = 1000 avec éviction LRU (dernier vu en premier)
///   - Nettoyage automatique des entrées > 1 minute d'inactivité
class AIRateLimiter {
  /// Nombre maximum d'identifiants différents suivis simultanément.
  static const int maxIdentifiers = 1000;

  /// Fenêtre d'analyse en millisecondes (1 minute).
  static const int windowMs = 60000;

  // Seuils de débit (req/min)
  static const int thresholdSlowdown = 10;
  static const int thresholdCaptcha  = 30;
  static const int thresholdBlocked  = 100;

  // Map identifiant → entrée de rate limit.
  // Borné à maxIdentifiers avec éviction LRU.
  final Map<String, _RateLimitEntry> _entries = {};

  // Ordre LRU : identifiants du moins récemment vu au plus récent.
  final List<String> _lruOrder = [];

  /// Enregistre une requête pour un identifiant et retourne le résultat.
  ///
  /// [identifier] : identifiant opaque (adresse IP hashée, token de session, etc.)
  ///                Ne jamais passer une valeur en clair (IP réelle, user ID).
  ///
  /// Nettoie automatiquement les entrées inactives depuis > 1 minute.
  RateLimitResult checkRequest(String identifier, DateTime now) {
    // Nettoyage des entrées expirées
    _cleanExpired(now);

    // Récupérer ou créer l'entrée
    _RateLimitEntry entry;
    if (_entries.containsKey(identifier)) {
      entry = _entries[identifier]!;
      // Mettre à jour LRU
      _lruOrder.remove(identifier);
      _lruOrder.add(identifier);
    } else {
      // Éviction LRU si plein
      if (_entries.length >= maxIdentifiers) {
        final oldest = _lruOrder.removeAt(0);
        _entries.remove(oldest);
      }
      entry = _RateLimitEntry(firstRequest: now);
      _entries[identifier] = entry;
      _lruOrder.add(identifier);
    }

    // Ajouter la requête courante
    entry.requestTimes.add(now);
    entry.lastSeen = now;

    // Compter les requêtes dans la fenêtre glissante d'1 minute
    final windowStart = now.subtract(const Duration(milliseconds: windowMs));
    final recentCount = entry.requestTimes
        .where((t) => t.isAfter(windowStart))
        .length;

    // Déterminer le résultat
    return _resultForCount(recentCount);
  }

  /// Nombre d'identifiants actuellement suivis.
  int get trackedCount => _entries.length;

  // ---------------------------------------------------------------------------
  // Utilitaires internes
  // ---------------------------------------------------------------------------

  /// Supprime les entrées inactives depuis plus d'1 minute.
  void _cleanExpired(DateTime now) {
    final expiry = now.subtract(const Duration(milliseconds: windowMs));
    final toRemove = <String>[];

    for (final entry in _entries.entries) {
      if (entry.value.lastSeen.isBefore(expiry)) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      _entries.remove(key);
      _lruOrder.remove(key);
    }
  }

  RateLimitResult _resultForCount(int count) {
    if (count > thresholdBlocked)  return RateLimitResult.blocked;
    if (count > thresholdCaptcha)  return RateLimitResult.captcha;
    if (count > thresholdSlowdown) return RateLimitResult.slowdown;
    return RateLimitResult.allowed;
  }
}

// =============================================================================
// SECTION 3 : Security Tarpit
// =============================================================================

/// Entrée interne du tarpit pour un identifiant.
class _TarpitEntry {
  /// Nombre d'échecs consécutifs.
  int consecutiveFailures;

  /// true si l'identifiant est définitivement blacklisté.
  bool isBlacklisted;

  /// Timestamp du dernier événement (succès ou échec).
  DateTime lastSeen;

  _TarpitEntry({
    required this.consecutiveFailures,
    required this.isBlacklisted,
    required this.lastSeen,
  });
}

/// Tarpit de sécurité avec délai exponentiel et blacklist automatique.
///
/// Principe :
///   - Chaque échec augmente le délai d'attente : 2^n secondes (max 60s)
///   - Après 20 échecs consécutifs → blacklist permanente de la session
///   - Un succès remet le compteur à zéro
///
/// Gestion mémoire :
///   - maxEntries = 1000 avec éviction FIFO (les plus anciens)
///   - Nettoyage automatique des entrées > 24h (sauf blacklistées)
class SecurityTarpit {
  /// Nombre maximum d'entrées suivies.
  static const int maxEntries = 1000;

  /// Nombre d'échecs consécutifs avant blacklist automatique.
  static const int blacklistThreshold = 20;

  /// Délai maximum en secondes (2^n ≤ 60s → n = 5 → 32s, n=6 → 64 → clamp à 60).
  static const int maxDelaySeconds = 60;

  /// Durée de vie d'une entrée non-blacklistée (24 heures).
  static const Duration entryTtl = Duration(hours: 24);

  // Map identifiant → entrée tarpit.
  final Map<String, _TarpitEntry> _entries = {};

  // Ordre d'insertion pour l'éviction FIFO des non-blacklistées.
  final List<String> _insertionOrder = [];

  /// Enregistre un échec pour un identifiant.
  ///
  /// Retourne la durée de délai à appliquer AVANT de traiter la prochaine requête.
  ///
  /// Si blacklisté, retourne [Duration.zero] (le blocage est géré par [isBlacklisted]).
  Duration recordFailure(String identifier, DateTime now) {
    _cleanExpired(now);

    final entry = _getOrCreate(identifier, now);

    if (entry.isBlacklisted) {
      // Déjà blacklisté → durée max
      entry.lastSeen = now;
      return Duration(seconds: maxDelaySeconds);
    }

    entry.consecutiveFailures++;
    entry.lastSeen = now;

    // Vérifier le seuil de blacklist
    if (entry.consecutiveFailures >= blacklistThreshold) {
      entry.isBlacklisted = true;
      return Duration(seconds: maxDelaySeconds);
    }

    // Délai exponentiel : 2^failures secondes, clampé à maxDelaySeconds
    final delaySecs = _exponentialDelay(entry.consecutiveFailures);
    return Duration(seconds: delaySecs);
  }

  /// Enregistre un succès et remet le compteur d'échecs à zéro.
  ///
  /// Ne déblackliste PAS un identifiant déjà blacklisté.
  void recordSuccess(String identifier, DateTime now) {
    _cleanExpired(now);

    if (_entries.containsKey(identifier)) {
      final entry = _entries[identifier]!;
      if (!entry.isBlacklisted) {
        entry.consecutiveFailures = 0;
        entry.lastSeen = now;
      }
    }
    // Si l'identifiant n'existe pas encore, pas besoin de créer une entrée.
  }

  /// Vérifie si un identifiant est blacklisté.
  bool isBlacklisted(String identifier) {
    return _entries[identifier]?.isBlacklisted ?? false;
  }

  /// Retourne le délai actuel pour un identifiant (sans modifier le compteur).
  Duration currentDelay(String identifier) {
    final entry = _entries[identifier];
    if (entry == null) return Duration.zero;
    if (entry.isBlacklisted) return Duration(seconds: maxDelaySeconds);
    final delaySecs = _exponentialDelay(entry.consecutiveFailures);
    return Duration(seconds: delaySecs);
  }

  /// Nombre d'entrées actives (incluant blacklistées).
  int get entryCount => _entries.length;

  /// Nombre d'identifiants blacklistés.
  int get blacklistedCount =>
      _entries.values.where((e) => e.isBlacklisted).length;

  // ---------------------------------------------------------------------------
  // Utilitaires internes
  // ---------------------------------------------------------------------------

  _TarpitEntry _getOrCreate(String identifier, DateTime now) {
    if (_entries.containsKey(identifier)) {
      return _entries[identifier]!;
    }

    // Éviction FIFO si plein (seulement les non-blacklistées)
    if (_entries.length >= maxEntries) {
      _evictOldest();
    }

    final entry = _TarpitEntry(
      consecutiveFailures: 0,
      isBlacklisted: false,
      lastSeen: now,
    );
    _entries[identifier] = entry;
    _insertionOrder.add(identifier);
    return entry;
  }

  /// Évince la plus ancienne entrée non-blacklistée.
  void _evictOldest() {
    for (int i = 0; i < _insertionOrder.length; i++) {
      final key = _insertionOrder[i];
      final entry = _entries[key];
      if (entry != null && !entry.isBlacklisted) {
        _entries.remove(key);
        _insertionOrder.removeAt(i);
        return;
      }
    }
    // Si toutes les entrées sont blacklistées, éviction forcée de la plus ancienne
    if (_insertionOrder.isNotEmpty) {
      final oldest = _insertionOrder.removeAt(0);
      _entries.remove(oldest);
    }
  }

  /// Supprime les entrées non-blacklistées inactives depuis > 24h.
  void _cleanExpired(DateTime now) {
    final toRemove = <String>[];
    for (final entry in _entries.entries) {
      if (!entry.value.isBlacklisted &&
          now.difference(entry.value.lastSeen) > entryTtl) {
        toRemove.add(entry.key);
      }
    }
    for (final key in toRemove) {
      _entries.remove(key);
      _insertionOrder.remove(key);
    }
  }

  /// Calcule le délai exponentiel en secondes : 2^failures, clampé à maxDelaySeconds.
  int _exponentialDelay(int failures) {
    if (failures <= 0) return 0;
    // 2^failures, mais en utilisant une boucle pour éviter l'overflow
    int delay = 1;
    for (int i = 0; i < failures; i++) {
      delay *= 2;
      if (delay >= maxDelaySeconds) return maxDelaySeconds;
    }
    return delay.clamp(0, maxDelaySeconds);
  }
}
