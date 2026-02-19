// =============================================================================
// TEST — FIX-023 — TailscalePrivacy + TailscaleMonitor
// Couvre : GAP-023 — IPs/noms peers Tailscale affichés en clair
// =============================================================================
//
// Pour lancer ces tests :
//   dart test test_fix_023.dart
// ou (si dans le projet ChillShell) :
//   dart test test/security/test_fix_023.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE — classes du fichier fix_023_tailscale_privacy_monitor.dart
// (retirer si import disponible)
// ---------------------------------------------------------------------------

enum ConnectionEventType { connected, rejected, disconnected, attempt }

class ConnectionEvent {
  final String sourceIP;
  final String destIP;
  final DateTime timestamp;
  final ConnectionEventType type;

  const ConnectionEvent({
    required this.sourceIP,
    required this.destIP,
    required this.timestamp,
    required this.type,
  });
}

class RevealContext {
  final String requestedBy;
  final DateTime requestedAt;
  final bool userConfirmed;

  const RevealContext({
    required this.requestedBy,
    required this.requestedAt,
    required this.userConfirmed,
  });
}

class AclVerificationResult {
  final bool hasViolation;
  final List<String> unauthorizedPeers;
  final List<String> missingAuthorizedPeers;

  const AclVerificationResult({
    required this.hasViolation,
    required this.unauthorizedPeers,
    required this.missingAuthorizedPeers,
  });
}

class LateralMovementResult {
  final bool detected;
  final String pattern;
  final List<ConnectionEvent> suspiciousEvents;

  const LateralMovementResult({
    required this.detected,
    required this.pattern,
    required this.suspiciousEvents,
  });
}

class BotnetAnalysisResult {
  final bool detected;
  final String patternName;
  final int severity;
  final int suspiciousEventCount;

  const BotnetAnalysisResult({
    required this.detected,
    required this.patternName,
    required this.severity,
    required this.suspiciousEventCount,
  });
}

class TailscalePrivacy {
  static const int _tailscaleOctet1 = 100;
  static const int _tailscaleMinOctet2 = 64;
  static const int _tailscaleMaxOctet2 = 127;
  static const int _maxPeerNameDisplay = 12;
  static const String _ipMask = '***';
  static const String _nameSuffix = '***';

  TailscalePrivacy._();

  static bool isInTailscaleRange(String ip) {
    final parts = _parseIPv4(ip);
    if (parts == null) return false;
    return parts[0] == _tailscaleOctet1 &&
        parts[1] >= _tailscaleMinOctet2 &&
        parts[1] <= _tailscaleMaxOctet2;
  }

  static String maskIP(String ip) {
    if (ip.isEmpty) throw ArgumentError('L\'adresse IP ne peut pas être vide.');
    final parts = _parseIPv4(ip);
    if (parts == null) throw ArgumentError('Format IPv4 invalide.');
    if (!isInTailscaleRange(ip)) {
      throw ArgumentError('Adresse hors du range autorisé. Opération refusée.');
    }
    return '${parts[0]}.${parts[1]}.$_ipMask.$_ipMask';
  }

  static bool shouldRevealIP(String ip, RevealContext ctx) {
    if (!isInTailscaleRange(ip)) return false;
    if (ctx.requestedBy.trim().isEmpty) return false;
    if (!ctx.userConfirmed) return false;
    return true;
  }

  static String maskPeerName(String name) {
    if (name.isEmpty) return name;
    if (name.length <= _maxPeerNameDisplay) return name;
    return '${name.substring(0, _maxPeerNameDisplay)}$_nameSuffix';
  }

  static List<int>? _parseIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return null;
      octets.add(n);
    }
    return octets;
  }
}

class TailscaleMonitor {
  static const int _stalkerDistinctIPThreshold = 3;
  static const int _stalkerWindowSeconds = 60;
  static const int _maxConnectionsPerMinute = 5;
  static const int _lateralMovementThreshold = 4;

  const TailscaleMonitor();

