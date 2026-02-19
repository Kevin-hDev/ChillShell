// test_fix_015.dart
// Tests unitaires — FIX-015 : Audit et verrouillage de dartssh2
// GAP-015, Priorité P2
//
// Ces tests vérifient que le rapport d'audit de dartssh2 est correct :
// - La version verrouillée est exactement 2.13.0 (sans caret)
// - Les risques sont documentés avec des mitigations
// - Les vérifications CI sont complètes

import 'package:flutter_test/flutter_test.dart';

// Import du module à tester (ajuster le chemin selon la structure du projet)
import 'package:vibeterm/core/security/dartssh2_audit.dart';

void main() {
  // Instance réutilisée dans tous les tests
  late Dartssh2AuditReport audit;

  setUp(() {
    audit = Dartssh2AuditReport();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 1 : Version verrouillée
  // ═══════════════════════════════════════════════════════════════════════════

  group('Version verrouillée — pinnedVersion', () {
    test('pinnedVersion est exactement "2.13.0"', () {
      expect(
        Dartssh2AuditReport.pinnedVersion,
        equals('2.13.0'),
        reason:
            'La version verrouillée doit être exactement 2.13.0. '
            'Toute modification doit passer par une revue de sécurité.',
      );
    });

    test('pinnedVersion ne contient pas de caret', () {
      expect(
        Dartssh2AuditReport.pinnedVersion.contains('^'),
        isFalse,
        reason:
            'La version verrouillée ne doit pas contenir de caret (^). '
            'Le caret autorise les mises à jour automatiques non auditées.',
      );
    });

    test('pinnedVersion ne contient pas de tilde', () {
      expect(
        Dartssh2AuditReport.pinnedVersion.contains('~'),
        isFalse,
        reason:
            'Le tilde (~) autorise les mises à jour de patch non auditées.',
      );
    });

    test('pinnedVersion correspond au format semver X.Y.Z', () {
      final semverPattern = RegExp(r'^\d+\.\d+\.\d+$');
      expect(
        semverPattern.hasMatch(Dartssh2AuditReport.pinnedVersion),
        isTrue,
        reason:
            'La version verrouillée doit suivre le format sémantique exact : '
            'MAJEUR.MINEUR.PATCH (ex: 2.13.0).',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 2 : getPubspecLockfix
  // ═══════════════════════════════════════════════════════════════════════════

  group('getPubspecLockfix — déclaration pubspec.yaml correcte', () {
    test('retourne "dartssh2: 2.13.0" sans caret', () {
      final lockfix = audit.getPubspecLockfix();
      expect(
        lockfix,
        equals('dartssh2: 2.13.0'),
        reason:
            'La déclaration pubspec.yaml doit être exacte, sans opérateur '
            'de version (pas de ^, ~, >=, etc.).',
      );
    });

    test('getPubspecLockfix ne contient pas de caret', () {
      final lockfix = audit.getPubspecLockfix();
      expect(
        lockfix.contains('^'),
        isFalse,
        reason:
            'Le caret dans pubspec.yaml autorise les mises à jour mineures '
            'automatiques qui pourraient introduire des régressions de sécurité.',
      );
    });

    test('getPubspecLockfix ne contient pas de tilde', () {
      final lockfix = audit.getPubspecLockfix();
      expect(
        lockfix.contains('~'),
        isFalse,
        reason: 'Le tilde autorise les mises à jour de patch non auditées.',
      );
    });

    test('getPubspecLockfix contient le nom du package', () {
      final lockfix = audit.getPubspecLockfix();
      expect(
        lockfix.contains('dartssh2'),
        isTrue,
        reason: 'La déclaration doit contenir le nom du package "dartssh2".',
      );
    });

    test('getPubspecLockfix contient la version pinnée', () {
      final lockfix = audit.getPubspecLockfix();
      expect(
        lockfix.contains(Dartssh2AuditReport.pinnedVersion),
        isTrue,
        reason:
            'La déclaration doit contenir la version verrouillée exacte '
            '(${Dartssh2AuditReport.pinnedVersion}).',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 3 : getKnownRisks
  // ═══════════════════════════════════════════════════════════════════════════

  group('getKnownRisks — risques identifiés', () {
    test('retourne au moins 3 risques documentés', () {
      final risks = audit.getKnownRisks();
      expect(
        risks.length,
        greaterThanOrEqualTo(3),
        reason:
            'L\'audit doit documenter au moins 3 risques pour dartssh2 : '
            'parser non fuzzé, disableHostkeyVerification, pas de PQC, bus factor.',
      );
    });

    test('chaque risque a un identifiant non vide', () {
      for (final risk in audit.getKnownRisks()) {
        expect(
          risk.id.isNotEmpty,
          isTrue,
          reason: 'Chaque risque doit avoir un identifiant unique non vide.',
        );
      }
    });

    test('chaque risque a une sévérité valide', () {
      const validSeverities = ['CRITIQUE', 'ÉLEVÉ', 'MOYEN', 'FAIBLE'];
      for (final risk in audit.getKnownRisks()) {
        expect(
          validSeverities.contains(risk.severity),
          isTrue,
          reason:
              'La sévérité "${risk.severity}" n\'est pas valide. '
              'Valeurs acceptées : ${validSeverities.join(", ")}.',
        );
      }
    });

    test('chaque risque a une description non vide', () {
      for (final risk in audit.getKnownRisks()) {
        expect(
          risk.description.isNotEmpty,
          isTrue,
          reason:
              'Le risque ${risk.id} n\'a pas de description. '
              'Chaque risque doit décrire concrètement le danger.',
        );
        expect(
          risk.description.length,
          greaterThan(20),
          reason:
              'La description du risque ${risk.id} est trop courte. '
              'Elle doit expliquer clairement le danger.',
        );
      }
    });

    test('chaque risque a une mitigation non vide', () {
      for (final risk in audit.getKnownRisks()) {
        expect(
          risk.mitigation.isNotEmpty,
          isTrue,
          reason:
              'Le risque ${risk.id} n\'a pas de mitigation. '
              'Chaque risque documenté doit avoir une mesure corrective.',
        );
        expect(
          risk.mitigation.length,
          greaterThan(10),
          reason:
              'La mitigation du risque ${risk.id} est trop courte. '
              'Elle doit proposer une action concrète.',
        );
      }
    });

    test('un risque CRITIQUE est présent (disableHostkeyVerification)', () {
      final risks = audit.getKnownRisks();
      final hasCritical = risks.any((r) => r.severity == 'CRITIQUE');
      expect(
        hasCritical,
        isTrue,
        reason:
            'L\'audit doit identifier au moins un risque CRITIQUE : '
            'disableHostkeyVerification accessible publiquement.',
      );
    });

    test('les identifiants de risques sont uniques', () {
      final risks = audit.getKnownRisks();
      final ids = risks.map((r) => r.id).toList();
      final uniqueIds = ids.toSet();
      expect(
        ids.length,
        equals(uniqueIds.length),
        reason:
            'Chaque risque doit avoir un identifiant unique. '
            'Des doublons indiquent une erreur de documentation.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 4 : getCIChecks
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCIChecks — vérifications CI', () {
    test('retourne au moins 4 vérifications CI', () {
      final checks = audit.getCIChecks();
      expect(
        checks.length,
        greaterThanOrEqualTo(4),
        reason:
            'Le rapport doit documenter au moins 4 vérifications CI : '
            'lockfile, caret, audit CVE, hash SHA-256.',
      );
    });

    test('une vérification mentionne pubspec.lock', () {
      final checks = audit.getCIChecks();
      final mentionsLock = checks.any(
        (c) => c.toLowerCase().contains('lock'),
      );
      expect(
        mentionsLock,
        isTrue,
        reason:
            'Le CI doit vérifier que pubspec.lock est committé et à jour '
            'pour garantir la reproductibilité des builds.',
      );
    });

    test('une vérification mentionne le caret', () {
      final checks = audit.getCIChecks();
      final mentionsCaret = checks.any(
        (c) => c.contains('^') || c.toLowerCase().contains('caret'),
      );
      expect(
        mentionsCaret,
        isTrue,
        reason:
            'Le CI doit vérifier l\'absence de caret dans la déclaration '
            'de dartssh2 pour éviter les mises à jour automatiques.',
      );
    });

    test('une vérification mentionne les CVEs ou un audit de sécurité', () {
      final checks = audit.getCIChecks();
      final mentionsCve = checks.any(
        (c) =>
            c.toLowerCase().contains('cve') ||
            c.toLowerCase().contains('audit') ||
            c.toLowerCase().contains('vulnérabilit'),
      );
      expect(
        mentionsCve,
        isTrue,
        reason:
            'Le CI doit inclure un scan de CVEs ou un audit de sécurité '
            'des dépendances.',
      );
    });

    test('chaque vérification CI est non vide et descriptive', () {
      for (var i = 0; i < audit.getCIChecks().length; i++) {
        final check = audit.getCIChecks()[i];
        expect(
          check.isNotEmpty,
          isTrue,
          reason: 'La vérification CI #$i ne doit pas être vide.',
        );
        expect(
          check.length,
          greaterThan(30),
          reason:
              'La vérification CI #$i est trop courte pour être utile. '
              'Elle doit décrire précisément ce qui est vérifié.',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 5 : generateReport
  // ═══════════════════════════════════════════════════════════════════════════

  group('generateReport — rapport complet', () {
    test('le rapport contient le nom du package', () {
      final report = audit.generateReport();
      expect(
        report.toLowerCase().contains('dartssh2'),
        isTrue,
        reason: 'Le rapport doit mentionner le nom du package audité.',
      );
    });

    test('le rapport contient la version verrouillée', () {
      final report = audit.generateReport();
      expect(
        report.contains(Dartssh2AuditReport.pinnedVersion),
        isTrue,
        reason: 'Le rapport doit mentionner la version verrouillée.',
      );
    });

    test('le rapport est non vide', () {
      final report = audit.generateReport();
      expect(
        report.isNotEmpty,
        isTrue,
        reason: 'Le rapport d\'audit ne doit pas être vide.',
      );
    });
  });
}
