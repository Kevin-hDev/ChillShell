// fix_015_dartssh2_audit.dart
// GAP-015 — Audit et verrouillage de la dépendance dartssh2
// Priorité : P2 (Important)
//
// Problème : dartssh2 est déclaré avec `^2.13.0` dans pubspec.yaml.
// Le caret (^) autorise les mises à jour mineures et de patch AUTOMATIQUES.
// Une mise à jour 2.14.0 ou 2.13.1 non auditée pourrait introduire
// une régression de sécurité silencieuse.
//
// Solution : Documentation du verrouillage de version, des risques connus,
// et des vérifications CI à mettre en place.

// ---------------------------------------------------------------------------
// Classe de risque de dépendance
// ---------------------------------------------------------------------------

/// Représente un risque de sécurité identifié dans une dépendance externe.
class DependencyRisk {
  /// Identifiant court du risque (ex: RISK-001).
  final String id;

  /// Niveau de sévérité : 'CRITIQUE', 'ÉLEVÉ', 'MOYEN', 'FAIBLE'.
  final String severity;

  /// Description claire du risque en français.
  final String description;

  /// Mesure de mitigation recommandée.
  final String mitigation;

  const DependencyRisk({
    required this.id,
    required this.severity,
    required this.description,
    required this.mitigation,
  });

  @override
  String toString() =>
      '[$severity] $id : $description\n  → Mitigation : $mitigation';
}

// ---------------------------------------------------------------------------
// Classe principale d'audit
// ---------------------------------------------------------------------------

/// Rapport d'audit de sécurité de la dépendance dartssh2.
///
/// dartssh2 est le cœur de ChillShell — toute vulnérabilité dans cette
/// bibliothèque compromet TOUTES les connexions SSH de l'application.
///
/// Notes sur dartssh2 2.13.0 :
/// - Cette version a ajouté `disableHostkeyVerification` (DANGER — ne JAMAIS
///   mettre à true, cela désactive la protection contre le Man-in-the-Middle)
/// - Meilleures performances de handshake
/// - Support des nouvelles clés OpenSSH (format openssh-key-v1)
///
/// ATTENTION : Le caret ^ dans `^2.13.0` autorise les mises à jour vers
/// 2.14.0, 2.15.0, etc. sans action de l'équipe. Ces versions pourraient
/// modifier le comportement cryptographique sans avertissement.
class Dartssh2AuditReport {
  // ---------------------------------------------------------------------------
  // Version verrouillée
  // ---------------------------------------------------------------------------

  /// Version exacte de dartssh2 auditée et approuvée.
  ///
  /// Cette version doit être fixée SANS caret dans pubspec.yaml.
  /// Toute mise à jour doit passer par une revue de sécurité explicite.
  static const String pinnedVersion = '2.13.0';

  /// Nom du package dans l'écosystème Dart/Flutter.
  static const String packageName = 'dartssh2';

  /// URL du dépôt officiel pour surveillance des releases.
  static const String repositoryUrl =
      'https://github.com/TerminalStudio/dartssh2';

  // ---------------------------------------------------------------------------
  // Correction pubspec.yaml
  // ---------------------------------------------------------------------------

  /// Retourne la déclaration de dépendance correcte pour pubspec.yaml.
  ///
  /// La version doit être déclarée SANS caret pour éviter les mises à jour
  /// automatiques non auditées.
  ///
  /// Avant (DANGEREUX) :
  ///   dartssh2: ^2.13.0
  ///
  /// Après (SÉCURISÉ) :
  ///   dartssh2: 2.13.0
  String getPubspecLockfix() {
    // IMPORTANT : pas de caret (^), pas de tilde (~), pas de range (>=)
    // Version exacte uniquement
    return '$packageName: $pinnedVersion';
  }

  // ---------------------------------------------------------------------------
  // Risques identifiés
  // ---------------------------------------------------------------------------