  BotnetAnalysisResult checkForBotnetPatterns(List<ConnectionEvent> events) {
    if (events.isEmpty) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }
    final ayyResult = _detectAyySSHush(events);
    if (ayyResult.detected) return ayyResult;
    final stalkerResult = _detectSSHStalker(events);
    if (stalkerResult.detected) return stalkerResult;
    final burstResult = _detectBurstPattern(events);
    if (burstResult.detected) return burstResult;
    return const BotnetAnalysisResult(
      detected: false,
      patternName: 'none',
      severity: 0,
      suspiciousEventCount: 0,
    );
  }

  AclVerificationResult verifyACLConsistency(
    List<String> allowedPeers,
    List<String> connectedPeers,
  ) {
    if (allowedPeers.isEmpty && connectedPeers.isNotEmpty) {
      return AclVerificationResult(
        hasViolation: true,
        unauthorizedPeers: List.unmodifiable(connectedPeers),
        missingAuthorizedPeers: const [],
      );
    }
    final allowedSet = Set<String>.from(allowedPeers);
    final connectedSet = Set<String>.from(connectedPeers);
    final unauthorized =
        connectedSet.where((p) => !allowedSet.contains(p)).toList();
    final missing =
        allowedSet.where((p) => !connectedSet.contains(p)).toList();
    return AclVerificationResult(
      hasViolation: unauthorized.isNotEmpty,
      unauthorizedPeers: List.unmodifiable(unauthorized),
      missingAuthorizedPeers: List.unmodifiable(missing),
    );
  }

  LateralMovementResult checkForLateralMovement(List<ConnectionEvent> events) {
    if (events.isEmpty) {
      return const LateralMovementResult(
        detected: false,
        pattern: 'aucun événement',
        suspiciousEvents: [],
      );
    }
    final destsBySource = <String, Set<String>>{};
    for (final e in events) {
      destsBySource.putIfAbsent(e.sourceIP, () => {});
      destsBySource[e.sourceIP]!.add(e.destIP);
    }
    String? suspect;
    int maxDests = 0;
    for (final entry in destsBySource.entries) {
      if (entry.value.length > maxDests) {
        maxDests = entry.value.length;
        suspect = entry.key;
      }
    }
    if (suspect == null || maxDests <= _lateralMovementThreshold) {
      return const LateralMovementResult(
        detected: false,
        pattern: 'aucun mouvement latéral détecté',
        suspiciousEvents: [],
      );
    }
    final suspicious = events.where((e) => e.sourceIP == suspect).toList();
    return LateralMovementResult(
      detected: true,
      pattern: 'source unique vers $maxDests destinations distinctes',
      suspiciousEvents: List.unmodifiable(suspicious),
    );
  }

  BotnetAnalysisResult _detectAyySSHush(List<ConnectionEvent> events) {
    final suspicious =
        events.where((e) => !TailscalePrivacy.isInTailscaleRange(e.sourceIP)).toList();
    if (suspicious.isEmpty) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }
    return BotnetAnalysisResult(
      detected: true,
      patternName: 'AyySSHush',
      severity: 3,
      suspiciousEventCount: suspicious.length,
    );
  }

  BotnetAnalysisResult _detectSSHStalker(List<ConnectionEvent> events) {
    if (events.length < _stalkerDistinctIPThreshold) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }
    final sorted = List<ConnectionEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (int i = 0; i < sorted.length; i++) {
      final windowStart = sorted[i].timestamp;
      final windowEnd =
          windowStart.add(const Duration(seconds: _stalkerWindowSeconds));
      final inWindow = sorted
          .skip(i)
          .takeWhile((e) =>
              e.timestamp.isBefore(windowEnd) ||
              e.timestamp.isAtSameMomentAs(windowEnd))
          .toList();
      final distinctDests = inWindow.map((e) => e.destIP).toSet();
      if (distinctDests.length >= _stalkerDistinctIPThreshold) {
        return BotnetAnalysisResult(
          detected: true,
          patternName: 'SSHStalker',
          severity: 2,
          suspiciousEventCount: inWindow.length,
        );
      }
    }
    return const BotnetAnalysisResult(
      detected: false,
      patternName: 'none',
      severity: 0,
      suspiciousEventCount: 0,
    );
  }

  BotnetAnalysisResult _detectBurstPattern(List<ConnectionEvent> events) {
    if (events.length <= _maxConnectionsPerMinute) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }
    final sorted = List<ConnectionEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    for (int i = 0; i < sorted.length; i++) {
      final windowStart = sorted[i].timestamp;
      final windowEnd = windowStart.add(const Duration(minutes: 1));
      final inWindow = sorted
          .skip(i)
          .takeWhile((e) =>
              e.timestamp.isBefore(windowEnd) ||
              e.timestamp.isAtSameMomentAs(windowEnd))
          .toList();
      if (inWindow.length > _maxConnectionsPerMinute) {
        return BotnetAnalysisResult(
          detected: true,
          patternName: 'BurstPattern',
          severity: 1,
          suspiciousEventCount: inWindow.length,
        );
      }
    }
    return const BotnetAnalysisResult(
      detected: false,
      patternName: 'none',
      severity: 0,
      suspiciousEventCount: 0,
    );
  }
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

