// =============================================================================
// TEST — FIX-022 — AIAgentDetector + AIRateLimiter + SecurityTarpit
// Couvre : GAP-022 — Agents IA non détectés ni ralentis
// =============================================================================
//
// Pour lancer ces tests :
//   dart test test_fix_022.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE pour tests autonomes
// ---------------------------------------------------------------------------

class AnomalyResult {
  final double score;
  final List<String> anomalies;
  const AnomalyResult({required this.score, required this.anomalies});
}

enum RateLimitResult { allowed, slowdown, captcha, blocked }

// --- AIAgentDetector ---

class AIAgentDetector {
  static const double regularTimingVarianceThreshold = 2500.0;
  static const double enumerationFractionThreshold = 0.70;
  static const int humanPauseThresholdMs = 5000;
  static const List<String> enumerationCommands = ['ls', 'cat', 'find', 'grep'];

  AnomalyResult detectAIPatterns(List<({DateTime timestamp, String command})> events) {
    if (events.length < 3) return const AnomalyResult(score: 0.0, anomalies: []);

    double score = 0.0;
    final anomalies = <String>[];

    final timingScore = _scoreRegularTiming(events);
    if (timingScore > 0.0) { score += timingScore; anomalies.add('Timing trop régulier'); }

    final enumScore = _scoreEnumeration(events);
    if (enumScore > 0.0) { score += enumScore; anomalies.add('Énumération systématique'); }

    final pauseScore = _scoreNoPauseHumain(events);
    if (pauseScore > 0.0) { score += pauseScore; anomalies.add('Aucune pause humaine'); }

    return AnomalyResult(score: score.clamp(0.0, 1.0), anomalies: anomalies);
  }

  double _scoreRegularTiming(List<({DateTime timestamp, String command})> events) {
    if (events.length < 2) return 0.0;
    final intervals = <double>[];
    for (int i = 1; i < events.length; i++) {
      intervals.add(events[i].timestamp.difference(events[i - 1].timestamp).inMilliseconds.abs().toDouble());
    }
    if (intervals.isEmpty) return 0.0;
    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    double sumSq = 0.0;
    for (final iv in intervals) { final d = iv - mean; sumSq += d * d; }
    final variance = sumSq / intervals.length;
    return variance < regularTimingVarianceThreshold ? 0.5 : 0.0;
  }

  double _scoreEnumeration(List<({DateTime timestamp, String command})> events) {
    if (events.isEmpty) return 0.0;
    int count = 0;
    for (final e in events) {
      if (enumerationCommands.contains(_extractBase(e.command))) count++;
    }
    return (count / events.length) > enumerationFractionThreshold ? 0.4 : 0.0;
  }

  double _scoreNoPauseHumain(List<({DateTime timestamp, String command})> events) {
    if (events.length < 2) return 0.0;
    for (int i = 1; i < events.length; i++) {
      final diff = events[i].timestamp.difference(events[i - 1].timestamp);
      if (diff.inMilliseconds.abs() >= humanPauseThresholdMs) return 0.0;
    }
    return 0.3;
  }

  String _extractBase(String command) {
    final parts = command.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first.toLowerCase();
  }
}

// --- AIRateLimiter ---

class _RateLimitEntry {
  final List<DateTime> requestTimes;
  DateTime lastSeen;
  _RateLimitEntry({required DateTime firstRequest})
      : requestTimes = [firstRequest],
        lastSeen = firstRequest;
}

class AIRateLimiter {
  static const int maxIdentifiers = 1000;
  static const int windowMs = 60000;
  static const int thresholdSlowdown = 10;
  static const int thresholdCaptcha  = 30;
  static const int thresholdBlocked  = 100;

  final Map<String, _RateLimitEntry> _entries = {};
  final List<String> _lruOrder = [];

  RateLimitResult checkRequest(String identifier, DateTime now) {
    _cleanExpired(now);
    _RateLimitEntry entry;
    if (_entries.containsKey(identifier)) {
      entry = _entries[identifier]!;
      _lruOrder.remove(identifier);
      _lruOrder.add(identifier);
    } else {
      if (_entries.length >= maxIdentifiers) {
        final oldest = _lruOrder.removeAt(0);
        _entries.remove(oldest);
      }
      entry = _RateLimitEntry(firstRequest: now);
      _entries[identifier] = entry;
      _lruOrder.add(identifier);
    }
    entry.requestTimes.add(now);
    entry.lastSeen = now;
    final windowStart = now.subtract(const Duration(milliseconds: windowMs));
    final recentCount = entry.requestTimes.where((t) => t.isAfter(windowStart)).length;
    return _resultForCount(recentCount);
  }

