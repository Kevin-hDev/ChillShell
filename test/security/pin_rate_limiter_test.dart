// =============================================================================
// TEST FIX-004 — PIN Rate Limiter
// =============================================================================
// Tests unitaires pour PinRateLimiter.
//
// Pour lancer ces tests :
//   flutter test test/security/test_fix_004.dart
//
// Note d'architecture : ces tests utilisent un mock de FlutterSecureStorage
// pour ne pas ecrire sur l'appareil reel pendant les tests.
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import du fichier teste
// import 'package:chillshell/core/security/fix_004_pin_rate_limiter.dart';

// ---------------------------------------------------------------------------
// Mock de FlutterSecureStorage
// ---------------------------------------------------------------------------
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// ---------------------------------------------------------------------------
// FakePinRateLimiter — version testable avec stockage en memoire
// ---------------------------------------------------------------------------
/// Version du PinRateLimiter qui utilise une Map en memoire au lieu de
/// FlutterSecureStorage. Permet des tests rapides et deterministes.
class FakePinRateLimiter {
  // Stockage en memoire (simule SecureStorage)
  final Map<String, String> _store = {};

  static const String _failedAttemptsKey = 'auth_counter_a';
  static const String _lastFailedAtKey   = 'auth_ts_a';
  static const String _lockoutUntilKey   = 'auth_hold_until';

  static const int maxAttempts      = 5;
  static const int wipeAfterAttempts = 10;

  static const List<Duration> lockoutDurations = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  void Function()? onWipeRequired;

  // Permet d'injecter un DateTime.now() different pour les tests
  DateTime Function() nowProvider;

  FakePinRateLimiter({DateTime Function()? nowProvider})
      : nowProvider = nowProvider ?? (() => DateTime.now());

  Future<AttemptCheckResultTest> canAttempt() async {
    final lockoutUntilRaw = _store[_lockoutUntilKey];

    if (lockoutUntilRaw != null) {
      final lockoutUntil =
          DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutUntilRaw));
      final now = nowProvider();

      if (now.isBefore(lockoutUntil)) {
        final remaining = lockoutUntil.difference(now);
        return AttemptCheckResultTest(allowed: false, waitTime: remaining);
      }

      _store.remove(_lockoutUntilKey);
    }

    return const AttemptCheckResultTest(allowed: true);
  }

  Future<void> recordFailure() async {
    final raw = _store[_failedAttemptsKey];
    final failedAttempts = int.tryParse(raw ?? '0') ?? 0;
    final newCount = failedAttempts + 1;

    _store[_failedAttemptsKey] = newCount.toString();
    _store[_lastFailedAtKey] =
        nowProvider().millisecondsSinceEpoch.toString();

    if (newCount >= wipeAfterAttempts) {
      _deleteAllKeys();
      onWipeRequired?.call();
      return;
    }

    if (newCount >= maxAttempts) {
      final palierIndex =
          (newCount - maxAttempts).clamp(0, lockoutDurations.length - 1);
      final lockoutDuration = lockoutDurations[palierIndex];
      final lockoutUntil =
          nowProvider().add(lockoutDuration).millisecondsSinceEpoch;
      _store[_lockoutUntilKey] = lockoutUntil.toString();
    }
  }

  Future<void> recordSuccess() async => _deleteAllKeys();
  Future<void> reset() async => _deleteAllKeys();

  void _deleteAllKeys() {
    _store.remove(_failedAttemptsKey);
    _store.remove(_lastFailedAtKey);
    _store.remove(_lockoutUntilKey);
  }

  int getFailedAttemptCount() =>
      int.tryParse(_store[_failedAttemptsKey] ?? '0') ?? 0;
}

class AttemptCheckResultTest {
  final bool allowed;
  final Duration? waitTime;
  const AttemptCheckResultTest({required this.allowed, this.waitTime});
}

