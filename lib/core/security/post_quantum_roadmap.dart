// fix_016_post_quantum_roadmap.dart
// GAP-016 — Documentation et préparation à la cryptographie post-quantique
// Priorité : P3 (Planification future)
//
// Problème : Ed25519 et Curve25519 sont vulnérables à l'algorithme de Shor
// exécuté sur un ordinateur quantique suffisamment puissant. dartssh2 ne
// supporte pas encore les algorithmes post-quantiques (ML-KEM / sntrup761x25519).
//
// Stratégie "harvest now, decrypt later" : des adversaires étatiques peuvent
// enregistrer aujourd'hui les sessions SSH chiffrées pour les déchiffrer demain
// quand les ordinateurs quantiques seront disponibles.
//
// Solution : Roadmap documentée + configuration serveur recommandée +
// placeholder de vérification de support serveur.

// ---------------------------------------------------------------------------
// Classe de statut post-quantique
// ---------------------------------------------------------------------------

/// Représente l'état actuel du support post-quantique dans ChillShell.
class PostQuantumStatus {
  /// Algorithme d'échange de clés actuellement utilisé.
  final String currentKex;

  /// Algorithme cible une fois le support disponible dans dartssh2.
  final String targetKex;

  /// dartssh2 supporte-t-il l'algorithme cible actuellement ?
  /// false = en attente d'une mise à jour de dartssh2.
  final bool dartssh2Support;

  /// OpenSSH supporte-t-il l'algorithme cible côté serveur ?
  /// true depuis OpenSSH 9.0 (mars 2022).
  final bool opensshSupport;

  /// Estimation du délai avant migration possible.
  final String timelineEstimate;

  const PostQuantumStatus({
    required this.currentKex,
    required this.targetKex,
    required this.dartssh2Support,
    required this.opensshSupport,
    required this.timelineEstimate,
  });
}

// ---------------------------------------------------------------------------
// Classe principale de roadmap
// ---------------------------------------------------------------------------

/// Roadmap de migration vers la cryptographie post-quantique pour ChillShell.
///
/// Contexte NIST :
/// - 2022 : NIST a sélectionné CRYSTALS-Kyber (ML-KEM) comme standard
///          pour l'encapsulation de clés post-quantique (FIPS 203)
/// - 2024 : Finalisation de FIPS 203 (ML-KEM), FIPS 204 (ML-DSA), FIPS 205
/// - OpenSSH 9.0 : Intégration de sntrup761x25519-sha512@openssh.com
/// - dartssh2 : Pas encore de support (à surveiller)
///
/// Modèle de menace :
/// - Adversaires étatiques enregistrent les sessions SSH aujourd'hui
/// - Un ordinateur quantique à ~4000 qubits logiques casserait RSA-2048
/// - Les estimations actuelles : 10-20 ans, mais accélération possible
/// - Les données sensibles doivent être protégées DÈS MAINTENANT
class PostQuantumRoadmap {
  // ---------------------------------------------------------------------------
  // État actuel
  // ---------------------------------------------------------------------------

  /// Retourne l'état actuel du support post-quantique dans ChillShell.
  PostQuantumStatus getCurrentStatus() {
    return const PostQuantumStatus(
      // Curve25519 est l'état de l'art classique actuel
      currentKex: 'curve25519-sha256',

      // sntrup761x25519 est l'hybride post-quantique prioritaire
      // Il combine un algo post-quantique (sntrup761) avec Curve25519 :
      // même si l'un des deux est cassé, la sécurité de l'autre reste entière
      targetKex: 'sntrup761x25519-sha512@openssh.com',

      // dartssh2 ne supporte pas encore sntrup761x25519 (à vérifier à chaque
      // mise à jour de la bibliothèque)
      dartssh2Support: false,

      // OpenSSH 9.0+ (mars 2022) supporte sntrup761x25519 côté serveur
      // La plupart des distributions Linux récentes ont OpenSSH >= 9.0
      opensshSupport: true,

      // Surveillance active recommandée — pas de blocage pour l'instant
      timelineEstimate:
          'Surveiller dartssh2 pour le support ML-KEM / sntrup761x25519. '
          'Réévaluer à chaque release mineure de dartssh2.',
    );
  }