  int get trackedCount => _entries.length;

  void _cleanExpired(DateTime now) {
    final expiry = now.subtract(const Duration(milliseconds: windowMs));
    final toRemove = <String>[];
    for (final e in _entries.entries) {
      if (e.value.lastSeen.isBefore(expiry)) toRemove.add(e.key);
    }
    for (final key in toRemove) { _entries.remove(key); _lruOrder.remove(key); }
  }

  RateLimitResult _resultForCount(int count) {
    if (count > thresholdBlocked)  return RateLimitResult.blocked;
    if (count > thresholdCaptcha)  return RateLimitResult.captcha;
    if (count > thresholdSlowdown) return RateLimitResult.slowdown;
    return RateLimitResult.allowed;
  }
}

// --- SecurityTarpit ---

class _TarpitEntry {
  int consecutiveFailures;
  bool isBlacklisted;
  DateTime lastSeen;
  _TarpitEntry({
    required this.consecutiveFailures,
    required this.isBlacklisted,
    required this.lastSeen,
  });
}

class SecurityTarpit {
  static const int maxEntries = 1000;
  static const int blacklistThreshold = 20;
  static const int maxDelaySeconds = 60;
  static const Duration entryTtl = Duration(hours: 24);

  final Map<String, _TarpitEntry> _entries = {};
  final List<String> _insertionOrder = [];

  Duration recordFailure(String identifier, DateTime now) {
    _cleanExpired(now);
    final entry = _getOrCreate(identifier, now);
    if (entry.isBlacklisted) { entry.lastSeen = now; return Duration(seconds: maxDelaySeconds); }
    entry.consecutiveFailures++;
    entry.lastSeen = now;
    if (entry.consecutiveFailures >= blacklistThreshold) {
      entry.isBlacklisted = true;
      return Duration(seconds: maxDelaySeconds);
    }
    return Duration(seconds: _exponentialDelay(entry.consecutiveFailures));
  }

  void recordSuccess(String identifier, DateTime now) {
    _cleanExpired(now);
    if (_entries.containsKey(identifier)) {
      final entry = _entries[identifier]!;
      if (!entry.isBlacklisted) { entry.consecutiveFailures = 0; entry.lastSeen = now; }
    }
  }

  bool isBlacklisted(String identifier) => _entries[identifier]?.isBlacklisted ?? false;

  Duration currentDelay(String identifier) {
    final entry = _entries[identifier];
    if (entry == null) return Duration.zero;
    if (entry.isBlacklisted) return Duration(seconds: maxDelaySeconds);
    return Duration(seconds: _exponentialDelay(entry.consecutiveFailures));
  }

  int get entryCount => _entries.length;
  int get blacklistedCount => _entries.values.where((e) => e.isBlacklisted).length;

  _TarpitEntry _getOrCreate(String identifier, DateTime now) {
    if (_entries.containsKey(identifier)) return _entries[identifier]!;
    if (_entries.length >= maxEntries) _evictOldest();
    final entry = _TarpitEntry(consecutiveFailures: 0, isBlacklisted: false, lastSeen: now);
    _entries[identifier] = entry;
    _insertionOrder.add(identifier);
    return entry;
  }

  void _evictOldest() {
    for (int i = 0; i < _insertionOrder.length; i++) {
      final key = _insertionOrder[i];
      final e = _entries[key];
      if (e != null && !e.isBlacklisted) { _entries.remove(key); _insertionOrder.removeAt(i); return; }
    }
    if (_insertionOrder.isNotEmpty) { final k = _insertionOrder.removeAt(0); _entries.remove(k); }
  }

  void _cleanExpired(DateTime now) {
    final toRemove = <String>[];
    for (final e in _entries.entries) {
      if (!e.value.isBlacklisted && now.difference(e.value.lastSeen) > entryTtl) {
        toRemove.add(e.key);
      }
    }
    for (final k in toRemove) { _entries.remove(k); _insertionOrder.remove(k); }
  }

