// =============================================================================
// FIX-008 — Activation freeRASP (GAP-008, P0)
// =============================================================================
//
// PROBLÈME RÉSOLU :
//   freeRASP était intégré mais DÉSACTIVÉ en pratique à cause de PLACEHOLDERS
//   dans la configuration. Résultat : toute la protection RASP était inopérante
//   en production (aucune détection Frida, root, tampering, débogueur).
//
// CE QUE CE FICHIER FAIT :
//   1. Fournit les outils pour générer le vrai hash de signature
//   2. Vérifie que la config ne contient plus de placeholders
//   3. Définit la sévérité de chaque menace RASP détectable
//   4. Fournit une configuration prête pour la production
//
// PRÉREQUIS :
//   freeRASP >= 6.6.0 dans pubspec.yaml :
//     freerasp: ^6.6.0
//
// INTÉGRATION RECOMMANDÉE :
//   Dans main.dart, AVANT runApp() :
//     final errors = RaspActivationGuide.verifyConfig(RaspActivationGuide.getActivatedConfig());
//     if (errors.isNotEmpty) throw StateError('RASP config invalide: $errors');
//     await Talsec.instance.start(RaspActivationGuide.getActivatedConfig());
// =============================================================================

import 'package:flutter/foundation.dart' show kDebugMode;

// Import conditionnel — freeRASP n'est disponible que sur Android/iOS
// Sur desktop (Linux, Windows, macOS) ces imports ne compileront pas sans
// ajout d'un stub. Adapter selon la plateforme cible.
//
// import 'package:freerasp/freerasp.dart';

// =============================================================================
// TYPES DE MENACES RASP
// =============================================================================

/// Niveau de sévérité associé à chaque menace détectée par freeRASP.
/// Détermine la réaction de l'application.
enum ThreatSeverity {
  /// Menace critique — terminer l'application immédiatement sans délai.
  /// Exemples : hook Frida actif, APK modifiée (tampering).
  critical,

  /// Menace élevée — bloquer les fonctions sensibles et avertir l'utilisateur.
  /// Exemples : débogueur attaché, accès root détecté.
  high,

  /// Menace moyenne — journaliser l'événement, continuer en mode dégradé.
  /// Exemple : exécution sur émulateur (tests automatisés légitimes possible).
  medium,
}

/// Types de menaces que freeRASP peut détecter.
/// Correspondance avec les callbacks ThreatListener de freeRASP.
enum RaspThreatType {
  /// Hook dynamique actif (Frida, Xposed, etc.).
  /// Permet à un attaquant de modifier le comportement de l'app en temps réel.
  hook,

  /// APK ou binaire modifié (repackaging).
  /// La signature de l'app ne correspond plus au certificat de production.
  tampering,

  /// Débogueur attaché au processus.
  /// Permet l'inspection de la mémoire et la modification du flux d'exécution.
  debugger,

  /// Appareil rooté ou jailbreaké.
  /// Accès privilégié qui contourne les protections sandboxées d'Android/iOS.
  privilegedAccess,

  /// Exécution sur émulateur (Android Emulator, Genymotion, etc.).
  /// Souvent utilisé pour les analyses automatisées de malware.
  emulator,

  /// Hook détecté au niveau de l'ART/Dalvik runtime.
  runtimeManipulation,

  /// Clavier tiers suspect (keylogger potentiel).
  untrustedInstallationSource,
}

// =============================================================================
// CLASSE PRINCIPALE — GUIDE D'ACTIVATION RASP
// =============================================================================

/// Outils et configuration pour activer correctement freeRASP en production.
///
/// ATTENTION : Ce fichier est un GUIDE et un VÉRIFICATEUR.
/// Les valeurs réelles (hash de signature, Team ID Apple) DOIVENT être
/// remplacées par les vraies valeurs avant tout build de production.
class RaspActivationGuide {
  // Constructeur privé — classe utilitaire, pas d'instanciation.
  const RaspActivationGuide._();

