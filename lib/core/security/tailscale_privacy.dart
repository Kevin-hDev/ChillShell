// =============================================================================
// FIX-023 — TailscalePrivacy + TailscaleMonitor
// Problème corrigé : GAP-023 — IPs et noms des peers Tailscale affichés en clair
// Catégorie : BH (Blue Hat — Surveillance comportementale)
// Priorité  : P3
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// L'interface ChillShell affiche en clair les adresses IP (100.64.x.y) et les
// noms des peers Tailscale dans les listes de connexion. Un attaquant ayant un
// accès visuel ou ayant compromis l'écran peut cartographier tout le réseau
// privé Tailscale de la victime (topology mapping).
//
// PROBLÈMES CUMULÉS :
//   1. IP complète visible (ex: 100.64.42.7) → localisation précise du peer
//   2. Nom du peer affiché sans troncature → divulgation de noms d'équipements
//   3. Aucune détection des connexions anormales (botnet, mouvement latéral)
//   4. Absence de vérification ACL → connexion non autorisée non détectée
//
// SOLUTION :
//   - TailscalePrivacy : masque IPs et noms, valide le range 100.64.0.0/10
//   - TailscaleMonitor : détecte les patterns d'attaque SSHStalker, AyySSHush,
//     les rafales, le mouvement latéral et les violations ACL
//
// INTÉGRATION :
//   Dans peer_list_widget.dart :
//     - Remplacer : Text(peer.ip)
//     - Par       : Text(TailscalePrivacy.maskIP(peer.ip))
//
//   Dans ssh_session_service.dart :
//     - À chaque nouvelle connexion : _monitor.checkForBotnetPatterns(events)
//     - Après liste de peers reçue : _monitor.verifyACLConsistency(allowed, connected)
// =============================================================================


// =============================================================================
// MODÈLES DE DONNÉES
// =============================================================================

/// Type d'événement de connexion SSH observé.
enum ConnectionEventType {
  /// Connexion établie avec succès.
  connected,

  /// Connexion refusée ou échouée.
  rejected,

  /// Session SSH fermée normalement.
  disconnected,

  /// Tentative de connexion (avant authentification).
  attempt,
}

/// Représente un événement de connexion SSH enregistré par le monitor.
///
/// Contient les deux extrémités de la connexion et le moment de l'événement.
/// Le champ [type] permet de distinguer les tentatives des connexions réelles.
class ConnectionEvent {
  /// Adresse IP source de la connexion.
  final String sourceIP;

  /// Adresse IP destination de la connexion.
  final String destIP;

  /// Moment précis de l'événement (UTC recommandé).
  final DateTime timestamp;

  /// Type d'événement (connexion, rejet, déconnexion, tentative).
  final ConnectionEventType type;

  const ConnectionEvent({
    required this.sourceIP,
    required this.destIP,
    required this.timestamp,
    required this.type,
  });

  @override
  String toString() =>
      'ConnectionEvent($type, src=$sourceIP, dst=$destIP, t=$timestamp)';
}

/// Contexte fourni lors d'une demande de révélation d'IP masquée.
///
/// La révélation d'une IP complète est un acte sensible : elle doit être
/// explicitement demandée, confirmée par l'utilisateur, et horodatée.
class RevealContext {
  /// Identifiant de l'entité qui demande la révélation (ex: "user", "admin").
  ///
  /// Ne doit jamais être une chaîne vide.
  final String requestedBy;

  /// Moment de la demande (pour audit).
  final DateTime requestedAt;

  /// L'utilisateur a explicitement confirmé vouloir voir l'IP complète.
  ///
  /// Cette confirmation doit venir d'un geste UI explicite (bouton "Voir IP"),
  /// jamais d'une déduction automatique.
  final bool userConfirmed;

  const RevealContext({
    required this.requestedBy,
    required this.requestedAt,
    required this.userConfirmed,
  });
}

// =============================================================================
// RÉSULTATS D'ANALYSE
// =============================================================================

/// Résultat d'une analyse de cohérence ACL.
class AclVerificationResult {
  /// La vérification a-t-elle détecté une anomalie ?
  final bool hasViolation;

