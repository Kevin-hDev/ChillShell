// fix_014_ssh_algorithm_config.dart
// GAP-014 — Restriction des algorithmes SSH autorisés
// Priorité : P1 (Critique)
//
// Problème : dartssh2 accepte tous les algorithmes par défaut, y compris
// les algorithmes faibles : SHA-1, modes CBC, 3DES, ssh-dss (DSA 1024 bits).
// Ces algorithmes sont cassés ou déconseillés depuis des années.
//
// Solution : Configuration explicite des algorithmes autorisés, avec
// rejet de tous les algorithmes non listés.

// ignore_for_file: avoid_classes_with_only_static_members

import 'dart:io';

// ---------------------------------------------------------------------------
// Constantes de priorité pour les algorithmes
// ---------------------------------------------------------------------------

/// Algorithmes d'échange de clés autorisés, du plus fort au plus faible.
/// Seuls les algorithmes basés sur des courbes elliptiques modernes sont permis.
const List<String> _kAllowedKex = [
  // Post-quantique hybride — priorité maximale si disponible
  'sntrup761x25519-sha512@openssh.com',

  // Curve25519 — référence actuelle (RFC 8731)
  'curve25519-sha256',
  'curve25519-sha256@libssh.org',

  // ECDH NIST — acceptable mais inférieur à Curve25519
  // (non inclus ici pour rester conservatif)
];

/// Algorithmes de chiffrement symétrique autorisés.
/// Uniquement des chiffrements AEAD (Authenticated Encryption with Associated Data).
/// Les modes CBC et CTR sans authentification intégrée sont interdits.
const List<String> _kAllowedCiphers = [
  // ChaCha20-Poly1305 — recommandé, immunisé aux attaques par oracle de padding
  'chacha20-poly1305@openssh.com',

  // AES-GCM — AEAD, accéléré matériellement sur la plupart des CPUs
  'aes256-gcm@openssh.com',
  'aes128-gcm@openssh.com',

  // AES-CTR — fallback acceptable (pas AEAD, mais pas vulnérable au padding oracle)
  // NOTE : CTR nécessite un MAC séparé (ETM obligatoire avec ce mode)
  'aes256-ctr',
];

/// Algorithmes de code d'authentification de message (MAC) autorisés.
/// Uniquement les variantes ETM (Encrypt-then-MAC), qui sont sûres.
/// Les variantes MTE (MAC-then-Encrypt) comme hmac-sha2-256 standard sont exclues.
const List<String> _kAllowedMacs = [
  // SHA-2 avec ETM — recommandés
  'hmac-sha2-512-etm@openssh.com',
  'hmac-sha2-256-etm@openssh.com',
];

/// Algorithmes de clé hôte acceptés pour l'authentification du serveur.
const List<String> _kAllowedHostKeys = [
  // Ed25519 — clé courte, sécurité excellente (RFC 8709)
  'ssh-ed25519',

  // ECDSA P-521 — acceptable, courbe NIST
  'ecdsa-sha2-nistp521',

  // RSA avec SHA-512 — pour la compatibilité avec les anciens serveurs
  // NOTE : nécessite une clé RSA d'au moins 4096 bits pour être sûr
  'rsa-sha2-512',
];

/// Algorithmes explicitement interdits — conservés pour documentation et audit.
/// Ces algorithmes NE DOIVENT JAMAIS apparaître dans une connexion.
const List<String> kForbiddenAlgorithms = [
  // Chiffrements : modes CBC vulnérables au Lucky-13 et aux attaques par oracle
  'aes128-cbc',
  'aes192-cbc',
  'aes256-cbc',
  '3des-cbc',       // Triple DES : cassé, clé effective de 112 bits
  'blowfish-cbc',   // Blowfish : clé max 448 bits mais CBC vulnérable
  'cast128-cbc',
  'arcfour',        // RC4 : cassé depuis BEAST (2011)
  'arcfour128',
  'arcfour256',

  // MACs : SHA-1 cassé (collision démontrée par Google en 2017)
  'hmac-sha1',
  'hmac-sha1-96',
  'hmac-md5',
  'hmac-md5-96',

  // Clés hôte : DSA limité à 1024 bits, SHA-1 pour la signature
  'ssh-dss',

  // KEX : Diffie-Hellman avec petits groupes, vulnérable à Logjam
  'diffie-hellman-group1-sha1',   // 768-1024 bits — cassé
  'diffie-hellman-group14-sha1',  // SHA-1 — déprécié
];