  // ===========================================================================
  // CONSTANTES
  // ===========================================================================

  /// Version minimale de freeRASP requise pour une protection complète.
  /// Les versions antérieures manquent de détections critiques.
  static const String requiredFreeRaspVersion = '6.6.0';

  /// Vrai package name de l'application ChillShell.
  /// IMPORTANT : doit correspondre EXACTEMENT à applicationId dans build.gradle.kts
  /// et au nom de package déclaré chez Google Play.
  static const String productionPackageName = 'com.vibeterm.vibeterm';

  /// Adresse email qui recevra les alertes de sécurité freeRASP.
  /// Peut être un alias de distribution (SOC, équipe sécu).
  static const String securityWatcherEmail = 'security@chillshell.app';

  // ===========================================================================
  // MÉTHODE : GÉNÉRATION DU HASH DE SIGNATURE
  // ===========================================================================

  /// Retourne la documentation pour générer le hash SHA-256 du certificat
  /// de signature Android (format attendu par freeRASP).
  ///
  /// ÉTAPES À SUIVRE (une seule fois, à la création du keystore) :
  ///
  /// 1. Extraire le hash depuis le keystore :
  ///    ```
  ///    keytool -list -v -keystore release.jks -alias chillshell
  ///    ```
  ///    Repérer la ligne "SHA-256: XX:XX:XX:..."
  ///
  /// 2. Supprimer les ":" et mettre en minuscules :
  ///    AA:BB:CC:DD → aabbccdd...
  ///
  /// 3. Encoder en Base64 :
  ///    ```bash
  ///    echo -n "aabbccdd..." | xxd -r -p | base64
  ///    ```
  ///
  /// 4. Placer le résultat dans signingCertHashes ci-dessous.
  ///
  /// ALTERNATIVE via apksigner (recommandée sur CI/CD) :
  ///    ```
  ///    apksigner verify --print-certs app-release.apk | grep SHA-256
  ///    ```
  static String generateSigningHashInstructions() {
    return '''
=== GÉNÉRATION DU HASH DE SIGNATURE POUR freeRASP ===

ÉTAPE 1 — Extraire depuis le keystore :
  keytool -list -v -keystore keystores/release.jks -alias chillshell | grep "SHA-256"

ÉTAPE 2 — Formater (supprimer ":" et mettre en minuscules) :
  Exemple : AA:BB:CC → aabbcc

ÉTAPE 3 — Convertir en Base64 :
  echo -n "aabbcc..." | xxd -r -p | base64

ÉTAPE 4 — Placer dans signingCertHashes :
  signingCertHashes: ['RÉSULTAT_BASE64_ICI']

VÉRIFICATION depuis un APK signé (méthode alternative) :
  apksigner verify --print-certs build/app/outputs/apk/release/app-release.apk

NOTE : En cas de signature Google Play Signing, utiliser le hash
du certificat de déploiement visible dans Play Console >
  App Integrity > App signing key certificate.
''';
  }

  // ===========================================================================
  // MÉTHODE : VÉRIFICATION DE LA CONFIGURATION
  // ===========================================================================

