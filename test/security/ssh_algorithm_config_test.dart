// test_fix_014.dart
// Tests unitaires — FIX-014 : Restriction des algorithmes SSH autorisés
// GAP-014, Priorité P1
//
// Ces tests vérifient que la configuration des algorithmes SSH respecte
// les exigences de sécurité minimales :
// - Aucun algorithme faible n'est autorisé
// - Les algorithmes forts sont présents et dans le bon ordre
// - La vérification des algorithmes serveur fonctionne correctement

import 'package:flutter_test/flutter_test.dart';

// Import du module à tester (ajuster le chemin selon la structure du projet)
import 'package:vibeterm/core/security/ssh_algorithm_config.dart';

void main() {
  // Instance réutilisée dans tous les tests
  late SSHAlgorithmConfig config;

  setUp(() {
    config = SSHAlgorithmConfig();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 1 : Algorithmes interdits absents des listes autorisées
  // ═══════════════════════════════════════════════════════════════════════════

  group('Algorithmes interdits — absents des listes autorisées', () {
    // ────────────────────────────────────────────────────────────────────────
    // Chiffrements : modes CBC interdits
    // ────────────────────────────────────────────────────────────────────────

    test('aes128-cbc absent de allowedCiphers', () {
      expect(
        config.allowedCiphers,
        isNot(contains('aes128-cbc')),
        reason: 'Le mode CBC est vulnérable aux attaques Lucky-13 et BEAST.',
      );
    });

    test('aes256-cbc absent de allowedCiphers', () {
      expect(
        config.allowedCiphers,
        isNot(contains('aes256-cbc')),
        reason: 'Le mode CBC est vulnérable quelle que soit la taille de clé.',
      );
    });

    test('3des-cbc absent de allowedCiphers', () {
      expect(
        config.allowedCiphers,
        isNot(contains('3des-cbc')),
        reason: '3DES est cassé : clé effective de 112 bits, vitesse très lente.',
      );
    });

    test('arcfour (RC4) absent de allowedCiphers', () {
      expect(
        config.allowedCiphers,
        isNot(contains('arcfour')),
        reason: 'RC4 est cassé depuis l\'attaque BEAST en 2011.',
      );
    });

    // ────────────────────────────────────────────────────────────────────────
    // MACs : SHA-1 interdit
    // ────────────────────────────────────────────────────────────────────────

    test('hmac-sha1 absent de allowedMacs', () {
      expect(
        config.allowedMacs,
        isNot(contains('hmac-sha1')),
        reason:
            'SHA-1 est cassé depuis 2017 (attaque SHAttered de Google). '
            'Les collisions SHA-1 sont calculables en pratique.',
      );
    });

    test('hmac-sha1-96 absent de allowedMacs', () {
      expect(
        config.allowedMacs,
        isNot(contains('hmac-sha1-96')),
        reason: 'Variante SHA-1 tronquée — encore plus faible que hmac-sha1.',
      );
    });

    test('hmac-md5 absent de allowedMacs', () {
      expect(
        config.allowedMacs,
        isNot(contains('hmac-md5')),
        reason: 'MD5 est cassé depuis 2004. Collisions trivialement générables.',
      );
    });

    // ────────────────────────────────────────────────────────────────────────
    // Clés hôte : ssh-dss interdit
    // ────────────────────────────────────────────────────────────────────────

    test('ssh-dss absent de allowedHostKeys', () {
      expect(
        config.allowedHostKeys,
        isNot(contains('ssh-dss')),
        reason:
            'ssh-dss utilise DSA limité à 1024 bits avec SHA-1. '
            'Désactivé par défaut dans OpenSSH >= 7.0 (2015).',
      );
    });

    // ────────────────────────────────────────────────────────────────────────
    // KEX : Diffie-Hellman avec petits groupes interdit
    // ────────────────────────────────────────────────────────────────────────

    test('diffie-hellman-group1-sha1 absent de allowedKex', () {
      expect(
        config.allowedKex,
        isNot(contains('diffie-hellman-group1-sha1')),
        reason:
            'Groupe DH de 768 bits, cassé par Logjam (2015). '
            'Calculable en pratique par des adversaires étatiques.',
      );
    });

    test('diffie-hellman-group14-sha1 absent de allowedKex', () {
      expect(
        config.allowedKex,
        isNot(contains('diffie-hellman-group14-sha1')),
        reason: 'Utilise SHA-1 pour le hash — SHA-1 est cassé.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 2 : Algorithmes forts présents et dans le bon ordre
  // ═══════════════════════════════════════════════════════════════════════════

  group('Algorithmes forts — présents et ordonnés', () {
    test('chacha20-poly1305 est le premier chiffrement', () {
      expect(
        config.allowedCiphers.isNotEmpty,
        isTrue,
        reason: 'La liste des chiffrements ne doit pas être vide.',
      );
      expect(
        config.allowedCiphers.first,
        equals('chacha20-poly1305@openssh.com'),
        reason:
            'ChaCha20-Poly1305 doit être le premier chiffrement : '
            'immunisé au timing, pas de vulnérabilité aux oracles de padding.',
      );
    });

    test('aes256-gcm est dans allowedCiphers', () {
      expect(
        config.allowedCiphers,
        contains('aes256-gcm@openssh.com'),
        reason: 'AES-256-GCM est un chiffrement AEAD fort requis en fallback.',
      );
    });

    test('curve25519-sha256 est dans allowedKex', () {
      expect(
        config.allowedKex,
        contains('curve25519-sha256'),
        reason: 'Curve25519 est l\'algorithme d\'échange de clés recommandé (RFC 8731).',
      );
    });

    test('hmac-sha2-512-etm est dans allowedMacs', () {
      expect(
        config.allowedMacs,
        contains('hmac-sha2-512-etm@openssh.com'),
        reason: 'SHA-512 ETM est le MAC le plus fort disponible dans SSH.',
      );
    });

    test('ssh-ed25519 est dans allowedHostKeys', () {
      expect(
        config.allowedHostKeys,
        contains('ssh-ed25519'),
        reason: 'Ed25519 est la clé hôte recommandée : courte, sécurisée (RFC 8709).',
      );
    });

    test('allowedMacs contient uniquement des variantes ETM', () {
      for (final mac in config.allowedMacs) {
        expect(
          mac.contains('etm'),
          isTrue,
          reason:
              'Le MAC "$mac" n\'est pas une variante ETM (Encrypt-then-MAC). '
              'Les variantes MTE (MAC-then-Encrypt) sont vulnérables.',
        );
      }
    });

    test('forbiddenAlgorithms est non vide et documenté', () {
      expect(
        config.forbiddenAlgorithms.length,
        greaterThanOrEqualTo(10),
        reason:
            'La liste des algorithmes interdits doit documenter au moins 10 entrées '
            'pour couvrir tous les cas faibles connus.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 3 : Constante de sécurité critique
  // ═══════════════════════════════════════════════════════════════════════════

  group('Constante de sécurité — disableHostkeyVerification', () {
    test('disableHostkeyVerification est false', () {
      expect(
        SSHAlgorithmConfig.disableHostkeyVerification,
        isFalse,
        reason:
            'La vérification de la clé hôte ne doit JAMAIS être désactivée. '
            'Si true, tout Man-in-the-Middle est trivial.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 4 : validateServerAlgorithms
  // ═══════════════════════════════════════════════════════════════════════════

  group('validateServerAlgorithms — détection des algorithmes faibles', () {
    test('aucun avertissement pour un serveur avec des algos forts', () {
      final serverAlgos = [
        'curve25519-sha256',
        'chacha20-poly1305@openssh.com',
        'hmac-sha2-512-etm@openssh.com',
        'ssh-ed25519',
      ];

      final warnings = config.validateServerAlgorithms(serverAlgos);
      expect(
        warnings,
        isEmpty,
        reason:
            'Un serveur proposant uniquement des algorithmes forts '
            'ne doit générer aucun avertissement.',
      );
    });

    test('avertissement si le serveur propose hmac-sha1', () {
      final serverAlgos = [
        'curve25519-sha256',
        'chacha20-poly1305@openssh.com',
        'hmac-sha1', // <-- faible
      ];

      final warnings = config.validateServerAlgorithms(serverAlgos);
      expect(
        warnings,
        isNotEmpty,
        reason: 'Un serveur proposant hmac-sha1 doit générer un avertissement.',
      );
      // Vérifier qu'au moins un avertissement mentionne sha1
      final mentionsSha1 = warnings.any(
        (w) => w.toLowerCase().contains('sha1') || w.toLowerCase().contains('sha-1'),
      );
      expect(
        mentionsSha1,
        isTrue,
        reason: 'L\'avertissement doit mentionner SHA-1 explicitement.',
      );
    });

    test('avertissement si le serveur propose des modes CBC', () {
      final serverAlgos = [
        'curve25519-sha256',
        'aes256-cbc', // <-- faible
        'hmac-sha2-256-etm@openssh.com',
      ];

      final warnings = config.validateServerAlgorithms(serverAlgos);
      expect(
        warnings,
        isNotEmpty,
        reason: 'Un serveur proposant AES-CBC doit générer un avertissement.',
      );
      final mentionsCbc = warnings.any(
        (w) => w.toLowerCase().contains('cbc'),
      );
      expect(
        mentionsCbc,
        isTrue,
        reason: 'L\'avertissement doit mentionner CBC explicitement.',
      );
    });

    test('avertissement critique si aucun KEX fort', () {
      final serverAlgos = [
        'diffie-hellman-group1-sha1', // <-- faible et interdit
        'aes256-ctr',
        'hmac-sha2-256',
      ];

      final warnings = config.validateServerAlgorithms(serverAlgos);
      expect(
        warnings,
        isNotEmpty,
        reason:
            'Un serveur sans KEX fort doit générer un avertissement critique.',
      );
      final hasCritical = warnings.any(
        (w) => w.toUpperCase().contains('CRITIQUE'),
      );
      expect(
        hasCritical,
        isTrue,
        reason:
            'L\'absence de KEX fort doit générer un avertissement CRITIQUE.',
      );
    });

    test('avertissement pour ssh-dss dans les algos serveur', () {
      final serverAlgos = [
        'curve25519-sha256',
        'aes256-gcm@openssh.com',
        'hmac-sha2-256-etm@openssh.com',
        'ssh-dss', // <-- faible et interdit
      ];

      final warnings = config.validateServerAlgorithms(serverAlgos);
      expect(
        warnings,
        isNotEmpty,
        reason: 'Un serveur proposant ssh-dss doit générer un avertissement.',
      );
    });

    test('liste vide retourne une liste vide d\'avertissements', () {
      final warnings = config.validateServerAlgorithms([]);
      expect(
        warnings,
        isEmpty,
        reason:
            'Une liste vide d\'algorithmes serveur ne doit pas générer '
            'd\'erreur (le serveur n\'a rien proposé).',
      );
    });

    test('avertissements multiples si plusieurs algos faibles', () {
      final serverAlgos = [
        'diffie-hellman-group1-sha1', // faible KEX
        'aes256-cbc',                  // CBC faible
        'hmac-sha1',                   // SHA-1 faible
        'ssh-dss',                     // DSA faible
      ];

      final warnings = config.validateServerAlgorithms(serverAlgos);
      expect(
        warnings.length,
        greaterThanOrEqualTo(2),
        reason:
            'Plusieurs algorithmes faibles doivent générer plusieurs '
            'avertissements distincts.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 5 : assertSafeConfiguration (intégrité interne)
  // ═══════════════════════════════════════════════════════════════════════════

  group('assertSafeConfiguration — intégrité de la configuration', () {
    test('assertSafeConfiguration ne lève pas d\'erreur sur la config par défaut', () {
      expect(
        () => config.assertSafeConfiguration(),
        returnsNormally,
        reason:
            'La configuration par défaut doit passer la vérification '
            'd\'intégrité sans erreur.',
      );
    });
  });
}