// ---------------------------------------------------------------------------
// Classe principale de configuration
// ---------------------------------------------------------------------------

/// Configuration des algorithmes SSH autorisés pour dartssh2.
///
/// Usage :
/// ```dart
/// final config = SSHAlgorithmConfig();
/// // Passer config.allowedKex, config.allowedCiphers, etc. à SSHAlgorithms
/// ```
class SSHAlgorithmConfig {
  // ---------------------------------------------------------------------------
  // Listes d'algorithmes autorisés (accessibles en lecture seule)
  // ---------------------------------------------------------------------------

  /// Algorithmes d'échange de clés autorisés (du plus fort au plus faible).
  List<String> get allowedKex => List.unmodifiable(_kAllowedKex);

  /// Chiffrements symétriques autorisés (AEAD en priorité).
  List<String> get allowedCiphers => List.unmodifiable(_kAllowedCiphers);

  /// MACs autorisés (uniquement variantes ETM).
  List<String> get allowedMacs => List.unmodifiable(_kAllowedMacs);

  /// Algorithmes de clé hôte autorisés.
  List<String> get allowedHostKeys => List.unmodifiable(_kAllowedHostKeys);

  /// Algorithmes explicitement interdits (pour documentation et audit).
  List<String> get forbiddenAlgorithms => List.unmodifiable(kForbiddenAlgorithms);

  // ---------------------------------------------------------------------------
  // Constante de sécurité critique
  // ---------------------------------------------------------------------------

  /// La vérification de la clé hôte ne doit JAMAIS être désactivée.
  /// Mettre cette valeur à true = Man-in-the-Middle trivial.
  // ignore: prefer_final_fields
  static const bool disableHostkeyVerification = false;

  // ---------------------------------------------------------------------------
  // Méthode de validation des algorithmes serveur
  // ---------------------------------------------------------------------------

  /// Vérifie les algorithmes proposés par un serveur SSH et retourne
  /// une liste d'avertissements si des algorithmes faibles sont détectés.
  ///
  /// [serverAlgos] : liste des algorithmes proposés par le serveur
  ///                 (extrait du message SSH_MSG_KEXINIT).
  ///
  /// Retourne une liste de chaînes d'avertissement, vide si tout est bon.
  List<String> validateServerAlgorithms(List<String> serverAlgos) {
    final warnings = <String>[];

    if (serverAlgos.isEmpty) {
      return warnings;
    }

    // Normaliser en minuscules pour la comparaison
    final serverAlgosLower = serverAlgos.map((a) => a.toLowerCase()).toList();
    final forbiddenLower =
        kForbiddenAlgorithms.map((a) => a.toLowerCase()).toList();

    for (final algo in serverAlgosLower) {
      if (forbiddenLower.contains(algo)) {
        // Retrouver la casse originale pour le message
        final originalAlgo =
            serverAlgos[serverAlgosLower.indexOf(algo)];
        warnings.add(
          'AVERTISSEMENT : Le serveur propose un algorithme faible : '
          '"$originalAlgo". Cet algorithme est dans la liste interdite.',
        );
      }
    }

    // Vérification spécifique : le serveur propose-t-il au moins un KEX fort ?
    final hasStrongKex = _kAllowedKex
        .any((kex) => serverAlgosLower.contains(kex.toLowerCase()));
    if (!hasStrongKex) {
      warnings.add(
        'AVERTISSEMENT CRITIQUE : Le serveur ne propose aucun algorithme '
        'd\'échange de clés considéré comme fort. '
        'Algorithmes forts attendus : ${_kAllowedKex.join(", ")}',
      );
    }

    // Vérification spécifique : présence de sha-1 dans les MACs
    final hasSha1Mac = serverAlgosLower
        .any((a) => a.contains('sha1') || a.contains('sha-1'));
    if (hasSha1Mac) {
      warnings.add(
        'AVERTISSEMENT : Le serveur propose des MACs basés sur SHA-1. '
        'SHA-1 est cassé depuis 2017 (attaque SHAttered de Google).',
      );
    }

    // Vérification spécifique : présence de modes CBC
    final hasCbc = serverAlgosLower.any((a) => a.contains('-cbc'));
    if (hasCbc) {
      warnings.add(
        'AVERTISSEMENT : Le serveur propose des chiffrements en mode CBC. '
        'Les modes CBC sont vulnérables aux attaques Lucky-13 et BEAST.',
      );
    }

    return warnings;
  }

