// =============================================================================
// FIX-010 — Suppression fallback debug signing (GAP-010, P0)
// =============================================================================
//
// PROBLÈME RÉSOLU :
//   Dans le build.gradle.kts original, si le fichier key.properties était absent,
//   le build utilisait silencieusement les clés debug Android.
//   Conséquence : n'importe qui peut signer un APK cloné avec ses propres clés
//   debug et le distribuer comme si c'était l'app officielle.
//   Les utilisateurs ne peuvent pas distinguer l'APK officiel du clone.
//
// CE QUE CE FICHIER FAIT :
//   1. Fournit le code Kotlin corrigé pour build.gradle.kts
//   2. Génère un template key.properties pour la configuration du keystore
//   3. Documente les entrées .gitignore obligatoires
//   4. Documente comment générer un keystore de production sécurisé
//
// INTÉGRATION :
//   1. Remplacer le bloc signingConfig dans android/app/build.gradle.kts
//      avec le code retourné par getFixedBuildGradle()
//   2. Créer android/key.properties avec generateKeyProperties()
//   3. Ajouter les entrées .gitignore avec getGitignoreEntries()
//   4. Générer le keystore avec les commandes de generateKeystoreInstructions()
// =============================================================================

// =============================================================================
// CLASSE PRINCIPALE — APPLICATION DES SIGNATURES DE PRODUCTION
// =============================================================================

/// Outils pour corriger la configuration de signature Android.
///
/// La règle fondamentale : si le keystore de production est absent,
/// le build DOIT échouer avec une erreur claire. JAMAIS retomber sur
/// les clés debug qui permettent à quiconque de signer un APK cloné.
class SigningEnforcement {
  // Constructeur privé — classe utilitaire, pas d'instanciation.
  const SigningEnforcement._();

  // ===========================================================================
  // MÉTHODE : CODE GRADLE CORRIGÉ
  // ===========================================================================

  /// Retourne le bloc Kotlin corrigé pour build.gradle.kts.
  ///
  /// AVANT (code vulnérable) :
  ///   signingConfig = if (keyPropertiesFile.exists()) {
  ///       signingConfigs.getByName("release")
  ///   } else {
  ///       // TODO: Configure key.properties for production signing
  ///       signingConfigs.getByName("debug")  ← DANGER
  ///   }
  ///
  /// APRÈS (code sécurisé) :
  ///   - Si key.properties absent → GradleException (build échoue)
  ///   - Pas de fallback silencieux sur les clés debug
  ///   - Message d'erreur clair pour le développeur/CI
  static String getFixedBuildGradle() {
    return r'''
// =============================================================================
// CONFIGURATION DE SIGNATURE ANDROID — PRODUCTION UNIQUEMENT
// Fichier : android/app/build.gradle.kts
//
// PRINCIPE : Si les clés de production sont absentes, le build échoue.
//            Jamais de fallback silencieux sur les clés debug.
// =============================================================================

// Charger les propriétés de signature depuis key.properties
val keyPropertiesFile = rootProject.file("key.properties")

android {
    // ...

    signingConfigs {
        // La config release ne sera créée QUE si key.properties existe
        if (keyPropertiesFile.exists()) {
            val keyProperties = Properties().apply {
                load(FileInputStream(keyPropertiesFile))
            }
            create("release") {
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // SÉCURITÉ : Si key.properties est absent, lancer une exception.
            // Le build DOIT échouer — pas de fallback silencieux sur les clés debug.
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "SECURITE: key.properties est absent! " +
                    "Impossible de compiler un APK release avec les cles debug. " +
                    "Action requise: " +
                    "1. Generer un keystore: keytool -genkeypair -v -keystore keystores/release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias chillshell " +
                    "2. Creer android/key.properties avec storeFile, storePassword, keyAlias, keyPassword " +
                    "3. Verifier que key.properties est dans .gitignore"
                )
            }

            // Activation de minification et obfuscation des ressources
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            // En mode debug, utiliser les clés debug est acceptable
            // Le mode debug n'est JAMAIS distribué aux utilisateurs finaux
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = true
        }
    }
}
''';
  }

  // ===========================================================================
  // MÉTHODE : TEMPLATE key.properties
  // ===========================================================================