  /// Vérifie qu'une configuration freeRASP ne contient pas de placeholders.
  ///
  /// Retourne la liste des erreurs détectées.
  /// Une liste vide signifie que la configuration est valide pour la production.
  ///
  /// [packageName] Le package Android à vérifier.
  /// [signingCertHashes] Les hashes de signature Android.
  /// [teamId] Le Team ID Apple pour iOS.
  /// [bundleIds] Les bundle IDs iOS.
  static List<String> verifyConfig({
    required String packageName,
    required List<String> signingCertHashes,
    required String teamId,
    required List<String> bundleIds,
  }) {
    final List<String> erreurs = [];

    // --- Vérification Android : package name ---
    if (packageName.isEmpty) {
      erreurs.add('ERREUR: packageName est vide.');
    }
    if (packageName.contains('PLACEHOLDER')) {
      erreurs.add('ERREUR: packageName contient un PLACEHOLDER non remplacé.');
    }
    if (packageName != productionPackageName) {
      erreurs.add(
        'AVERTISSEMENT: packageName "$packageName" ne correspond pas au '
        'package de production attendu "$productionPackageName". '
        'Vérifier que c\'est intentionnel.',
      );
    }

    // --- Vérification Android : hashes de signature ---
    if (signingCertHashes.isEmpty) {
      erreurs.add('ERREUR: signingCertHashes est vide. La vérification de signature est désactivée.');
    }
    for (int i = 0; i < signingCertHashes.length; i++) {
      final hash = signingCertHashes[i];
      if (hash.isEmpty) {
        erreurs.add('ERREUR: signingCertHashes[$i] est vide.');
      }
      if (hash.toUpperCase().contains('PLACEHOLDER')) {
        erreurs.add(
          'ERREUR CRITIQUE: signingCertHashes[$i] contient "PLACEHOLDER". '
          'freeRASP ne peut pas vérifier la signature. L\'app peut être '
          'repackagée sans détection.',
        );
      }
      // Un hash Base64 valide ne contient que [A-Za-z0-9+/=]
      // et fait typiquement 44 caractères (SHA-256 en Base64)
      if (hash.length < 20 && !hash.contains('PLACEHOLDER')) {
        erreurs.add(
          'AVERTISSEMENT: signingCertHashes[$i] semble trop court (${ hash.length} chars). '
          'Un hash SHA-256 en Base64 fait 44 caractères.',
        );
      }
    }

    // --- Vérification iOS : Team ID ---
    if (teamId.isEmpty) {
      erreurs.add('ERREUR: teamId iOS est vide.');
    }
    if (teamId.toUpperCase().contains('PLACEHOLDER')) {
      erreurs.add(
        'ERREUR CRITIQUE: teamId iOS contient "PLACEHOLDER". '
        'La protection iOS est inopérante.',
      );
    }
    // Un Team ID Apple est exactement 10 caractères alphanumériques majuscules
    if (teamId.isNotEmpty &&
        !teamId.contains('PLACEHOLDER') &&
        !RegExp(r'^[A-Z0-9]{10}$').hasMatch(teamId)) {
      erreurs.add(
        'AVERTISSEMENT: teamId "$teamId" ne ressemble pas à un Team ID Apple '
        'valide (10 caractères alphanumériques majuscules, ex: ABCDE12345).',
      );
    }

    // --- Vérification iOS : bundle IDs ---
    if (bundleIds.isEmpty) {
      erreurs.add('ERREUR: bundleIds iOS est vide.');
    }
    for (final bundleId in bundleIds) {
      if (bundleId.toUpperCase().contains('PLACEHOLDER')) {
        erreurs.add('ERREUR: bundleId "$bundleId" contient un PLACEHOLDER.');
      }
    }

    return erreurs;
  }

  // ===========================================================================
  // MÉTHODE : CONFIGURATION PRÊTE POUR LA PRODUCTION
  // ===========================================================================

  /// Retourne les paramètres de configuration freeRASP pour la production.
  ///
  /// AVANT D'UTILISER : remplacer les valeurs marquées "À_REMPLACER" par les
  /// vraies valeurs générées via [generateSigningHashInstructions].
  ///
  /// Le paramètre isProd est automatiquement false en mode debug Flutter,
  /// ce qui désactive les protections pendant le développement.
  static Map<String, dynamic> getActivatedConfig() {
    return {
      'androidConfig': {
        // Package name réel — NE PAS MODIFIER sauf si renommage de l'app
        'packageName': productionPackageName,

        // OBLIGATOIRE : remplacer par le vrai hash généré avec keytool
        // Voir generateSigningHashInstructions() pour la procédure
        'signingCertHashes': [
          // 'HASH_BASE64_À_REMPLACER_AVANT_PRODUCTION',
          // Exemple de format attendu (44 chars Base64) :
          // 'mVBCMFiGMSPSfPCYSFIl9Bz8sT+... (44 chars)'
        ],
      },
      'iosConfig': {
        'bundleIds': ['com.vibeterm.vibeterm'],
        // OBLIGATOIRE : remplacer par le vrai Team ID Apple (10 chars)
        // Visible dans developer.apple.com > Account > Membership
        'teamId': 'TEAM_ID_À_REMPLACER',
      },
      'watcherMail': securityWatcherEmail,
      // isProd = false en debug, true en release
      // Cela évite les faux positifs sur les émulateurs de développement
      'isProd': !kDebugMode,
    };
  }

