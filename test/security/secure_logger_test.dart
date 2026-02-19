// =============================================================================
// TEST — FIX-002 — SecureLogger
// Couvre : GAP-002 — 197 debugPrint() exposant des infos sensibles en release
// =============================================================================
//
// Pour lancer ces tests :
//   flutter test test_fix_002.dart
//
// Note sur kDebugMode dans les tests :
// En mode test Dart, kDebugMode == true (les tests tournent en debug).
// Les tests du comportement RELEASE nécessitent de mocker kDebugMode,
// ce qui n'est pas directement possible en Dart standard.
// On teste donc :
//   - Le filtrage des patterns sensibles (comportement debug)
//   - logSensitive() qui doit être vide quelle que soit la config
//   - La troncature à 200 caractères
//   - Que les patterns regex matchent correctement
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// Import du code à tester
// import 'package:chillshell/core/security/fix_002_secure_logger.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE pour tests autonomes
// ---------------------------------------------------------------------------

class _SensitivePattern {
  final RegExp regex;
  final String replacement;
  const _SensitivePattern(this.regex, this.replacement);
}

// Version testable de SecureLogger avec méthodes d'accès aux mécanismes internes
class SecureLogger {
  static const int _maxLogLength = 200;
  static const String _truncationMarker = '...[tronqué]';

  static final RegExp _ipPattern = RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}');
  static final RegExp _portPattern = RegExp(r':\d{2,5}(?=\s|$|[^/])');
  static final RegExp _usernamePattern = RegExp(r'\bas\s+\w+', caseSensitive: false);
  static final RegExp _filePathPattern = RegExp(r"""/[^\s,;:'"]{3,}""");
  static final RegExp _keyLikePattern = RegExp(r'[A-Fa-f0-9]{32,}|[A-Za-z0-9+/]{32,}={0,2}');
  static final RegExp _emailPattern = RegExp(r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}');

  static final List<_SensitivePattern> _sensitivePatterns = [
    _SensitivePattern(_ipPattern, '[IP]'),
    _SensitivePattern(_portPattern, ':[PORT]'),
    _SensitivePattern(_usernamePattern, 'as [USER]'),
    _SensitivePattern(_filePathPattern, '[PATH]'),
    _SensitivePattern(_keyLikePattern, '[KEY/TOKEN]'),
    _SensitivePattern(_emailPattern, '[EMAIL]'),
  ];

  // Méthode exposée pour les tests (normalement privée)
  static String sanitizeForTest(String message) => _sanitize(message);
  static String truncateForTest(String message) => _truncate(message);

  static void log(String tag, String message) {
    // En vrai projet : if (!kDebugMode) return;
    final sanitized = _sanitize(message);
    final truncated = _truncate(sanitized);
    // Dans les tests on ne fait pas de debugPrint pour ne pas polluer la sortie
    _ = '[$tag] $truncated'; // Empêche l'optimisation par le compilateur
  }

  static String logSensitive(String tag, String message) {
    return '[opération sécurisée]';
  }

  static void logDebugOnly(String tag, String message) {
    // En vrai projet : if (!kDebugMode) return;
    final sanitized = _sanitize(message);
    final truncated = _truncate(sanitized);
    _ = '[DEBUG][$tag] $truncated';
  }

  static void logError(String tag, Object error) {
    // En vrai projet : if (!kDebugMode) return;
    _ = '[ERROR][$tag] ${error.runtimeType}';
  }

  static String _sanitize(String message) {
    String result = message;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAll(pattern.regex, pattern.replacement);
    }
    return result;
  }

  static String _truncate(String message) {
    if (message.length <= _maxLogLength) return message;
    final cutLength = _maxLogLength - _truncationMarker.length;
    return '${message.substring(0, cutLength)}$_truncationMarker';
  }
}

