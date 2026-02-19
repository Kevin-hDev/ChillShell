// test_fix_018.dart — Tests unitaires pour FIX-018
//
// Vérifie la sécurité Wake-on-LAN via Tailscale :
// - Les limitations du protocole WOL sont documentées
// - Les mitigations proposées sont complètes
// - isValidTailscaleIP accepte les IPs Tailscale et rejette les autres
// - La couverture complète du range 100.64.0.0/10 est assurée

import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/core/security/wol_tailscale_only.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 1 — WolSecurityDoc.getProtocolLimitations()
  // ─────────────────────────────────────────────────────────────────────────
  group('WolSecurityDoc.getProtocolLimitations()', () {
    late WolSecurityDoc doc;

    setUp(() {
      doc = WolSecurityDoc();
    });

    test('Retourne au moins 4 limitations', () {
      final limitations = doc.getProtocolLimitations();
      expect(
        limitations.length,
        greaterThanOrEqualTo(4),
        reason: 'Minimum 4 limitations du protocole WOL requises',
      );
    });

    test('Aucune limitation n\'est vide', () {
      for (final limitation in doc.getProtocolLimitations()) {
        expect(
          limitation.trim().isEmpty,
          isFalse,
          reason: 'Une limitation est vide',
        );
      }
    });

    test('Mentionne l\'absence d\'authentification', () {
      final text = doc.getProtocolLimitations().join('\n').toLowerCase();
      expect(
        text.contains('authentification') || text.contains('authentication'),
        isTrue,
        reason: 'Doit mentionner l\'absence d\'authentification',
      );
    });

    test('Mentionne UDP ou broadcast', () {
      final text = doc.getProtocolLimitations().join('\n').toLowerCase();
      expect(
        text.contains('udp') || text.contains('broadcast'),
        isTrue,
        reason: 'Doit mentionner UDP ou broadcast',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 2 — WolSecurityDoc.getMitigations()
  // ─────────────────────────────────────────────────────────────────────────
  group('WolSecurityDoc.getMitigations()', () {
    late WolSecurityDoc doc;

    setUp(() {
      doc = WolSecurityDoc();
    });

    test('Retourne au moins 2 mitigations', () {
      final mitigations = doc.getMitigations();
      expect(
        mitigations.length,
        greaterThanOrEqualTo(2),
        reason: 'Minimum 2 mitigations requises',
      );
    });

    test('Chaque mitigation a un titre non vide', () {
      for (final m in doc.getMitigations()) {
        expect(
          m.title.trim().isEmpty,
          isFalse,
          reason: 'Une mitigation a un titre vide',
        );
      }
    });

    test('Chaque mitigation a une description non vide', () {
      for (final m in doc.getMitigations()) {
        expect(
          m.description.trim().isEmpty,
          isFalse,
          reason: 'Une mitigation a une description vide',
        );
      }
    });

    test('Chaque mitigation a un niveau d\'efficacité non vide', () {
      for (final m in doc.getMitigations()) {
        expect(
          m.effectiveness.trim().isEmpty,
          isFalse,
          reason: 'Une mitigation a une efficacité vide',
        );
      }
    });

    test('Une mitigation mentionne Tailscale', () {
      final allTitles = doc.getMitigations().map((m) => m.title).join('\n');
      expect(
        allTitles.toLowerCase().contains('tailscale'),
        isTrue,
        reason: 'Une mitigation doit proposer l\'utilisation de Tailscale',
      );
    });

    test('Le modèle WolMitigation fonctionne correctement', () {
      const m = WolMitigation(
        title: 'Test mitigation',
        description: 'Description de test',
        effectiveness: 'Haute',
      );
      expect(m.title, equals('Test mitigation'));
      expect(m.description, equals('Description de test'));
      expect(m.effectiveness, equals('Haute'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 3 — SecureWolViaTailscale.isValidTailscaleIP()
  // ─────────────────────────────────────────────────────────────────────────
  group('SecureWolViaTailscale.isValidTailscaleIP()', () {
    late SecureWolViaTailscale wol;

    setUp(() {
      wol = SecureWolViaTailscale();
    });

    // ── IPs Tailscale valides ─────────────────────────────────────────────

    test('Accepte 100.64.0.1 — début du range Tailscale', () {
      expect(
        wol.isValidTailscaleIP('100.64.0.1'),
        isTrue,
        reason: '100.64.0.1 est dans le range Tailscale 100.64.0.0/10',
      );
    });

    test('Accepte 100.100.100.100 — IP Tailscale typique', () {
      expect(
        wol.isValidTailscaleIP('100.100.100.100'),
        isTrue,
        reason: '100.100.100.100 est dans le range Tailscale',
      );
    });

    test('Accepte 100.64.0.0 — première adresse du range', () {
      expect(
        wol.isValidTailscaleIP('100.64.0.0'),
        isTrue,
        reason: '100.64.0.0 est la première adresse du range Tailscale',
      );
    });

    test('Accepte 100.127.255.255 — dernière adresse du range', () {
      expect(
        wol.isValidTailscaleIP('100.127.255.255'),
        isTrue,
        reason: '100.127.255.255 est la dernière adresse du range Tailscale',
      );
    });

    test('Accepte 100.80.50.10 — IP Tailscale intermédiaire', () {
      expect(
        wol.isValidTailscaleIP('100.80.50.10'),
        isTrue,
      );
    });

    test('Accepte 100.90.1.200 — IP Tailscale intermédiaire', () {
      expect(
        wol.isValidTailscaleIP('100.90.1.200'),
        isTrue,
      );
    });

    // ── IPs NON Tailscale — doivent être rejetées ─────────────────────────

    test('Rejette 192.168.1.1 — réseau local privé', () {
      expect(
        wol.isValidTailscaleIP('192.168.1.1'),
        isFalse,
        reason: '192.168.1.1 est un réseau privé local, pas Tailscale',
      );
    });

    test('Rejette 10.0.0.1 — réseau privé RFC 1918', () {
      expect(
        wol.isValidTailscaleIP('10.0.0.1'),
        isFalse,
        reason: '10.0.0.1 est un réseau privé RFC 1918, pas Tailscale',
      );
    });

    test('Rejette 172.16.0.1 — réseau privé RFC 1918', () {
      expect(
        wol.isValidTailscaleIP('172.16.0.1'),
        isFalse,
      );
    });

    test('Rejette 8.8.8.8 — IP publique Google DNS', () {
      expect(
        wol.isValidTailscaleIP('8.8.8.8'),
        isFalse,
      );
    });

    test('Rejette 100.128.0.0 — juste après le range Tailscale', () {
      // 100.128.0.0 est HORS du range (le range s'arrête à 100.127.255.255)
      expect(
        wol.isValidTailscaleIP('100.128.0.0'),
        isFalse,
        reason: '100.128.0.0 est hors du range Tailscale (après 100.127.255.255)',
      );
    });

    test('Rejette 100.63.255.255 — juste avant le range Tailscale', () {
      // 100.63.255.255 est HORS du range (le range commence à 100.64.0.0)
      expect(
        wol.isValidTailscaleIP('100.63.255.255'),
        isFalse,
        reason: '100.63.255.255 est avant le début du range Tailscale',
      );
    });

    test('Rejette 100.0.0.1 — dans 100.x mais hors range Tailscale', () {
      expect(
        wol.isValidTailscaleIP('100.0.0.1'),
        isFalse,
      );
    });

    // ── Cas limites — formats invalides ──────────────────────────────────

    test('Rejette une chaîne vide', () {
      expect(wol.isValidTailscaleIP(''), isFalse);
    });

    test('Rejette un format invalide (trop d\'octets)', () {
      expect(wol.isValidTailscaleIP('100.64.0.0.0'), isFalse);
    });

    test('Rejette un format invalide (octet non numérique)', () {
      expect(wol.isValidTailscaleIP('100.64.abc.1'), isFalse);
    });

    test('Rejette un octet hors de 0-255', () {
      expect(wol.isValidTailscaleIP('100.64.0.256'), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 4 — Couverture complète du range Tailscale
  // ─────────────────────────────────────────────────────────────────────────
  group('Couverture du range Tailscale 100.64.0.0/10', () {
    late SecureWolViaTailscale wol;

    setUp(() {
      wol = SecureWolViaTailscale();
    });

    test('Les 64 sous-réseaux /16 de 100.64.x à 100.127.x sont acceptés', () {
      // Test d'un échantillon représentatif de chaque /16 dans le range
      for (var secondOctet = 64; secondOctet <= 127; secondOctet++) {
        final ip = '100.$secondOctet.1.1';
        expect(
          wol.isValidTailscaleIP(ip),
          isTrue,
          reason: '$ip devrait être dans le range Tailscale',
        );
      }
    });

    test('Les adresses avant 100.64.x sont toutes rejetées', () {
      // Teste quelques valeurs représentatives hors range
      for (final ip in [
        '100.0.0.1',
        '100.32.0.1',
        '100.63.255.255',
      ]) {
        expect(
          wol.isValidTailscaleIP(ip),
          isFalse,
          reason: '$ip devrait être HORS du range Tailscale',
        );
      }
    });

    test('Les adresses après 100.127.x sont toutes rejetées', () {
      for (final ip in [
        '100.128.0.0',
        '100.200.0.1',
        '100.255.255.255',
      ]) {
        expect(
          wol.isValidTailscaleIP(ip),
          isFalse,
          reason: '$ip devrait être HORS du range Tailscale',
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Groupe 5 — SecureWolViaTailscale.wakeViaTailscale()
  // ─────────────────────────────────────────────────────────────────────────
  group('SecureWolViaTailscale.wakeViaTailscale()', () {
    late SecureWolViaTailscale wol;

    setUp(() {
      wol = SecureWolViaTailscale();
    });

    test('Retourne false pour une IP non Tailscale (fail closed)', () async {
      final result = await wol.wakeViaTailscale(
        '192.168.1.100', // IP réseau local — rejetée
        'AA:BB:CC:DD:EE:FF',
      );
      expect(
        result,
        isFalse,
        reason:
            'Doit rejeter les IPs non Tailscale — fail closed obligatoire',
      );
    });

    test('Retourne false pour une adresse MAC invalide', () async {
      final result = await wol.wakeViaTailscale(
        '100.64.0.1',
        'ADRESSE_MAC_INVALIDE',
      );
      expect(
        result,
        isFalse,
        reason: 'Doit rejeter les adresses MAC invalides',
      );
    });

    test('Retourne true pour une IP Tailscale et une MAC valide', () async {
      final result = await wol.wakeViaTailscale(
        '100.100.100.100', // IP Tailscale valide
        'AA:BB:CC:DD:EE:FF', // MAC valide
      );
      expect(
        result,
        isTrue,
        reason: 'Doit accepter une IP Tailscale avec une MAC valide',
      );
    });

    test('Rejette une MAC sans séparateur deux-points', () async {
      final result = await wol.wakeViaTailscale(
        '100.64.0.1',
        'AABBCCDDEEFF', // Format sans séparateur — invalide
      );
      expect(result, isFalse);
    });
  });
}