  /// Pairs connectés qui ne figurent pas dans la liste autorisée.
  final List<String> unauthorizedPeers;

  /// Pairs autorisés mais non connectés (informatif, pas une alerte).
  final List<String> missingAuthorizedPeers;

  const AclVerificationResult({
    required this.hasViolation,
    required this.unauthorizedPeers,
    required this.missingAuthorizedPeers,
  });
}

/// Résultat d'une détection de mouvement latéral.
class LateralMovementResult {
  /// Un mouvement latéral potentiel a-t-il été détecté ?
  final bool detected;

  /// Description courte du pattern détecté (sans info interne).
  final String pattern;

  /// Événements impliqués dans la détection.
  final List<ConnectionEvent> suspiciousEvents;

  const LateralMovementResult({
    required this.detected,
    required this.pattern,
    required this.suspiciousEvents,
  });
}

/// Résultat d'une analyse de pattern botnet SSH.
class BotnetAnalysisResult {
  /// Un pattern botnet a-t-il été détecté ?
  final bool detected;

  /// Nom du pattern détecté (SSHStalker, AyySSHush, BurstPattern...).
  final String patternName;

  /// Gravité : 0 (aucune) à 3 (critique).
  final int severity;

  /// Nombre d'événements suspects trouvés.
  final int suspiciousEventCount;

  const BotnetAnalysisResult({
    required this.detected,
    required this.patternName,
    required this.severity,
    required this.suspiciousEventCount,
  });
}

// =============================================================================
// TAILSCALE PRIVACY — Masquage des IPs et noms
// =============================================================================

/// Gère la confidentialité des données réseau Tailscale dans l'interface.
///
/// Toutes les IPs affichées dans l'UI passent par [maskIP] avant rendu.
/// Les noms de peers passent par [maskPeerName].
/// La révélation d'une IP complète nécessite [shouldRevealIP] → true.
///
/// IMPORTANT : Le range Tailscale légal est 100.64.0.0/10 (RFC 6598).
/// Toute IP hors de ce range est rejetée pour éviter de masquer des IPs
/// publiques qui ne devraient pas être là.
class TailscalePrivacy {
  // Valeurs de la sous-réseau Tailscale (100.64.0.0/10)
  // Octet 1 : 100 (fixe)
  // Octet 2 : 64 à 127 (100 + 10 bits → /10 couvre 64 à 127 pour le 2ème octet)
  static const int _tailscaleOctet1 = 100;
  static const int _tailscaleMinOctet2 = 64;
  static const int _tailscaleMaxOctet2 = 127;

  // Longueur maximale d'un nom de peer avant troncature
  static const int _maxPeerNameDisplay = 12;

  // Masque affiché pour les octets cachés
  static const String _ipMask = '***';
  static const String _nameSuffix = '***';

  // Constructeur privé : cette classe ne s'instancie pas.
  TailscalePrivacy._();

  // ---------------------------------------------------------------------------
  // Validation du range Tailscale
  // ---------------------------------------------------------------------------

  /// Vérifie qu'une IP appartient au range Tailscale 100.64.0.0/10.
  ///
  /// Retourne [true] si l'IP est dans le range, [false] sinon.
  /// Retourne [false] pour toute IP malformée.
  static bool isInTailscaleRange(String ip) {
    final parts = _parseIPv4(ip);
    if (parts == null) return false;

    // Vérification range 100.64.0.0/10 :
    // Octet 1 == 100
    // Octet 2 dans [64, 127]
    return parts[0] == _tailscaleOctet1 &&
        parts[1] >= _tailscaleMinOctet2 &&
        parts[1] <= _tailscaleMaxOctet2;
  }

  // ---------------------------------------------------------------------------
  // Masquage d'IP
  // ---------------------------------------------------------------------------

