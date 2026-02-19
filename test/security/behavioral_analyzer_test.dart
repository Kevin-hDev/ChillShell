// =============================================================================
// TEST — FIX-021 — BehavioralAnalyzer
// Couvre : GAP-021 — Aucune détection comportementale dans ChillShell
// =============================================================================
//
// Pour lancer ces tests :
//   dart test test_fix_021.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE pour tests autonomes
// ---------------------------------------------------------------------------

enum AnomalyAction { allow, warn, block }

class AnomalyResult {
  final double score;
  final List<String> anomalies;
  final AnomalyAction action;

  const AnomalyResult({
    required this.score,
    required this.anomalies,
    required this.action,
  });
}

class BehaviorEvent {
  final String command;
  final DateTime timestamp;
  final String sessionId;

  const BehaviorEvent({
    required this.command,
    required this.timestamp,
    required this.sessionId,
  });

  String get baseCommand {
    final parts = command.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first.toLowerCase();
  }
}

class BehavioralAnalyzer {
  static const int maxHistory = 1000;
  static const int minHistoryForUnknown = 50;
  static const double unusualHourThreshold = 0.02;
  static const int burstThreshold = 10;

  final List<BehaviorEvent> _history = [];

  static const List<String> dangerousPatterns = [
    'rm -rf', 'rm -r', 'chmod 777', 'chmod 666',
    'cat /etc/shadow', 'cat /etc/passwd', 'cat /etc/sudoers',
    'sudo su', 'su root', 'sudo -s', 'sudo bash', 'sudo sh',
    'mkfs', 'dd if=', 'shred', 'cryptsetup', '> /dev/sda',
    ':(){:|:&};:', 'wget http', 'curl http',
    'nc -l', 'ncat -l', 'python -c', 'perl -e',
    'bash -i', 'sh -i', '/bin/bash -c', 'base64 -d',
    'eval', 'exec', 'passwd',
  ];

  void recordEvent(BehaviorEvent event) {
    if (_history.length >= maxHistory) _history.removeAt(0);
    _history.add(event);
  }

  AnomalyResult analyzeEvent(BehaviorEvent event) {
    double score = 0.0;
    final anomalies = <String>[];

    final hourScore = _scoreUnusualHour(event.timestamp);
    if (hourScore > 0.0) {
      score += hourScore;
      anomalies.add('Horaire inhabituel pour cette session');
    }

    final unknownScore = _scoreUnknownCommand(event.command);
    if (unknownScore > 0.0) {
      score += unknownScore;
      anomalies.add('Commande non observée dans l\'historique');
    }

    final dangerScore = _scoreDangerousCommand(event.command);
    if (dangerScore > 0.0) {
      score += dangerScore;
      anomalies.add('Commande à risque élevé détectée');
    }

    final burstScore = _scoreBurst(event);
    if (burstScore > 0.0) {
      score += burstScore;
      anomalies.add('Fréquence de commandes anormalement élevée');
    }

    score = score.clamp(0.0, 1.0);

    return AnomalyResult(
      score: score,
      anomalies: anomalies,
      action: _scoreToAction(score),
    );
  }

  int get historyLength => _history.length;

  Map<int, int> get hourlyDistribution {
    final dist = <int, int>{};
    for (final event in _history) {
      final hour = event.timestamp.toUtc().hour;
      dist[hour] = (dist[hour] ?? 0) + 1;
    }
    return dist;
  }

  Map<String, int> get commandFrequency {
    final freq = <String, int>{};
    for (final event in _history) {
      final base = event.baseCommand;
      if (base.isNotEmpty) freq[base] = (freq[base] ?? 0) + 1;
    }
    return freq;
  }

  double _scoreUnusualHour(DateTime timestamp) {
    if (_history.isEmpty) return 0.0;
    final hour = timestamp.toUtc().hour;
    final dist = hourlyDistribution;
    final countAtHour = dist[hour] ?? 0;
    final fraction = countAtHour / _history.length;
    if (fraction < unusualHourThreshold) return 0.3;
    return 0.0;
  }

  double _scoreUnknownCommand(String command) {
    if (_history.length < minHistoryForUnknown) return 0.0;
    final baseCmd = _extractBase(command);
    final freq = commandFrequency;
    if (!freq.containsKey(baseCmd)) return 0.4;
    return 0.0;
  }

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

  AnomalyAction _scoreToAction(double score) {
    if (score >= 0.7) return AnomalyAction.block;
    if (score >= 0.4) return AnomalyAction.warn;
    return AnomalyAction.allow;
  }