  /// Retourne le template du fichier android/key.properties.
  ///
  /// IMPORTANT : Ce fichier contient le mot de passe du keystore.
  ///   - Ne JAMAIS committer dans git
  ///   - Vérifier que key.properties est dans android/.gitignore ET .gitignore racine
  ///   - En CI/CD : stocker dans les secrets du vault (GitHub Secrets, Vault, etc.)
  ///     et générer key.properties dynamiquement avant le build
  ///
  /// UTILISATION EN CI/CD (GitHub Actions) :
  /// ```yaml
  /// - name: Créer key.properties depuis les secrets
  ///   run: |
  ///     echo "storeFile=../keystores/release.jks" > android/key.properties
  ///     echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" >> android/key.properties
  ///     echo "keyAlias=chillshell" >> android/key.properties
  ///     echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
  /// ```
  static String generateKeyProperties() {
    return '''# =============================================================================
# android/key.properties — Configuration du keystore de production
#
# SECURITE OBLIGATOIRE :
#   - Ce fichier NE DOIT PAS être commité dans git
#   - Vérifier que .gitignore contient : key.properties
#   - En CI/CD : générer ce fichier depuis les secrets du vault
#
# GÉNÉRATION DU KEYSTORE (voir SigningEnforcement.generateKeystoreInstructions())
# =============================================================================

# Chemin vers le keystore JKS (relatif au dossier android/)
storeFile=../keystores/release.jks

# Mot de passe du keystore (minimum 12 caractères, caractères spéciaux)
storePassword=CHANGER_CE_MOT_DE_PASSE

# Alias de la clé dans le keystore
keyAlias=chillshell

# Mot de passe de la clé (peut être différent de storePassword)
keyPassword=CHANGER_CE_MOT_DE_PASSE
''';
  }

  // ===========================================================================
  // MÉTHODE : ENTRÉES .gitignore
  // ===========================================================================

  /// Retourne la liste des patterns à ajouter dans .gitignore.
  ///
  /// Ces entrées protègent contre la fuite accidentelle du keystore
  /// ou des informations de signature dans git.
  ///
  /// PLACER DANS :
  ///   1. .gitignore (racine du projet) — pour protection globale
  ///   2. android/.gitignore — pour protection locale au dossier Android
  static List<String> getGitignoreEntries() {
    return [
      // Fichier de configuration de signature Android
      'key.properties',

      // Fichiers keystore Java (format JKS)
      '*.jks',

      // Fichiers keystore Android (format PKCS12 ou legacy)
      '*.keystore',

      // Dossier keystores/ (si les keystores sont centralisés)
      'keystores/',

      // Fichiers de propriétés de signature génériques
      '*signing*.properties',

      // Symboles de débogage obfusqués (ne pas distribuer)
      'build/debug-info/',
    ];
  }

  // ===========================================================================
  // MÉTHODE : INSTRUCTIONS GÉNÉRATION KEYSTORE
  // ===========================================================================

  /// Retourne la documentation pour générer un keystore de production sécurisé.
  ///
  /// Un keystore de production doit être :
  ///   - Généré une seule fois et conservé précieusement
  ///   - Sauvegardé dans un endroit sécurisé (vault, HSM, backup chiffré)
  ///   - Protégé par un mot de passe fort (minimum 16 caractères)
  ///   - Valide pour 10000 jours minimum (éviter les renouvellements fréquents)
  ///   - Clé RSA 4096 bits (pas 2048 bits)
  static String generateKeystoreInstructions() {
    return '''
=== GÉNÉRATION DU KEYSTORE DE PRODUCTION CHILLSHELL ===

ÉTAPE 1 — Créer le dossier keystores (hors du dossier git si possible) :
  mkdir -p android/keystores

ÉTAPE 2 — Générer le keystore avec keytool (JDK requis) :
  keytool -genkeypair -v \\
    -keystore android/keystores/release.jks \\
    -keyalg RSA \\
    -keysize 4096 \\
    -validity 10000 \\
    -alias chillshell

  Renseigner quand demandé :
    - Mot de passe du keystore (16+ caractères, noter en lieu sûr)
    - Prénom/Nom : ChillShell Release
    - Organisation : VibeTerm
    - Ville, État, Pays : selon votre localisation
    - Mot de passe de la clé (peut être identique au keystore)

ÉTAPE 3 — Créer android/key.properties :
  storeFile=../keystores/release.jks
  storePassword=MOT_DE_PASSE_KEYSTORE
  keyAlias=chillshell
  keyPassword=MOT_DE_PASSE_CLE

ÉTAPE 4 — Vérifier que key.properties et release.jks sont dans .gitignore :
  grep "key.properties" .gitignore  # Doit retourner un résultat
  grep "*.jks" .gitignore           # Doit retourner un résultat

ÉTAPE 5 — Sauvegarder le keystore (CRITIQUE) :
  Le keystore est IRRÉCUPÉRABLE si perdu.
  Google Play lie l'app à ce keystore pour toujours (sauf Google Play Signing).
  Sauvegarder dans :
    - Un gestionnaire de mots de passe (1Password, Bitwarden)
    - Un vault chiffré (HashiCorp Vault, AWS Secrets Manager)
    - Un support physique chiffré (clé USB VeraCrypt)

VÉRIFICATION du keystore :
  keytool -list -v -keystore android/keystores/release.jks -alias chillshell

ALTERNATIVE RECOMMANDÉE : Google Play Signing
  Déléguer la signature finale à Google Play.
  L'app est signée avec un upload key lors de l'upload,
  puis re-signée par Google avec la clé finale.
  Avantage : si l'upload key est compromise, elle peut être révoquée.
  Voir : https://support.google.com/googleplay/android-developer/answer/9842756
''';
  }