  /// Masque une IP Tailscale pour l'affichage dans l'UI.
  ///
  /// Format de sortie : 100.64.***.***.
  ///
  /// Lance [ArgumentError] si l'IP n'est pas dans le range 100.64.0.0/10.
  /// Cette validation empêche de masquer des IPs hors Tailscale qui
  /// ne devraient pas être présentes dans ce contexte.
  ///
  /// Exemple :
  ///   maskIP('100.64.42.7') → '100.64.***.***'
  static String maskIP(String ip) {
    if (ip.isEmpty) {
      throw ArgumentError('L\'adresse IP ne peut pas être vide.');
    }

    final parts = _parseIPv4(ip);
    if (parts == null) {
      // Fail CLOSED : IP malformée → rejet, pas de masquage partiel
      throw ArgumentError('Format IPv4 invalide.');
    }

    if (!isInTailscaleRange(ip)) {
      // Fail CLOSED : hors range Tailscale → rejet explicite
      throw ArgumentError(
        'Adresse hors du range autorisé. Opération refusée.',
      );
    }

    // On conserve uniquement les deux premiers octets (100.64)
    // Les deux derniers sont remplacés par des masques
    return '${parts[0]}.${parts[1]}.$_ipMask.$_ipMask';
  }

  // ---------------------------------------------------------------------------
  // Révélation contrôlée d'IP
  // ---------------------------------------------------------------------------

  /// Vérifie si une IP peut être révélée dans le contexte donné.
  ///
  /// Conditions requises (toutes doivent être vraies) :
  ///   1. L'IP est dans le range Tailscale valide
  ///   2. Le demandeur est identifié (non vide)
  ///   3. L'utilisateur a explicitement confirmé
  ///
  /// Retourne [false] en cas de doute (fail CLOSED).
  static bool shouldRevealIP(String ip, RevealContext ctx) {
    // L'IP doit être valide et dans le range
    if (!isInTailscaleRange(ip)) return false;

    // Le demandeur doit être identifié
    if (ctx.requestedBy.trim().isEmpty) return false;

    // La confirmation utilisateur est obligatoire
    if (!ctx.userConfirmed) return false;

    return true;
  }

  // ---------------------------------------------------------------------------
  // Masquage de nom de peer
  // ---------------------------------------------------------------------------

  /// Masque un nom de peer Tailscale pour l'affichage.
  ///
  /// - Si le nom fait [_maxPeerNameDisplay] caractères ou moins : affiché tel quel.
  /// - Si le nom est plus long : [_maxPeerNameDisplay] premiers caractères + '***'.
  /// - Un nom vide est retourné tel quel (cas normal pour peers non nommés).
  ///
  /// Exemple :
  ///   maskPeerName('mon-serveur-linux-prod') → 'mon-serveur-***'
  ///   maskPeerName('laptop') → 'laptop'
  static String maskPeerName(String name) {
    if (name.isEmpty) return name;

    if (name.length <= _maxPeerNameDisplay) {
      return name;
    }

    // Troncature : [_maxPeerNameDisplay] premiers chars + suffixe masque
    return '${name.substring(0, _maxPeerNameDisplay)}$_nameSuffix';
  }

  // ---------------------------------------------------------------------------
  // Utilitaire privé : parsing IPv4
  // ---------------------------------------------------------------------------

  /// Parse une adresse IPv4 en liste de 4 entiers [0..255].
  ///
  /// Retourne [null] si le format est invalide.
  static List<int>? _parseIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;

    final octets = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return null;
      octets.add(n);
    }

    return octets;
  }
}

// =============================================================================
// TAILSCALE MONITOR — Détection des comportements anormaux
// =============================================================================

/// Surveille les patterns de connexion SSH pour détecter les comportements
/// anormaux sur le réseau Tailscale.
///
/// Patterns détectés :
///   - SSHStalker  : sessions multiples vers des IPs DIFFÉRENTES en peu de temps
///   - AyySSHush   : connexions depuis des IPs hors range Tailscale
///   - BurstPattern: rafale > [_maxConnectionsPerMinute] connexions en 1 minute
///
/// Mouvement latéral :
///   - Une source contactant plus de [_lateralMovementThreshold] destinations
///     distinctes dans la fenêtre de surveillance
///
/// ACL consistency :
///   - Vérification que les peers connectés sont dans la liste autorisée
class TailscaleMonitor {
  // Seuil de vitesse pour SSHStalker : X IPs différentes en Y secondes
  static const int _stalkerDistinctIPThreshold = 3;
  static const int _stalkerWindowSeconds = 60;

  // Seuil de rafale : max connexions par minute
  static const int _maxConnectionsPerMinute = 5;

