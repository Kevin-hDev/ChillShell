// =============================================================================
// TEST FIX-013 — Tests unitaires de BiometricHardening
// =============================================================================
// Couvre :
//   - getSecurityWarnings() retourne au moins 3 avertissements
//   - getSecurityLevel() retourne le bon niveau selon les capteurs disponibles
//   - authenticateForCriticalAction() exige les deux facteurs quand disponibles
//   - authenticateForCriticalAction() retourne false si aucun facteur dispo
//   - authenticateForCriticalAction() retourne false si biométrie échoue (pas de fallback)
//   - Constantes kLimite* sont non vides
//   - Fail CLOSED : exception pendant auth → false
//
// Lancer avec :
//   flutter test test/security/fix_013_biometric_hardening_test.dart
// =============================================================================

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

// Chemin à adapter selon la structure réelle du projet ChillShell.
// import 'package:chillshell/core/security/fix_013_biometric_hardening.dart';

// ─────────────────────────────────────────────────────────────────────────────
// [Copie inline — à SUPPRIMER et remplacer par l'import ci-dessus en intégration]
// ─────────────────────────────────────────────────────────────────────────────

enum BiometricSecurityLevel { high, medium, low, none }
enum AuthMethod { biometric, pin, both }

const String kLimite1PasDeLinenessDetection =
    'local_auth n\'implémente pas de liveness detection. '
    'Une photo haute résolution peut tromper certains capteurs.';

const String kLimite2PasDeFallbackPin =
    'biometricOnly:true exclut le PIN de l\'appareil comme fallback. '
    'Si la biométrie échoue, l\'utilisateur est bloqué.';

const String kLimite3BackgroundingCorrect =
    'persistAcrossBackgrounding:false est correct : '
    'la re-auth est exigée après mise en arrière-plan. Ne pas changer.';

const String kLimite4PasDeCryptoObject =
    'Android: CryptoObject non utilisé. '
    'La biométrie déverrouille l\'UI, pas un objet crypto. '
    'Un attaquant root peut court-circuiter cette protection.';

abstract class BiometricAuthProvider {
  Future<bool> isBiometricAvailable();
  Future<bool> isPinAvailable();
  Future<bool> authenticateWithBiometric(String reason);
  Future<bool> authenticateWithPin(String reason);
}

class BiometricHardening {
  final BiometricAuthProvider _authProvider;

  BiometricHardening({required BiometricAuthProvider authProvider})
      : _authProvider = authProvider;

  Future<BiometricSecurityLevel> getSecurityLevel() async {
    final biometrieDisponible = await _authProvider.isBiometricAvailable();
    final pinDisponible = await _authProvider.isPinAvailable();

    if (biometrieDisponible && pinDisponible) return BiometricSecurityLevel.high;
    if (biometrieDisponible) return BiometricSecurityLevel.medium;
    if (pinDisponible) return BiometricSecurityLevel.low;
    return BiometricSecurityLevel.none;
  }

  Future<List<AuthMethod>> getAvailableAuthMethods() async {
    final biometrieDisponible = await _authProvider.isBiometricAvailable();
    final pinDisponible = await _authProvider.isPinAvailable();

    if (biometrieDisponible && pinDisponible) {
      return [AuthMethod.both, AuthMethod.biometric, AuthMethod.pin];
    } else if (biometrieDisponible) {
      return [AuthMethod.biometric];
    } else if (pinDisponible) {
      return [AuthMethod.pin];
    } else {
      return [];
    }
  }

  List<String> getSecurityWarnings() {
    return [
      'La biométrie dépend entièrement du matériel de votre appareil. '
          'Tous les capteurs n\'ont pas le même niveau de protection.',
      'Pas de détection de vivant (liveness detection) : '
          'certains capteurs peuvent être trompés par une photo haute résolution.',
      'Recommandé : combiner biométrie + PIN pour les actions critiques '
          '(suppression de clés, déconnexion forcée).',
      'Les données biométriques sont gérées par l\'OS, jamais par l\'application. '
          'ChillShell ne stocke aucune empreinte ni image faciale.',
      kLimite4PasDeCryptoObject,
    ];
  }

  Future<bool> authenticateForCriticalAction(String reason) async {
    final methods = await getAvailableAuthMethods();
    if (methods.isEmpty) return false;

    final biometrieDisponible = methods.contains(AuthMethod.biometric) ||
        methods.contains(AuthMethod.both);
    final pinDisponible =
        methods.contains(AuthMethod.pin) || methods.contains(AuthMethod.both);

    try {
      if (biometrieDisponible && pinDisponible) {
        final biometrieOk = await _authProvider.authenticateWithBiometric(
            'Étape 1/2 — Biométrie : $reason');
        if (!biometrieOk) return false;
        return await _authProvider.authenticateWithPin(
            'Étape 2/2 — PIN : $reason');
      } else if (biometrieDisponible) {
        return await _authProvider.authenticateWithBiometric(reason);
      } else {
        return await _authProvider.authenticateWithPin(reason);
      }
    } catch (_) {
      return false;
    }
  }
}