  // ===========================================================================
  // MÉTHODE : VÉRIFICATION DU CODE GRADLE
  // ===========================================================================

  /// Vérifie que le code Gradle fourni respecte les règles de sécurité.
  ///
  /// [gradleContent] : contenu du fichier build.gradle.kts à auditer.
  ///
  /// Retourne la liste des problèmes détectés.
  /// Liste vide = code conforme.
  static List<String> auditGradleContent(String gradleContent) {
    final List<String> problemes = [];

    // Vérifier l'absence du fallback debug dans le contexte release
    // Pattern dangereux : assigner les clés debug dans le bloc release
    if (_contientFallbackDebug(gradleContent)) {
      problemes.add(
        'CRITIQUE: Le code contient un fallback vers les clés debug dans le bloc release. '
        'Remplacer par throw GradleException(...).',
      );
    }

    // Vérifier la présence de GradleException (protection active)
    if (!gradleContent.contains('GradleException')) {
      problemes.add(
        'MANQUANT: throw GradleException(...) absent. '
        'Sans ce bloc, le build peut continuer silencieusement en cas d\'erreur.',
      );
    }

    // Vérifier la présence de la vérification d'existence de key.properties
    if (!gradleContent.contains('keyPropertiesFile.exists()')) {
      problemes.add(
        'MANQUANT: Vérification keyPropertiesFile.exists() absente. '
        'Le build ne vérifie pas si la configuration de signature est présente.',
      );
    }

    // Vérifier que isMinifyEnabled est activé en release
    if (gradleContent.contains('release') && !gradleContent.contains('isMinifyEnabled = true')) {
      problemes.add(
        'RECOMMANDATION: isMinifyEnabled = true absent du bloc release. '
        'La minification réduit la surface d\'attaque de la rétro-ingénierie.',
      );
    }

    return problemes;
  }

  /// Vérifie si le contenu Gradle contient un fallback dangereux vers les clés debug.
  ///
  /// Le pattern dangereux est : getByName("debug") dans un contexte qui inclut
  /// une condition sur keyPropertiesFile (donc dans le bloc de décision release/debug).
  static bool _contientFallbackDebug(String gradleContent) {
    // Chercher le pattern : else { ... signingConfigs.getByName("debug") }
    // sans throw GradleException avant
    final lignes = gradleContent.split('\n');
    bool dansBloc = false;

    for (int i = 0; i < lignes.length; i++) {
      final ligne = lignes[i];

      // Détecter l'entrée dans le bloc conditionnel (présence de keyPropertiesFile)
      if (ligne.contains('keyPropertiesFile.exists()')) {
        dansBloc = true;
      }

      // Dans ce bloc, chercher getByName("debug") SANS throw GradleException
      if (dansBloc &&
          ligne.contains('getByName("debug")') &&
          !ligne.trim().startsWith('//')) {
        // Vérifier si les lignes précédentes dans le bloc else contiennent throw
        bool throwTrouve = false;
        for (int j = i - 1; j >= 0 && j >= i - 5; j--) {
          if (lignes[j].contains('throw GradleException')) {
            throwTrouve = true;
            break;
          }
        }
        if (!throwTrouve) {
          return true; // Fallback debug sans protection détecté
        }
      }
    }

    return false;
  }
}