// Nécessaire pour compiler `_ = ...` sans warning
dynamic _ ;

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  group('SecureLogger — Filtrage des adresses IP', () {
    // -------------------------------------------------------------------------
    test('filtre une adresse IPv4 classique', () {
      final result = SecureLogger.sanitizeForTest(
        'Connexion à 192.168.1.100 réussie',
      );
      expect(result, isNot(contains('192.168.1.100')));
      expect(result, contains('[IP]'));
    });

    // -------------------------------------------------------------------------
    test('filtre une adresse IP dans un contexte SSH', () {
      // Exemple réel du code existant :
      // debugPrint('SSHService: Key parsed OK, connecting TCP to $host:$port...');
      final result = SecureLogger.sanitizeForTest(
        'SSHService: Key parsed OK, connecting TCP to 10.0.0.50',
      );
      expect(result, isNot(contains('10.0.0.50')));
      expect(result, contains('[IP]'));
    });

    // -------------------------------------------------------------------------
    test('filtre plusieurs adresses IP dans le même message', () {
      final result = SecureLogger.sanitizeForTest(
        'Source: 192.168.0.1 → Destination: 10.0.0.1',
      );
      expect(result, isNot(contains('192.168.0.1')));
      expect(result, isNot(contains('10.0.0.1')));
      expect(result, contains('[IP]'));
    });

    // -------------------------------------------------------------------------
    test('ne filtre pas les chiffres normaux qui ressemblent pas à des IP', () {
      final result = SecureLogger.sanitizeForTest(
        'Timeout après 30 secondes, code erreur 404',
      );
      // '404' ne ressemble pas à une IP (pas 4 groupes)
      expect(result, contains('30'));
      expect(result, contains('404'));
    });
  });

  // =========================================================================
  group('SecureLogger — Filtrage des ports réseau', () {
    // -------------------------------------------------------------------------
    test('filtre le port SSH standard (:22)', () {
      final result = SecureLogger.sanitizeForTest(
        'Connexion sur le port :22',
      );
      expect(result, isNot(contains(':22')));
    });

    // -------------------------------------------------------------------------
    test('filtre les ports dans la plage commune', () {
      for (final port in ['80', '443', '8080', '22', '2222']) {
        final result = SecureLogger.sanitizeForTest('Port :$port disponible');
        expect(
          result,
          isNot(contains(':$port')),
          reason: 'Le port :$port devrait être filtré',
        );
      }
    });
  });

  // =========================================================================
  group('SecureLogger — Filtrage des noms d\'utilisateur', () {
    // -------------------------------------------------------------------------
    test('filtre "as username" (authentification SSH)', () {
      // Exemple réel : debugPrint('Authenticating as kevin');
      final result = SecureLogger.sanitizeForTest(
        'SSHService: Authenticating as kevin',
      );
      expect(result, isNot(contains('as kevin')));
      expect(result, contains('as [USER]'));
    });

    // -------------------------------------------------------------------------
    test('filtre "as" insensible à la casse', () {
      final result = SecureLogger.sanitizeForTest('Logging AS root');
      expect(result, isNot(contains('AS root')));
    });
  });

  // =========================================================================
  group('SecureLogger — Filtrage des chemins de fichiers', () {
    // -------------------------------------------------------------------------
    test('filtre un chemin absolu Linux', () {
      // Exemple réel : debugPrint('LocalShell: Starting shell: /bin/bash');
      final result = SecureLogger.sanitizeForTest(
        'LocalShell: Starting shell: /bin/bash',
      );
      expect(result, isNot(contains('/bin/bash')));
      expect(result, contains('[PATH]'));
    });

    // -------------------------------------------------------------------------
    test('filtre un chemin de clé SSH', () {
      final result = SecureLogger.sanitizeForTest(
        'Loading key from /home/user/.ssh/id_rsa',
      );
      expect(result, isNot(contains('/home/user/.ssh/id_rsa')));
      expect(result, contains('[PATH]'));
    });

    // -------------------------------------------------------------------------
    test('filtre un chemin de fichier de config', () {
      final result = SecureLogger.sanitizeForTest(
        'Config file: /etc/ssh/sshd_config loaded',
      );
      expect(result, isNot(contains('/etc/ssh/sshd_config')));
    });
  });

  // =========================================================================
  group('SecureLogger — Filtrage des clés et tokens', () {
    // -------------------------------------------------------------------------
    test('filtre une longue chaîne hexadécimale (fingerprint SSH)', () {
      final longHex = 'a' * 40; // 40 chars hex → doit être filtré
      final result = SecureLogger.sanitizeForTest('Fingerprint: $longHex');
      expect(result, isNot(contains(longHex)));
    });

    // -------------------------------------------------------------------------
    test('filtre un token base64 long', () {
      final longBase64 = 'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXo' * 2; // > 32 chars
      final result = SecureLogger.sanitizeForTest('Token: $longBase64');
      expect(result, isNot(contains(longBase64)));
    });
  });

  // =========================================================================
  group('SecureLogger — Filtrage des emails', () {
    // -------------------------------------------------------------------------
    test('filtre une adresse email', () {
      final result = SecureLogger.sanitizeForTest(
        'Utilisateur connecté: user@example.com',
      );
      expect(result, isNot(contains('user@example.com')));
      expect(result, contains('[EMAIL]'));
    });
  });

  // =========================================================================
  group('SecureLogger — Troncature à 200 caractères', () {
    // -------------------------------------------------------------------------
    test('ne tronque pas un message court (< 200 chars)', () {
      const shortMessage = 'Message court';
      final result = SecureLogger.truncateForTest(shortMessage);
      expect(result, equals(shortMessage));
    });

    // -------------------------------------------------------------------------
    test('ne tronque pas un message exactement à 200 chars', () {
      final exactMessage = 'A' * 200;
      final result = SecureLogger.truncateForTest(exactMessage);
      expect(result, equals(exactMessage));
      expect(result.length, equals(200));
    });

    // -------------------------------------------------------------------------
    test('tronque un message de 201 caractères', () {
      final longMessage = 'B' * 201;
      final result = SecureLogger.truncateForTest(longMessage);

      // Le résultat ne doit pas dépasser 200 chars
      expect(result.length, lessThanOrEqualTo(200));
      // Doit contenir le marqueur de troncature
      expect(result, contains('[tronqué]'));
    });

    // -------------------------------------------------------------------------
    test('tronque un très long message (1000 chars)', () {
      final veryLongMessage = 'C' * 1000;
      final result = SecureLogger.truncateForTest(veryLongMessage);

      expect(result.length, lessThanOrEqualTo(200));
      expect(result, contains('[tronqué]'));
    });

    // -------------------------------------------------------------------------
    test('le message tronqué commence bien par le début du message original', () {
      final longMessage = 'DEBUT' + ('X' * 300);
      final result = SecureLogger.truncateForTest(longMessage);

      expect(result, startsWith('DEBUT'));
    });
  });

  // =========================================================================
  group('SecureLogger — logSensitive()', () {
    // -------------------------------------------------------------------------
    test('logSensitive() retourne toujours une chaîne générique non sensible', () {
      // Tester avec différents contenus sensibles
      final testCases = [
        ('KeyService', 'Clé privée: -----BEGIN OPENSSH...'),
        ('AuthService', 'Mot de passe: SuperSecret123!'),
        ('SSHService', 'Connexion à 192.168.1.1 as admin'),
        ('CryptoService', 'Déchiffrement AES-256...'),
      ];

      for (final (tag, message) in testCases) {
        final result = SecureLogger.logSensitive(tag, message);

        // Ne doit JAMAIS contenir des infos du message original
        expect(
          result,
          isNot(contains('BEGIN')),
          reason: 'Ne doit pas contenir de fragment PEM',
        );
        expect(
          result,
          isNot(contains('Secret')),
          reason: 'Ne doit pas contenir de mot de passe',
        );
        expect(
          result,
          isNot(contains('192.168')),
          reason: 'Ne doit pas contenir d\'IP',
        );
        expect(
          result,
          isNot(contains('admin')),
          reason: 'Ne doit pas contenir de username',
        );

        // Doit retourner quelque chose d'utile mais générique
        expect(result, isNotEmpty);
      }
    });

    // -------------------------------------------------------------------------
    test('logSensitive() retourne la même valeur générique à chaque appel', () {
      final result1 = SecureLogger.logSensitive('A', 'info1');
      final result2 = SecureLogger.logSensitive('B', 'info2');
      final result3 = SecureLogger.logSensitive('C', 'info3');

      // Tous les appels doivent retourner la même chaîne générique
      expect(result1, equals(result2));
      expect(result2, equals(result3));
    });
  });

  // =========================================================================
  group('SecureLogger — Messages sans données sensibles (non filtrés)', () {
    // -------------------------------------------------------------------------
    test('un message sans données sensibles passe intact', () {
      const safeMessage = 'Connexion SSH établie avec succès';
      final result = SecureLogger.sanitizeForTest(safeMessage);
      expect(result, equals(safeMessage));
    });

    // -------------------------------------------------------------------------
    test('un message avec des chiffres normaux passe intact', () {
      const safeMessage = 'Tentative 3 sur 5 — timeout après 30s';
      final result = SecureLogger.sanitizeForTest(safeMessage);
      // '3 sur 5' et '30s' ne ressemblent pas à des IPs
      expect(result, contains('3 sur 5'));
    });

    // -------------------------------------------------------------------------
    test('un message vide passe intact', () {
      final result = SecureLogger.sanitizeForTest('');
      expect(result, equals(''));
    });
  });

  // =========================================================================
  group('SecureLogger — Combinaison filtrage + troncature', () {
    // -------------------------------------------------------------------------
    test('filtre ET tronque un message qui contient les deux', () {
      // Message long avec IP → doit être filtré ET tronqué
      final longWithIp =
          'Connexion à 192.168.1.1 ' + ('X' * 300);

      final sanitized = SecureLogger.sanitizeForTest(longWithIp);
      final truncated = SecureLogger.truncateForTest(sanitized);

      expect(truncated, isNot(contains('192.168.1.1')));
      expect(truncated.length, lessThanOrEqualTo(200));
    });
  });
}
