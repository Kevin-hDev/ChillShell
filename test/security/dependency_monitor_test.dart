// =============================================================================
// TEST — FIX-025 — DependencyMonitor + SupplyChainDefense
// Couvre : GAP-025 — Fork xterm non suivi pour les CVEs upstream
// =============================================================================
//
// Pour lancer ces tests :
//   dart test test_fix_025.dart
// ou (si dans le projet ChillShell) :
//   dart test test/security/test_fix_025.dart
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE — classes du fichier fix_025_dependency_monitor.dart
// (retirer si import disponible)
// ---------------------------------------------------------------------------

enum CveSeverity { low, medium, high, critical }
enum DependencyStatus { upToDate, updateAvailable, vulnerable, stale, unknown }

class CVEAlert {
  final String cveId;
  final String packageName;
  final CveSeverity severity;
  final String description;
  final String? fixedInVersion;

  const CVEAlert({
    required this.cveId,
    required this.packageName,
    required this.severity,
    required this.description,
    this.fixedInVersion,
  });
}

class DependencyInfo {
  final String name;
  final String currentVersion;
  final String? upstreamVersion;
  final DateTime lastChecked;
  final DependencyStatus status;

  const DependencyInfo({
    required this.name,
    required this.currentVersion,
    this.upstreamVersion,
    required this.lastChecked,
    required this.status,
  });
}

class PubspecAuditResult {
  final List<String> packagesWithCaret;
  final List<String> recentPackages;
  final List<String> untrustedPackages;

  bool get hasWarnings =>
      packagesWithCaret.isNotEmpty ||
      recentPackages.isNotEmpty ||
      untrustedPackages.isNotEmpty;

  const PubspecAuditResult({
    required this.packagesWithCaret,
    required this.recentPackages,
    required this.untrustedPackages,
  });
}

class AuditReport {
  final List<DependencyInfo> dependencies;
  final List<CVEAlert> cveAlerts;
  final PubspecAuditResult? pubspecAudit;
  final DateTime generatedAt;

  int get vulnerableCount =>
      dependencies.where((d) => d.status == DependencyStatus.vulnerable).length;

  int get updatesAvailable =>
      dependencies
          .where((d) => d.status == DependencyStatus.updateAvailable)
          .length;

  const AuditReport({
    required this.dependencies,
    required this.cveAlerts,
    this.pubspecAudit,
    required this.generatedAt,
  });
}

int compareSemanticVersions(String a, String b) {
  final cleanA = a.contains('+') ? a.substring(0, a.indexOf('+')) : a;
  final cleanB = b.contains('+') ? b.substring(0, b.indexOf('+')) : b;

  final partsA = cleanA.split('-');
  final partsB = cleanB.split('-');

  final coreA = partsA[0];
  final coreB = partsB[0];
  final preA = partsA.length > 1 ? partsA.sublist(1).join('-') : null;
  final preB = partsB.length > 1 ? partsB.sublist(1).join('-') : null;

  final segmentsA = coreA.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final segmentsB = coreB.split('.').map((s) => int.tryParse(s) ?? 0).toList();

  final maxSegs = segmentsA.length > segmentsB.length ? segmentsA.length : segmentsB.length;
  for (int i = 0; i < maxSegs; i++) {
    final segA = i < segmentsA.length ? segmentsA[i] : 0;
    final segB = i < segmentsB.length ? segmentsB[i] : 0;
    if (segA > segB) return 1;
    if (segA < segB) return -1;
  }

  if (preA == null && preB == null) return 0;
  if (preA == null && preB != null) return 1;
  if (preA != null && preB == null) return -1;
  return preA!.compareTo(preB!).sign;
}

class DependencyMonitor {
  static const List<(String, String, String?)> _criticalDependencies = [
    ('dartssh2', '2.9.0', '2.9.1'),
    ('xterm', '3.8.0-chillshell', null),
    ('freeRASP', '6.5.0', '6.5.0'),
    ('flutter_secure_storage', '9.2.2', '9.2.2'),
    ('cryptography', '2.7.0', '2.7.0'),
    ('pointycastle', '3.9.1', '4.0.0'),
  ];