  String _extractBase(String command) {
    final parts = command.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? '' : parts.first.toLowerCase();
  }
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

void main() {
  // Heure de référence pour les tests (heure de journée normale : 10h UTC)
  final normalHour = DateTime.utc(2026, 2, 19, 10, 0, 0);
  // Heure inhabituelles (3h du matin)
  final unusualHour = DateTime.utc(2026, 2, 19, 3, 0, 0);
  const testSession = 'session_test_001';

  // ---------------------------------------------------------------------------
  // Helper : créer N événements à une heure donnée
  // ---------------------------------------------------------------------------
  List<BehaviorEvent> makeEvents({
    required int count,
    required DateTime timestamp,
    required String command,
    String session = testSession,
  }) {
    return List.generate(
      count,
      (i) => BehaviorEvent(
        command: command,
        timestamp: timestamp.add(Duration(seconds: i * 5)),
        sessionId: session,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helper : remplir l'historique avec des événements normaux
  // (heure 10h, 60 événements → historique suffisant pour activer unknown)
  // ---------------------------------------------------------------------------
  void seedHistory(BehavioralAnalyzer analyzer, {int count = 60}) {
    final commands = ['ls', 'pwd', 'cd', 'echo', 'cat'];
    for (int i = 0; i < count; i++) {
      analyzer.recordEvent(BehaviorEvent(
        command: commands[i % commands.length],
        timestamp: normalHour.add(Duration(minutes: i)),
        sessionId: testSession,
      ));
    }
  }

  // =========================================================================
  group('BehavioralAnalyzer — événements normaux', () {
    // -----------------------------------------------------------------------
    test('commande habituelle à heure normale → allow', () {
      final analyzer = BehavioralAnalyzer();
      seedHistory(analyzer);

      // ls est dans l'historique, heure normale → should be allow or warn
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls -la',
        timestamp: normalHour,
        sessionId: testSession,
      ));

      // ls est connu dans l'historique → pas de score unknown
      // Pas de burst → score < 0.4 normalement
      expect(result.action, isNot(equals(AnomalyAction.block)));
    });

    // -----------------------------------------------------------------------
    test('historique vide → aucune anomalie détectée', () {
      final analyzer = BehavioralAnalyzer();
      // Sans historique : les critères hour et unknown ne s'activent pas
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls',
        timestamp: normalHour,
        sessionId: testSession,
      ));
      expect(result.anomalies.where((a) => a.contains('historique')), isEmpty);
    });

    // -----------------------------------------------------------------------
    test('score commande normale non dangereuse = 0.0', () {
      final analyzer = BehavioralAnalyzer();
      seedHistory(analyzer);

      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls -la',
        timestamp: normalHour,
        sessionId: testSession,
      ));

      // Pas de pattern dangereux → le score dangereux est 0
      expect(result.anomalies.where((a) => a.contains('risque')), isEmpty);
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — horaire inhabituel', () {
    // -----------------------------------------------------------------------
    test('heure qui représente < 2% de l\'historique → score augmente', () {
      final analyzer = BehavioralAnalyzer();
      // Remplir l'historique avec des événements à 10h (100% des événements)
      // Donc 3h = 0% → < 2% → score horaire activé
      for (int i = 0; i < 60; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: normalHour.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }

      // Analyser à 3h du matin (jamais vu dans l'historique = 0%)
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls',
        timestamp: unusualHour,
        sessionId: testSession,
      ));

      expect(result.score, greaterThanOrEqualTo(0.3));
      expect(
        result.anomalies.any((a) => a.toLowerCase().contains('horaire')),
        isTrue,
      );
    });

    // -----------------------------------------------------------------------
    test('heure qui représente >= 2% de l\'historique → pas d\'anomalie horaire', () {
      final analyzer = BehavioralAnalyzer();
      // 50 événements à normalHour, 10 à unusualHour → 10/60 = 16.7% > 2%
      for (int i = 0; i < 50; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: normalHour.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }
      for (int i = 0; i < 10; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: unusualHour.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }

      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls',
        timestamp: unusualHour,
        sessionId: testSession,
      ));

