// =============================================================================
// FIX-009 — Configuration obfuscation Flutter (GAP-009, P0)
// =============================================================================
//
// PROBLÈME RÉSOLU :
//   Le build Flutter ne passait pas --obfuscate. Après décompilation d'un APK
//   de production avec apktool ou jadx, tous les noms de classes Dart étaient
//   lisibles en clair : SshConnectionManager, PrivateKeyStore, etc.
//   Un attaquant peut identifier et cibler directement les fonctions critiques.
//
// CE QUE CE FICHIER FAIT :
//   1. Documente les flags de build obligatoires pour activer l'obfuscation
//   2. Génère les scripts de build pour chaque plateforme
//   3. Fournit une vérification post-build pour détecter si l'obfuscation a été omise
//   4. Explique les limites de --obfuscate (chaînes en clair) et la solution complémentaire
//
// INTÉGRATION :
//   Remplacer dans CI/CD (GitHub Actions, Codemagic, Bitrise) :
//     AVANT : flutter build apk --release
//     APRÈS  : flutter build apk --obfuscate --split-debug-info=build/debug-info
//
// IMPORTANT — CONSERVATION DES SYMBOLS :
//   Le dossier build/debug-info/ doit être archivé de manière sécurisée.
//   Il est nécessaire pour déchiffrer les stack traces de crashes en production.
//   Ne JAMAIS inclure build/debug-info/ dans l'APK distribué.
// =============================================================================

import 'dart:io';

// =============================================================================
// CLASSE PRINCIPALE — CONFIGURATION D'OBFUSCATION
// =============================================================================

/// Outils pour activer et vérifier l'obfuscation du code Flutter.
///
/// L'obfuscation Flutter (via Dart --obfuscate) remplace les noms de classes,
/// méthodes et variables par des identifiants courts sans signification.
/// Cela rend la rétro-ingénierie significativement plus difficile.
class ObfuscationConfig {
  // Constructeur privé — classe utilitaire, pas d'instanciation.
  const ObfuscationConfig._();

  // ===========================================================================
  // CONSTANTES
  // ===========================================================================

  /// Dossier de destination pour les symboles de débogage.
  /// Archiver ce dossier de manière sécurisée après chaque build de production.
  /// Ne JAMAIS l'inclure dans le paquet distribué.
  static const String obfuscatedBuildDir = 'build/debug-info';

  /// Noms de classes ChillShell à rechercher pour vérifier si l'obfuscation
  /// a bien fonctionné. Si ces chaînes sont trouvées dans le binaire final,
  /// l'obfuscation n'a pas été appliquée.
  static const List<String> sensitiveDartClassNames = [
    'SshConnectionManager',
    'PrivateKeyStore',
    'TerminalSession',
    'RaspService',
    'SecurityAuditLogger',
    'CommandRunner',
  ];

  // ===========================================================================
  // MÉTHODE : FLAGS DE BUILD
  // ===========================================================================

  /// Retourne les flags Flutter à ajouter à chaque commande de build release.
  ///
  /// Ces deux flags sont TOUJOURS utilisés ensemble :
  ///   --obfuscate             : active l'obfuscation Dart
  ///   --split-debug-info=DIR  : sauvegarde les symboles pour décoder les crashes
  ///
  /// Sans --split-debug-info, les crashes en production produisent des
  /// stack traces illisibles qu'on ne peut pas décoder.
  static List<String> getBuildFlags() {
    return [
      '--obfuscate',
      '--split-debug-info=$obfuscatedBuildDir',
    ];
  }

  // ===========================================================================
  // MÉTHODE : GÉNÉRATION DU SCRIPT DE BUILD
  // ===========================================================================

  /// Génère un script shell (Linux/macOS) ou batch (Windows) pour automatiser
  /// les builds de production avec obfuscation activée.
  ///
  /// [platform] : 'linux_macos' ou 'windows'
  /// Retourne le contenu du script prêt à écrire dans un fichier.
  static String generateBuildScript({String platform = 'linux_macos'}) {
    if (platform == 'windows') {
      return _generateWindowsBuildScript();
    }
    return _generateUnixBuildScript();
  }