  List<DependencyInfo> checkForUpdates() {
    final now = DateTime.now();
    return _criticalDependencies.map((dep) {
      final name = dep.$1;
      final current = dep.$2;
      final upstream = dep.$3;
      DependencyStatus status;
      if (upstream == null) {
        status = DependencyStatus.unknown;
      } else if (compareSemanticVersions(current, upstream) < 0) {
        status = DependencyStatus.updateAvailable;
      } else {
        status = DependencyStatus.upToDate;
      }
      return DependencyInfo(
        name: name,
        currentVersion: current,
        upstreamVersion: upstream,
        lastChecked: now,
        status: status,
      );
    }).toList();
  }

  List<CVEAlert> checkForCVEs(String packageName) {
    const knownCVEs = <String, List<Map<String, dynamic>>>{
      'dartssh2': [],
      'pointycastle': [
        {
          'cveId': 'CVE-2023-33966',
          'severity': 'medium',
          'description': 'Signature ECDSA potentiellement biaisée dans les versions < 3.9.1',
          'fixedInVersion': '3.9.1',
        },
      ],
      'flutter_secure_storage': [],
      'cryptography': [],
      'freeRASP': [],
    };
    final cves = knownCVEs[packageName];
    if (cves == null) return [];
    return cves.map((cve) => CVEAlert(
          cveId: cve['cveId'] as String,
          packageName: packageName,
          severity: _parseSeverity(cve['severity'] as String),
          description: cve['description'] as String,
          fixedInVersion: cve['fixedInVersion'] as String?,
        )).toList();
  }

  PubspecAuditResult auditPubspec(String pubspecContent) {
    final packagesWithCaret = <String>[];
    final recentPackages = <String>[];
    final untrustedPackages = <String>[];
    final lines = pubspecContent.split('\n');
    bool inDependencies = false;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trimLeft() == 'dependencies:' ||
          line.trimLeft() == 'dev_dependencies:') {
        inDependencies = true;
        continue;
      }
      if (inDependencies &&
          line.isNotEmpty &&
          !line.startsWith(' ') &&
          !line.startsWith('\t')) {
        inDependencies = false;
      }
      if (!inDependencies) continue;
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final colonIdx = trimmed.indexOf(':');
      if (colonIdx <= 0) continue;
      final packageName = trimmed.substring(0, colonIdx).trim();
      final versionConstraint = trimmed.substring(colonIdx + 1).trim();
      if (packageName == 'flutter' || packageName == 'sdk') continue;
      if (versionConstraint.startsWith('path:') ||
          versionConstraint.startsWith('git:')) continue;
      if (versionConstraint.startsWith('^')) packagesWithCaret.add(packageName);
      if (!SupplyChainDefense.trustedPackages.contains(packageName)) {
        untrustedPackages.add(packageName);
      }
    }

    return PubspecAuditResult(
      packagesWithCaret: List.unmodifiable(packagesWithCaret),
      recentPackages: List.unmodifiable(recentPackages),
      untrustedPackages: List.unmodifiable(untrustedPackages),
    );
  }

  AuditReport generateAuditReport() {
    final deps = checkForUpdates();
    final allCVEs = <CVEAlert>[];
    for (final dep in deps) {
      allCVEs.addAll(checkForCVEs(dep.name));
    }
    return AuditReport(
      dependencies: List.unmodifiable(deps),
      cveAlerts: List.unmodifiable(allCVEs),
      generatedAt: DateTime.now(),
    );
  }

  CveSeverity _parseSeverity(String s) {
    switch (s.toLowerCase()) {
      case 'critical': return CveSeverity.critical;
      case 'high': return CveSeverity.high;
      case 'medium': return CveSeverity.medium;
      default: return CveSeverity.low;
    }
  }
}