// =============================================================================
// MOCKS pour les tests
// =============================================================================

/// Mock configurable pour simuler différentes configurations hardware.
class _MockBiometricProvider implements BiometricAuthProvider {
  final bool biometricAvailable;
  final bool pinAvailable;
  final bool biometricResult;
  final bool pinResult;
  final bool throwOnBiometric;
  final bool throwOnPin;

  /// Compteurs pour vérifier que les deux facteurs ont bien été appelés.
  int biometricCallCount = 0;
  int pinCallCount = 0;

  _MockBiometricProvider({
    this.biometricAvailable = true,
    this.pinAvailable = true,
    this.biometricResult = true,
    this.pinResult = true,
    this.throwOnBiometric = false,
    this.throwOnPin = false,
  });

  @override
  Future<bool> isBiometricAvailable() async => biometricAvailable;

  @override
  Future<bool> isPinAvailable() async => pinAvailable;

  @override
  Future<bool> authenticateWithBiometric(String reason) async {
    biometricCallCount++;
    if (throwOnBiometric) throw Exception('Erreur hardware simulée');
    return biometricResult;
  }

  @override
  Future<bool> authenticateWithPin(String reason) async {
    pinCallCount++;
    if (throwOnPin) throw Exception('Erreur PIN simulée');
    return pinResult;
  }
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // Groupe 1 : getSecurityWarnings()
  // ---------------------------------------------------------------------------

  group('getSecurityWarnings()', () {
    test('retourne au moins 3 avertissements', () {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(),
      );

      final warnings = hardening.getSecurityWarnings();

      expect(warnings.length, greaterThanOrEqualTo(3),
          reason: 'Au moins 3 avertissements de sécurité sont requis');
    });

    test('chaque avertissement est une chaîne non vide', () {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(),
      );

      final warnings = hardening.getSecurityWarnings();

      for (final w in warnings) {
        expect(w, isNotEmpty,
            reason: 'Un avertissement ne peut pas être une chaîne vide');
      }
    });