  // ---------------------------------------------------------------------------
  // Méthode de log de la configuration (pour audit)
  // ---------------------------------------------------------------------------

  /// Affiche la configuration d'algorithmes active dans stderr.
  /// À appeler au démarrage pour laisser une trace d'audit.
  void logConfiguration() {
    stderr.writeln('[SSHAlgorithmConfig] Configuration des algorithmes SSH :');
    stderr.writeln('  KEX autorisés    : ${_kAllowedKex.join(", ")}');
    stderr.writeln('  Chiffrements     : ${_kAllowedCiphers.join(", ")}');
    stderr.writeln('  MACs             : ${_kAllowedMacs.join(", ")}');
    stderr.writeln('  Clés hôte        : ${_kAllowedHostKeys.join(", ")}');
    stderr.writeln('  Algos interdits  : ${kForbiddenAlgorithms.length} entrées');
    stderr.writeln(
      '  Vérif. clé hôte  : ACTIVÉE (disableHostkeyVerification = false)',
    );
  }

  // ---------------------------------------------------------------------------
  // Vérification d'intégrité de la configuration
  // ---------------------------------------------------------------------------

  /// Vérifie que la configuration respecte les contraintes minimales de sécurité.
  /// Lève une [StateError] si une contrainte est violée.
  ///
  /// À appeler une fois au démarrage de l'application.
  void assertSafeConfiguration() {
    // Règle 1 : Aucun algorithme interdit ne doit être dans les listes autorisées
    for (final forbidden in kForbiddenAlgorithms) {
      final forbiddenLower = forbidden.toLowerCase();

      if (_kAllowedKex.map((e) => e.toLowerCase()).contains(forbiddenLower)) {
        throw StateError(
          '[SSHAlgorithmConfig] ERREUR CRITIQUE : '
          'L\'algorithme interdit "$forbidden" est dans allowedKex !',
        );
      }
      if (_kAllowedCiphers
          .map((e) => e.toLowerCase())
          .contains(forbiddenLower)) {
        throw StateError(
          '[SSHAlgorithmConfig] ERREUR CRITIQUE : '
          'L\'algorithme interdit "$forbidden" est dans allowedCiphers !',
        );
      }
      if (_kAllowedMacs.map((e) => e.toLowerCase()).contains(forbiddenLower)) {
        throw StateError(
          '[SSHAlgorithmConfig] ERREUR CRITIQUE : '
          'L\'algorithme interdit "$forbidden" est dans allowedMacs !',
        );
      }
    }

    // Règle 2 : chacha20-poly1305 doit être le premier chiffrement
    if (_kAllowedCiphers.isEmpty ||
        _kAllowedCiphers.first != 'chacha20-poly1305@openssh.com') {
      throw StateError(
        '[SSHAlgorithmConfig] ERREUR : chacha20-poly1305@openssh.com '
        'doit être le premier chiffrement dans allowedCiphers.',
      );
    }

    // Règle 3 : La vérification de clé hôte doit rester activée
    if (disableHostkeyVerification) {
      throw StateError(
        '[SSHAlgorithmConfig] ERREUR CRITIQUE : '
        'disableHostkeyVerification ne peut jamais être true !',
      );
    }
  }
}