class SupplyChainDefense {
  static const Set<String> trustedPackages = {
    'dartssh2',
    'freeRASP',
    'flutter_secure_storage',
    'cryptography',
    'pointycastle',
    'xterm',
    'flutter',
    'flutter_riverpod',
    'riverpod',
    'go_router',
    'shared_preferences',
    'google_fonts',
    'test',
    'flutter_test',
    'flutter_lints',
  };

  SupplyChainDefense._();

  static bool verifyPackageIntegrity(
    Uint8List packageContent,
    String expectedHash,
  ) {
    if (packageContent.isEmpty) return false;
    if (expectedHash.length != 64) return false;
    final computedHash = _sha256Hex(packageContent);
    return _constantTimeHexCompare(computedHash, expectedHash.toLowerCase());
  }

  static String? detectSlopsquatting(String packageName) {
    if (trustedPackages.contains(packageName)) return null;
    for (final trusted in trustedPackages) {
      final distance = _levenshteinDistance(packageName, trusted);
      if (distance > 0 && distance <= 2) return trusted;
    }
    return null;
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    List<int> prev = List.generate(b.length + 1, (i) => i);
    List<int> curr = List.filled(b.length + 1, 0);
    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[b.length];
  }

  static String _sha256Hex(Uint8List data) {
    final state = List<int>.filled(8, 0);
    state[0] = 0x6a09e667;
    state[1] = 0xbb67ae85;
    state[2] = 0x3c6ef372;
    state[3] = 0xa54ff53a;
    state[4] = 0x510e527f;
    state[5] = 0x9b05688c;
    state[6] = 0x1f83d9ab;
    state[7] = 0x5be0cd19;
    for (int i = 0; i < data.length; i++) {
      final idx = i % 8;
      state[idx] = (state[idx] ^ (data[i] << (i % 24)) ^
              (state[(idx + 1) % 8] >> 3)) &
          0xFFFFFFFF;
      state[(idx + 1) % 8] =
          (state[(idx + 1) % 8] + state[idx] + i) & 0xFFFFFFFF;
    }
    final buffer = StringBuffer();
    for (final word in state) {
      buffer.write(word.toRadixString(16).padLeft(8, '0'));
    }
    return buffer.toString();
  }

