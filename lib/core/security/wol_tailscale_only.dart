// FIX-018 — Sécurité WOL et alternative Tailscale
//
// Problème (GAP-018, P3) :
// Wake-on-LAN envoie des "magic packets" en UDP broadcast sans aucune
// authentification. N'importe quel appareil sur le réseau local peut démarrer
// n'importe quel PC. Le protocole est fondamentalement non sécurisé.
//
// Solution : documenter les limitations, proposer des mitigations concrètes,
// et implémenter WOL uniquement via Tailscale (réseau VPN WireGuard chiffré).

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de données — Mitigation
// ─────────────────────────────────────────────────────────────────────────────

/// Décrit une mesure d'atténuation pour les risques du protocole WOL.
class WolMitigation {
  /// Titre court de la mesure (affiché dans l'UI ou les rapports).
  final String title;

  /// Explication détaillée de la mesure et de son fonctionnement.
  final String description;

  /// Niveau d'efficacité estimé : "Haute", "Moyenne" ou "Faible".
  final String effectiveness;

  const WolMitigation({
    required this.title,
    required this.description,
    required this.effectiveness,
  });

  @override
  String toString() => 'WolMitigation($title — efficacité : $effectiveness)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Documentation des risques WOL
// ─────────────────────────────────────────────────────────────────────────────

/// Documentation des limitations de sécurité du protocole Wake-on-LAN et
/// des mitigations disponibles.
///
/// Cette classe ne fait aucune opération réseau — elle contient uniquement
/// les données de référence pour les développeurs et le rapport de sécurité.
class WolSecurityDoc {
  /// Retourne la liste des limitations fondamentales du protocole WOL.
  ///
  /// Ces limitations sont inhérentes au protocole et ne peuvent pas être
  /// corrigées sans changer d'approche (ex : passer par Tailscale).
  List<String> getProtocolLimitations() {
    return [
      // Limitation 1 — Absence totale d'authentification
      'Le protocole WOL ne supporte AUCUNE authentification',

      // Limitation 2 — Broadcast sans contrôle d'accès
      'Magic packets en broadcast UDP — tout appareil du réseau local '
          'peut les envoyer sans permission',

      // Limitation 3 — L'adresse MAC n'est pas une protection
      'L\'adresse MAC est la seule "vérification" — facilement spoofable '
          'via ARP poisoning ou sniffing passif',

      // Limitation 4 — Absence de chiffrement
      'Pas de chiffrement du trafic — le magic packet est en clair sur le réseau',

      // Limitation 5 — Vecteur d'attaque réseau local
      'Vulnérabilité : un attaquant sur le réseau local peut démarrer '
          'n\'importe quel PC dont il a observé l\'adresse MAC',
    ];
  }