  static String _generateUnixBuildScript() {
    return '''#!/bin/bash
# =============================================================================
# Script de build ChillShell avec obfuscation (Linux/macOS)
# Généré par ObfuscationConfig.generateBuildScript()
#
# USAGE : bash build_release.sh
# PRÉREQUIS : flutter >= 3.0.0, JAVA_HOME défini, keystore configuré
# =============================================================================

set -e  # Arrêter immédiatement en cas d'erreur

# Nettoyage du dossier de symboles précédent
echo "[BUILD] Nettoyage des symboles précédents..."
rm -rf $obfuscatedBuildDir
mkdir -p $obfuscatedBuildDir

# --- Android APK ---
echo "[BUILD] Compilation APK Android (obfuscation activée)..."
flutter build apk --obfuscate --split-debug-info=$obfuscatedBuildDir

# --- Android App Bundle (Play Store) ---
echo "[BUILD] Compilation App Bundle Android (obfuscation activée)..."
flutter build appbundle --obfuscate --split-debug-info=$obfuscatedBuildDir

# --- iOS ---
echo "[BUILD] Compilation iOS (obfuscation activée)..."
flutter build ios --obfuscate --split-debug-info=$obfuscatedBuildDir

# --- Archivage sécurisé des symboles ---
echo "[BUILD] Archivage des symboles de débogage..."
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
SYMBOLS_ARCHIVE="debug-symbols_\${TIMESTAMP}.tar.gz"
tar -czf "\$SYMBOLS_ARCHIVE" $obfuscatedBuildDir
echo "[BUILD] Symboles archivés dans : \$SYMBOLS_ARCHIVE"
echo "[BUILD] IMPORTANT : Stocker cet archive de manière sécurisée (vault, S3 chiffré, etc.)"
echo "[BUILD] Ne PAS inclure dans les artefacts distribués publiquement."

echo "[BUILD] Build terminé avec obfuscation activée."
echo "[BUILD] Pour décoder un crash : flutter symbolize -i crash.txt -d $obfuscatedBuildDir"
''';
  }

  static String _generateWindowsBuildScript() {
    return '''@echo off
rem =============================================================================
rem Script de build ChillShell avec obfuscation (Windows)
rem Généré par ObfuscationConfig.generateBuildScript()
rem
rem USAGE : build_release.bat
rem PRÉREQUIS : flutter >= 3.0.0, JAVA_HOME défini, keystore configuré
rem =============================================================================

echo [BUILD] Nettoyage des symboles precedents...
if exist $obfuscatedBuildDir rmdir /s /q $obfuscatedBuildDir
mkdir $obfuscatedBuildDir

rem --- Android APK ---
echo [BUILD] Compilation APK Android (obfuscation activee)...
flutter build apk --obfuscate --split-debug-info=$obfuscatedBuildDir
if errorlevel 1 goto :error

rem --- Android App Bundle ---
echo [BUILD] Compilation App Bundle Android (obfuscation activee)...
flutter build appbundle --obfuscate --split-debug-info=$obfuscatedBuildDir
if errorlevel 1 goto :error

rem --- iOS (necessaire macOS, ignoré sur Windows) ---
rem flutter build ios --obfuscate --split-debug-info=$obfuscatedBuildDir

echo [BUILD] Build termine avec obfuscation activee.
echo [BUILD] IMPORTANT : Archiver le dossier $obfuscatedBuildDir de maniere securisee.
goto :end

:error
echo [ERREUR] Le build a echoue. Consulter les logs ci-dessus.
exit /b 1

:end
''';
  }

  // ===========================================================================
  // MÉTHODE : VÉRIFICATION DE L'OBFUSCATION
  // ===========================================================================