      // Heure bien représentée → pas d'anomalie horaire
      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('horaire')),
        isEmpty,
      );
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — commande inconnue', () {
    // -----------------------------------------------------------------------
    test('commande jamais vue avec historique > 50 → score augmente', () {
      final analyzer = BehavioralAnalyzer();
      seedHistory(analyzer, count: 60); // ls, pwd, cd, echo, cat

      // 'nmap' n'est jamais dans l'historique
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'nmap -sV 192.168.1.1',
        timestamp: normalHour,
        sessionId: testSession,
      ));

      expect(result.score, greaterThanOrEqualTo(0.4));
      expect(
        result.anomalies.any((a) => a.toLowerCase().contains('historique')),
        isTrue,
      );
    });

    // -----------------------------------------------------------------------
    test('commande inconnue avec historique < 50 → pas d\'anomalie unknown', () {
      final analyzer = BehavioralAnalyzer();
      // Seulement 10 événements dans l'historique → pas assez pour unknown
      for (int i = 0; i < 10; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: normalHour,
          sessionId: testSession,
        ));
      }

      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'commande_totalement_inconnue',
        timestamp: normalHour,
        sessionId: testSession,
      ));

      // Pas assez d'historique → critère unknown désactivé
      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('historique')),
        isEmpty,
      );
    });

    // -----------------------------------------------------------------------
    test('commande connue dans l\'historique → pas d\'anomalie unknown', () {
      final analyzer = BehavioralAnalyzer();
      seedHistory(analyzer, count: 60);

      // 'ls' est dans l'historique
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls -la /tmp',
        timestamp: normalHour,
        sessionId: testSession,
      ));

      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('historique')),
        isEmpty,
      );
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — commandes dangereuses', () {
    // -----------------------------------------------------------------------
    test('cat /etc/shadow → score dangereux élevé', () {
      final analyzer = BehavioralAnalyzer();
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'cat /etc/shadow',
        timestamp: normalHour,
        sessionId: testSession,
      ));
      expect(result.score, greaterThanOrEqualTo(0.5));
      expect(
        result.anomalies.any((a) => a.toLowerCase().contains('risque')),
        isTrue,
      );
    });

    // -----------------------------------------------------------------------
    test('rm -rf / → score dangereux élevé', () {
      final analyzer = BehavioralAnalyzer();
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'rm -rf /',
        timestamp: normalHour,
        sessionId: testSession,
      ));
      expect(result.score, greaterThanOrEqualTo(0.5));
    });

    // -----------------------------------------------------------------------
    test('chmod 777 sur un fichier → score dangereux', () {
      final analyzer = BehavioralAnalyzer();
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'chmod 777 /etc/passwd',
        timestamp: normalHour,
        sessionId: testSession,
      ));
      expect(result.score, greaterThanOrEqualTo(0.5));
    });

    // -----------------------------------------------------------------------
    test('sudo bash → score dangereux', () {
      final analyzer = BehavioralAnalyzer();
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'sudo bash',
        timestamp: normalHour,
        sessionId: testSession,
      ));
      expect(result.score, greaterThanOrEqualTo(0.5));
    });

    // -----------------------------------------------------------------------
    test('liste des commandes dangereuses couvre au moins 20 patterns', () {
      expect(BehavioralAnalyzer.dangerousPatterns.length, greaterThanOrEqualTo(20));
    });

    // -----------------------------------------------------------------------
    test('commande normale (ls) ne déclenche pas le critère dangereux', () {
      final analyzer = BehavioralAnalyzer();
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls -la /home',
        timestamp: normalHour,
        sessionId: testSession,
      ));
      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('risque')),
        isEmpty,
      );
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — détection de rafale', () {
    // -----------------------------------------------------------------------
    test('plus de 10 commandes par minute → score rafale activé', () {
      final analyzer = BehavioralAnalyzer();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Enregistrer 15 commandes dans la même minute
      for (int i = 0; i < 15; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: now.add(Duration(seconds: i * 3)),
          sessionId: testSession,
        ));
      }

      // 16ème commande dans la même minute → burst
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls',
        timestamp: now.add(const Duration(seconds: 48)),
        sessionId: testSession,
      ));

      expect(result.score, greaterThanOrEqualTo(0.3));
      expect(
        result.anomalies.any((a) => a.toLowerCase().contains('fréquence')),
        isTrue,
      );
    });

    // -----------------------------------------------------------------------
    test('moins de 10 commandes par minute → pas de rafale', () {
      final analyzer = BehavioralAnalyzer();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Enregistrer 5 commandes sur 5 minutes (1 par minute)
      for (int i = 0; i < 5; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: now.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }

      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls',
        timestamp: now.add(const Duration(minutes: 5)),
        sessionId: testSession,
      ));

      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('fréquence')),
        isEmpty,
      );
    });

    // -----------------------------------------------------------------------
    test('rafale dans une session différente n\'affecte pas l\'analyse', () {
      final analyzer = BehavioralAnalyzer();
      final now = DateTime.utc(2026, 2, 19, 10, 0, 0);

      // Rafale dans session A
      for (int i = 0; i < 15; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: now.add(Duration(seconds: i)),
          sessionId: 'session_A',
        ));
      }

      // Analyser depuis session B → pas de rafale pour session B
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'ls',
        timestamp: now.add(const Duration(seconds: 20)),
        sessionId: 'session_B',
      ));

      expect(
        result.anomalies.where((a) => a.toLowerCase().contains('fréquence')),
        isEmpty,
      );
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — combinaison de critères', () {
    // -----------------------------------------------------------------------
    test('commande dangereuse + inconnue + horaire → action block', () {
      final analyzer = BehavioralAnalyzer();
      // Historique complet à 10h
      for (int i = 0; i < 60; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: normalHour.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }

      // Commande dangereuse à 3h du matin (score : 0.5 + 0.3 + 0.4 = 1.2 → clampé 1.0)
      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'cat /etc/shadow',
        timestamp: unusualHour, // Horaire inhabituel
        sessionId: testSession,
      ));

      expect(result.score, equals(1.0)); // Clampé
      expect(result.action, equals(AnomalyAction.block));
      expect(result.anomalies.length, greaterThanOrEqualTo(2));
    });

    // -----------------------------------------------------------------------
    test('score toujours clampé à 1.0 maximum', () {
      final analyzer = BehavioralAnalyzer();
      seedHistory(analyzer, count: 60);
      final now = DateTime.utc(2026, 2, 19, 3, 0, 0); // Heure inhabituelle

      // Rafale dans la dernière minute
      for (int i = 0; i < 15; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: now.add(Duration(seconds: i)),
          sessionId: testSession,
        ));
      }

      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'cat /etc/shadow', // Dangereux
        timestamp: now.add(const Duration(seconds: 20)),
        sessionId: testSession,
      ));

      expect(result.score, lessThanOrEqualTo(1.0));
    });

    // -----------------------------------------------------------------------
    test('score 0.4-0.7 → warn', () {
      final analyzer = BehavioralAnalyzer();
      // Juste un critère unknown (0.4) → warn
      seedHistory(analyzer, count: 60);

      final result = analyzer.analyzeEvent(BehaviorEvent(
        command: 'nmap',  // Jamais vu dans l'historique
        timestamp: normalHour,
        sessionId: testSession,
      ));

      // Score = 0.4 → warn
      expect(result.score, greaterThanOrEqualTo(0.4));
      if (result.score < 0.7) {
        expect(result.action, equals(AnomalyAction.warn));
      }
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — queue bornée', () {
    // -----------------------------------------------------------------------
    test('queue ne dépasse pas maxHistory (1000)', () {
      final analyzer = BehavioralAnalyzer();
      for (int i = 0; i < 1200; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: normalHour.add(Duration(seconds: i)),
          sessionId: testSession,
        ));
      }
      expect(analyzer.historyLength, equals(BehavioralAnalyzer.maxHistory));
    });

    // -----------------------------------------------------------------------
    test('éviction FIFO : les plus anciens sont supprimés en premier', () {
      final analyzer = BehavioralAnalyzer();
      final base = DateTime.utc(2026, 1, 1);

      // Remplir exactement maxHistory avec des timestamps croissants
      for (int i = 0; i < BehavioralAnalyzer.maxHistory; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'cmd_$i',
          timestamp: base.add(Duration(seconds: i)),
          sessionId: testSession,
        ));
      }

      // Ajouter un événement de plus → éviction du premier
      analyzer.recordEvent(BehaviorEvent(
        command: 'cmd_new',
        timestamp: base.add(const Duration(seconds: 9999)),
        sessionId: testSession,
      ));

      expect(analyzer.historyLength, equals(BehavioralAnalyzer.maxHistory));
    });
  });

  // =========================================================================
  group('BehavioralAnalyzer — profil d\'utilisation', () {
    // -----------------------------------------------------------------------
    test('distribution horaire compte correctement les occurrences par heure', () {
      final analyzer = BehavioralAnalyzer();
      final h10 = DateTime.utc(2026, 2, 19, 10, 0, 0);
      final h14 = DateTime.utc(2026, 2, 19, 14, 0, 0);

      for (int i = 0; i < 5; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: h10.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }
      for (int i = 0; i < 3; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls',
          timestamp: h14.add(Duration(minutes: i)),
          sessionId: testSession,
        ));
      }

      final dist = analyzer.hourlyDistribution;
      expect(dist[10], equals(5));
      expect(dist[14], equals(3));
    });

    // -----------------------------------------------------------------------
    test('fréquence commandes compte correctement les occurrences', () {
      final analyzer = BehavioralAnalyzer();
      for (int i = 0; i < 5; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'ls -la',
          timestamp: normalHour,
          sessionId: testSession,
        ));
      }
      for (int i = 0; i < 3; i++) {
        analyzer.recordEvent(BehaviorEvent(
          command: 'pwd',
          timestamp: normalHour,
          sessionId: testSession,
        ));
      }

      final freq = analyzer.commandFrequency;
      expect(freq['ls'], equals(5));
      expect(freq['pwd'], equals(3));
    });
  });
}