    test('contient un avertissement sur liveness detection', () {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(),
      );

      final warnings = hardening.getSecurityWarnings();
      final mentionneLiveness = warnings.any((w) =>
          w.toLowerCase().contains('liveness') ||
          w.toLowerCase().contains('vivant') ||
          w.toLowerCase().contains('photo'));

      expect(mentionneLiveness, isTrue,
          reason: 'L\'absence de liveness detection doit être mentionnée');
    });

    test('contient un avertissement sur la gestion OS des données biométriques',
        () {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(),
      );

      final warnings = hardening.getSecurityWarnings();
      final mentionneOs = warnings.any((w) => w.toLowerCase().contains('os'));

      expect(mentionneOs, isTrue,
          reason:
              'Il doit être précisé que l\'OS gère les données biométriques');
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 2 : getSecurityLevel()
  // ---------------------------------------------------------------------------

  group('getSecurityLevel()', () {
    test('retourne high si biométrie ET PIN disponibles', () async {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(
          biometricAvailable: true,
          pinAvailable: true,
        ),
      );

      final level = await hardening.getSecurityLevel();
      expect(level, equals(BiometricSecurityLevel.high));
    });

    test('retourne medium si biométrie seule disponible', () async {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(
          biometricAvailable: true,
          pinAvailable: false,
        ),
      );

      final level = await hardening.getSecurityLevel();
      expect(level, equals(BiometricSecurityLevel.medium));
    });

    test('retourne low si PIN seul disponible', () async {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(
          biometricAvailable: false,
          pinAvailable: true,
        ),
      );

      final level = await hardening.getSecurityLevel();
      expect(level, equals(BiometricSecurityLevel.low));
    });

    test('retourne none si aucune méthode disponible', () async {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(
          biometricAvailable: false,
          pinAvailable: false,
        ),
      );

      final level = await hardening.getSecurityLevel();
      expect(level, equals(BiometricSecurityLevel.none));
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 3 : authenticateForCriticalAction()
  // ---------------------------------------------------------------------------

  group('authenticateForCriticalAction()', () {
    test('exige biométrie ET PIN quand les deux sont disponibles', () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: true,
        pinAvailable: true,
        biometricResult: true,
        pinResult: true,
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Suppression de clé SSH');

      expect(result, isTrue, reason: 'Les deux facteurs validés → succès');
      expect(provider.biometricCallCount, equals(1),
          reason: 'La biométrie doit être demandée exactement une fois');
      expect(provider.pinCallCount, equals(1),
          reason: 'Le PIN doit être demandé exactement une fois');
    });

    test('retourne false si biométrie échoue — pas de fallback sur PIN seul',
        () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: true,
        pinAvailable: true,
        biometricResult: false, // Biométrie échoue.
        pinResult: true,
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Export de configuration');

      expect(result, isFalse,
          reason:
              'Si la biométrie échoue en double facteur, refus immédiat — '
              'pas de fallback sur PIN seul');
      expect(provider.biometricCallCount, equals(1));
      expect(provider.pinCallCount, equals(0),
          reason: 'Le PIN ne doit PAS être demandé après échec biométrie');
    });

    test('retourne false si PIN échoue au second facteur', () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: true,
        pinAvailable: true,
        biometricResult: true,
        pinResult: false, // PIN échoue.
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Shutdown forcé');

      expect(result, isFalse,
          reason: 'PIN échoué → refus de l\'action critique');
    });

    test('retourne false si aucune méthode disponible (fail CLOSED)', () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: false,
        pinAvailable: false,
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Action quelconque');

      expect(result, isFalse,
          reason: 'Sans aucune méthode disponible, l\'accès doit être refusé');
    });

    test('retourne false si une exception est levée pendant l\'auth (fail CLOSED)',
        () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: true,
        pinAvailable: true,
        throwOnBiometric: true, // Simule une erreur hardware.
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Action critique');

      expect(result, isFalse,
          reason:
              'Une exception pendant l\'auth doit provoquer un refus (fail CLOSED)');
    });

    test('biométrie seule : fonctionne si biométrie réussit', () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: true,
        pinAvailable: false, // Pas de PIN.
        biometricResult: true,
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Action critique sans PIN');

      expect(result, isTrue);
      expect(provider.biometricCallCount, equals(1));
      expect(provider.pinCallCount, equals(0));
    });

    test('PIN seul : fonctionne si PIN réussit', () async {
      final provider = _MockBiometricProvider(
        biometricAvailable: false,
        pinAvailable: true, // Pas de biométrie.
        pinResult: true,
      );
      final hardening = BiometricHardening(authProvider: provider);

      final result = await hardening.authenticateForCriticalAction(
          'Action critique sans biométrie');

      expect(result, isTrue);
      expect(provider.biometricCallCount, equals(0));
      expect(provider.pinCallCount, equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 4 : Constantes de documentation
  // ---------------------------------------------------------------------------

  group('Constantes de documentation des limites', () {
    test('kLimite1PasDeLinenessDetection est non vide', () {
      expect(kLimite1PasDeLinenessDetection, isNotEmpty);
      expect(kLimite1PasDeLinenessDetection.toLowerCase(),
          contains('liveness'));
    });

    test('kLimite2PasDeFallbackPin est non vide', () {
      expect(kLimite2PasDeFallbackPin, isNotEmpty);
      expect(kLimite2PasDeFallbackPin.toLowerCase(), contains('biometriconly'));
    });

    test('kLimite3BackgroundingCorrect mentionne persistAcrossBackgrounding',
        () {
      expect(kLimite3BackgroundingCorrect, isNotEmpty);
      expect(kLimite3BackgroundingCorrect.toLowerCase(),
          contains('persistacrossbackgrounding'));
    });

    test('kLimite4PasDeCryptoObject mentionne CryptoObject', () {
      expect(kLimite4PasDeCryptoObject, isNotEmpty);
      expect(kLimite4PasDeCryptoObject.toLowerCase(), contains('cryptoobject'));
    });
  });

  // ---------------------------------------------------------------------------
  // Groupe 5 : getAvailableAuthMethods()
  // ---------------------------------------------------------------------------

  group('getAvailableAuthMethods()', () {
    test('retourne both+biometric+pin quand les deux sont disponibles',
        () async {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(
          biometricAvailable: true,
          pinAvailable: true,
        ),
      );

      final methods = await hardening.getAvailableAuthMethods();
      expect(methods.contains(AuthMethod.both), isTrue);
      expect(methods.contains(AuthMethod.biometric), isTrue);
      expect(methods.contains(AuthMethod.pin), isTrue);
    });

    test('retourne liste vide si aucune méthode disponible', () async {
      final hardening = BiometricHardening(
        authProvider: _MockBiometricProvider(
          biometricAvailable: false,
          pinAvailable: false,
        ),
      );

      final methods = await hardening.getAvailableAuthMethods();
      expect(methods, isEmpty);
    });
  });
}