  /// Retourne la liste des risques de sécurité connus pour dartssh2.
  ///
  /// Ces risques sont documentés pour informer l'équipe de développement
  /// et guider les décisions de mitigation.
  List<DependencyRisk> getKnownRisks() {
    return const [
      DependencyRisk(
        id: 'DARTSSH2-RISK-001',
        severity: 'MOYEN',
        description:
            'Parser SSH implémenté en pur Dart sans fuzzing formel connu. '
            'Les parsers SSH sont historiquement une surface d\'attaque '
            'importante (CVE-2002-0639 dans OpenSSH, CVE-2019-6111). '
            'Un paquet SSH malformé pourrait provoquer un crash ou '
            'une exécution de code dans le contexte de l\'application.',
        mitigation:
            'Surveiller les issues et releases sur GitHub. '
            'Envisager d\'exécuter la connexion SSH dans un isolate Dart '
            'séparé pour limiter l\'impact d\'un crash. '
            'Tester régulièrement avec des paquets malformés en interne.',
      ),

      DependencyRisk(
        id: 'DARTSSH2-RISK-002',
        severity: 'CRITIQUE',
        description:
            'La propriété `disableHostkeyVerification` est accessible '
            'publiquement depuis la version 2.13.0. Si un développeur '
            'la met à `true` pour "faciliter les tests", toutes les '
            'connexions deviennent vulnérables au Man-in-the-Middle. '
            'Un attaquant entre le client et le serveur peut voir et '
            'modifier toutes les commandes SSH.',
        mitigation:
            'Revue de code obligatoire : grep sur "disableHostkeyVerification" '
            'dans le CI doit échouer si la valeur est `true`. '
            'Documenter explicitement l\'interdiction dans CLAUDE.md et '
            'dans le code via la constante SSHAlgorithmConfig.disableHostkeyVerification.',
      ),

      DependencyRisk(
        id: 'DARTSSH2-RISK-003',
        severity: 'FAIBLE',
        description:
            'Pas de support de l\'échange de clés post-quantique '
            'sntrup761x25519-sha512@openssh.com. Avec l\'avancement '
            'des ordinateurs quantiques, l\'algorithme de Shor pourrait '
            'casser les échanges Curve25519 dans le futur. '
            'Les sessions enregistrées aujourd\'hui pourraient être '
            'déchiffrées demain ("harvest now, decrypt later").',
        mitigation:
            'Surveiller les releases de dartssh2 pour le support de '
            'sntrup761x25519. OpenSSH 9.0+ supporte déjà cet algorithme '
            'côté serveur. Implémenter FIX-016 (roadmap post-quantique) '
            'pour préparer la migration.',
      ),

      DependencyRisk(
        id: 'DARTSSH2-RISK-004',
        severity: 'MOYEN',
        description:
            'Bus factor élevé : dartssh2 est maintenu par un petit nombre '
            'de contributeurs. En cas d\'abandon du projet, les vulnérabilités '
            'découvertes après l\'abandon ne seront pas corrigées. '
            'ChillShell dépend entièrement de cette bibliothèque pour '
            'toutes les connexions SSH.',
        mitigation:
            'Évaluer les alternatives (ssh_client, pointycastle + ssh manuel). '
            'Maintenir un fork privé en cas d\'abandon du projet upstream. '
            'Versionner strictement (sans caret) pour contrôler les mises à jour.',
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Vérifications CI recommandées
  // ---------------------------------------------------------------------------

  /// Retourne la liste des vérifications à intégrer dans le pipeline CI/CD.
  ///
  /// Ces vérifications doivent bloquer le déploiement si elles échouent.
  List<String> getCIChecks() {
    return const [
      // Vérification 1 : Le lockfile doit être committé et à jour
      'Vérifier que pubspec.lock est committié dans le dépôt Git — '
          'il garantit que tous les développeurs utilisent exactement '
          'la même version de dartssh2.',

      // Vérification 2 : Aucune mise à jour automatique
      'Vérifier que pubspec.yaml ne contient PAS de caret (^) devant '
          'la version de dartssh2 — commande : '
          'grep "dartssh2:" pubspec.yaml | grep -v "^#" | grep "\\^" && exit 1',

      // Vérification 3 : Audit des CVEs
      'Scanner les CVEs de dartssh2 via `dart pub audit` (quand disponible) — '
          'cette commande vérifie les advisories de sécurité publiés '
          'sur pub.dev pour toutes les dépendances.',

      // Vérification 4 : Vérification du hash SHA-256
      'Comparer le hash SHA-256 du package dartssh2 téléchargé avec '
          'la valeur attendue stockée dans pubspec.lock — '
          'toute divergence indique une tampering de la supply chain.',

      // Vérification 5 : Absence de disableHostkeyVerification=true
      'Vérifier qu\'aucun fichier source ne contient '
          '"disableHostkeyVerification: true" — commande : '
          'grep -r "disableHostkeyVerification.*true" lib/ && exit 1',

      // Vérification 6 : Pas de mise à jour non planifiée
      'Exécuter `flutter pub outdated` et alerter (sans bloquer) '
          'si dartssh2 a une version plus récente disponible — '
          'permet à l\'équipe de planifier une revue de mise à jour.',
    ];
  }

  // ---------------------------------------------------------------------------
  // Rapport complet en texte
  // ---------------------------------------------------------------------------

  /// Génère un rapport d'audit complet sous forme de texte lisible.
  String generateReport() {
    final buffer = StringBuffer();

    buffer.writeln('=' * 70);
    buffer.writeln('RAPPORT D\'AUDIT — $packageName $pinnedVersion');
    buffer.writeln('Date : ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 70);

    buffer.writeln('\n## VERSION VERROUILLÉE');
    buffer.writeln('  Déclaration pubspec.yaml recommandée :');
    buffer.writeln('    ${getPubspecLockfix()}');

    buffer.writeln('\n## RISQUES IDENTIFIÉS (${getKnownRisks().length})');
    for (final risk in getKnownRisks()) {
      buffer.writeln('\n  ${risk.id} [${risk.severity}]');
      buffer.writeln('  Description : ${risk.description}');
      buffer.writeln('  Mitigation  : ${risk.mitigation}');
    }

    buffer.writeln('\n## VÉRIFICATIONS CI (${getCIChecks().length})');
    for (var i = 0; i < getCIChecks().length; i++) {
      buffer.writeln('\n  [CI-${(i + 1).toString().padLeft(2, "0")}] ${getCIChecks()[i]}');
    }

    buffer.writeln('\n' + '=' * 70);
    return buffer.toString();
  }
}
