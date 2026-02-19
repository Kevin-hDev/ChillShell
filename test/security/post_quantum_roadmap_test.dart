// test_fix_016.dart
// Tests unitaires — FIX-016 : Roadmap post-quantique
// GAP-016, Priorité P3
//
// Ces tests vérifient que la roadmap post-quantique est correctement
// documentée et cohérente :
// - État actuel : dartssh2 ne supporte PAS encore le PQC
// - Serveur OpenSSH supporte sntrup761x25519 depuis la v9.0
// - Les recommandations sont concrètes et suffisantes
// - La config sshd_config contient les bons algorithmes

import 'package:flutter_test/flutter_test.dart';

// Import du module à tester (ajuster le chemin selon la structure du projet)
import 'package:vibeterm/core/security/post_quantum_roadmap.dart';

void main() {
  // Instance réutilisée dans tous les tests
  late PostQuantumRoadmap roadmap;

  setUp(() {
    roadmap = PostQuantumRoadmap();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 1 : getCurrentStatus
  // ═══════════════════════════════════════════════════════════════════════════

  group('getCurrentStatus — état actuel du support PQC', () {
    test('currentKex est curve25519-sha256', () {
      final status = roadmap.getCurrentStatus();
      expect(
        status.currentKex,
        equals('curve25519-sha256'),
        reason:
            'L\'algorithme KEX actuel de ChillShell doit être curve25519-sha256. '
            'C\'est l\'état de l\'art classique utilisé par dartssh2.',
      );
    });

    test('targetKex est sntrup761x25519-sha512@openssh.com', () {
      final status = roadmap.getCurrentStatus();
      expect(
        status.targetKex,
        equals('sntrup761x25519-sha512@openssh.com'),
        reason:
            'L\'objectif post-quantique doit être sntrup761x25519 — '
            'algorithme hybride (post-quantique + Curve25519) supporté '
            'par OpenSSH 9.0+.',
      );
    });

    test('dartssh2Support est false (pas encore supporté)', () {
      final status = roadmap.getCurrentStatus();
      expect(
        status.dartssh2Support,
        isFalse,
        reason:
            'dartssh2 ne supporte PAS encore sntrup761x25519 à la date de cet audit. '
            'Ce test doit passer à true quand dartssh2 implémentera le PQC.',
      );
    });

    test('opensshSupport est true (OpenSSH 9.0+ supporte sntrup761x25519)', () {
      final status = roadmap.getCurrentStatus();
      expect(
        status.opensshSupport,
        isTrue,
        reason:
            'OpenSSH 9.0+ (mars 2022) supporte sntrup761x25519-sha512@openssh.com '
            'côté serveur. Les distributions modernes ont OpenSSH >= 9.0.',
      );
    });

    test('timelineEstimate est non vide et descriptif', () {
      final status = roadmap.getCurrentStatus();
      expect(
        status.timelineEstimate.isNotEmpty,
        isTrue,
        reason: 'L\'estimation de délai ne doit pas être vide.',
      );
      expect(
        status.timelineEstimate.length,
        greaterThan(20),
        reason:
            'L\'estimation de délai doit être suffisamment descriptive '
            'pour guider les décisions de planification.',
      );
    });

    test('targetKex contient "sntrup" (post-quantique)', () {
      final status = roadmap.getCurrentStatus();
      expect(
        status.targetKex.toLowerCase().contains('sntrup'),
        isTrue,
        reason:
            'L\'algorithme cible doit être un algorithme post-quantique '
            'basé sur NTRU (sntrup761).',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 2 : getRecommendations
  // ═══════════════════════════════════════════════════════════════════════════

  group('getRecommendations — recommandations concrètes', () {
    test('retourne au moins 3 recommandations', () {
      final recommendations = roadmap.getRecommendations();
      expect(
        recommendations.length,
        greaterThanOrEqualTo(3),
        reason:
            'La roadmap doit proposer au moins 3 recommandations concrètes '
            'pour la migration post-quantique.',
      );
    });

    test('une recommandation mentionne dartssh2', () {
      final recommendations = roadmap.getRecommendations();
      final mentionsDartssh2 = recommendations.any(
        (r) => r.toLowerCase().contains('dartssh2'),
      );
      expect(
        mentionsDartssh2,
        isTrue,
        reason:
            'Une recommandation doit indiquer de surveiller les releases '
            'de dartssh2 pour le support PQC.',
      );
    });

    test('une recommandation mentionne la configuration serveur', () {
      final recommendations = roadmap.getRecommendations();
      final mentionsServer = recommendations.any(
        (r) =>
            r.toLowerCase().contains('serveur') ||
            r.toLowerCase().contains('server') ||
            r.toLowerCase().contains('openssh'),
      );
      expect(
        mentionsServer,
        isTrue,
        reason:
            'Une recommandation doit mentionner la configuration du serveur SSH '
            'avec sntrup761x25519 (déjà supporté côté serveur).',
      );
    });

    test('une recommandation mentionne la migration des clés', () {
      final recommendations = roadmap.getRecommendations();
      final mentionsMigration = recommendations.any(
        (r) =>
            r.toLowerCase().contains('migration') ||
            r.toLowerCase().contains('clé') ||
            r.toLowerCase().contains('cle'),
      );
      expect(
        mentionsMigration,
        isTrue,
        reason:
            'Une recommandation doit planifier la migration des clés SSH '
            'vers des algorithmes post-quantiques.',
      );
    });

    test('chaque recommandation est suffisamment descriptive', () {
      for (var i = 0; i < roadmap.getRecommendations().length; i++) {
        final rec = roadmap.getRecommendations()[i];
        expect(
          rec.length,
          greaterThan(30),
          reason:
              'La recommandation #$i est trop courte. '
              'Chaque recommandation doit être actionnable et claire.',
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 3 : getRecommendedSshdConfig
  // ═══════════════════════════════════════════════════════════════════════════

  group('getRecommendedSshdConfig — configuration sshd_config', () {
    test('la config contient sntrup761x25519', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.contains('sntrup761x25519'),
        isTrue,
        reason:
            'La config sshd_config recommandée doit inclure sntrup761x25519 '
            'en priorité dans KexAlgorithms.',
      );
    });

    test('la config contient chacha20-poly1305', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.contains('chacha20-poly1305'),
        isTrue,
        reason:
            'La config sshd_config doit inclure chacha20-poly1305 '
            'comme premier chiffrement recommandé.',
      );
    });

    test('la config contient hmac-sha2 avec ETM', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.contains('etm'),
        isTrue,
        reason:
            'La config sshd_config doit inclure des MACs ETM (Encrypt-then-MAC). '
            'Les variantes non-ETM sont moins sécurisées.',
      );
    });

    test('la config contient KexAlgorithms', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.contains('KexAlgorithms'),
        isTrue,
        reason:
            'La config sshd_config doit définir KexAlgorithms explicitement '
            'pour forcer les algorithmes forts.',
      );
    });

    test('la config contient Ciphers', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.contains('Ciphers'),
        isTrue,
        reason:
            'La config sshd_config doit définir Ciphers pour restreindre '
            'les chiffrements aux algorithmes AEAD uniquement.',
      );
    });

    test('la config contient MACs', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.contains('MACs'),
        isTrue,
        reason:
            'La config sshd_config doit définir MACs pour restreindre '
            'aux variantes ETM uniquement.',
      );
    });

    test('la config désactive l\'authentification par mot de passe', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      final disablesPassword =
          sshdConfig.contains('PasswordAuthentication no') ||
          sshdConfig.contains('PasswordAuthentication no');
      expect(
        disablesPassword,
        isTrue,
        reason:
            'La config sshd_config recommandée doit désactiver l\'authentification '
            'par mot de passe. Les clés publiques sont obligatoires.',
      );
    });

    test('la config ne contient pas d\'algorithmes CBC', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      // Vérifier dans les lignes actives (pas les commentaires)
      final activeLines = sshdConfig
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('#'))
          .join('\n');
      expect(
        activeLines.contains('-cbc'),
        isFalse,
        reason:
            'La config sshd_config recommandée ne doit pas inclure de modes CBC '
            'dans les lignes actives (hors commentaires).',
      );
    });

    test('la config est non vide', () {
      final sshdConfig = roadmap.getRecommendedSshdConfig();
      expect(
        sshdConfig.isNotEmpty,
        isTrue,
        reason: 'La config sshd_config recommandée ne doit pas être vide.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 4 : checkServerPostQuantum
  // ═══════════════════════════════════════════════════════════════════════════

  group('checkServerPostQuantum — vérification serveur (placeholder)', () {
    test('retourne false pour un hôte valide (comportement pessimiste par défaut)',
        () async {
      final result = await roadmap.checkServerPostQuantum('192.168.1.1');
      expect(
        result,
        isFalse,
        reason:
            'Le placeholder doit retourner false par défaut (fail-safe). '
            'Mieux supposer qu\'il n\'y a pas de PQC que de supposer qu\'il y en a.',
      );
    });

    test('lève ArgumentError pour un hôte vide', () async {
      expect(
        () => roadmap.checkServerPostQuantum(''),
        throwsArgumentError,
        reason:
            'Un hôte vide doit être rejeté — il ne peut pas correspondre '
            'à une adresse IP ou un nom de domaine valide.',
      );
    });

    test('lève ArgumentError pour un hôte trop long', () async {
      // 254 caractères — dépasse la limite de 253 pour un nom de domaine
      final tooLong = 'a' * 254;
      expect(
        () => roadmap.checkServerPostQuantum(tooLong),
        throwsArgumentError,
        reason:
            'Un nom d\'hôte de plus de 253 caractères est invalide selon '
            'les spécifications DNS (RFC 1035).',
      );
    });

    test('lève ArgumentError pour un hôte avec des caractères dangereux', () async {
      // Tentative d'injection de commande
      expect(
        () => roadmap.checkServerPostQuantum('192.168.1.1; rm -rf /'),
        throwsArgumentError,
        reason:
            'Les caractères dangereux (;, espaces, etc.) doivent être rejetés '
            'pour éviter les injections de commandes.',
      );
    });

    test('accepte une adresse IPv4 valide', () async {
      // Ne doit pas lever d'exception
      expect(
        () => roadmap.checkServerPostQuantum('10.0.0.1'),
        returnsNormally,
        reason: 'Une adresse IPv4 valide doit être acceptée sans erreur.',
      );
    });

    test('accepte un nom de domaine valide', () async {
      expect(
        () => roadmap.checkServerPostQuantum('mon-serveur.exemple.com'),
        returnsNormally,
        reason: 'Un nom de domaine valide doit être accepté sans erreur.',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUPE 5 : generateExecutiveSummary
  // ═══════════════════════════════════════════════════════════════════════════

  group('generateExecutiveSummary — résumé exécutif', () {
    test('le résumé est non vide', () {
      final summary = roadmap.generateExecutiveSummary();
      expect(
        summary.isNotEmpty,
        isTrue,
        reason: 'Le résumé exécutif ne doit pas être vide.',
      );
    });

    test('le résumé mentionne curve25519', () {
      final summary = roadmap.generateExecutiveSummary();
      expect(
        summary.toLowerCase().contains('curve25519'),
        isTrue,
        reason: 'Le résumé doit indiquer l\'algorithme KEX actuel.',
      );
    });

    test('le résumé mentionne sntrup ou post-quantique', () {
      final summary = roadmap.generateExecutiveSummary();
      final mentionsPqc =
          summary.toLowerCase().contains('sntrup') ||
          summary.toLowerCase().contains('post-quantique') ||
          summary.toLowerCase().contains('quantique');
      expect(
        mentionsPqc,
        isTrue,
        reason:
            'Le résumé doit mentionner l\'objectif post-quantique '
            'pour sensibiliser les décideurs.',
      );
    });
  });
}