  // ---------------------------------------------------------------------------
  // Recommandations
  // ---------------------------------------------------------------------------

  /// Retourne la liste des recommandations concrètes pour la migration PQC.
  List<String> getRecommendations() {
    return const [
      // Recommandation 1 : Surveillance active de dartssh2
      'Surveiller les releases de dartssh2 sur GitHub pour l\'ajout du support '
          'de sntrup761x25519-sha512@openssh.com. S\'abonner aux notifications '
          'de releases sur https://github.com/TerminalStudio/dartssh2/releases.',

      // Recommandation 2 : Configuration serveur dès maintenant
      'Configurer le serveur SSH avec sntrup761x25519 en priorité — cet algorithme '
          'est déjà supporté par OpenSSH 9.0+ (disponible sur Ubuntu 22.04+, '
          'Debian 12+, Fedora 36+). Les serveurs correctement configurés '
          'bénéficieront immédiatement du PQC dès que dartssh2 le supportera.',

      // Recommandation 3 : Migration des clés
      'Planifier la migration des clés d\'hôte SSH vers des algorithmes '
          'post-quantiques. Ed25519 reste sûr à court terme (résistant aux '
          'ordinateurs quantiques actuels), mais la migration vers ML-DSA '
          '(FIPS 204) devra être planifiée sur 5-10 ans.',

      // Recommandation 4 : ML-KEM (RFC 9370 draft)
      'Surveiller l\'évolution de mlkem768x25519-sha256 (hybride ML-KEM + '
          'Curve25519) — ce schéma hybride sera probablement le remplaçant '
          'à long terme de sntrup761x25519. Référence : RFC 9370 (draft) et '
          'IETF draft-kampanakis-curdle-ssh-pq-ke.',

      // Recommandation 5 : Chiffrement de stockage
      'Évaluer si les clés privées SSH stockées localement (id_ed25519) doivent '
          'être re-chiffrées avec un algorithme PQC pour le stockage au repos. '
          'Pour l\'instant, AES-256 (classique) reste sûr contre les ordi quantiques '
          '(l\'algorithme de Grover réduit la sécurité de 256 à 128 bits — '
          'encore largement suffisant).',
    ];
  }

  // ---------------------------------------------------------------------------
  // Configuration sshd_config recommandée
  // ---------------------------------------------------------------------------

  /// Retourne une configuration sshd_config optimisée pour la sécurité maximale
  /// et la préparation post-quantique.
  ///
  /// À appliquer sur le serveur SSH cible de ChillShell.
  /// Compatible avec OpenSSH 9.0+.
  String getRecommendedSshdConfig() {
    return '''# Configuration SSH serveur recommandée — ChillShell
# Compatible avec OpenSSH 9.0+
# Dernière révision : 2026-02-19

# ──────────────────────────────────────────────────────────
# ÉCHANGE DE CLÉS — Post-quantique hybride en priorité
# ──────────────────────────────────────────────────────────
# sntrup761x25519 : hybride post-quantique (sntrup761 + Curve25519)
# Si l'un des deux est cassé, l'autre protège toujours
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256

# ──────────────────────────────────────────────────────────
# CHIFFREMENTS — AEAD uniquement (pas de CBC, pas de CTR seul)
# ──────────────────────────────────────────────────────────
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

# ──────────────────────────────────────────────────────────
# MACs — Encrypt-then-MAC uniquement (variantes ETM)
# ──────────────────────────────────────────────────────────
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# ──────────────────────────────────────────────────────────
# CLÉS HÔTE — Ed25519 uniquement (pas de RSA, pas de DSA)
# ──────────────────────────────────────────────────────────
HostKeyAlgorithms ssh-ed25519
PubkeyAcceptedAlgorithms ssh-ed25519

# ──────────────────────────────────────────────────────────
# AUTHENTIFICATION — Clés publiques uniquement
# ──────────────────────────────────────────────────────────
# Désactiver l'authentification par mot de passe
PasswordAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password

# ──────────────────────────────────────────────────────────
# DURCISSEMENT GÉNÉRAL
# ──────────────────────────────────────────────────────────
# Délai de grâce pour l'authentification (30 secondes)
LoginGraceTime 30
# Nombre maximum de tentatives d'authentification
MaxAuthTries 3
# Sessions simultanées limitées
MaxSessions 5
# Désactiver le forwarding X11 (surface d'attaque inutile)
X11Forwarding no
# Désactiver le forwarding TCP (sauf si nécessaire)
AllowTcpForwarding no
# Bannière de connexion
# Banner /etc/ssh/banner.txt
''';
  }