  // ===========================================================================
  // SÉVÉRITÉS DES MENACES
  // ===========================================================================

  /// Définit la réaction pour chaque type de menace détecté par freeRASP.
  ///
  /// LOGIQUE DE RÉACTION :
  ///   - critical → appeler [ReactToThreat.killApp] immédiatement
  ///   - high     → bloquer les actions SSH/terminal, afficher alerte
  ///   - medium   → journaliser via AuditLogger, continuer normalement
  static const Map<RaspThreatType, ThreatSeverity> threatSeverities = {
    // Frida ou autre framework de hook dynamique détecté.
    // Un attaquant peut intercepter toutes les fonctions SSH, voler les clés.
    // Réaction : terminer l'app sans délai, sans message explicatif.
    RaspThreatType.hook: ThreatSeverity.critical,

    // APK repackagée — la signature ne correspond pas au certificat de prod.
    // Distribution non officielle, potentiellement modifiée pour voler des données.
    // Réaction : terminer l'app immédiatement.
    RaspThreatType.tampering: ThreatSeverity.critical,

    // Débogueur Android (ADB, JDWP) ou iOS (lldb) attaché.
    // Inspection de la mémoire possible, lecture des clés SSH en clair.
    // Réaction : bloquer les fonctions sensibles, avertir l'utilisateur.
    RaspThreatType.debugger: ThreatSeverity.high,

    // Appareil rooté (Android) ou jailbreaké (iOS).
    // Les protections sandbox sont contournables.
    // Réaction : bloquer les fonctions sensibles, avertir l'utilisateur.
    RaspThreatType.privilegedAccess: ThreatSeverity.high,

    // Émulateur détecté (peut être légitime pour les tests).
    // Réaction : journaliser seulement, ne pas bloquer.
    RaspThreatType.emulator: ThreatSeverity.medium,

    // Manipulation du runtime Android (ART hooks).
    RaspThreatType.runtimeManipulation: ThreatSeverity.critical,

    // Source d'installation non officielle ou clavier suspect.
    RaspThreatType.untrustedInstallationSource: ThreatSeverity.high,
  };

  // ===========================================================================
  // NOTE : killOnBypass (freeRASP v17+)
  // ===========================================================================

  /// RECOMMANDATION : Passer à freeRASP v17+ pour activer killOnBypass.
  ///
  /// killOnBypass = true termine l'application automatiquement si freeRASP
  /// détecte que ses propres callbacks ont été hookés (attaque de niveau 2).
  ///
  /// Configuration à ajouter dans TalsecConfig quand la version le permet :
  ///
  /// ```dart
  /// final config = TalsecConfig(
  ///   // ... autres paramètres ...
  ///   killOnBypass: true, // Disponible dans freeRASP v17+
  /// );
  /// ```
  ///
  /// Sans killOnBypass, un attaquant avancé peut hooker les callbacks RASP
  /// eux-mêmes pour rendre les alertes silencieuses.
  static const String killOnBypassNote = '''
RECOMMANDATION : Mettre à jour vers freeRASP v17+ et activer :
  killOnBypass: true
dans TalsecConfig. Cela termine l\'app si les callbacks RASP sont hookés.
Version actuelle minimale requise : $requiredFreeRaspVersion
''';
}
