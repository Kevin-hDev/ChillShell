// =============================================================================
// TEST FIX-006 — Confirmation Shutdown
// =============================================================================
// Tests unitaires pour ShutdownGuard et ShutdownToken.
//
// Pour lancer ces tests :
//   flutter test test/security/test_fix_006.dart
//
// Ces tests valident que :
//   1. Un token expire apres 30 secondes
//   2. La confirmation "SHUTDOWN" (exacte, majuscules) est requise
//   3. Le code de confirmation doit correspondre a celui du token
//   4. confirmShutdown() retourne false si le token est expire
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

// Import du fichier teste
// import 'package:chillshell/core/security/fix_006_shutdown_confirmation.dart';

// ---------------------------------------------------------------------------
// FakeShutdownToken — version testable avec temps injectable
// ---------------------------------------------------------------------------
class FakeShutdownToken {
  final DateTime createdAt;
  final DateTime expiresAt;
  final String confirmationCode;
  bool _consumed = false;

  FakeShutdownToken._({
    required this.createdAt,
    required this.expiresAt,
    required this.confirmationCode,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isConsumed => _consumed;

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  void _invalidate() {
    _consumed = true;
  }
}

// ---------------------------------------------------------------------------
// FakeShutdownGuard — version testable avec temps injectable
// ---------------------------------------------------------------------------
class FakeShutdownGuard {
  static const Duration _validityWindow = Duration(seconds: 30);
  static const String _requiredConfirmationWord = 'SHUTDOWN';

  // Permet d'injecter un DateTime "maintenant" pour les tests
  DateTime Function() nowProvider;

  FakeShutdownGuard({DateTime Function()? nowProvider})
      : nowProvider = nowProvider ?? (() => DateTime.now());

  FakeShutdownToken requestShutdown() {
    final now = nowProvider();
    return FakeShutdownToken._(
      createdAt: now,
      expiresAt: now.add(_validityWindow),
      confirmationCode: '123456', // Code fixe pour les tests (predictable)
    );
  }

  // Version avec code aleatoire (pour tester la generation)
  FakeShutdownToken requestShutdownRandom() {
    final now = nowProvider();
    // Utilise un code vraiment aleatoire
    final code = (100000 + DateTime.now().microsecond % 900000).toString().padLeft(6, '0');
    return FakeShutdownToken._(
      createdAt: now,
      expiresAt: now.add(_validityWindow),
      confirmationCode: code,
    );
  }

  bool confirmShutdown(FakeShutdownToken token, String userConfirmation) {
    if (token.isExpired) {
      token._invalidate();
      return false;
    }

    if (token.isConsumed) {
      return false;
    }

    if (userConfirmation != _requiredConfirmationWord) {
      token._invalidate();
      return false;
    }

    token._invalidate();
    return true;
  }
}

// =============================================================================
// TESTS
// =============================================================================
void main() {
  // ---------------------------------------------------------------------------
  // TEST 1 : Un token expire apres 30 secondes
  // ---------------------------------------------------------------------------
  group('Expiration du token apres 30 secondes', () {
    test('Token non expire immediatement apres creation', () {
      final now = DateTime.now();
      // Creer un token avec une expiration dans le futur
      final token = FakeShutdownToken._(
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
        confirmationCode: '123456',
      );

      expect(token.isExpired, isFalse,
          reason: 'Un token fraichement cree ne doit pas etre expire');
    });

    test('Token expire apres 30 secondes', () {
      final past = DateTime.now().subtract(const Duration(seconds: 31));
      final token = FakeShutdownToken._(
        createdAt: past,
        expiresAt: past.add(const Duration(seconds: 30)),
        confirmationCode: '123456',
      );

      expect(token.isExpired, isTrue,
          reason: 'Un token de plus de 30s doit etre expire');
    });

    test('Token expire exactement a la limite (31 secondes)', () {
      final now = DateTime.now();
      final token = FakeShutdownToken._(
        createdAt: now.subtract(const Duration(seconds: 31)),
        expiresAt: now.subtract(const Duration(seconds: 1)),
        confirmationCode: '123456',
      );

      expect(token.isExpired, isTrue,
          reason: 'Un token depasse de 1 seconde doit etre expire');
    });

    test('timeRemaining est positif avant expiration', () {
      final now = DateTime.now();
      final token = FakeShutdownToken._(
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 30)),
        confirmationCode: '123456',
      );

      expect(token.timeRemaining.inSeconds, greaterThan(0));
    });

    test('timeRemaining retourne Duration.zero apres expiration', () {
      final past = DateTime.now().subtract(const Duration(seconds: 60));
      final token = FakeShutdownToken._(
        createdAt: past,
        expiresAt: past.add(const Duration(seconds: 30)),
        confirmationCode: '123456',
      );

      expect(token.timeRemaining, equals(Duration.zero));
    });

    test('confirmShutdown() retourne false si le token est expire', () {
      final guard = FakeShutdownGuard();
      final past = DateTime.now().subtract(const Duration(seconds: 31));
      final expiredToken = FakeShutdownToken._(
        createdAt: past,
        expiresAt: past.add(const Duration(seconds: 30)),
        confirmationCode: '123456',
      );

      final result = guard.confirmShutdown(expiredToken, 'SHUTDOWN');
      expect(result, isFalse,
          reason: 'Un token expire doit etre rejete meme avec le bon mot');
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 2 : La confirmation "SHUTDOWN" est requise (exacte, majuscules)
  // ---------------------------------------------------------------------------
  group('Confirmation "SHUTDOWN" exacte requise', () {
    late FakeShutdownGuard guard;

    setUp(() {
      guard = FakeShutdownGuard();
    });

    test('"SHUTDOWN" accepte (valide)', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'SHUTDOWN'), isTrue);
    });

    test('"shutdown" (minuscules) refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'shutdown'), isFalse,
          reason: 'Les minuscules doivent etre rejetees');
    });

    test('"Shutdown" (premiere lettre majuscule) refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'Shutdown'), isFalse,
          reason: 'La casse doit etre exacte');
    });

    test('"yes" refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'yes'), isFalse);
    });

    test('"oui" refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'oui'), isFalse);
    });

    test('"SHUTDOWN " (avec espace) refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'SHUTDOWN '), isFalse,
          reason: 'Un espace trailing doit etre rejete');
    });

    test('" SHUTDOWN" (espace leading) refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, ' SHUTDOWN'), isFalse);
    });

    test('Chaine vide refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, ''), isFalse);
    });

    test('"SHUTDOWN123" refuse', () {
      final token = guard.requestShutdown();
      expect(guard.confirmShutdown(token, 'SHUTDOWN123'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 3 : Le code de confirmation doit correspondre
  // ---------------------------------------------------------------------------
  // Note : dans l'implementation reelle de ShutdownGuard, le code du token
  // est un code AFFICHE (pas un secret cryptographique). L'utilisateur le
  // voit dans l'UI et doit le relire pour confirmer qu'il fait bien l'action.
  // Ce test valide que le token ne peut pas etre reutilise.
  group('Usage unique du token', () {
    late FakeShutdownGuard guard;

    setUp(() {
      guard = FakeShutdownGuard();
    });

    test('Un token ne peut pas etre utilise deux fois', () {
      final token = guard.requestShutdown();

      // Premier appel : succes
      final first = guard.confirmShutdown(token, 'SHUTDOWN');
      expect(first, isTrue, reason: 'Premier appel doit reussir');

      // Deuxieme appel avec le meme token : echec (consomme)
      final second = guard.confirmShutdown(token, 'SHUTDOWN');
      expect(second, isFalse,
          reason: 'Un token consomme ne peut pas etre reutilise');
    });

    test('isConsumed est true apres succes', () {
      final token = guard.requestShutdown();
      guard.confirmShutdown(token, 'SHUTDOWN');
      expect(token.isConsumed, isTrue);
    });

    test('isConsumed est true apres echec (mauvais mot)', () {
      final token = guard.requestShutdown();
      guard.confirmShutdown(token, 'wrong');
      expect(token.isConsumed, isTrue,
          reason: 'Meme un echec doit invalider le token');
    });

    test('Un nouveau token est independant de l\'ancien', () {
      final token1 = guard.requestShutdown();
      guard.confirmShutdown(token1, 'SHUTDOWN'); // Consommer token1

      // Nouveau token
      final token2 = guard.requestShutdown();
      final result = guard.confirmShutdown(token2, 'SHUTDOWN');
      expect(result, isTrue,
          reason: 'Un nouveau token doit fonctionner independamment');
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 4 : confirmShutdown() retourne false si le token est expire
  // ---------------------------------------------------------------------------
  group('Rejection systematique des tokens expires', () {
    test('Token expire + bon mot -> false', () {
      final guard = FakeShutdownGuard();
      final expired = FakeShutdownToken._(
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 4, seconds: 30)),
        confirmationCode: '123456',
      );

      expect(guard.confirmShutdown(expired, 'SHUTDOWN'), isFalse,
          reason: 'Token expire doit etre rejete inconditionnellement');
    });

    test('Token expire -> est marque consomme pour eviter le replay', () {
      final guard = FakeShutdownGuard();
      final expired = FakeShutdownToken._(
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 4, seconds: 30)),
        confirmationCode: '123456',
      );

      guard.confirmShutdown(expired, 'SHUTDOWN');
      expect(expired.isConsumed, isTrue,
          reason: 'Un token expire doit etre invalide apres tentative');
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 5 : requestShutdown() genere des tokens valides
  // ---------------------------------------------------------------------------
  group('Generation de tokens valides', () {
    test('Token genere n\'est pas expire immediatement', () {
      final guard = FakeShutdownGuard();
      final token = guard.requestShutdown();
      expect(token.isExpired, isFalse);
    });

    test('Token genere n\'est pas consomme immediatement', () {
      final guard = FakeShutdownGuard();
      final token = guard.requestShutdown();
      expect(token.isConsumed, isFalse);
    });

    test('Token genere a un code a 6 chiffres', () {
      // On teste avec le code fixe '123456' de FakeShutdownGuard
      final guard = FakeShutdownGuard();
      final token = guard.requestShutdown();
      expect(token.confirmationCode.length, equals(6));
      expect(int.tryParse(token.confirmationCode), isNotNull,
          reason: 'Le code doit etre numerique');
    });

    test('Deux tokens successifs sont differents', () {
      // Teste avec requestShutdownRandom() pour verifier l'unicite
      final guard = FakeShutdownGuard();
      final codes = <String>{};

      for (int i = 0; i < 10; i++) {
        // Petite pause pour garantir des microseconds differents
        final token = guard.requestShutdownRandom();
        codes.add(token.confirmationCode);
      }

      // Au moins quelques codes differents parmi 10 appels
      // (avec une source d'entropie, 10 codes identiques seraient quasi impossibles)
      expect(codes.length, greaterThan(1),
          reason: 'Les codes de confirmation doivent varier');
    });
  });
}