  /// Vérifie si un binaire Flutter a bien été obfusqué.
  ///
  /// Stratégie : chercher les noms de classes Dart sensibles dans les chaînes
  /// extraites du binaire. Si des noms sont trouvés en clair, l'obfuscation
  /// n'a pas fonctionné (ou n'a pas été appliquée).
  ///
  /// [binaryPath] : chemin vers le fichier .so, .apk ou le dossier du build
  ///
  /// Retourne true si l'obfuscation semble active (aucun nom trouvé).
  /// Retourne false si des noms de classes sensibles sont détectés en clair.
  ///
  /// LIMITATION : Cette vérification est heuristique. Une absence de détection
  /// ne garantit pas à 100% que l'obfuscation est active. Préférer vérifier
  /// les flags de build directement dans le pipeline CI/CD.
  static Future<ObfuscationVerificationResult> verifyObfuscation(
    String binaryPath,
  ) async {
    final fichier = File(binaryPath);
    if (!await fichier.exists()) {
      return ObfuscationVerificationResult(
        isObfuscated: false,
        erreur: 'Fichier introuvable : $binaryPath',
        classesDetectees: [],
      );
    }

    // Utiliser la commande `strings` pour extraire les chaînes lisibles
    // `strings` est disponible sur Linux/macOS, et dans Git Bash sur Windows
    ProcessResult result;
    try {
      result = await Process.run(
        'strings',
        ['-n', '8', binaryPath], // Chaînes de 8+ caractères
        runInShell: false, // Sécurité : pas de runInShell
      );
    } on ProcessException catch (e) {
      return ObfuscationVerificationResult(
        isObfuscated: false,
        erreur: 'Impossible d\'exécuter strings : ${e.message}. '
            'Installer binutils ou vérifier le PATH.',
        classesDetectees: [],
      );
    }

    if (result.exitCode != 0) {
      return ObfuscationVerificationResult(
        isObfuscated: false,
        erreur: 'Erreur strings (code ${result.exitCode})',
        classesDetectees: [],
      );
    }

    // Chercher les noms de classes sensibles dans la sortie
    final output = result.stdout as String;
    final classesDetectees = sensitiveDartClassNames
        .where((nom) => output.contains(nom))
        .toList();

    return ObfuscationVerificationResult(
      isObfuscated: classesDetectees.isEmpty,
      erreur: classesDetectees.isEmpty
          ? null
          : 'Classes Dart trouvées en clair : ${classesDetectees.join(', ')}. '
              'L\'obfuscation n\'est pas active.',
      classesDetectees: classesDetectees,
    );
  }

  // ===========================================================================
  // NOTE : Limites de --obfuscate et solution complémentaire
  // ===========================================================================

  /// RECOMMANDATION : Compléter --obfuscate avec dart_confidential.
  ///
  /// --obfuscate de Flutter obfusque les NOMS de classes, méthodes et variables.
  /// Mais les CHAÎNES DE CARACTÈRES restent en clair dans le binaire :
  ///   - URLs d'API
  ///   - Clés hardcodées (même partielles)
  ///   - Noms de commandes shell
  ///   - Messages d'erreur internes
  ///
  /// Un attaquant peut extraire ces chaînes avec `strings` ou jadx.
  ///
  /// SOLUTION : Ajouter dart_confidential dans pubspec.yaml :
  ///   dart_confidential: ^1.0.0
  ///
  /// Utilisation :
  /// ```dart
  /// // Avant (vulnérable — URL visible dans le binaire) :
  /// const apiUrl = 'https://api.chillshell.app/v1/auth';
  ///
  /// // Après (obfusqué au niveau des chaînes) :
  /// final apiUrl = Confidential.reveal('ENCODED_VALUE_HERE');
  /// ```
  ///
  /// Encoder les chaînes sensibles avec l'outil CLI dart_confidential :
  ///   dart run dart_confidential encode "https://api.chillshell.app/v1/auth"
  static const String dartConfidentialNote = '''
RECOMMANDATION : Ajouter dart_confidential pour protéger les chaînes de caractères.

--obfuscate protège les NOMS de classes/méthodes.
dart_confidential protège les VALEURS de chaînes (URLs, clés, constantes).

Les deux outils sont complémentaires et doivent être utilisés ensemble.
Voir : https://pub.dev/packages/dart_confidential
''';
}

// =============================================================================
// CLASSE DE RÉSULTAT DE VÉRIFICATION
// =============================================================================

/// Résultat de la vérification d'obfuscation.
class ObfuscationVerificationResult {
  /// true si aucune classe sensible n'a été détectée (obfuscation probable).
  final bool isObfuscated;

  /// Message d'erreur si l'obfuscation n'est pas détectée. null si OK.
  final String? erreur;

  /// Liste des noms de classes trouvés en clair dans le binaire.
  final List<String> classesDetectees;

  const ObfuscationVerificationResult({
    required this.isObfuscated,
    required this.erreur,
    required this.classesDetectees,
  });

  @override
  String toString() {
    if (isObfuscated) {
      return 'Obfuscation : ACTIVE (aucune classe sensible détectée en clair)';
    }
    return 'Obfuscation : INACTIVE — $erreur';
  }
}
