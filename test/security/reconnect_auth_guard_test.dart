// =============================================================================
// TEST FIX-011 — Tests unitaires de ReconnectAuthGuard
// =============================================================================
// Couvre :
//   - needsReAuthentication() : jamais authentifié → true
//   - needsReAuthentication() : authentifié récemment → false
//   - needsReAuthentication() : après 2 min en arrière-plan → true
//   - recordAuthentication()  : met à jour lastAuthenticatedAt
//   - onReconnectRequested()  : retourne authRequired quand nécessaire
//
// Lancer avec :
//   flutter test test/security/fix_011_reconnect_auth_test.dart
// =============================================================================

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Chemin à adapter selon la structure réelle du projet ChillShell.
// import 'package:chillshell/core/security/fix_011_reconnect_auth.dart';

// Pour les tests autonomes dans le rapport, on inclut une copie inline de la
// classe afin de rendre le fichier autoportant.
// ─────────────────────────────────────────────────────────────────────────────
// [Copie inline — à SUPPRIMER et remplacer par l'import ci-dessus en intégration]
// ─────────────────────────────────────────────────────────────────────────────

enum ReconnectDecision { allowed, authRequired, denied }

class ReconnectAuthGuard with WidgetsBindingObserver {
  ReconnectAuthGuard._internal();
  static final ReconnectAuthGuard instance = ReconnectAuthGuard._internal();

  Duration backgroundTimeout = const Duration(minutes: 2);
  DateTime? _lastAuthenticatedAt;
  DateTime? _backgroundedAt;
  bool _requiresReAuth = true;

  DateTime? get lastAuthenticatedAt => _lastAuthenticatedAt;
  bool get requiresReAuth => _requiresReAuth;

  bool needsReAuthentication() {
    if (_lastAuthenticatedAt == null) return true;
    if (_requiresReAuth) return true;
    return false;
  }

  ReconnectDecision onReconnectRequested() {
    if (needsReAuthentication()) return ReconnectDecision.authRequired;
    return ReconnectDecision.allowed;
  }

  void recordAuthentication() {
    _lastAuthenticatedAt = DateTime.now();
    _requiresReAuth = false;
  }

