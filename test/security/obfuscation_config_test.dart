// =============================================================================
// TEST FIX-009 — Vérification configuration obfuscation Flutter
// =============================================================================
//
// Ces tests valident que :
//   1. getBuildFlags retourne exactement les bons flags
//   2. Le script de build contient --obfuscate
//   3. Le script de build contient --split-debug-info
//   4. Le dossier de symboles est correctement défini
//   5. Les deux plateformes (Unix et Windows) sont couvertes
//
// LANCER LES TESTS :
//   flutter test test/security/test_fix_009.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/core/security/obfuscation_config.dart';

void main() {
  group('FIX-009 — ObfuscationConfig', () {

    // =========================================================================
    // GROUPE 1 : Flags de build
    // =========================================================================

    group('getBuildFlags — drapeaux de compilation', () {

      test('doit retourner exactement 2 flags', () {
        final flags = ObfuscationConfig.getBuildFlags();
        expect(
          flags.length,
          equals(2),
          reason: 'Deux flags sont nécessaires : --obfuscate et --split-debug-info',
        );
      });

      test('doit contenir le flag --obfuscate', () {
        final flags = ObfuscationConfig.getBuildFlags();
        expect(
          flags.contains('--obfuscate'),
          isTrue,
          reason: '--obfuscate est obligatoire pour activer l\'obfuscation Dart',
        );
      });

      test('doit contenir --split-debug-info avec un chemin', () {
        final flags = ObfuscationConfig.getBuildFlags();
        final splitFlag = flags.firstWhere(
          (f) => f.startsWith('--split-debug-info='),
          orElse: () => '',
        );

        expect(
          splitFlag,
          isNotEmpty,
          reason: '--split-debug-info est obligatoire pour conserver les symboles de crash',
        );

        // Vérifier que le chemin après = n'est pas vide
        final chemin = splitFlag.split('=').skip(1).join('=');
        expect(
          chemin,
          isNotEmpty,
          reason: 'Le chemin du dossier de symboles ne peut pas être vide',
        );
      });

      test('le chemin de --split-debug-info doit correspondre à obfuscatedBuildDir', () {
        final flags = ObfuscationConfig.getBuildFlags();
        final splitFlag = flags.firstWhere(
          (f) => f.startsWith('--split-debug-info='),
          orElse: () => '',
        );

        final chemin = splitFlag.replaceFirst('--split-debug-info=', '');
        expect(
          chemin,
          equals(ObfuscationConfig.obfuscatedBuildDir),
          reason: 'Le chemin dans les flags doit correspondre à la constante obfuscatedBuildDir',
        );
      });

      test('les flags ne doivent PAS contenir --debug ou --profile', () {
        final flags = ObfuscationConfig.getBuildFlags();
        expect(
          flags.any((f) => f == '--debug' || f == '--profile'),
          isFalse,
          reason: 'L\'obfuscation s\'applique uniquement aux builds release',
        );
      });
    });

    // =========================================================================
    // GROUPE 2 : Script de build Unix/Linux/macOS
    // =========================================================================

    group('generateBuildScript — script Unix', () {

      late String scriptUnix;

      setUp(() {
        scriptUnix = ObfuscationConfig.generateBuildScript(platform: 'linux_macos');
      });

      test('le script Unix doit contenir --obfuscate', () {
        expect(
          scriptUnix.contains('--obfuscate'),
          isTrue,
          reason: 'Le script de build doit inclure --obfuscate',
        );
      });

      test('le script Unix doit contenir --split-debug-info', () {
        expect(
          scriptUnix.contains('--split-debug-info='),
          isTrue,
          reason: 'Sans --split-debug-info les crashes en production sont illisibles',
        );
      });

      test('le script Unix doit couvrir les 3 plateformes', () {
        expect(
          scriptUnix.contains('flutter build apk'),
          isTrue,
          reason: 'Le script doit inclure le build APK Android',
        );
        expect(
          scriptUnix.contains('flutter build appbundle'),
          isTrue,
          reason: 'Le script doit inclure le build App Bundle (Play Store)',
        );
        expect(
          scriptUnix.contains('flutter build ios'),
          isTrue,
          reason: 'Le script doit inclure le build iOS',
        );
      });

      test('le script Unix doit avoir le shebang bash', () {
        expect(
          scriptUnix.startsWith('#!/bin/bash'),
          isTrue,
          reason: 'Un script shell doit commencer par un shebang',
        );
      });

      test('le script Unix doit avoir set -e (arrêt sur erreur)', () {
        expect(
          scriptUnix.contains('set -e'),
          isTrue,
          reason: 'set -e arrête le script si une commande échoue — sécurité obligatoire',
        );
      });

      test('le script Unix doit mentionner flutter symbolize pour décoder les crashes', () {
        expect(
          scriptUnix.contains('flutter symbolize') || scriptUnix.contains('symbolize'),
          isTrue,
          reason: 'Les développeurs doivent savoir comment décoder les stack traces',
        );
      });
    });

    // =========================================================================
    // GROUPE 3 : Script de build Windows
    // =========================================================================

    group('generateBuildScript — script Windows', () {

      late String scriptWindows;

      setUp(() {
        scriptWindows = ObfuscationConfig.generateBuildScript(platform: 'windows');
      });

      test('le script Windows doit contenir --obfuscate', () {
        expect(
          scriptWindows.contains('--obfuscate'),
          isTrue,
        );
      });

      test('le script Windows doit contenir --split-debug-info', () {
        expect(
          scriptWindows.contains('--split-debug-info='),
          isTrue,
        );
      });

      test('le script Windows doit avoir @echo off', () {
        expect(
          scriptWindows.contains('@echo off'),
          isTrue,
          reason: 'Convention Windows batch standard',
        );
      });

      test('le script Windows doit vérifier errorlevel', () {
        expect(
          scriptWindows.contains('errorlevel'),
          isTrue,
          reason: 'Windows batch doit vérifier les codes d\'erreur avec errorlevel',
        );
      });
    });

    // =========================================================================
    // GROUPE 4 : Constantes
    // =========================================================================

    group('Constantes d\'obfuscation', () {

      test('obfuscatedBuildDir ne doit pas être vide', () {
        expect(
          ObfuscationConfig.obfuscatedBuildDir,
          isNotEmpty,
        );
      });

      test('obfuscatedBuildDir doit être sous build/', () {
        expect(
          ObfuscationConfig.obfuscatedBuildDir.startsWith('build/'),
          isTrue,
          reason: 'Les symboles doivent être dans le dossier build/ (ignoré par git)',
        );
      });

      test('la liste sensitiveDartClassNames ne doit pas être vide', () {
        expect(
          ObfuscationConfig.sensitiveDartClassNames,
          isNotEmpty,
          reason: 'Des classes sensibles doivent être définies pour la vérification',
        );
      });

      test('sensitiveDartClassNames doit contenir les classes critiques ChillShell', () {
        expect(
          ObfuscationConfig.sensitiveDartClassNames.contains('SshConnectionManager'),
          isTrue,
        );
        expect(
          ObfuscationConfig.sensitiveDartClassNames.contains('PrivateKeyStore'),
          isTrue,
        );
      });
    });

    // =========================================================================
    // GROUPE 5 : Cohérence des flags dans le script vs getBuildFlags()
    // =========================================================================

    group('Cohérence flags / script', () {

      test('le script Unix doit utiliser exactement les mêmes flags que getBuildFlags()', () {
        final flags = ObfuscationConfig.getBuildFlags();
        final scriptUnix = ObfuscationConfig.generateBuildScript(platform: 'linux_macos');

        // Chaque flag retourné par getBuildFlags() doit apparaître dans le script
        for (final flag in flags) {
          expect(
            scriptUnix.contains(flag),
            isTrue,
            reason: 'Le flag "$flag" est dans getBuildFlags() mais absent du script',
          );
        }
      });

      test('le script Windows doit utiliser exactement les mêmes flags que getBuildFlags()', () {
        final flags = ObfuscationConfig.getBuildFlags();
        final scriptWindows = ObfuscationConfig.generateBuildScript(platform: 'windows');

        for (final flag in flags) {
          expect(
            scriptWindows.contains(flag),
            isTrue,
            reason: 'Le flag "$flag" est dans getBuildFlags() mais absent du script Windows',
          );
        }
      });
    });

    // =========================================================================
    // GROUPE 6 : Résultat de vérification
    // =========================================================================

    group('ObfuscationVerificationResult', () {

      test('toString doit indiquer ACTIVE quand isObfuscated = true', () {
        final resultat = ObfuscationVerificationResult(
          isObfuscated: true,
          erreur: null,
          classesDetectees: [],
        );
        expect(
          resultat.toString(),
          contains('ACTIVE'),
        );
      });

      test('toString doit indiquer INACTIVE quand isObfuscated = false', () {
        final resultat = ObfuscationVerificationResult(
          isObfuscated: false,
          erreur: 'Classes trouvées : SshConnectionManager',
          classesDetectees: ['SshConnectionManager'],
        );
        expect(
          resultat.toString(),
          contains('INACTIVE'),
        );
      });

      test('doit lister les classes détectées', () {
        final resultat = ObfuscationVerificationResult(
          isObfuscated: false,
          erreur: 'Test',
          classesDetectees: ['SshConnectionManager', 'PrivateKeyStore'],
        );
        expect(resultat.classesDetectees, hasLength(2));
        expect(resultat.classesDetectees, contains('SshConnectionManager'));
      });
    });
  });
}