  // Seuil mouvement latéral : destinations distinctes par source
  static const int _lateralMovementThreshold = 4;

  // Constructeur public
  const TailscaleMonitor();

  // ---------------------------------------------------------------------------
  // Détection botnet SSH
  // ---------------------------------------------------------------------------

  /// Analyse une liste d'événements pour détecter des patterns de botnet SSH.
  ///
  /// Retourne le premier pattern détecté par ordre de gravité décroissante.
  /// Si aucun pattern n'est trouvé, retourne un résultat avec detected=false.
  ///
  /// [events] : liste des événements récents (doit contenir les timestamps).
  BotnetAnalysisResult checkForBotnetPatterns(List<ConnectionEvent> events) {
    if (events.isEmpty) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }

    // 1. Vérifier AyySSHush (IPs hors range Tailscale) — gravité 3
    final ayySSHushResult = _detectAyySSHush(events);
    if (ayySSHushResult.detected) return ayySSHushResult;

    // 2. Vérifier SSHStalker (sessions multiples vers IPs différentes) — gravité 2
    final stalkerResult = _detectSSHStalker(events);
    if (stalkerResult.detected) return stalkerResult;

    // 3. Vérifier BurstPattern (rafale) — gravité 1
    final burstResult = _detectBurstPattern(events);
    if (burstResult.detected) return burstResult;

