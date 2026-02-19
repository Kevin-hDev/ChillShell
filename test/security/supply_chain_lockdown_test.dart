// test_fix_017.dart — Tests unitaires pour FIX-017
//
// Vérifie que le verrouillage de supply chain fonctionne correctement :
// - Les versions retournées sont EXACTES (pas de caret)
// - L'audit détecte les carets sur les packages critiques
// - L'audit IGNORE les packages non critiques avec caret
// - Les listes CI et procédure de mise à jour sont complètes

import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/core/security/supply_chain_lockdown.dart';

void main() {
  // Instancier une seule fois pour tous les tests du groupe
  final lockdown = SupplyChainLockdown();

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 1 — getLockedVersions()
  // ─────────────────────────────────────────────────────────────────────────
  group('getLockedVersions()', () {
    late Map<String, String> versions;

    setUp(() {
      versions = lockdown.getLockedVersions();
    });

    test('Retourne bien 6 dépendances', () {
      expect(versions.length, equals(6));
    });

    test('Aucune version ne contient de caret ^', () {
      for (final entry in versions.entries) {
        expect(
          entry.value.contains('^'),
          isFalse,
          reason:
              '${entry.key} contient un caret : ${entry.value} — '
              'le verrouillage exact est obligatoire',
        );
      }
    });

    test('Toutes les dépendances critiques sont présentes', () {
      const expected = [
        'dartssh2',
        'flutter_secure_storage',
        'freerasp',
        'cryptography',
        'pointycastle',
        'local_auth',
      ];
      for (final pkg in expected) {
        expect(
          versions.containsKey(pkg),
          isTrue,
          reason: 'Package manquant dans getLockedVersions : $pkg',
        );
      }
    });

    test('Les versions sont non vides', () {
      for (final entry in versions.entries) {
        expect(
          entry.value.trim().isEmpty,
          isFalse,
          reason: '${entry.key} a une version vide',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 2 — getPubspecFix()
  // ─────────────────────────────────────────────────────────────────────────
  group('getPubspecFix()', () {
    late String yamlFix;

    setUp(() {
      yamlFix = lockdown.getPubspecFix();
    });

    test('Ne contient aucun caret ^', () {
      // On exclut les lignes de commentaire (qui pourraient contenir ^
      // dans une explication), et on vérifie uniquement les lignes de valeur
      final valueLines = yamlFix
          .split('\n')
          .where((l) => !l.trim().startsWith('#') && l.contains(':'))
          .toList();

      for (final line in valueLines) {
        expect(
          line.contains('^'),
          isFalse,
          reason: 'Ligne avec caret trouvée : "$line"',
        );
      }
    });

    test('Contient les 6 packages critiques', () {
      expect(yamlFix, contains('dartssh2'));
      expect(yamlFix, contains('flutter_secure_storage'));
      expect(yamlFix, contains('freerasp'));
      expect(yamlFix, contains('cryptography'));
      expect(yamlFix, contains('pointycastle'));
      expect(yamlFix, contains('local_auth'));
    });

    test('Est un bloc YAML non vide', () {
      expect(yamlFix.trim().isEmpty, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 3 — auditPubspec()
  // ─────────────────────────────────────────────────────────────────────────
  group('auditPubspec()', () {
    test('Détecte les carets sur les dépendances de sécurité', () {
      const pubspecAvecCarets = '''
name: chillshell
dependencies:
  dartssh2: ^2.13.0
  flutter_secure_storage: ^10.0.0
  freerasp: ^6.6.0
  cryptography: ^2.7.0
  pointycastle: ^3.7.3
  local_auth: ^3.0.0
''';
      final warnings = lockdown.auditPubspec(pubspecAvecCarets);

      // Doit détecter exactement 6 avertissements (un par package critique)
      expect(
        warnings.length,
        equals(6),
        reason:
            'Attendu 6 warnings (un par package critique), '
            'obtenu ${warnings.length}',
      );

      // Chaque warning doit mentionner le package concerné
      final warningText = warnings.join('\n');
      expect(warningText, contains('dartssh2'));
      expect(warningText, contains('flutter_secure_storage'));
      expect(warningText, contains('freerasp'));
      expect(warningText, contains('cryptography'));
      expect(warningText, contains('pointycastle'));
      expect(warningText, contains('local_auth'));
    });

    test('Ne se plaint PAS des dépendances non critiques avec caret', () {
      // provider, go_router, etc. ne sont pas des packages de sécurité
      const pubspecNonCritique = '''
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  go_router: ^14.2.0
  shared_preferences: ^2.2.0
''';
      final warnings = lockdown.auditPubspec(pubspecNonCritique);

      expect(
        warnings.isEmpty,
        isTrue,
        reason:
            'Aucun warning attendu pour des packages non critiques, '
            'mais ${warnings.length} warning(s) retourné(s) : $warnings',
      );
    });

    test('Ne retourne aucun warning si les versions sont déjà verrouillées', () {
      const pubspecVerrouille = '''
dependencies:
  dartssh2: 2.13.0
  flutter_secure_storage: 10.0.0
  freerasp: 6.6.0
  cryptography: 2.7.0
  pointycastle: 3.7.3
  local_auth: 3.0.0
''';
      final warnings = lockdown.auditPubspec(pubspecVerrouille);

      expect(
        warnings.isEmpty,
        isTrue,
        reason:
            'Aucun warning attendu — toutes les versions sont verrouillées',
      );
    });

    test('Détecte un seul caret sur un seul package critique', () {
      // Seul dartssh2 a un caret — les autres sont verrouillés
      const pubspecPartiel = '''
dependencies:
  dartssh2: ^2.13.0
  flutter_secure_storage: 10.0.0
  freerasp: 6.6.0
  provider: ^6.0.0
''';
      final warnings = lockdown.auditPubspec(pubspecPartiel);

      expect(
        warnings.length,
        equals(1),
        reason: 'Attendu 1 warning (dartssh2 uniquement)',
      );
      expect(warnings.first, contains('dartssh2'));
    });

    test('Ignore les lignes de commentaire', () {
      // Une ligne de commentaire contient ^dartssh2 — ne doit pas lever de warning
      const pubspecAvecCommentaire = '''
dependencies:
  # dartssh2: ^2.13.0  # ancienne version
  dartssh2: 2.13.0
''';
      final warnings = lockdown.auditPubspec(pubspecAvecCommentaire);

      expect(
        warnings.isEmpty,
        isTrue,
        reason: 'Les commentaires ne doivent pas être audités',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 4 — getCIChecks()
  // ─────────────────────────────────────────────────────────────────────────
  group('getCIChecks()', () {
    late List<String> checks;

    setUp(() {
      checks = lockdown.getCIChecks();
    });

    test('Retourne au moins 3 vérifications CI', () {
      expect(
        checks.length,
        greaterThanOrEqualTo(3),
        reason: 'Minimum 3 vérifications CI requises',
      );
    });

    test('Mentionne pubspec.lock', () {
      final text = checks.join('\n');
      expect(
        text.toLowerCase().contains('pubspec.lock'),
        isTrue,
        reason: 'pubspec.lock doit être mentionné dans les checks CI',
      );
    });

    test('Aucun check n\'est vide', () {
      for (final check in checks) {
        expect(
          check.trim().isEmpty,
          isFalse,
          reason: 'Un check CI est vide',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 5 — getUpdateProcedure()
  // ─────────────────────────────────────────────────────────────────────────
  group('getUpdateProcedure()', () {
    late List<String> steps;

    setUp(() {
      steps = lockdown.getUpdateProcedure();
    });

    test('Retourne au moins 5 étapes', () {
      expect(
        steps.length,
        greaterThanOrEqualTo(5),
        reason: 'Minimum 5 étapes de mise à jour requises',
      );
    });

    test('Aucune étape n\'est vide', () {
      for (final step in steps) {
        expect(
          step.trim().isEmpty,
          isFalse,
          reason: 'Une étape de procédure est vide',
        );
      }
    });

    test('Mentionne les tests', () {
      final text = steps.join('\n').toLowerCase();
      expect(
        text.contains('test'),
        isTrue,
        reason: 'La procédure doit inclure une étape de tests',
      );
    });

    test('Mentionne le changelog', () {
      final text = steps.join('\n').toLowerCase();
      expect(
        text.contains('changelog'),
        isTrue,
        reason: 'La procédure doit inclure la lecture du changelog',
      );
    });
  });
}