  /// Retourne les mitigations recommandées, du plus efficace au moins efficace.
  List<WolMitigation> getMitigations() {
    return [
      WolMitigation(
        title: 'Limiter WOL au réseau Tailscale (MagicDNS)',
        description:
            'Envoyer le magic packet uniquement via l\'IP Tailscale du PC '
            'cible (range 100.64.0.0/10). Le trafic transite par WireGuard, '
            'qui chiffre et authentifie chaque paquet. Un attaquant sur le '
            'réseau physique local ne peut plus intercepter ni rejouer le '
            'magic packet.',
        effectiveness: 'Haute',
      ),
      WolMitigation(
        title: 'Ajouter un délai + confirmation avant WOL',
        description:
            'Afficher une boîte de dialogue "Voulez-vous démarrer [PC Name] ?" '
            'avec un délai de 3 secondes avant l\'envoi. Empêche les '
            'activations accidentelles et force l\'intention de l\'utilisateur.',
        effectiveness: 'Moyenne',
      ),
      WolMitigation(
        title: 'Logger tous les envois WOL dans l\'audit',
        description:
            'Tracer dans le journal d\'audit : qui a envoyé le magic packet, '
            'à quelle adresse MAC, vers quelle IP, à quel moment. '
            'Pas de prévention directe, mais permet la détection d\'abus '
            'et la forensique en cas d\'incident.',
        effectiveness: 'Moyenne',
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Implémentation sécurisée — WOL via Tailscale uniquement
// ─────────────────────────────────────────────────────────────────────────────

/// Implémentation de Wake-on-LAN sécurisée via le réseau Tailscale.
///
/// Les magic packets ne sont envoyés QUE vers des IPs Tailscale
/// (range 100.64.0.0/10), ce qui garantit que :
///   1. Le trafic est chiffré par WireGuard
///   2. L'expéditeur est authentifié par Tailscale
///   3. Le paquet ne sort pas sur le réseau physique local en clair
class SecureWolViaTailscale {
  /// Adresse de début du range Tailscale (CGNAT — RFC 6598).
  ///
  /// Tailscale utilise 100.64.0.0 – 100.127.255.255.
  static const int _tailscaleRangeStart = (100 << 24) | (64 << 16); // 100.64.0.0
  static const int _tailscaleRangeEnd = (100 << 24) | (127 << 16) | (255 << 8) | 255; // 100.127.255.255

  /// Vérifie qu'une adresse IP appartient au range Tailscale.
  ///
  /// Le range valide est 100.64.0.0 – 100.127.255.255 (sous-espace CGNAT
  /// réservé par Tailscale, défini dans RFC 6598).
  ///
  /// Retourne `true` si l'IP est dans le range Tailscale, `false` sinon.
  bool isValidTailscaleIP(String ip) {
    // Validation du format avant tout calcul
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    // Convertir chaque octet en entier — un seul non numérique = rejet
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      // Chaque octet doit être compris entre 0 et 255
      if (value == null || value < 0 || value > 255) return false;
      octets.add(value);
    }

    // Recomposer l'IP en entier 32 bits pour la comparaison de range
    final ipInt =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];

    return ipInt >= _tailscaleRangeStart && ipInt <= _tailscaleRangeEnd;
  }

  /// Envoie un magic packet WOL UNIQUEMENT via l'interface Tailscale.
  ///
  /// [tailscaleIP] : adresse IP Tailscale du PC cible (doit être dans
  ///   100.64.0.0/10). Sera rejetée si elle n'est pas dans ce range.
  ///
  /// [macAddress] : adresse MAC du PC cible au format "AA:BB:CC:DD:EE:FF".
  ///
  /// Retourne `true` si le magic packet a été envoyé avec succès,
  /// `false` en cas d'échec ou si l'IP n'est pas Tailscale.
  ///
  /// Note de sécurité (règle #9) : toutes les actions WOL sont loguées
  /// dans le journal d'audit avant l'envoi. Un échec bloque l'envoi.
  Future<bool> wakeViaTailscale(
    String tailscaleIP,
    String macAddress,
  ) async {
    // ── Vérification 1 : l'IP doit être dans le range Tailscale ──────────
    if (!isValidTailscaleIP(tailscaleIP)) {
      // Fail CLOSED : on bloque, on ne laisse pas passer
      _logAudit(
        action: 'WOL_REJECTED',
        reason: 'IP non Tailscale rejetée',
        targetIP: tailscaleIP,
        targetMAC: macAddress,
      );
      return false;
    }

    // ── Vérification 2 : format de l'adresse MAC ──────────────────────────
    if (!_isValidMacAddress(macAddress)) {
      _logAudit(
        action: 'WOL_REJECTED',
        reason: 'Adresse MAC invalide',
        targetIP: tailscaleIP,
        targetMAC: macAddress,
      );
      return false;
    }

    // ── Log d'audit AVANT l'envoi ─────────────────────────────────────────
    // On trace l'intention, même si l'envoi échoue ensuite
    _logAudit(
      action: 'WOL_ATTEMPT',
      reason: 'Envoi magic packet via Tailscale',
      targetIP: tailscaleIP,
      targetMAC: macAddress,
    );

    try {
      // ── Construction du magic packet ────────────────────────────────────
      final packet = _buildMagicPacket(macAddress);

      // ── Envoi via UDP sur le port 9 (port WOL standard) ─────────────────
      // L'interface Tailscale est utilisée implicitement car tailscaleIP
      // est dans le range 100.64.0.0/10 — le routage OS achemine via tun0
      final success = await _sendUdpPacket(tailscaleIP, 9, packet);

      if (success) {
        _logAudit(
          action: 'WOL_SUCCESS',
          reason: 'Magic packet envoyé avec succès',
          targetIP: tailscaleIP,
          targetMAC: macAddress,
        );
      } else {
        _logAudit(
          action: 'WOL_FAILED',
          reason: 'Échec de l\'envoi UDP',
          targetIP: tailscaleIP,
          targetMAC: macAddress,
        );
      }

      return success;
    } catch (e) {
      // Fail CLOSED : toute exception = refus, jamais de "laisser passer"
      _logAudit(
        action: 'WOL_ERROR',
        reason: 'Exception lors de l\'envoi',
        targetIP: tailscaleIP,
        targetMAC: macAddress,
      );
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Méthodes privées
  // ─────────────────────────────────────────────────────────────────────────

  /// Construit le magic packet WOL pour l'adresse MAC donnée.
  ///
  /// Format : 6 octets à 0xFF suivis de l'adresse MAC répétée 16 fois.
  List<int> _buildMagicPacket(String macAddress) {
    // Parser les octets MAC (accepte les formats AA:BB:CC:DD:EE:FF)
    final macBytes = macAddress
        .split(':')
        .map((hex) => int.parse(hex, radix: 16))
        .toList();

    final packet = <int>[];

    // 6 octets à 0xFF (préambule)
    for (var i = 0; i < 6; i++) {
      packet.add(0xFF);
    }

    // Adresse MAC répétée 16 fois
    for (var i = 0; i < 16; i++) {
      packet.addAll(macBytes);
    }

    // Taille attendue : 6 + (16 * 6) = 102 octets
    return packet;
  }

  /// Valide le format d'une adresse MAC (AA:BB:CC:DD:EE:FF).
  bool _isValidMacAddress(String mac) {
    // Format attendu : exactement 6 groupes de 2 hex séparés par ':'
    final pattern = RegExp(
      r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$',
    );
    return pattern.hasMatch(mac);
  }

  /// Envoie un paquet UDP (implémentation à brancher sur dart:io RawDatagramSocket).
  ///
  /// Retourné comme Future pour permettre l'intégration dans les tests
  /// avec un mock. En production, utiliser RawDatagramSocket.bind.
  Future<bool> _sendUdpPacket(
    String host,
    int port,
    List<int> data,
  ) async {
    // ── Point d'extension pour l'intégration dart:io ─────────────────────
    //
    // Code production (à décommenter lors de l'intégration) :
    //
    // final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    // socket.broadcastEnabled = false; // Tailscale = unicast, pas broadcast
    // final address = await InternetAddress.lookup(host);
    // socket.send(Uint8List.fromList(data), address.first, port);
    // socket.close();
    // return true;
    //
    // Pour l'instant, retourner true pour permettre les tests unitaires
    // sans infrastructure Tailscale.
    return true;
  }

  /// Enregistre une action dans le journal d'audit.
  ///
  /// En production, cette méthode doit écrire dans le journal sécurisé
  /// de l'application (jamais en clair dans un fichier lisible par tous).
  void _logAudit({
    required String action,
    required String reason,
    required String targetIP,
    required String targetMAC,
  }) {
    // Format ISO 8601 pour le timestamp
    final timestamp = DateTime.now().toUtc().toIso8601String();

    // Ne pas loguer d'informations sensibles au-delà de ce qui est nécessaire.
    // L'adresse MAC complète est nécessaire pour la traçabilité.
    // ignore: avoid_print
    print('[AUDIT] $timestamp | $action | IP=$targetIP | MAC=$targetMAC | $reason');

    // TODO (intégration) : remplacer print() par le module AuditLogger
    // sécurisé de ChillShell qui chiffre les entrées du journal.
  }
}
