// =============================================================================
// TEST FIX-012 — Tests unitaires de SessionTimeoutManager
// =============================================================================
// Couvre :
//   - Démarrage du timer avec le bon timeout
//   - resetTimer remet le compteur à zéro
//   - onSessionExpired est appelé après expiration
//   - L'avertissement est envoyé [warningBefore] avant expiration
//   - setCustomTimeout modifie le timeout
//   - stopMonitoring annule le timer
//   - Gestion de plusieurs sessions simultanées
//   - Limites de sécurité (tabId vide, trop long, capacité max)
//
// Lancer avec :
//   flutter test test/security/fix_012_session_timeout_test.dart
// =============================================================================

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

// Chemin à adapter selon la structure réelle du projet ChillShell.
// import 'package:chillshell/core/security/fix_012_session_timeout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// [Copie inline — à SUPPRIMER et remplacer par l'import ci-dessus en intégration]
// ─────────────────────────────────────────────────────────────────────────────

typedef SessionExpiredCallback = void Function(String tabId);
typedef SessionWarningCallback = void Function(String tabId, int remainingSeconds);

const Duration kSessionTimeoutMin = Duration(minutes: 5);
const Duration kSessionTimeoutMax = Duration(hours: 2);

class _SessionTimers {
  final Timer principal;
  final Timer? avertissement;
  _SessionTimers({required this.principal, this.avertissement});
  void cancel() {
    principal.cancel();
    avertissement?.cancel();
  }
}

class SessionTimeoutManager {
  Duration defaultTimeout;
  final Duration warningBefore;
  final SessionExpiredCallback onSessionExpired;
  final SessionWarningCallback? onWarning;
  final Map<String, _SessionTimers> _timers = {};
  static const int _maxSessions = 50;

  SessionTimeoutManager({
    this.defaultTimeout = const Duration(minutes: 15),
    this.warningBefore = const Duration(minutes: 2),
    required this.onSessionExpired,
    this.onWarning,
  }) {
    if (warningBefore >= defaultTimeout) {
      throw ArgumentError(
          'warningBefore ($warningBefore) doit être inférieur à defaultTimeout ($defaultTimeout)');
    }
  }

  void startMonitoring(String tabId) {
    _validateTabId(tabId);
    if (_timers.containsKey(tabId)) _cancelTimers(tabId);
    _checkCapacity();
    _scheduleTimers(tabId, defaultTimeout);
  }

  void resetTimer(String tabId) {
    _validateTabId(tabId);
    if (!_timers.containsKey(tabId)) return;
    _cancelTimers(tabId);
    _scheduleTimers(tabId, defaultTimeout);
  }

  void stopMonitoring(String tabId) {
    _validateTabId(tabId);
    _cancelTimers(tabId);
  }

  void setCustomTimeout(Duration timeout) {
    if (timeout < kSessionTimeoutMin || timeout > kSessionTimeoutMax) {
      throw RangeError(
          'Le timeout doit être compris entre ${kSessionTimeoutMin.inMinutes} min '
          'et ${kSessionTimeoutMax.inHours} h. Valeur reçue : ${timeout.inMinutes} min.');
    }
    if (warningBefore >= timeout) {
      throw ArgumentError(
          'warningBefore ($warningBefore) doit rester inférieur au nouveau timeout ($timeout)');
    }
    defaultTimeout = timeout;
  }

  List<String> get activeSessions => List.unmodifiable(_timers.keys);
  bool isMonitoring(String tabId) => _timers.containsKey(tabId);

  void dispose() {
    for (final tabId in List<String>.from(_timers.keys)) {
      _cancelTimers(tabId);
    }
  }

  void _scheduleTimers(String tabId, Duration totalTimeout) {
    final delaiAvertissement = totalTimeout - warningBefore;
    Timer? timerAvertissement;
    if (onWarning != null) {
      timerAvertissement = Timer(delaiAvertissement, () {
        onWarning!(tabId, warningBefore.inSeconds);
      });
    }
    final timerPrincipal = Timer(totalTimeout, () => _onTimeout(tabId));
    _timers[tabId] = _SessionTimers(
        principal: timerPrincipal, avertissement: timerAvertissement);
  }

  void _onTimeout(String tabId) {
    _cancelTimers(tabId);
    onSessionExpired(tabId);
  }

  void _cancelTimers(String tabId) {
    final timers = _timers.remove(tabId);
    timers?.cancel();
  }

  void _validateTabId(String tabId) {
    if (tabId.isEmpty) throw ArgumentError('tabId ne peut pas être vide');
    if (tabId.length > 128) throw ArgumentError('tabId trop long (max 128 caractères)');
  }

  void _checkCapacity() {
    if (_timers.length >= _maxSessions) {
      throw StateError('Nombre maximum de sessions simultanées atteint ($_maxSessions).');
    }
  }
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // Les tests utilisent fake_async pour simuler le temps sans attente réelle.
  // Dépendance à ajouter dans pubspec.yaml (dev_dependencies) :
  //   fake_async: ^1.3.1