void main() {
  // Référence de temps fixe pour les tests — évite la dépendance à l'horloge
  final baseTime = DateTime(2026, 2, 19, 10, 0, 0);

  // IPs de test dans le range Tailscale valide (100.64.0.0/10)
  const validIP1 = '100.64.42.7';
  const validIP2 = '100.127.255.1';
  const validIP3 = '100.64.0.1';

  // IPs hors range Tailscale
  const outsideIP1 = '192.168.1.1';
  const outsideIP2 = '10.0.0.1';
  const outsideIP3 = '100.63.255.255'; // juste en dessous du range
  const outsideIP4 = '100.128.0.0';   // juste au dessus du range

  final monitor = TailscaleMonitor();

  // ===========================================================================
  group('TailscalePrivacy — isInTailscaleRange()', () {
    // -------------------------------------------------------------------------
    test('100.64.42.7 est dans le range Tailscale', () {
      expect(TailscalePrivacy.isInTailscaleRange(validIP1), isTrue);
    });

    // -------------------------------------------------------------------------
    test('100.127.255.1 est dans le range Tailscale (limite haute)', () {
      expect(TailscalePrivacy.isInTailscaleRange(validIP2), isTrue);
    });

    // -------------------------------------------------------------------------
    test('100.64.0.1 est dans le range Tailscale (limite basse)', () {
      expect(TailscalePrivacy.isInTailscaleRange(validIP3), isTrue);
    });

    // -------------------------------------------------------------------------
    test('192.168.1.1 est hors range Tailscale', () {
      expect(TailscalePrivacy.isInTailscaleRange(outsideIP1), isFalse);
    });

    // -------------------------------------------------------------------------
    test('10.0.0.1 est hors range Tailscale', () {
      expect(TailscalePrivacy.isInTailscaleRange(outsideIP2), isFalse);
    });

    // -------------------------------------------------------------------------
    test('100.63.255.255 est juste sous le range — rejeté', () {
      expect(TailscalePrivacy.isInTailscaleRange(outsideIP3), isFalse);
    });

    // -------------------------------------------------------------------------
    test('100.128.0.0 est juste au dessus du range — rejeté', () {
      expect(TailscalePrivacy.isInTailscaleRange(outsideIP4), isFalse);
    });

    // -------------------------------------------------------------------------
    test('IP malformée retourne false', () {
      expect(TailscalePrivacy.isInTailscaleRange('pas-une-ip'), isFalse);
      expect(TailscalePrivacy.isInTailscaleRange('100.64'), isFalse);
      expect(TailscalePrivacy.isInTailscaleRange(''), isFalse);
    });
  });

  // ===========================================================================
  group('TailscalePrivacy — maskIP()', () {
    // -------------------------------------------------------------------------
    test('maskIP masque correctement les deux derniers octets', () {
      expect(TailscalePrivacy.maskIP(validIP1), equals('100.64.***.***'));
    });

    // -------------------------------------------------------------------------
    test('maskIP préserve les deux premiers octets (100.64)', () {
      final result = TailscalePrivacy.maskIP(validIP1);
      expect(result, startsWith('100.64.'));
    });

    // -------------------------------------------------------------------------
    test('maskIP masque une IP à la limite haute du range', () {
      expect(TailscalePrivacy.maskIP(validIP2), equals('100.127.***.***'));
    });

    // -------------------------------------------------------------------------
    test('maskIP refuse les IPs hors range Tailscale', () {
      expect(
        () => TailscalePrivacy.maskIP(outsideIP1),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('maskIP refuse 10.0.0.1 (hors range)', () {
      expect(
        () => TailscalePrivacy.maskIP(outsideIP2),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('maskIP refuse une IP vide', () {
      expect(
        () => TailscalePrivacy.maskIP(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('maskIP refuse une IP malformée', () {
      expect(
        () => TailscalePrivacy.maskIP('100.64.abc.def'),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('message d\'erreur de maskIP ne contient pas l\'IP originale', () {
      try {
        TailscalePrivacy.maskIP(outsideIP1);
        fail('Devrait lever ArgumentError');
      } on ArgumentError catch (e) {
        // L'erreur ne doit pas contenir l'IP (192.168.1.1)
        expect(e.message.toString(), isNot(contains('192.168')));
      }
    });
  });

  // ===========================================================================
  group('TailscalePrivacy — maskPeerName()', () {
    // -------------------------------------------------------------------------
    test('maskPeerName ne tronque pas un nom court (≤ 12 chars)', () {
      expect(TailscalePrivacy.maskPeerName('laptop'), equals('laptop'));
      expect(TailscalePrivacy.maskPeerName('mon-pc'), equals('mon-pc'));
    });

    // -------------------------------------------------------------------------
    test('maskPeerName tronque exactement à 12 chars + ***', () {
      const longName = 'mon-serveur-linux-prod';
      final result = TailscalePrivacy.maskPeerName(longName);
      expect(result, equals('mon-serveur-***'));
      expect(result.substring(0, 12), equals('mon-serveur-'));
    });

    // -------------------------------------------------------------------------
    test('maskPeerName ne tronque pas un nom de exactement 12 chars', () {
      const exactName = 'mon-serveur-'; // 12 chars pile
      expect(TailscalePrivacy.maskPeerName(exactName), equals(exactName));
    });

    // -------------------------------------------------------------------------
    test('maskPeerName tronque un nom de 13+ chars', () {
      const name13 = 'abcdefghijklm'; // 13 chars
      expect(TailscalePrivacy.maskPeerName(name13), equals('abcdefghijkl***'));
    });

    // -------------------------------------------------------------------------
    test('maskPeerName retourne vide si nom vide', () {
      expect(TailscalePrivacy.maskPeerName(''), equals(''));
    });
  });

  // ===========================================================================
  group('TailscalePrivacy — shouldRevealIP()', () {
    // -------------------------------------------------------------------------
    test('shouldRevealIP retourne true avec confirmation et IP valide', () {
      final ctx = RevealContext(
        requestedBy: 'user',
        requestedAt: baseTime,
        userConfirmed: true,
      );
      expect(TailscalePrivacy.shouldRevealIP(validIP1, ctx), isTrue);
    });

    // -------------------------------------------------------------------------
    test('shouldRevealIP retourne false sans confirmation utilisateur', () {
      final ctx = RevealContext(
        requestedBy: 'user',
        requestedAt: baseTime,
        userConfirmed: false,  // Pas de confirmation
      );
      expect(TailscalePrivacy.shouldRevealIP(validIP1, ctx), isFalse);
    });

    // -------------------------------------------------------------------------
    test('shouldRevealIP retourne false avec IP hors range Tailscale', () {
      final ctx = RevealContext(
        requestedBy: 'user',
        requestedAt: baseTime,
        userConfirmed: true,
      );
      expect(TailscalePrivacy.shouldRevealIP(outsideIP1, ctx), isFalse);
    });

    // -------------------------------------------------------------------------
    test('shouldRevealIP retourne false avec demandeur vide', () {
      final ctx = RevealContext(
        requestedBy: '   ',  // Seulement des espaces
        requestedAt: baseTime,
        userConfirmed: true,
      );
      expect(TailscalePrivacy.shouldRevealIP(validIP1, ctx), isFalse);
    });

    // -------------------------------------------------------------------------
    test('shouldRevealIP retourne false si demandeur est chaîne vide', () {
      final ctx = RevealContext(
        requestedBy: '',
        requestedAt: baseTime,
        userConfirmed: true,
      );
      expect(TailscalePrivacy.shouldRevealIP(validIP1, ctx), isFalse);
    });
  });

  // ===========================================================================
  group('TailscaleMonitor — Détection AyySSHush (IP hors range)', () {
    // -------------------------------------------------------------------------
    test('AyySSHush détecté : source IP hors range Tailscale', () {
      final events = [
        ConnectionEvent(
          sourceIP: outsideIP1,  // 192.168.1.1 — hors range
          destIP: validIP1,
          timestamp: baseTime,
          type: ConnectionEventType.connected,
        ),
      ];

      final result = monitor.checkForBotnetPatterns(events);
      expect(result.detected, isTrue);
      expect(result.patternName, equals('AyySSHush'));
      expect(result.severity, equals(3));
    });

    // -------------------------------------------------------------------------
    test('AyySSHush non détecté : toutes les sources dans le range', () {
      final events = [
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: validIP2,
          timestamp: baseTime,
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP2,
          destIP: validIP3,
          timestamp: baseTime.add(const Duration(seconds: 5)),
          type: ConnectionEventType.connected,
        ),
      ];

      final result = monitor.checkForBotnetPatterns(events);
      expect(result.patternName, isNot(equals('AyySSHush')));
    });
  });

  // ===========================================================================
  group('TailscaleMonitor — Détection SSHStalker (sessions multiples rapides)', () {
    // -------------------------------------------------------------------------
    test('SSHStalker détecté : 3 IPs différentes en moins de 60 secondes', () {
      final events = [
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.10.1',
          timestamp: baseTime,
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.10.2',
          timestamp: baseTime.add(const Duration(seconds: 20)),
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.10.3',
          timestamp: baseTime.add(const Duration(seconds: 40)),
          type: ConnectionEventType.connected,
        ),
      ];

      final result = monitor.checkForBotnetPatterns(events);
      expect(result.detected, isTrue);
      expect(result.patternName, equals('SSHStalker'));
      expect(result.severity, equals(2));
    });

    // -------------------------------------------------------------------------
    test('SSHStalker non détecté : connexions espacées de plus de 60 secondes', () {
      final events = [
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.10.1',
          timestamp: baseTime,
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.10.2',
          timestamp: baseTime.add(const Duration(minutes: 5)),
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.10.3',
          timestamp: baseTime.add(const Duration(minutes: 10)),
          type: ConnectionEventType.connected,
        ),
      ];

      final result = monitor.checkForBotnetPatterns(events);
      // Les connexions sont espacées — pas de SSHStalker
      expect(result.patternName, isNot(equals('SSHStalker')));
    });
  });

  // ===========================================================================
  group('TailscaleMonitor — Détection BurstPattern (rafale)', () {
    // -------------------------------------------------------------------------
    test('BurstPattern détecté : 6 connexions en moins de 1 minute', () {
      // 6 connexions vers la même destination — rafale
      final events = List.generate(
        6,
        (i) => ConnectionEvent(
          sourceIP: validIP1,
          destIP: validIP2,
          timestamp: baseTime.add(Duration(seconds: i * 5)),
          type: ConnectionEventType.connected,
        ),
      );

      final result = monitor.checkForBotnetPatterns(events);
      expect(result.detected, isTrue);
      expect(result.patternName, equals('BurstPattern'));
      expect(result.severity, equals(1));
      expect(result.suspiciousEventCount, greaterThan(5));
    });

    // -------------------------------------------------------------------------
    test('BurstPattern non détecté : 5 connexions ou moins en 1 minute', () {
      final events = List.generate(
        5,
        (i) => ConnectionEvent(
          sourceIP: validIP1,
          destIP: validIP2,
          timestamp: baseTime.add(Duration(seconds: i * 5)),
          type: ConnectionEventType.connected,
        ),
      );

      final result = monitor.checkForBotnetPatterns(events);
      expect(result.patternName, isNot(equals('BurstPattern')));
    });
  });

  // ===========================================================================
  group('TailscaleMonitor — verifyACLConsistency()', () {
    // -------------------------------------------------------------------------
    test('ACL correcte : peer autorisé connecté → pas de violation', () {
      final result = monitor.verifyACLConsistency(
        [validIP1, validIP2],
        [validIP1],
      );
      expect(result.hasViolation, isFalse);
      expect(result.unauthorizedPeers, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('ACL violation : peer connecté non dans la liste autorisée', () {
      final result = monitor.verifyACLConsistency(
        [validIP1],         // Seul validIP1 est autorisé
        [validIP1, validIP2], // validIP2 est connecté sans autorisation
      );
      expect(result.hasViolation, isTrue);
      expect(result.unauthorizedPeers, contains(validIP2));
    });

    // -------------------------------------------------------------------------
    test('ACL violation : liste autorisée vide mais connexions présentes', () {
      final result = monitor.verifyACLConsistency(
        [],           // Aucun peer autorisé
        [validIP1],   // Mais un peer est connecté
      );
      expect(result.hasViolation, isTrue);
      expect(result.unauthorizedPeers, contains(validIP1));
    });

    // -------------------------------------------------------------------------
    test('ACL correcte : aucun peer connecté → pas de violation', () {
      final result = monitor.verifyACLConsistency(
        [validIP1, validIP2],
        [],  // Personne connecté
      );
      expect(result.hasViolation, isFalse);
      expect(result.unauthorizedPeers, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('ACL : peers autorisés manquants sont identifiés (informatif)', () {
      final result = monitor.verifyACLConsistency(
        [validIP1, validIP2, validIP3],
        [validIP1],  // validIP2 et validIP3 sont autorisés mais pas connectés
      );
      expect(result.hasViolation, isFalse);
      expect(result.missingAuthorizedPeers, containsAll([validIP2, validIP3]));
    });
  });

  // ===========================================================================
  group('TailscaleMonitor — checkForLateralMovement()', () {
    // -------------------------------------------------------------------------
    test('Mouvement latéral détecté : 1 source → 5 destinations distinctes', () {
      final events = List.generate(
        5,
        (i) => ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.20.${i + 1}',
          timestamp: baseTime.add(Duration(minutes: i)),
          type: ConnectionEventType.connected,
        ),
      );

      final result = monitor.checkForLateralMovement(events);
      expect(result.detected, isTrue);
      expect(result.suspiciousEvents, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    test('Mouvement latéral non détecté : source → 3 destinations seulement', () {
      final events = [
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.20.1',
          timestamp: baseTime,
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.20.2',
          timestamp: baseTime.add(const Duration(minutes: 1)),
          type: ConnectionEventType.connected,
        ),
        ConnectionEvent(
          sourceIP: validIP1,
          destIP: '100.64.20.3',
          timestamp: baseTime.add(const Duration(minutes: 2)),
          type: ConnectionEventType.connected,
        ),
      ];

      final result = monitor.checkForLateralMovement(events);
      expect(result.detected, isFalse);
    });

    // -------------------------------------------------------------------------
    test('checkForLateralMovement avec liste vide retourne detected=false', () {
      final result = monitor.checkForLateralMovement([]);
      expect(result.detected, isFalse);
    });

    // -------------------------------------------------------------------------
    test('checkForBotnetPatterns avec liste vide retourne detected=false', () {
      final result = monitor.checkForBotnetPatterns([]);
      expect(result.detected, isFalse);
      expect(result.severity, equals(0));
    });
  });
}