    return const BotnetAnalysisResult(
      detected: false,
      patternName: 'none',
      severity: 0,
      suspiciousEventCount: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Vérification cohérence ACL
  // ---------------------------------------------------------------------------

  /// Vérifie que les peers connectés respectent les ACLs définies.
  ///
  /// [allowedPeers] : liste des IPs autorisées par la politique ACL.
  /// [connectedPeers] : liste des IPs actuellement connectées.
  ///
  /// Toute IP connectée qui n'est pas dans [allowedPeers] est une violation.
  /// Fail CLOSED : en cas de liste vide ou null-like, traiter comme violation.
  AclVerificationResult verifyACLConsistency(
    List<String> allowedPeers,
    List<String> connectedPeers,
  ) {
    // Cas dégénéré : si allowedPeers est vide et qu'il y a des connexions
    // → toutes les connexions sont non autorisées (fail CLOSED)
    if (allowedPeers.isEmpty && connectedPeers.isNotEmpty) {
      return AclVerificationResult(
        hasViolation: true,
        unauthorizedPeers: List.unmodifiable(connectedPeers),
        missingAuthorizedPeers: const [],
      );
    }

    final allowedSet = Set<String>.from(allowedPeers);
    final connectedSet = Set<String>.from(connectedPeers);

    // Peers connectés mais non autorisés
    final unauthorized = connectedSet
        .where((peer) => !allowedSet.contains(peer))
        .toList();

    // Peers autorisés mais non connectés (informatif)
    final missingAuthorized = allowedSet
        .where((peer) => !connectedSet.contains(peer))
        .toList();

    return AclVerificationResult(
      hasViolation: unauthorized.isNotEmpty,
      unauthorizedPeers: List.unmodifiable(unauthorized),
      missingAuthorizedPeers: List.unmodifiable(missingAuthorized),
    );
  }

  // ---------------------------------------------------------------------------
  // Détection mouvement latéral
  // ---------------------------------------------------------------------------

  /// Détecte les tentatives de mouvement latéral dans le réseau Tailscale.
  ///
  /// Un mouvement latéral est suspect quand une même source IP contacte
  /// plus de [_lateralMovementThreshold] destinations distinctes.
  ///
  /// Les attaquants qui ont compromis un nœud cherchent à pivoter vers
  /// d'autres machines du réseau — ce pattern les trahit.
  LateralMovementResult checkForLateralMovement(
    List<ConnectionEvent> events,
  ) {
    if (events.isEmpty) {
      return const LateralMovementResult(
        detected: false,
        pattern: 'aucun événement',
        suspiciousEvents: [],
      );
    }

    // Regrouper les destinations par source
    final destinationsBySource = <String, Set<String>>{};
    for (final event in events) {
      destinationsBySource.putIfAbsent(event.sourceIP, () => {});
      destinationsBySource[event.sourceIP]!.add(event.destIP);
    }

    // Chercher les sources qui atteignent trop de destinations distinctes
    String? suspiciousSource;
    int maxDestinations = 0;

    for (final entry in destinationsBySource.entries) {
      if (entry.value.length > maxDestinations) {
        maxDestinations = entry.value.length;
        suspiciousSource = entry.key;
      }
    }

    if (suspiciousSource == null ||
        maxDestinations <= _lateralMovementThreshold) {
      return const LateralMovementResult(
        detected: false,
        pattern: 'aucun mouvement latéral détecté',
        suspiciousEvents: [],
      );
    }

    // Collecter les événements liés à la source suspecte
    final suspiciousEvents = events
        .where((e) => e.sourceIP == suspiciousSource)
        .toList();

    return LateralMovementResult(
      detected: true,
      pattern: 'source unique vers $maxDestinations destinations distinctes',
      suspiciousEvents: List.unmodifiable(suspiciousEvents),
    );
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées de détection
  // ---------------------------------------------------------------------------

  /// Détecte les connexions depuis des IPs hors range Tailscale (AyySSHush).
  BotnetAnalysisResult _detectAyySSHush(List<ConnectionEvent> events) {
    final suspicious = events
        .where((e) => !TailscalePrivacy.isInTailscaleRange(e.sourceIP))
        .toList();

    if (suspicious.isEmpty) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }

    return BotnetAnalysisResult(
      detected: true,
      patternName: 'AyySSHush',
      severity: 3,
      suspiciousEventCount: suspicious.length,
    );
  }

  /// Détecte les sessions multiples vers des IPs différentes en peu de temps (SSHStalker).
  BotnetAnalysisResult _detectSSHStalker(List<ConnectionEvent> events) {
    if (events.length < _stalkerDistinctIPThreshold) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }

    // Trier par timestamp pour analyse de fenêtre glissante
    final sorted = List<ConnectionEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Fenêtre glissante : chercher X IPs distinctes dans Y secondes
    for (int i = 0; i < sorted.length; i++) {
      final windowStart = sorted[i].timestamp;
      final windowEnd =
          windowStart.add(const Duration(seconds: _stalkerWindowSeconds));

      final inWindow = sorted
          .skip(i)
          .takeWhile((e) => e.timestamp.isBefore(windowEnd) ||
              e.timestamp.isAtSameMomentAs(windowEnd))
          .toList();

      final distinctDests = inWindow.map((e) => e.destIP).toSet();

      if (distinctDests.length >= _stalkerDistinctIPThreshold) {
        return BotnetAnalysisResult(
          detected: true,
          patternName: 'SSHStalker',
          severity: 2,
          suspiciousEventCount: inWindow.length,
        );
      }
    }

    return const BotnetAnalysisResult(
      detected: false,
      patternName: 'none',
      severity: 0,
      suspiciousEventCount: 0,
    );
  }

  /// Détecte une rafale de connexions (> [_maxConnectionsPerMinute] en 1 minute).
  BotnetAnalysisResult _detectBurstPattern(List<ConnectionEvent> events) {
    if (events.length <= _maxConnectionsPerMinute) {
      return const BotnetAnalysisResult(
        detected: false,
        patternName: 'none',
        severity: 0,
        suspiciousEventCount: 0,
      );
    }

    // Trier par timestamp
    final sorted = List<ConnectionEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Fenêtre glissante de 1 minute
    for (int i = 0; i < sorted.length; i++) {
      final windowStart = sorted[i].timestamp;
      final windowEnd = windowStart.add(const Duration(minutes: 1));

      final inWindow = sorted
          .skip(i)
          .takeWhile((e) => e.timestamp.isBefore(windowEnd) ||
              e.timestamp.isAtSameMomentAs(windowEnd))
          .toList();

      if (inWindow.length > _maxConnectionsPerMinute) {
        return BotnetAnalysisResult(
          detected: true,
          patternName: 'BurstPattern',
          severity: 1,
          suspiciousEventCount: inWindow.length,
        );
      }
    }

    return const BotnetAnalysisResult(
      detected: false,
      patternName: 'none',
      severity: 0,
      suspiciousEventCount: 0,
    );
  }
}