  void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  void onAppResumed() {
    if (_backgroundedAt == null) return;
    final elapsed = DateTime.now().difference(_backgroundedAt!);
    if (elapsed >= backgroundTimeout) {
      _requiresReAuth = true;
    }
    _backgroundedAt = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        onAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        onAppResumed();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _requiresReAuth = true;
        break;
    }
  }

  void resetForTesting() {
    _lastAuthenticatedAt = null;
    _backgroundedAt = null;
    _requiresReAuth = true;
    backgroundTimeout = const Duration(minutes: 2);
  }

  void setBackgroundTimeoutForTesting(Duration timeout) {
    backgroundTimeout = timeout;
  }

  void setBackgroundedAtForTesting(DateTime? dt) {
    _backgroundedAt = dt;
  }
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // On utilise setUp/tearDown pour garantir un état propre entre chaque test.
  // L'instance singleton est réinitialisée avant chaque test.
  final guard = ReconnectAuthGuard.instance;

  setUp(() {
    guard.resetForTesting();
  });

  // ---------------------------------------------------------------------------
  // Groupe 1 : needsReAuthentication()
  // ---------------------------------------------------------------------------

  group('needsReAuthentication()', () {
    test(
        'retourne true si jamais authentifié (lastAuthenticatedAt est null)',
        () {
      // Aucune authentification enregistrée → doit exiger re-auth.
      expect(guard.lastAuthenticatedAt, isNull);
      expect(guard.needsReAuthentication(), isTrue);
    });

    test(
        'retourne false après une authentification réussie récente',
        () {
      // Simuler une authentification réussie.
      guard.recordAuthentication();

      // Le timestamp doit être renseigné et le flag réinitialisé.
      expect(guard.lastAuthenticatedAt, isNotNull);
      expect(guard.needsReAuthentication(), isFalse);
    });

    test(
        'retourne true après avoir été en arrière-plan plus de 2 minutes',
        () {
      // Simuler une authentification initiale réussie.
      guard.recordAuthentication();
      expect(guard.needsReAuthentication(), isFalse);

      // Simuler une mise en arrière-plan datant de 3 minutes.
      guard.setBackgroundTimeoutForTesting(const Duration(seconds: 1));
      guard.setBackgroundedAtForTesting(
        DateTime.now().subtract(const Duration(seconds: 5)),
      );

      // Déclencher le retour au premier plan : le timeout est dépassé.
      guard.onAppResumed();

      expect(guard.needsReAuthentication(), isTrue,
          reason:
              'Le timeout en arrière-plan a été dépassé : re-auth obligatoire');
    });

    test(
        'retourne false si arrière-plan INFERIEUR au timeout',
        () {
      // Authentification initiale.
      guard.recordAuthentication();

      // Arrière-plan très court (moins de 1 seconde).
      guard.setBackgroundTimeoutForTesting(const Duration(minutes: 2));
      guard.setBackgroundedAtForTesting(DateTime.now());

      // Retour immédiat au premier plan.
      guard.onAppResumed();

      expect(guard.needsReAuthentication(), isFalse,
          reason: 'Le timeout n\'est pas encore atteint');
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 2 : recordAuthentication()
  // ---------------------------------------------------------------------------

  group('recordAuthentication()', () {
    test('met à jour lastAuthenticatedAt', () {
      expect(guard.lastAuthenticatedAt, isNull);

      final avant = DateTime.now();
      guard.recordAuthentication();
      final apres = DateTime.now();

      expect(guard.lastAuthenticatedAt, isNotNull);
      // L'horodatage doit être dans la fenêtre [avant, après].
      expect(
        guard.lastAuthenticatedAt!.isAfter(avant) ||
            guard.lastAuthenticatedAt!.isAtSameMomentAs(avant),
        isTrue,
      );
      expect(
        guard.lastAuthenticatedAt!.isBefore(apres) ||
            guard.lastAuthenticatedAt!.isAtSameMomentAs(apres),
        isTrue,
      );
    });

    test('efface le flag requiresReAuth', () {
      // Le flag est levé par défaut après resetForTesting().
      expect(guard.requiresReAuth, isTrue);

      guard.recordAuthentication();

      expect(guard.requiresReAuth, isFalse);
    });

    test('deux appels successifs mettent à jour l\'horodatage', () async {
      guard.recordAuthentication();
      final premier = guard.lastAuthenticatedAt;

      // Petite pause pour que les timestamps diffèrent.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      guard.recordAuthentication();
      final second = guard.lastAuthenticatedAt;

      expect(second!.isAfter(premier!), isTrue,
          reason: 'Le deuxième appel doit mettre à jour le timestamp');
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 3 : onReconnectRequested()
  // ---------------------------------------------------------------------------

  group('onReconnectRequested()', () {
    test(
        'retourne authRequired si jamais authentifié',
        () {
      final decision = guard.onReconnectRequested();
      expect(decision, equals(ReconnectDecision.authRequired));
    });

    test(
        'retourne allowed après une authentification réussie récente',
        () {
      guard.recordAuthentication();
      final decision = guard.onReconnectRequested();
      expect(decision, equals(ReconnectDecision.allowed));
    });

    test(
        'retourne authRequired après timeout en arrière-plan',
        () {
      guard.recordAuthentication();

      // Forcer le timeout.
      guard.setBackgroundTimeoutForTesting(const Duration(milliseconds: 1));
      guard.setBackgroundedAtForTesting(
        DateTime.now().subtract(const Duration(seconds: 1)),
      );
      guard.onAppResumed();

      final decision = guard.onReconnectRequested();
      expect(decision, equals(ReconnectDecision.authRequired));
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 4 : cycle de vie (onAppBackgrounded / onAppResumed)
  // ---------------------------------------------------------------------------

  group('Cycle de vie app', () {
    test('onAppBackgrounded sans onAppResumed ne lève pas le flag prématurément',
        () {
      guard.recordAuthentication();

      // L'app passe en arrière-plan mais n'est pas encore revenue.
      guard.onAppBackgrounded();

      // La décision doit toujours être allowed (on n'est pas encore revenu).
      expect(guard.needsReAuthentication(), isFalse);
    });

    test(
        'onAppResumed sans onAppBackgrounded préalable ne crash pas',
        () {
      guard.recordAuthentication();

      // Appel de onAppResumed sans avoir appelé onAppBackgrounded.
      expect(() => guard.onAppResumed(), returnsNormally);
      // Le flag ne doit pas être levé.
      expect(guard.needsReAuthentication(), isFalse);
    });

    test(
        'didChangeAppLifecycleState(paused) puis resumed déclenche la logique',
        () {
      guard.recordAuthentication();
      guard.setBackgroundTimeoutForTesting(const Duration(milliseconds: 1));

      // Simuler la mise en arrière-plan via le WidgetsBindingObserver.
      guard.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Simuler le temps qui passe.
      // On injecte directement le timestamp pour contourner la vraie horloge.
      guard.setBackgroundedAtForTesting(
        DateTime.now().subtract(const Duration(seconds: 1)),
      );

      // Retour au premier plan.
      guard.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(guard.needsReAuthentication(), isTrue);
    });
  });
}
