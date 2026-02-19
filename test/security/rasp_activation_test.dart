// =============================================================================
// TEST FIX-008 — Vérification activation freeRASP
// =============================================================================
//
// Ces tests valident que :
//   1. verifyConfig détecte les PLACEHOLDERS (ancienne config brisée)
//   2. verifyConfig passe sans erreur avec des valeurs réelles
//   3. Les niveaux de sévérité sont correctement définis
//   4. Le package name de production est le bon
//   5. isProd est false en mode debug
//
// LANCER LES TESTS :
//   flutter test test/security/test_fix_008.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Import du fichier à tester
import 'package:vibeterm/core/security/rasp_activation.dart';

void main() {
  group('FIX-008 — RaspActivationGuide', () {

    // =========================================================================
    // GROUPE 1 : Détection des PLACEHOLDERS
    // =========================================================================

    group('verifyConfig — détection PLACEHOLDERS (ancienne config brisée)', () {

      test('doit détecter PLACEHOLDER dans signingCertHashes', () {
        // Simule l'ancienne config avec le placeholder non remplacé
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.vibeterm',
          signingCertHashes: ['PLACEHOLDER_REPLACE_WITH_ACTUAL_HASH'],
          teamId: 'ABCDE12345',
          bundleIds: ['com.vibeterm.vibeterm'],
        );

        // DOIT contenir une erreur sur le hash placeholder
        expect(
          erreurs.any((e) => e.contains('signingCertHashes') && e.contains('PLACEHOLDER')),
          isTrue,
          reason: 'Un hash PLACEHOLDER doit déclencher une erreur critique',
        );
      });

      test('doit détecter PLACEHOLDER dans teamId iOS', () {
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.vibeterm',
          signingCertHashes: ['mVBCMFiGMSPSfPCYSFIl9Bz8sTxABCDEFGHIJKLMNOP='],
          teamId: 'PLACEHOLDER_REPLACE_WITH_TEAM_ID',
          bundleIds: ['com.vibeterm.vibeterm'],
        );

        expect(
          erreurs.any((e) => e.contains('teamId') && e.contains('PLACEHOLDER')),
          isTrue,
          reason: 'Un Team ID PLACEHOLDER doit déclencher une erreur critique',
        );
      });

      test('doit détecter PLACEHOLDER dans bundleIds iOS', () {
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.vibeterm',
          signingCertHashes: ['mVBCMFiGMSPSfPCYSFIl9Bz8sTxABCDEFGHIJKLMNOP='],
          teamId: 'ABCDE12345',
          bundleIds: ['PLACEHOLDER_BUNDLE_ID'],
        );

        expect(
          erreurs.any((e) => e.contains('PLACEHOLDER')),
          isTrue,
          reason: 'Un bundle ID PLACEHOLDER doit déclencher une erreur',
        );
      });

      test('doit détecter la config entièrement placeholder (cas original)', () {
        // Reproduit EXACTEMENT la config défaillante du code original
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.app', // mauvais package name
          signingCertHashes: ['PLACEHOLDER_REPLACE_WITH_ACTUAL_HASH'],
          teamId: 'PLACEHOLDER_REPLACE_WITH_TEAM_ID',
          bundleIds: ['com.vibeterm.app'],
        );

        // Doit y avoir plusieurs erreurs
        expect(
          erreurs.length,
          greaterThanOrEqualTo(2),
          reason: 'La config originale doit générer au moins 2 erreurs (hash + teamId)',
        );

        // Toutes les erreurs critiques doivent être présentes
        expect(
          erreurs.any((e) => e.contains('signingCertHashes') && e.contains('PLACEHOLDER')),
          isTrue,
        );
        expect(
          erreurs.any((e) => e.contains('teamId') && e.contains('PLACEHOLDER')),
          isTrue,
        );
      });
    });

    // =========================================================================
    // GROUPE 2 : Configuration valide (valeurs réelles)
    // =========================================================================

    group('verifyConfig — configuration valide sans placeholders', () {

      test('doit retourner une liste vide avec des valeurs réelles correctes', () {
        // Un vrai hash SHA-256 en Base64 fait 44 caractères
        final hashReel = 'mVBCMFiGMSPSfPCYSFIl9Bz8sTxABCDEFGHIJKLMNOP=';
        // Un vrai Team ID Apple : 10 caractères alphanumériques majuscules
        final teamIdReel = 'ABCDE12345';

        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.vibeterm',
          signingCertHashes: [hashReel],
          teamId: teamIdReel,
          bundleIds: ['com.vibeterm.vibeterm'],
        );

        // Aucune erreur CRITIQUE (les avertissements sont acceptables)
        final erreursCritiques = erreurs.where((e) => e.startsWith('ERREUR')).toList();
        expect(
          erreursCritiques,
          isEmpty,
          reason: 'Une config réelle sans placeholders ne doit pas avoir d\'erreurs critiques',
        );
      });

      test('doit accepter plusieurs hashes de signature (cas key rotation)', () {
        // Cas d'usage : rotation de certificat, deux hashes valides en même temps
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.vibeterm',
          signingCertHashes: [
            'mVBCMFiGMSPSfPCYSFIl9Bz8sTxABCDEFGHIJKLMNOP=',
            'newHashABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789A=',
          ],
          teamId: 'ABCDE12345',
          bundleIds: ['com.vibeterm.vibeterm'],
        );

        final erreursCritiques = erreurs.where((e) => e.startsWith('ERREUR')).toList();
        expect(
          erreursCritiques,
          isEmpty,
          reason: 'Plusieurs hashes valides doivent être acceptés',
        );
      });

      test('doit signaler si signingCertHashes est vide', () {
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.vibeterm',
          signingCertHashes: [], // vide = protection signature désactivée
          teamId: 'ABCDE12345',
          bundleIds: ['com.vibeterm.vibeterm'],
        );

        expect(
          erreurs.any((e) => e.contains('signingCertHashes') && e.contains('vide')),
          isTrue,
          reason: 'Une liste vide de hashes doit être signalée comme erreur',
        );
      });
    });

    // =========================================================================
    // GROUPE 3 : Package name de production
    // =========================================================================

    group('Package name de production', () {

      test('le package name de production doit être com.vibeterm.vibeterm', () {
        expect(
          RaspActivationGuide.productionPackageName,
          equals('com.vibeterm.vibeterm'),
          reason: 'Le vrai namespace du projet est com.vibeterm.vibeterm',
        );
      });

      test('doit avertir si packageName est com.vibeterm.app (ancienne valeur)', () {
        final erreurs = RaspActivationGuide.verifyConfig(
          packageName: 'com.vibeterm.app', // ancienne valeur incorrecte
          signingCertHashes: ['mVBCMFiGMSPSfPCYSFIl9Bz8sTxABCDEFGHIJKLMNOP='],
          teamId: 'ABCDE12345',
          bundleIds: ['com.vibeterm.vibeterm'],
        );

        // Doit au moins avertir que le package ne correspond pas
        expect(
          erreurs.any((e) => e.contains('com.vibeterm.app') || e.contains('correspond')),
          isTrue,
          reason: 'L\'ancienne valeur com.vibeterm.app doit déclencher un avertissement',
        );
      });
    });

    // =========================================================================
    // GROUPE 4 : Niveaux de sévérité des menaces
    // =========================================================================

    group('Sévérités des menaces RASP', () {

      test('hook Frida doit être CRITICAL', () {
        expect(
          RaspActivationGuide.threatSeverities[RaspThreatType.hook],
          equals(ThreatSeverity.critical),
          reason: 'Frida peut voler les clés SSH — réaction immédiate requise',
        );
      });

      test('tampering (APK modifiée) doit être CRITICAL', () {
        expect(
          RaspActivationGuide.threatSeverities[RaspThreatType.tampering],
          equals(ThreatSeverity.critical),
          reason: 'Une APK repackagée peut contenir un backdoor',
        );
      });

      test('runtimeManipulation doit être CRITICAL', () {
        expect(
          RaspActivationGuide.threatSeverities[RaspThreatType.runtimeManipulation],
          equals(ThreatSeverity.critical),
        );
      });

      test('debugger attaché doit être HIGH', () {
        expect(
          RaspActivationGuide.threatSeverities[RaspThreatType.debugger],
          equals(ThreatSeverity.high),
          reason: 'Un débogueur peut lire la mémoire — bloquer les fonctions sensibles',
        );
      });

      test('accès privilégié (root/jailbreak) doit être HIGH', () {
        expect(
          RaspActivationGuide.threatSeverities[RaspThreatType.privilegedAccess],
          equals(ThreatSeverity.high),
        );
      });

      test('émulateur doit être MEDIUM (non bloquant)', () {
        expect(
          RaspActivationGuide.threatSeverities[RaspThreatType.emulator],
          equals(ThreatSeverity.medium),
          reason: 'Les émulateurs peuvent être légitimes (tests CI/CD)',
        );
      });

      test('toutes les menaces connues ont une sévérité définie', () {
        // Vérifie qu'aucun type de menace n'a été oublié dans la map
        for (final type in RaspThreatType.values) {
          expect(
            RaspActivationGuide.threatSeverities.containsKey(type),
            isTrue,
            reason: 'La menace $type n\'a pas de sévérité définie — oubli dangereux',
          );
        }
      });
    });

    // =========================================================================
    // GROUPE 5 : Configuration getActivatedConfig
    // =========================================================================

    group('getActivatedConfig', () {

      test('isProd doit être false en mode debug Flutter', () {
        final config = RaspActivationGuide.getActivatedConfig();
        // En environnement de test, kDebugMode est true
        // donc isProd doit être false
        expect(
          config['isProd'],
          equals(!kDebugMode),
          reason: 'isProd doit être synchronisé avec kDebugMode pour éviter les '
              'faux positifs en développement',
        );
      });

      test('la config doit contenir le bon package name', () {
        final config = RaspActivationGuide.getActivatedConfig();
        final androidConfig = config['androidConfig'] as Map<String, dynamic>;
        expect(
          androidConfig['packageName'],
          equals('com.vibeterm.vibeterm'),
        );
      });

      test('le watcherMail doit être défini', () {
        final config = RaspActivationGuide.getActivatedConfig();
        expect(
          config['watcherMail'],
          isNotEmpty,
        );
        expect(
          config['watcherMail'],
          contains('@'),
          reason: 'Le watcherMail doit être une adresse email valide',
        );
      });
    });

    // =========================================================================
    // GROUPE 6 : Version requise
    // =========================================================================

    group('Version freeRASP', () {

      test('la version minimale requise doit être au moins 6.6.0', () {
        // Vérification que la constante est définie et non vide
        expect(
          RaspActivationGuide.requiredFreeRaspVersion,
          isNotEmpty,
        );

        // Parser la version pour vérifier qu'elle est >= 6.6.0
        final parts = RaspActivationGuide.requiredFreeRaspVersion
            .split('.')
            .map(int.parse)
            .toList();

        expect(parts[0], greaterThanOrEqualTo(6), reason: 'Major >= 6');
        if (parts[0] == 6) {
          expect(parts[1], greaterThanOrEqualTo(6), reason: 'Minor >= 6 quand major == 6');
        }
      });
    });
  });
}
