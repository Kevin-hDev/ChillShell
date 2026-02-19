// FIX-017 — Verrouillage supply chain pub.dev
//
// Problème (GAP-017, P2) :
// Les dépendances critiques utilisent le caret `^` ce qui autorise les mises à
// jour mineures automatiques sans contrôle humain. Si un package est compromis
// sur pub.dev (attaque supply chain), la version malveillante peut être
// installée silencieusement lors du prochain `flutter pub get`.
//
// Solution : verrouiller les versions EXACTES pour tous les packages de
// sécurité, et documenter le processus de mise à jour contrôlé.

/// Gestion du verrouillage des dépendances critiques.
///
/// Cette classe ne fait aucun appel réseau ni opération I/O : elle fournit
/// uniquement les données de référence et les instructions nécessaires au
/// durcissement du pipeline de dépendances.
class SupplyChainLockdown {
  // ---------------------------------------------------------------------------
  // Constantes internes
  // ---------------------------------------------------------------------------

  /// Liste des packages considérés comme "critiques pour la sécurité".
  /// Toute dépendance de cette liste DOIT être verrouillée sans caret.
  static const Set<String> _securityPackages = {
    'dartssh2',
    'flutter_secure_storage',
    'freerasp',
    'cryptography',
    'pointycastle',
    'local_auth',
  };

  // ---------------------------------------------------------------------------
  // Versions verrouillées
  // ---------------------------------------------------------------------------

  /// Retourne les versions EXACTES pour toutes les dépendances de sécurité.
  ///
  /// Ces versions ont été auditées manuellement. Toute modification doit
  /// suivre la procédure définie dans [getUpdateProcedure].
  ///
  /// Aucun caret (`^`) n'est présent dans ces valeurs — c'est volontaire.
  Map<String, String> getLockedVersions() {
    return const {
      // Client SSH — vecteur d'attaque majeur si compromis
      'dartssh2': '2.13.0',

      // Stockage chiffré des secrets (clés, tokens)
      'flutter_secure_storage': '10.0.0',

      // Détection de tampering et root/jailbreak
      'freerasp': '6.6.0',

      // Primitives cryptographiques (AES-GCM, ChaCha20, HMAC…)
      'cryptography': '2.7.0',

      // Cryptographie bas niveau (courbes elliptiques, RSA)
      'pointycastle': '3.7.3',

      // Authentification biométrique locale
      'local_auth': '3.0.0',
    };
  }

  // ---------------------------------------------------------------------------
  // Bloc YAML corrigé pour pubspec.yaml
  // ---------------------------------------------------------------------------

  /// Retourne le bloc YAML prêt à coller dans `pubspec.yaml`.
  ///
  /// Toutes les versions sont exactes — aucun caret.
  /// Les commentaires rappellent pourquoi le verrouillage est obligatoire.
  String getPubspecFix() {
    return '''
dependencies:
  # ── Dépendances de sécurité ── versions verrouillées, SANS caret
  # Toute mise à jour doit suivre la procédure manuelle documentée.

  dartssh2: 2.13.0             # Verrouillé — client SSH critique
  flutter_secure_storage: 10.0.0 # Verrouillé — stockage des secrets
  freerasp: 6.6.0              # Verrouillé — détection tampering
  cryptography: 2.7.0          # Verrouillé — primitives crypto
  pointycastle: 3.7.3          # Verrouillé — crypto bas niveau
  local_auth: 3.0.0            # Verrouillé — authentification locale
''';
  }

  // ---------------------------------------------------------------------------
  // Vérifications CI
  // ---------------------------------------------------------------------------

  /// Retourne les étapes à ajouter dans le pipeline CI/CD pour protéger la
  /// supply chain à chaque build.
  List<String> getCIChecks() {
    return [
      // Étape 1 — Engager le fichier lock dans le dépôt
      'Ajouter pubspec.lock au contrôle de version (git add pubspec.lock)',

      // Étape 2 — Détecter toute modification non autorisée du lock
      'En CI, vérifier que pubspec.lock n\'a pas changé : '
          'git diff --exit-code pubspec.lock',

      // Étape 3 — Audit officiel des vulnérabilités connues
      'Exécuter `dart pub audit` dans le pipeline (quand stable)',

      // Étape 4 — Alerter proactivement si une mise à jour est disponible
      'Alerter si une dépendance critique a une mise à jour disponible',

      // Étape 5 — Bloquer les builds si des packages non verrouillés sont détectés
      'Échouer le build si un package de sécurité utilise un caret dans pubspec.yaml',
    ];
  }

  // ---------------------------------------------------------------------------
  // Procédure de mise à jour contrôlée
  // ---------------------------------------------------------------------------

  /// Retourne les étapes à suivre OBLIGATOIREMENT avant de mettre à jour une
  /// dépendance de sécurité.
  ///
  /// Aucune mise à jour ne doit être faite de façon automatique ou sans revue.
  List<String> getUpdateProcedure() {
    return [
      '1. Lire le changelog de la nouvelle version',
      '2. Vérifier les CVEs connues sur le repository GitHub du package',
      '3. Mettre à jour la version exacte dans pubspec.yaml (sans caret)',
      '4. Lancer `flutter pub get`',
      '5. Lancer tous les tests',
      '6. Commit avec le message : chore(deps): update package_name to x.y.z',
    ];
  }

  // ---------------------------------------------------------------------------
  // Audit du fichier pubspec.yaml existant
  // ---------------------------------------------------------------------------

  /// Analyse le contenu d'un `pubspec.yaml` et retourne la liste des
  /// avertissements pour chaque dépendance de sécurité qui utilise encore le
  /// caret `^`.
  ///
  /// [pubspecContent] : contenu brut du fichier pubspec.yaml (String).
  ///
  /// Les dépendances non listées dans [_securityPackages] sont ignorées —
  /// seules les dépendances critiques sont contrôlées ici.
  List<String> auditPubspec(String pubspecContent) {
    final warnings = <String>[];

    // Découper ligne par ligne pour analyser chaque dépendance
    final lines = pubspecContent.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();

      // Ignorer les lignes vides et les commentaires
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Chercher un pattern du type : "  package_name: ^x.y.z"
      // Le caret peut être suivi immédiatement d'un chiffre de version
      final caretPattern = RegExp(r'^(\S+):\s*\^(.+)$');
      final match = caretPattern.firstMatch(trimmed);

      if (match == null) continue;

      final packageName = match.group(1)!.trim();
      final version = match.group(2)!.trim();

      // N'avertir QUE pour les packages de sécurité
      if (_securityPackages.contains(packageName)) {
        warnings.add(
          '[RISQUE SUPPLY CHAIN] $packageName utilise le caret : ^$version — '
          'verrouiller à : $packageName: $version',
        );
      }
    }

    return warnings;
  }
}