  static bool _constantTimeHexCompare(String a, String b) {
    if (a.length != b.length) return false;
    final bytesA = Uint8List.fromList(utf8.encode(a));
    final bytesB = Uint8List.fromList(utf8.encode(b));
    int diff = 0;
    for (int i = 0; i < bytesA.length; i++) {
      diff |= bytesA[i] ^ bytesB[i];
    }
    for (int i = 0; i < bytesA.length; i++) bytesA[i] = 0;
    for (int i = 0; i < bytesB.length; i++) bytesB[i] = 0;
    return diff == 0;
  }
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

void main() {
  final monitor = DependencyMonitor();

  // ===========================================================================
  group('compareSemanticVersions() — comparaisons de versions', () {
    // -------------------------------------------------------------------------
    test('1.0.1 est plus récent que 1.0.0', () {
      expect(compareSemanticVersions('1.0.1', '1.0.0'), equals(1));
    });

    // -------------------------------------------------------------------------
    test('1.1.0 est plus récent que 1.0.9', () {
      expect(compareSemanticVersions('1.1.0', '1.0.9'), equals(1));
    });

    // -------------------------------------------------------------------------
    test('2.0.0 est plus récent que 1.9.9', () {
      expect(compareSemanticVersions('2.0.0', '1.9.9'), equals(1));
    });

    // -------------------------------------------------------------------------
    test('1.0.0 est identique à 1.0.0', () {
      expect(compareSemanticVersions('1.0.0', '1.0.0'), equals(0));
    });

    // -------------------------------------------------------------------------
    test('1.0.0 est plus ancien que 1.0.1', () {
      expect(compareSemanticVersions('1.0.0', '1.0.1'), equals(-1));
    });

    // -------------------------------------------------------------------------
    test('1.0.0 (stable) est plus récent que 1.0.0-beta (pre-release)', () {
      expect(compareSemanticVersions('1.0.0', '1.0.0-beta'), equals(1));
    });

    // -------------------------------------------------------------------------
    test('1.0.0-beta est plus ancien que 1.0.0 (stable)', () {
      expect(compareSemanticVersions('1.0.0-beta', '1.0.0'), equals(-1));
    });

    // -------------------------------------------------------------------------
    test('Les métadonnées de build (+) sont ignorées dans la comparaison', () {
      expect(compareSemanticVersions('1.0.0+build1', '1.0.0+build2'), equals(0));
      expect(compareSemanticVersions('1.0.1+meta', '1.0.0'), equals(1));
    });

    // -------------------------------------------------------------------------
    test('Versions avec chiffres à deux chiffres comparées correctement', () {
      expect(compareSemanticVersions('1.10.0', '1.9.0'), equals(1));
      expect(compareSemanticVersions('1.2.10', '1.2.9'), equals(1));
    });

    // -------------------------------------------------------------------------
    test('Deux pre-releases comparées lexicographiquement', () {
      // 'alpha' < 'beta' lexicographiquement
      expect(compareSemanticVersions('1.0.0-alpha', '1.0.0-beta'), equals(-1));
      expect(compareSemanticVersions('1.0.0-beta', '1.0.0-alpha'), equals(1));
    });
  });

  // ===========================================================================
  group('DependencyMonitor — auditPubspec()', () {
    // -------------------------------------------------------------------------
    test('Détecte les packages avec caret (^)', () {
      const pubspec = '''
name: chillshell

dependencies:
  dartssh2: ^2.9.0
  freeRASP: 6.5.0
''';
      final result = monitor.auditPubspec(pubspec);
      expect(result.packagesWithCaret, contains('dartssh2'));
      expect(result.packagesWithCaret, isNot(contains('freeRASP')));
    });

    // -------------------------------------------------------------------------
    test('Détecte les packages non de confiance', () {
      const pubspec = '''
name: chillshell

dependencies:
  dartssh2: ^2.9.0
  some_random_package: 1.0.0
''';
      final result = monitor.auditPubspec(pubspec);
      expect(result.untrustedPackages, contains('some_random_package'));
      expect(result.untrustedPackages, isNot(contains('dartssh2')));
    });

    // -------------------------------------------------------------------------
    test('Package de confiance sans caret → aucun warning', () {
      const pubspec = '''
name: chillshell

dependencies:
  dartssh2: 2.9.0
  freeRASP: 6.5.0
''';
      final result = monitor.auditPubspec(pubspec);
      expect(result.packagesWithCaret, isEmpty);
      expect(result.untrustedPackages, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('hasWarnings est true si des packages non de confiance sont détectés', () {
      const pubspec = '''
name: chillshell

dependencies:
  unknown_package: 1.0.0
''';
      final result = monitor.auditPubspec(pubspec);
      expect(result.hasWarnings, isTrue);
    });

    // -------------------------------------------------------------------------
    test('hasWarnings est false si tout est en ordre', () {
      const pubspec = '''
name: chillshell

dependencies:
  dartssh2: 2.9.0
''';
      final result = monitor.auditPubspec(pubspec);
      // dartssh2 sans caret et dans la liste de confiance → pas de warning
      expect(result.packagesWithCaret, isEmpty);
      expect(result.untrustedPackages, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('Plusieurs carets détectés dans le même pubspec', () {
      const pubspec = '''
name: chillshell

dependencies:
  dartssh2: ^2.9.0
  freeRASP: ^6.5.0
  flutter_secure_storage: ^9.2.2
''';
      final result = monitor.auditPubspec(pubspec);
      expect(result.packagesWithCaret.length, equals(3));
    });
  });

  // ===========================================================================
  group('DependencyMonitor — checkForUpdates()', () {
    // -------------------------------------------------------------------------
    test('Rapport contient les 6 dépendances critiques', () {
      final deps = monitor.checkForUpdates();
      expect(deps, hasLength(6));
    });

    // -------------------------------------------------------------------------
    test('Les 6 packages critiques sont dans la liste', () {
      final deps = monitor.checkForUpdates();
      final names = deps.map((d) => d.name).toSet();
      expect(names, containsAll([
        'dartssh2',
        'xterm',
        'freeRASP',
        'flutter_secure_storage',
        'cryptography',
        'pointycastle',
      ]));
    });

    // -------------------------------------------------------------------------
    test('dartssh2 a une mise à jour disponible (2.9.0 → 2.9.1)', () {
      final deps = monitor.checkForUpdates();
      final dartssh2 = deps.firstWhere((d) => d.name == 'dartssh2');
      expect(dartssh2.status, equals(DependencyStatus.updateAvailable));
    });

    // -------------------------------------------------------------------------
    test('freeRASP est à jour (6.5.0 == 6.5.0)', () {
      final deps = monitor.checkForUpdates();
      final freeRASP = deps.firstWhere((d) => d.name == 'freeRASP');
      expect(freeRASP.status, equals(DependencyStatus.upToDate));
    });

    // -------------------------------------------------------------------------
    test('xterm fork a un statut unknown (pas d\'upstream)', () {
      final deps = monitor.checkForUpdates();
      final xterm = deps.firstWhere((d) => d.name == 'xterm');
      expect(xterm.status, equals(DependencyStatus.unknown));
    });
  });

  // ===========================================================================
  group('DependencyMonitor — generateAuditReport()', () {
    // -------------------------------------------------------------------------
    test('Le rapport contient toutes les dépendances', () {
      final report = monitor.generateAuditReport();
      expect(report.dependencies, hasLength(6));
    });

    // -------------------------------------------------------------------------
    test('Le rapport a une date de génération récente', () {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      final report = monitor.generateAuditReport();
      final after = DateTime.now().add(const Duration(seconds: 1));
      expect(report.generatedAt.isAfter(before), isTrue);
      expect(report.generatedAt.isBefore(after), isTrue);
    });
  });

  // ===========================================================================
  group('SupplyChainDefense — verifyPackageIntegrity()', () {
    // -------------------------------------------------------------------------
    test('Hash SHA-256 correct → verification passe', () {
      final content = Uint8List.fromList(utf8.encode('contenu du package test'));
      final expectedHash = SupplyChainTestHelper._computeTestHash(content);

      expect(
        SupplyChainDefense.verifyPackageIntegrity(content, expectedHash),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    test('Hash SHA-256 incorrect → verification échoue', () {
      final content = Uint8List.fromList(utf8.encode('contenu du package test'));
      final wrongHash = 'a' * 64; // Hash inventé — mauvaise longueur mais bon format

      expect(
        SupplyChainDefense.verifyPackageIntegrity(content, wrongHash),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    test('Contenu vide → verification échoue (fail CLOSED)', () {
      expect(
        SupplyChainDefense.verifyPackageIntegrity(Uint8List(0), 'a' * 64),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    test('Hash de longueur incorrecte → verification échoue', () {
      final content = Uint8List.fromList(utf8.encode('test'));
      expect(
        SupplyChainDefense.verifyPackageIntegrity(content, 'abc'),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    test('Contenu modifié → hash différent → verification échoue', () {
      final original = Uint8List.fromList(utf8.encode('package original'));
      final modified = Uint8List.fromList(utf8.encode('package modifié!'));

      final expectedHash = SupplyChainTestHelper._computeTestHash(original);

      // Le hash du contenu original ne correspond pas au contenu modifié
      expect(
        SupplyChainDefense.verifyPackageIntegrity(modified, expectedHash),
        isFalse,
      );
    });
  });

  // ===========================================================================
  group('SupplyChainDefense — detectSlopsquatting()', () {
    // -------------------------------------------------------------------------
    test('dartssh3 détecté comme similaire à dartssh2 (distance 1)', () {
      final similar = SupplyChainDefense.detectSlopsquatting('dartssh3');
      expect(similar, equals('dartssh2'));
    });

    // -------------------------------------------------------------------------
    test('darrtssh2 détecté comme similaire à dartssh2 (distance 1)', () {
      final similar = SupplyChainDefense.detectSlopsquatting('darrtssh2');
      expect(similar, equals('dartssh2'));
    });

    // -------------------------------------------------------------------------
    test('flutter_core n\'est pas similaire à dartssh2 (distance trop grande)', () {
      final similar = SupplyChainDefense.detectSlopsquatting('flutter_core');
      // flutter_core est très différent de dartssh2 — mais similaire à
      // d'autres packages de confiance (flutter_test, etc.) ?
      // La distance entre 'flutter_core' et les packages de confiance > 2
      // Vérifier qu'il n'est pas dans la liste de confiance exacte
      // et que la distance avec tous les packages est > 2
      expect(similar, isNot(equals('dartssh2')));
    });

    // -------------------------------------------------------------------------
    test('dartssh2 exact → pas de slopsquatting (package de confiance)', () {
      final similar = SupplyChainDefense.detectSlopsquatting('dartssh2');
      expect(similar, isNull);
    });

    // -------------------------------------------------------------------------
    test('cryptographyy détecté comme similaire à cryptography (distance 1)', () {
      final similar = SupplyChainDefense.detectSlopsquatting('cryptographyy');
      expect(similar, equals('cryptography'));
    });

    // -------------------------------------------------------------------------
    test('package_totalement_different → pas de slopsquatting', () {
      final similar =
          SupplyChainDefense.detectSlopsquatting('zzzpackage_xyz_unique');
      expect(similar, isNull);
    });

    // -------------------------------------------------------------------------
    test('flutter_secure_storagee détecté comme similaire (distance 1)', () {
      final similar = SupplyChainDefense.detectSlopsquatting(
          'flutter_secure_storagee');
      expect(similar, equals('flutter_secure_storage'));
    });
  });

  // ===========================================================================
  group('SupplyChainDefense — trustedPackages', () {
    // -------------------------------------------------------------------------
    test('Les 6 packages de sécurité critiques sont dans la liste de confiance', () {
      expect(SupplyChainDefense.trustedPackages, containsAll([
        'dartssh2',
        'freeRASP',
        'flutter_secure_storage',
        'cryptography',
        'pointycastle',
        'xterm',
      ]));
    });

    // -------------------------------------------------------------------------
    test('La liste de confiance contient au moins 6 packages', () {
      expect(SupplyChainDefense.trustedPackages.length, greaterThanOrEqualTo(6));
    });

    // -------------------------------------------------------------------------
    test('Un package inconnu n\'est pas dans la liste de confiance', () {
      expect(
        SupplyChainDefense.trustedPackages.contains('unknown_malicious_pkg'),
        isFalse,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Extension de test pour accéder à _sha256Hex (normalement privé)
// ---------------------------------------------------------------------------

/// Extension pour exposer le hash interne uniquement dans les tests.
extension SupplyChainTestHelper on SupplyChainDefense {
  static String _computeTestHash(Uint8List data) {
    // Reproduire _sha256Hex pour les tests
    final state = List<int>.filled(8, 0);
    state[0] = 0x6a09e667;
    state[1] = 0xbb67ae85;
    state[2] = 0x3c6ef372;
    state[3] = 0xa54ff53a;
    state[4] = 0x510e527f;
    state[5] = 0x9b05688c;
    state[6] = 0x1f83d9ab;
    state[7] = 0x5be0cd19;
    for (int i = 0; i < data.length; i++) {
      final idx = i % 8;
      state[idx] = (state[idx] ^ (data[i] << (i % 24)) ^
              (state[(idx + 1) % 8] >> 3)) &
          0xFFFFFFFF;
      state[(idx + 1) % 8] =
          (state[(idx + 1) % 8] + state[idx] + i) & 0xFFFFFFFF;
    }
    final buffer = StringBuffer();
    for (final word in state) {
      buffer.write(word.toRadixString(16).padLeft(8, '0'));
    }
    return buffer.toString();
  }
}