  // ---------------------------------------------------------------------------
  // Vérification de support serveur (placeholder)
  // ---------------------------------------------------------------------------

  /// Vérifie si le serveur SSH cible supporte les algorithmes post-quantiques.
  ///
  /// PLACEHOLDER : Cette méthode simule la vérification.
  /// Une implémentation complète nécessiterait :
  /// 1. Un handshake SSH partiel pour récupérer SSH_MSG_KEXINIT
  /// 2. Parsing des algorithmes proposés par le serveur
  /// 3. Recherche de sntrup761x25519-sha512@openssh.com dans la liste
  ///
  /// [host] : adresse du serveur SSH à vérifier
  ///
  /// Retourne true si le serveur supporte un algorithme post-quantique.
  Future<bool> checkServerPostQuantum(String host) async {
    // Validation basique de l'entrée pour éviter les injections
    if (host.isEmpty || host.length > 253) {
      throw ArgumentError(
        '[PostQuantumRoadmap] Hôte invalide : doit être entre 1 et 253 caractères.',
      );
    }

    // Vérifier que l'hôte ne contient pas de caractères dangereux
    // (protection contre les injections de commandes)
    final validHostPattern = RegExp(r'^[a-zA-Z0-9.\-\[\]:]+$');
    if (!validHostPattern.hasMatch(host)) {
      throw ArgumentError(
        '[PostQuantumRoadmap] Hôte invalide : caractères non autorisés détectés.',
      );
    }

    // TODO : Implémenter la vérification réelle quand dartssh2 expose
    // les algorithmes proposés par le serveur dans le handshake initial.
    //
    // Implémentation future :
    // ```dart
    // final socket = await SSHSocket.connect(host, 22);
    // final kexInit = await socket.getServerKexInit();
    // return kexInit.kexAlgorithms.contains('sntrup761x25519-sha512@openssh.com');
    // ```

    // Pour l'instant, retourner false (pessimiste = sécurisé par défaut)
    // Fail-safe : mieux supposer qu'il n'y a pas de PQC que de supposer qu'il y en a
    return Future.value(false);
  }

  // ---------------------------------------------------------------------------
  // Résumé exécutif
  // ---------------------------------------------------------------------------

  /// Génère un résumé de la situation post-quantique pour les non-techniciens.
  String generateExecutiveSummary() {
    final status = getCurrentStatus();
    final buffer = StringBuffer();

    buffer.writeln('RÉSUMÉ EXÉCUTIF — Sécurité Post-Quantique ChillShell');
    buffer.writeln('Date : ${DateTime.now().toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('SITUATION ACTUELLE :');
    buffer.writeln('  Algorithme actif  : ${status.currentKex}');
    buffer.writeln('  Objectif futur    : ${status.targetKex}');
    buffer.writeln(
      '  Support dartssh2  : ${status.dartssh2Support ? "OUI" : "NON (en attente)"}',
    );
    buffer.writeln(
      '  Support serveur   : ${status.opensshSupport ? "OUI (OpenSSH 9.0+)" : "NON"}',
    );
    buffer.writeln('');
    buffer.writeln('RISQUE IMMÉDIAT : FAIBLE');
    buffer.writeln('  Les ordinateurs quantiques capables de casser Curve25519');
    buffer.writeln('  sont estimés à 10-20 ans de distance.');
    buffer.writeln('  Cependant, les données enregistrées aujourd\'hui pourraient');
    buffer.writeln('  être déchiffrées dans le futur ("harvest now, decrypt later").');
    buffer.writeln('');
    buffer.writeln('ACTION REQUISE :');
    buffer.writeln('  1. Configurer le serveur SSH avec sntrup761x25519 (dès maintenant)');
    buffer.writeln('  2. Surveiller les releases de dartssh2 pour le support PQC');
    buffer.writeln('  3. Réévaluer dans 6 mois ou à la prochaine version de dartssh2');

    return buffer.toString();
  }
}