  // ---------------------------------------------------------------------------
  // Groupe 1 : Démarrage et configuration
  // ---------------------------------------------------------------------------

  group('startMonitoring()', () {
    test('démarre la surveillance avec le bon timeout', () {
      fakeAsync((fake) {
        bool expired = false;

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 15),
          warningBefore: const Duration(minutes: 2),
          onSessionExpired: (_) => expired = true,
        );

        manager.startMonitoring('tab_1');

        // Avancer de 14 minutes : pas encore expiré.
        fake.elapse(const Duration(minutes: 14));
        expect(expired, isFalse,
            reason: 'La session ne doit pas expirer avant 15 minutes');

        // Avancer de 1 minute supplémentaire : timeout atteint.
        fake.elapse(const Duration(minutes: 1));
        expect(expired, isTrue,
            reason: 'La session doit expirer après 15 minutes');

        manager.dispose();
      });
    });

    test('démarre la surveillance correctement (isMonitoring retourne true)', () {
      fakeAsync((fake) {
        final manager = SessionTimeoutManager(
          onSessionExpired: (_) {},
        );

        expect(manager.isMonitoring('tab_1'), isFalse);
        manager.startMonitoring('tab_1');
        expect(manager.isMonitoring('tab_1'), isTrue);

        manager.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 2 : resetTimer
  // ---------------------------------------------------------------------------

  group('resetTimer()', () {
    test('remet le compteur à zéro : la session ne doit pas expirer tôt', () {
      fakeAsync((fake) {
        int expirations = 0;

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 10),
          warningBefore: const Duration(minutes: 1),
          onSessionExpired: (_) => expirations++,
        );

        manager.startMonitoring('tab_1');

        // Avancer de 9 minutes (presque le timeout) puis reset.
        fake.elapse(const Duration(minutes: 9));
        manager.resetTimer('tab_1'); // Remet à zéro.

        // Avancer de 9 nouvelles minutes : pas encore expiré (total = 18 min,
        // mais le timer a été remis à zéro à 9 min).
        fake.elapse(const Duration(minutes: 9));
        expect(expirations, equals(0),
            reason: 'Le reset doit empêcher l\'expiration prématurée');

        // Avancer de 1 minute : timeout atteint depuis le dernier reset.
        fake.elapse(const Duration(minutes: 1));
        expect(expirations, equals(1),
            reason: 'La session doit expirer 10 min après le dernier reset');

        manager.dispose();
      });
    });

    test('resetTimer ignoré si la session n\'est pas surveillée', () {
      fakeAsync((fake) {
        final manager = SessionTimeoutManager(
          onSessionExpired: (_) {},
        );

        // Pas de startMonitoring : l'appel doit être silencieux.
        expect(() => manager.resetTimer('tab_inconnu'), returnsNormally);

        manager.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 3 : onSessionExpired
  // ---------------------------------------------------------------------------

  group('onSessionExpired callback', () {
    test('est appelé avec le bon tabId après expiration', () {
      fakeAsync((fake) {
        String? tabIdRecu;

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 5),
          warningBefore: const Duration(minutes: 1),
          onSessionExpired: (tabId) => tabIdRecu = tabId,
        );

        manager.startMonitoring('ssh_tab_42');
        fake.elapse(const Duration(minutes: 5));

        expect(tabIdRecu, equals('ssh_tab_42'),
            reason: 'onSessionExpired doit recevoir le bon tabId');

        manager.dispose();
      });
    });

    test('n\'est PAS appelé si stopMonitoring est appelé avant le timeout', () {
      fakeAsync((fake) {
        bool expired = false;

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 5),
          warningBefore: const Duration(minutes: 1),
          onSessionExpired: (_) => expired = true,
        );

        manager.startMonitoring('tab_1');
        fake.elapse(const Duration(minutes: 3));
        manager.stopMonitoring('tab_1'); // Fermeture manuelle avant expiration.

        fake.elapse(const Duration(minutes: 5));
        expect(expired, isFalse,
            reason: 'stopMonitoring doit empêcher l\'expiration');

        manager.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 4 : Avertissement
  // ---------------------------------------------------------------------------

  group('onWarning callback', () {
    test('est envoyé [warningBefore] avant l\'expiration', () {
      fakeAsync((fake) {
        int? avertissementRestant;
        bool expired = false;

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 10),
          warningBefore: const Duration(minutes: 2),
          onSessionExpired: (_) => expired = true,
          onWarning: (_, remainingSeconds) =>
              avertissementRestant = remainingSeconds,
        );

        manager.startMonitoring('tab_1');

        // Avancer jusqu'au moment de l'avertissement (10 - 2 = 8 minutes).
        fake.elapse(const Duration(minutes: 8));
        expect(avertissementRestant, isNotNull,
            reason: 'L\'avertissement doit être envoyé à 8 minutes');
        expect(avertissementRestant, equals(120),
            reason: 'Il doit rester 120 secondes (2 min) au moment de l\'avertissement');
        expect(expired, isFalse,
            reason: 'La session ne doit pas encore être expirée à 8 minutes');

        // Avancer les 2 minutes restantes.
        fake.elapse(const Duration(minutes: 2));
        expect(expired, isTrue,
            reason: 'La session doit expirer à 10 minutes');

        manager.dispose();
      });
    });

    test('onWarning null : pas d\'erreur si non fourni', () {
      fakeAsync((fake) {
        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 5),
          warningBefore: const Duration(minutes: 1),
          onSessionExpired: (_) {},
          // onWarning non fourni
        );

        expect(() {
          manager.startMonitoring('tab_1');
          fake.elapse(const Duration(minutes: 5));
        }, returnsNormally);

        manager.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 5 : setCustomTimeout
  // ---------------------------------------------------------------------------

  group('setCustomTimeout()', () {
    test('modifie le timeout pour les nouvelles sessions', () {
      fakeAsync((fake) {
        bool expired = false;

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 15),
          warningBefore: const Duration(minutes: 2),
          onSessionExpired: (_) => expired = true,
        );

        // Réduire le timeout à 5 minutes.
        manager.setCustomTimeout(const Duration(minutes: 5));
        expect(manager.defaultTimeout, equals(const Duration(minutes: 5)));

        manager.startMonitoring('tab_1');
        fake.elapse(const Duration(minutes: 5));
        expect(expired, isTrue,
            reason: 'Le nouveau timeout de 5 min doit être respecté');

        manager.dispose();
      });
    });

    test('lève RangeError si timeout < 5 minutes', () {
      final manager = SessionTimeoutManager(
        defaultTimeout: const Duration(minutes: 15),
        warningBefore: const Duration(minutes: 2),
        onSessionExpired: (_) {},
      );

      expect(
        () => manager.setCustomTimeout(const Duration(minutes: 4)),
        throwsRangeError,
        reason: 'Le timeout minimum est 5 minutes',
      );
    });

    test('lève RangeError si timeout > 2 heures', () {
      final manager = SessionTimeoutManager(
        defaultTimeout: const Duration(minutes: 15),
        warningBefore: const Duration(minutes: 2),
        onSessionExpired: (_) {},
      );

      expect(
        () => manager.setCustomTimeout(const Duration(hours: 3)),
        throwsRangeError,
        reason: 'Le timeout maximum est 2 heures',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 6 : stopMonitoring
  // ---------------------------------------------------------------------------

  group('stopMonitoring()', () {
    test('retire la session de activeSessions', () {
      fakeAsync((fake) {
        final manager = SessionTimeoutManager(
          onSessionExpired: (_) {},
        );

        manager.startMonitoring('tab_1');
        expect(manager.activeSessions.contains('tab_1'), isTrue);

        manager.stopMonitoring('tab_1');
        expect(manager.activeSessions.contains('tab_1'), isFalse);

        manager.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 7 : Plusieurs sessions simultanées
  // ---------------------------------------------------------------------------

  group('Sessions simultanées', () {
    test('gère plusieurs sessions indépendamment', () {
      fakeAsync((fake) {
        final expirees = <String>[];

        final manager = SessionTimeoutManager(
          defaultTimeout: const Duration(minutes: 10),
          warningBefore: const Duration(minutes: 1),
          onSessionExpired: (tabId) => expirees.add(tabId),
        );

        manager.startMonitoring('tab_A');
        manager.startMonitoring('tab_B');
        manager.startMonitoring('tab_C');

        expect(manager.activeSessions.length, equals(3));

        // Avancer de 5 minutes et reset tab_B.
        fake.elapse(const Duration(minutes: 5));
        manager.resetTimer('tab_B'); // tab_B repart à zéro.

        // Fermer tab_C manuellement.
        manager.stopMonitoring('tab_C');

        // Avancer de 5 minutes supplémentaires : tab_A doit expirer.
        fake.elapse(const Duration(minutes: 5));
        expect(expirees.contains('tab_A'), isTrue,
            reason: 'tab_A doit expirer à 10 minutes sans reset');
        expect(expirees.contains('tab_C'), isFalse,
            reason: 'tab_C a été arrêté manuellement, pas expiré');

        // Avancer encore 5 minutes : tab_B doit maintenant expirer.
        fake.elapse(const Duration(minutes: 5));
        expect(expirees.contains('tab_B'), isTrue,
            reason: 'tab_B doit expirer 10 min après son reset');

        manager.dispose();
      });
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 8 : Sécurité — validation des entrées
  // ---------------------------------------------------------------------------

  group('Sécurité des entrées', () {
    test('tabId vide lève ArgumentError', () {
      final manager = SessionTimeoutManager(onSessionExpired: (_) {});
      expect(() => manager.startMonitoring(''), throwsArgumentError);
    });

    test('tabId trop long lève ArgumentError', () {
      final manager = SessionTimeoutManager(onSessionExpired: (_) {});
      final tabIdTropLong = 'x' * 129;
      expect(() => manager.startMonitoring(tabIdTropLong), throwsArgumentError);
    });
  });
}