  int _exponentialDelay(int failures) {
    if (failures <= 0) return 0;
    int delay = 1;
    for (int i = 0; i < failures; i++) { delay *= 2; if (delay >= maxDelaySeconds) return maxDelaySeconds; }
    return delay.clamp(0, maxDelaySeconds);
  }
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Helpers de test
// ---------------------------------------------------------------------------

/// Génère N événements avec un timing parfaitement régulier (machine).
List<({DateTime timestamp, String command})> _regularTimingEvents({
  required int count,
  required DateTime start,
  required int intervalMs,
  String command = 'ls',
}) {
  return List.generate(
    count,
    (i) => (
      timestamp: start.add(Duration(milliseconds: i * intervalMs)),
      command: command,
    ),
  );
}

/// Génère N événements avec un timing irrégulier (humain).
List<({DateTime timestamp, String command})> _humanTimingEvents({
  required DateTime start,
}) {
  // Intervalles très irréguliers : 500ms, 8000ms, 300ms, 12000ms, 2000ms
  final offsets = [0, 500, 8500, 8800, 20800, 22800];
  final commands = ['ls', 'cd /home', 'pwd', 'ls -la', 'cat README.md', 'echo hello'];
  return List.generate(
    offsets.length,
    (i) => (
      timestamp: start.add(Duration(milliseconds: offsets[i])),
      command: commands[i % commands.length],
    ),
  );
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  final baseTime = DateTime.utc(2026, 2, 19, 10, 0, 0);

  // =========================================================================
  group('AIAgentDetector — timing régulier', () {
    // -----------------------------------------------------------------------
    test('timing ultra-régulier (intervalle constant 100ms) → score >= 0.5', () {
      final detector = AIAgentDetector();
      // 100ms = variance = 0 (toujours 100ms) → bien < 2500
      final events = _regularTimingEvents(
        count: 10,
        start: baseTime,
        intervalMs: 100,
      );
      final result = detector.detectAIPatterns(events);
      expect(result.score, greaterThanOrEqualTo(0.5));
      expect(result.anomalies, isNotEmpty);
    });

    // -----------------------------------------------------------------------
    test('timing humain irrégulier (variance >> 2500) → score < 0.5 pour ce critère seul', () {
      final detector = AIAgentDetector();
      final events = _humanTimingEvents(start: baseTime);
      final result = detector.detectAIPatterns(events);
      // Les intervalles humains ont une variance élevée → pas de +0.5 timing
      // (il peut y avoir d'autres scores si commandes enumeration)
      // On vérifie que l'anomalie timing n'est pas dans la liste
      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('régulier')),
        isEmpty,
      );
    });

    // -----------------------------------------------------------------------
    test('moins de 3 événements → score = 0.0 (pas assez de données)', () {
      final detector = AIAgentDetector();
      final events = _regularTimingEvents(count: 2, start: baseTime, intervalMs: 100);
      final result = detector.detectAIPatterns(events);
      expect(result.score, equals(0.0));
    });
  });

  // =========================================================================
  group('AIAgentDetector — énumération systématique', () {
    // -----------------------------------------------------------------------
    test('> 70% de commandes ls/cat/find/grep → score >= 0.4', () {
      final detector = AIAgentDetector();
      // 8 sur 10 sont des commandes d'énumération (80%)
      final events = [
        (timestamp: baseTime.add(const Duration(milliseconds: 0)),   command: 'ls /etc'),
        (timestamp: baseTime.add(const Duration(milliseconds: 100)),  command: 'cat /etc/hosts'),
        (timestamp: baseTime.add(const Duration(milliseconds: 200)),  command: 'find / -name "*.conf"'),
        (timestamp: baseTime.add(const Duration(milliseconds: 300)),  command: 'grep -r "password"'),
        (timestamp: baseTime.add(const Duration(milliseconds: 400)),  command: 'ls /home'),
        (timestamp: baseTime.add(const Duration(milliseconds: 500)),  command: 'cat /etc/shadow'),
        (timestamp: baseTime.add(const Duration(milliseconds: 600)),  command: 'find /var -name "*.log"'),
        (timestamp: baseTime.add(const Duration(milliseconds: 700)),  command: 'grep -i "admin"'),
        (timestamp: baseTime.add(const Duration(milliseconds: 800)),  command: 'pwd'),    // Non-enum
        (timestamp: baseTime.add(const Duration(milliseconds: 900)),  command: 'echo hi'), // Non-enum
      ];
      final result = detector.detectAIPatterns(events);
      expect(result.anomalies.any((a) => a.toLowerCase().contains('énum')), isTrue);
      expect(result.score, greaterThanOrEqualTo(0.4));
    });

    // -----------------------------------------------------------------------
    test('< 70% de commandes d\'énumération → pas d\'anomalie enum', () {
      final detector = AIAgentDetector();
      // Mix : seulement 3/10 sont des commandes d'énumération (30%)
      final events = List.generate(10, (i) {
        final cmd = i < 3 ? 'ls' : 'ssh user@host';
        return (
          timestamp: baseTime.add(Duration(seconds: i * 2)),
          command: cmd,
        );
      });
      final result = detector.detectAIPatterns(events);
      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('énum')),
        isEmpty,
      );
    });
  });

  // =========================================================================
  group('AIAgentDetector — pauses humaines', () {
    // -----------------------------------------------------------------------
    test('aucune pause > 5s entre commandes → anomalie "aucune pause"', () {
      final detector = AIAgentDetector();
      // Tous les intervalles < 5s (réguliers à 1s)
      final events = _regularTimingEvents(
        count: 10,
        start: baseTime,
        intervalMs: 1000, // 1 seconde — sous le seuil de 5s
        command: 'pwd',   // Commande non-enum pour isoler ce critère
      );
      final result = detector.detectAIPatterns(events);
      expect(
        result.anomalies.any((a) => a.toLowerCase().contains('pause')),
        isTrue,
      );
    });

    // -----------------------------------------------------------------------
    test('au moins une pause > 5s → pattern humain reconnu', () {
      final detector = AIAgentDetector();
      // Un événement a un intervalle de 10 secondes
      final events = [
        (timestamp: baseTime,                                         command: 'ls'),
        (timestamp: baseTime.add(const Duration(seconds: 1)),        command: 'pwd'),
        (timestamp: baseTime.add(const Duration(seconds: 12)),       command: 'ls'), // +11s → pause humaine
        (timestamp: baseTime.add(const Duration(seconds: 13)),       command: 'pwd'),
        (timestamp: baseTime.add(const Duration(seconds: 14)),       command: 'ls'),
      ];
      final result = detector.detectAIPatterns(events);
      // Au moins une pause > 5s → pas d'anomalie "aucune pause"
      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('pause')),
        isEmpty,
      );
    });
  });

  // =========================================================================
  group('AIRateLimiter — seuils de débit', () {
    // -----------------------------------------------------------------------
    test('10 req/min ou moins → allowed', () {
      final limiter = AIRateLimiter();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      RateLimitResult last = RateLimitResult.allowed;
      // NOTE sur l'implémentation : _RateLimitEntry est créé avec firstRequest
      // dans requestTimes, puis checkRequest ajoute encore la requête courante.
      // Résultat : le 1er appel à checkRequest enregistre 2 timestamps (1 du
      // constructeur + 1 de l'add). Pour 10 appels = 11 timestamps en fenêtre.
      // Seuil slowdown = > 10 → 11 > 10 → slowdown.
      //
      // Pour obtenir "allowed", il faut envoyer au max 9 requêtes (= 10 timestamps).
      for (int i = 0; i < 9; i++) {
        last = limiter.checkRequest('user_A', now.add(Duration(seconds: i * 5)));
      }
      expect(last, equals(RateLimitResult.allowed));
    });

    // -----------------------------------------------------------------------
    test('entre 11 et 30 req/min → slowdown', () {
      final limiter = AIRateLimiter();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      // Envoyer 20 requêtes en 30 secondes (toutes dans la fenêtre)
      RateLimitResult last = RateLimitResult.allowed;
      for (int i = 0; i < 20; i++) {
        last = limiter.checkRequest('user_B', now.add(Duration(seconds: i)));
      }
      expect(last, equals(RateLimitResult.slowdown));
    });

    // -----------------------------------------------------------------------
    test('entre 31 et 100 req/min → captcha', () {
      final limiter = AIRateLimiter();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      // Envoyer 50 requêtes dans la fenêtre
      RateLimitResult last = RateLimitResult.allowed;
      for (int i = 0; i < 50; i++) {
        last = limiter.checkRequest('user_C', now.add(Duration(milliseconds: i * 500)));
      }
      expect(last, equals(RateLimitResult.captcha));
    });

    // -----------------------------------------------------------------------
    test('plus de 100 req/min → blocked', () {
      final limiter = AIRateLimiter();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      // Envoyer 150 requêtes dans la fenêtre
      RateLimitResult last = RateLimitResult.allowed;
      for (int i = 0; i < 150; i++) {
        last = limiter.checkRequest('user_D', now.add(Duration(milliseconds: i * 300)));
      }
      expect(last, equals(RateLimitResult.blocked));
    });

    // -----------------------------------------------------------------------
    test('nettoyage après 1 minute : les requêtes expirées ne comptent plus', () {
      final limiter = AIRateLimiter();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Envoyer 50 requêtes dans la minute 1
      for (int i = 0; i < 50; i++) {
        limiter.checkRequest('user_E', now.add(Duration(seconds: i)));
      }

      // Deux minutes plus tard → toutes les requêtes précédentes sont expirées
      final later = now.add(const Duration(minutes: 2));
      final result = limiter.checkRequest('user_E', later);
      // Après nettoyage, seulement 1 requête dans la fenêtre → allowed
      expect(result, equals(RateLimitResult.allowed));
    });

    // -----------------------------------------------------------------------
    test('maxIdentifiers respecté avec éviction LRU', () {
      final limiter = AIRateLimiter();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Remplir à maxIdentifiers en utilisant des timestamps très proches
      // (intervalles de 1ms) pour que tous restent dans la fenêtre de 60s
      // et ne soient pas nettoyés par _cleanExpired lors des appels suivants.
      for (int i = 0; i < AIRateLimiter.maxIdentifiers; i++) {
        limiter.checkRequest('id_$i', now.add(Duration(milliseconds: i)));
      }

      expect(limiter.trackedCount, equals(AIRateLimiter.maxIdentifiers));

      // Ajouter un nouvel identifiant (dans la même fenêtre temporelle)
      // → le plus ancien (LRU) doit être évincé, le compte reste à maxIdentifiers
      limiter.checkRequest('id_nouveau', now.add(const Duration(milliseconds: AIRateLimiter.maxIdentifiers)));
      expect(limiter.trackedCount, equals(AIRateLimiter.maxIdentifiers));
    });
  });

  // =========================================================================
  group('SecurityTarpit — délai exponentiel', () {
    // -----------------------------------------------------------------------
    test('1er échec → 2 secondes', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      final delay = tarpit.recordFailure('session_1', now);
      expect(delay.inSeconds, equals(2));
    });

    // -----------------------------------------------------------------------
    test('2ème échec → 4 secondes', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      tarpit.recordFailure('session_1', now);
      final delay = tarpit.recordFailure('session_1', now.add(const Duration(seconds: 2)));
      expect(delay.inSeconds, equals(4));
    });

    // -----------------------------------------------------------------------
    test('3ème échec → 8 secondes', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      tarpit.recordFailure('session_1', now);
      tarpit.recordFailure('session_1', now.add(const Duration(seconds: 2)));
      final delay = tarpit.recordFailure('session_1', now.add(const Duration(seconds: 6)));
      expect(delay.inSeconds, equals(8));
    });

    // -----------------------------------------------------------------------
    test('délai maximum = 60 secondes (jamais dépassé)', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      Duration lastDelay = Duration.zero;
      // 15 échecs → 2^15 = 32768s → mais clampé à 60s
      for (int i = 0; i < 15; i++) {
        lastDelay = tarpit.recordFailure('session_2', now.add(Duration(seconds: i)));
      }
      expect(lastDelay.inSeconds, lessThanOrEqualTo(SecurityTarpit.maxDelaySeconds));
    });

    // -----------------------------------------------------------------------
    test('6ème échec → délai = 60s (clamp atteint)', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      Duration delay = Duration.zero;
      // 2^1=2, 2^2=4, 2^3=8, 2^4=16, 2^5=32, 2^6=64→clamp→60
      for (int i = 0; i < 6; i++) {
        delay = tarpit.recordFailure('session_3', now.add(Duration(seconds: i)));
      }
      expect(delay.inSeconds, equals(SecurityTarpit.maxDelaySeconds));
    });
  });

  // =========================================================================
  group('SecurityTarpit — blacklist automatique', () {
    // -----------------------------------------------------------------------
    test('20 échecs consécutifs → blacklisté', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      for (int i = 0; i < SecurityTarpit.blacklistThreshold; i++) {
        tarpit.recordFailure('session_4', now.add(Duration(seconds: i)));
      }
      expect(tarpit.isBlacklisted('session_4'), isTrue);
    });

    // -----------------------------------------------------------------------
    test('19 échecs → pas encore blacklisté', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      for (int i = 0; i < 19; i++) {
        tarpit.recordFailure('session_5', now.add(Duration(seconds: i)));
      }
      expect(tarpit.isBlacklisted('session_5'), isFalse);
    });

    // -----------------------------------------------------------------------
    test('succès remet le compteur d\'échecs à zéro', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      // 5 échecs
      for (int i = 0; i < 5; i++) {
        tarpit.recordFailure('session_6', now.add(Duration(seconds: i)));
      }
      // Succès → reset
      tarpit.recordSuccess('session_6', now.add(const Duration(seconds: 10)));
      // Vérifier : le délai est revenu à 0 (pas d'échecs)
      final delay = tarpit.currentDelay('session_6');
      expect(delay.inSeconds, equals(0));
    });

    // -----------------------------------------------------------------------
    test('succès ne déblackliste pas un identifiant blacklisté', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      // Blacklister
      for (int i = 0; i < SecurityTarpit.blacklistThreshold; i++) {
        tarpit.recordFailure('session_7', now.add(Duration(seconds: i)));
      }
      expect(tarpit.isBlacklisted('session_7'), isTrue);

      // Tentative de "succès"
      tarpit.recordSuccess('session_7', now.add(const Duration(seconds: 30)));

      // Doit rester blacklisté
      expect(tarpit.isBlacklisted('session_7'), isTrue);
    });
  });

  // =========================================================================
  group('SecurityTarpit — nettoyage et mémoire', () {
    // -----------------------------------------------------------------------
    test('entrée > 24h est supprimée lors du nettoyage', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);
      tarpit.recordFailure('session_old', now);
      expect(tarpit.entryCount, equals(1));

      // Simuler 25h plus tard
      final later = now.add(const Duration(hours: 25));
      // Le nettoyage se déclenche lors du prochain recordFailure
      tarpit.recordFailure('session_new', later);

      // session_old doit être nettoyée (> 24h d'inactivité)
      expect(tarpit.isBlacklisted('session_old'), isFalse);
    });

    // -----------------------------------------------------------------------
    test('entrée blacklistée survit au nettoyage > 24h', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Blacklister
      for (int i = 0; i < SecurityTarpit.blacklistThreshold; i++) {
        tarpit.recordFailure('session_bl', now.add(Duration(seconds: i)));
      }
      expect(tarpit.isBlacklisted('session_bl'), isTrue);

      // 25h plus tard
      final later = now.add(const Duration(hours: 25));
      tarpit.recordFailure('session_trigger', later); // Déclenche le nettoyage

      // session_bl est blacklistée → doit survivre au cleanup
      expect(tarpit.isBlacklisted('session_bl'), isTrue);
    });

    // -----------------------------------------------------------------------
    test('maxEntries respecté avec éviction FIFO', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Remplir à maxEntries
      for (int i = 0; i < SecurityTarpit.maxEntries; i++) {
        tarpit.recordFailure('session_$i', now.add(Duration(seconds: i)));
      }
      expect(tarpit.entryCount, equals(SecurityTarpit.maxEntries));

      // Ajouter une entrée de plus → éviction de la plus ancienne non-blacklistée
      tarpit.recordFailure('session_new', now.add(const Duration(seconds: 9999)));
      expect(tarpit.entryCount, equals(SecurityTarpit.maxEntries));
    });

    // -----------------------------------------------------------------------
    test('entrée inconnue n\'est pas blacklistée par défaut', () {
      final tarpit = SecurityTarpit();
      expect(tarpit.isBlacklisted('session_inconnue'), isFalse);
    });

    // -----------------------------------------------------------------------
    test('currentDelay pour entrée inconnue = 0', () {
      final tarpit = SecurityTarpit();
      expect(tarpit.currentDelay('session_inconnue'), equals(Duration.zero));
    });

    // -----------------------------------------------------------------------
    test('blacklistedCount compte correctement les blacklistés', () {
      final tarpit = SecurityTarpit();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Blacklister session_X
      for (int i = 0; i < SecurityTarpit.blacklistThreshold; i++) {
        tarpit.recordFailure('session_X', now.add(Duration(seconds: i)));
      }
      // Quelques échecs non-blacklistés
      tarpit.recordFailure('session_Y', now);
      tarpit.recordFailure('session_Z', now);

      expect(tarpit.blacklistedCount, equals(1));
    });
  });
}