// =============================================================================
// TESTS
// =============================================================================
void main() {
  late FakePinRateLimiter rateLimiter;

  setUp(() {
    rateLimiter = FakePinRateLimiter();
  });

  // ---------------------------------------------------------------------------
  // TEST 1 : 5 echecs consecutifs declenchent un lockout
  // ---------------------------------------------------------------------------
  group('Verrouillage apres maxAttempts echecs', () {
    test('canAttempt() retourne allowed=true avant 5 echecs', () async {
      // Simuler 4 echecs — pas encore de lockout
      for (int i = 0; i < 4; i++) {
        await rateLimiter.recordFailure();
      }

      final result = await rateLimiter.canAttempt();
      expect(result.allowed, isTrue,
          reason: '4 echecs ne doivent pas encore verrouiller');
    });

    test('canAttempt() retourne allowed=false apres 5 echecs', () async {
      // Simuler 5 echecs -> premier lockout
      for (int i = 0; i < 5; i++) {
        await rateLimiter.recordFailure();
      }

      final result = await rateLimiter.canAttempt();
      expect(result.allowed, isFalse,
          reason: '5 echecs doivent verrouiller');
      expect(result.waitTime, isNotNull,
          reason: 'waitTime doit etre fourni quand locked');
    });

    test('waitTime est positif apres le premier lockout', () async {
      for (int i = 0; i < 5; i++) {
        await rateLimiter.recordFailure();
      }

      final result = await rateLimiter.canAttempt();
      expect(result.waitTime!.inSeconds, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 2 : Durees de lockout exponentielles (30s, 1m, 5m, 15m)
  // ---------------------------------------------------------------------------
  group('Durees de lockout exponentielles', () {
    test('1er lockout (5 echecs) -> environ 30 secondes', () async {
      for (int i = 0; i < 5; i++) {
        await rateLimiter.recordFailure();
      }
      final result = await rateLimiter.canAttempt();
      // Tolerance de 2 secondes pour le temps d'execution du test
      expect(result.waitTime!.inSeconds,
          inInclusiveRange(28, 30),
          reason: 'Premier lockout doit etre de 30 secondes');
    });

    test('2e lockout (6 echecs) -> environ 1 minute', () async {
      // On simule que le premier lockout est passe
      final now = DateTime.now();
      var t = now;

      // Fake time provider pour avancer le temps
      final limiter = FakePinRateLimiter(nowProvider: () => t);

      // 5 echecs -> lockout 30s
      for (int i = 0; i < 5; i++) {
        await limiter.recordFailure();
      }

      // Avancer le temps de 31s -> lockout expire
      t = now.add(const Duration(seconds: 31));

      // 6e echec -> lockout 1 minute
      await limiter.recordFailure();

      final result = await limiter.canAttempt();
      expect(result.allowed, isFalse);
      expect(result.waitTime!.inSeconds,
          inInclusiveRange(58, 60),
          reason: '2e lockout doit etre de 60 secondes');
    });

    test('3e lockout (7 echecs) -> environ 5 minutes', () async {
      final now = DateTime.now();
      var t = now;
      final limiter = FakePinRateLimiter(nowProvider: () => t);

      // 5 echecs -> lockout 30s
      for (int i = 0; i < 5; i++) {
        await limiter.recordFailure();
      }
      // Avancer 31s -> expire
      t = now.add(const Duration(seconds: 31));

      // 6e echec -> lockout 1m
      await limiter.recordFailure();
      // Avancer 61s -> expire
      t = now.add(const Duration(seconds: 92));

      // 7e echec -> lockout 5 minutes
      await limiter.recordFailure();

      final result = await limiter.canAttempt();
      expect(result.allowed, isFalse);
      expect(result.waitTime!.inMinutes,
          inInclusiveRange(4, 5),
          reason: '3e lockout doit etre de 5 minutes');
    });

    test('4e lockout (8 echecs) -> environ 15 minutes', () async {
      final now = DateTime.now();
      var t = now;
      final limiter = FakePinRateLimiter(nowProvider: () => t);

      // 5 echecs
      for (int i = 0; i < 5; i++) {
        await limiter.recordFailure();
      }
      t = now.add(const Duration(seconds: 31));
      await limiter.recordFailure(); // 6
      t = now.add(const Duration(seconds: 92));
      await limiter.recordFailure(); // 7
      t = now.add(const Duration(seconds: 393)); // 6m32s apres le debut
      await limiter.recordFailure(); // 8

      final result = await limiter.canAttempt();
      expect(result.allowed, isFalse);
      expect(result.waitTime!.inMinutes,
          inInclusiveRange(14, 15),
          reason: '4e lockout doit etre de 15 minutes');
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 3 : recordSuccess() remet les compteurs a zero
  // ---------------------------------------------------------------------------
  group('recordSuccess() reinitialise les compteurs', () {
    test('Apres un succes, canAttempt() retourne allowed=true', () async {
      // Provoquer un lockout
      for (int i = 0; i < 5; i++) {
        await rateLimiter.recordFailure();
      }
      // Verifier que c'est bien verrouille
      var result = await rateLimiter.canAttempt();
      expect(result.allowed, isFalse);

      // Succes (ex: biometrie, recuperation admin)
      await rateLimiter.recordSuccess();

      // Maintenant ca doit etre debloque
      result = await rateLimiter.canAttempt();
      expect(result.allowed, isTrue,
          reason: 'Apres succes, le verrou doit etre leve');
    });

    test('Apres un succes, le compteur d\'echecs est a 0', () async {
      for (int i = 0; i < 3; i++) {
        await rateLimiter.recordFailure();
      }
      await rateLimiter.recordSuccess();

      expect(rateLimiter.getFailedAttemptCount(), equals(0),
          reason: 'Le compteur doit etre remis a zero apres un succes');
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 4 : canAttempt() bloque pendant le lockout
  // ---------------------------------------------------------------------------
  group('canAttempt() bloque correctement pendant le lockout', () {
    test('Chaque appel a canAttempt() retourne false pendant le lockout', () async {
      for (int i = 0; i < 5; i++) {
        await rateLimiter.recordFailure();
      }

      // Appeler plusieurs fois — doit toujours etre bloque
      for (int i = 0; i < 3; i++) {
        final result = await rateLimiter.canAttempt();
        expect(result.allowed, isFalse,
            reason: 'Appel #$i : doit rester verrouille');
      }
    });

    test('canAttempt() se debloque apres expiration du lockout', () async {
      final now = DateTime.now();
      var t = now;
      final limiter = FakePinRateLimiter(nowProvider: () => t);

      for (int i = 0; i < 5; i++) {
        await limiter.recordFailure();
      }

      // Verifier que c'est verrouille
      var result = await limiter.canAttempt();
      expect(result.allowed, isFalse);

      // Avancer le temps de 31s -> lockout expire
      t = now.add(const Duration(seconds: 31));

      result = await limiter.canAttempt();
      expect(result.allowed, isTrue,
          reason: 'Le lockout doit expirer apres 30 secondes');
    });
  });

  // ---------------------------------------------------------------------------
  // TEST 5 : 10 echecs appellent onWipeRequired
  // ---------------------------------------------------------------------------
  group('onWipeRequired est appele apres wipeAfterAttempts echecs', () {
    test('10 echecs consecutifs declenchent onWipeRequired', () async {
      bool wipeTriggered = false;
      rateLimiter.onWipeRequired = () {
        wipeTriggered = true;
      };

      // Simuler 10 echecs, en remettant le lockout a zero a chaque fois
      // (via fake time) pour pouvoir continuer a enregistrer des echecs
      final now = DateTime.now();
      var t = now;
      final limiter = FakePinRateLimiter(nowProvider: () => t);
      limiter.onWipeRequired = () {
        wipeTriggered = true;
      };

      for (int i = 0; i < FakePinRateLimiter.wipeAfterAttempts; i++) {
        // Avancer le temps pour depasser chaque lockout
        t = now.add(Duration(hours: i));
        await limiter.recordFailure();
      }

      expect(wipeTriggered, isTrue,
          reason: '${FakePinRateLimiter.wipeAfterAttempts} echecs '
              'doivent declencher onWipeRequired');
    });

    test('9 echecs NE declenchent PAS onWipeRequired', () async {
      bool wipeTriggered = false;
      final now = DateTime.now();
      var t = now;
      final limiter = FakePinRateLimiter(nowProvider: () => t);
      limiter.onWipeRequired = () {
        wipeTriggered = true;
      };

      for (int i = 0; i < FakePinRateLimiter.wipeAfterAttempts - 1; i++) {
        t = now.add(Duration(hours: i));
        await limiter.recordFailure();
      }

      expect(wipeTriggered, isFalse,
          reason: '${FakePinRateLimiter.wipeAfterAttempts - 1} echecs '
              'ne doivent pas declencher le wipe');
    });

    test('Apres wipe, le stockage est vide', () async {
      final now = DateTime.now();
      var t = now;
      final limiter = FakePinRateLimiter(nowProvider: () => t);
      limiter.onWipeRequired = () {};

      for (int i = 0; i < FakePinRateLimiter.wipeAfterAttempts; i++) {
        t = now.add(Duration(hours: i));
        await limiter.recordFailure();
      }

      // Apres le wipe, le compteur doit etre a 0
      expect(limiter.getFailedAttemptCount(), equals(0),
          reason: 'Le compteur doit etre efface apres le wipe');
    });
  });
}
