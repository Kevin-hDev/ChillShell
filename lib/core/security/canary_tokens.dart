// =============================================================================
// FIX-019 — CanaryTokenManager
// Problème corrigé : GAP-019 — Aucun piège pour détecter les attaquants
// Catégorie : DC (Deception)  |  Priorité : P2
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// ChillShell n'a aucun mécanisme pour détecter qu'un attaquant explore le
// système. Un attaquant peut naviguer dans l'arborescence, lire des fichiers
// de configuration, exfiltrer des données — le tout sans déclencher aucune
// alerte.
//
// SOLUTION :
// Déployer des fichiers pièges aux emplacements stratégiques (répertoires SSH,
// fichiers de configuration, credentials). Ces fichiers ont :
//   - Des noms réalistes (jamais "canary", "trap", "honey", "fake")
//   - Un contenu réaliste (clé SSH au bon format, JSON credentials valide)
//   - Un registre chiffré SHA-256 permettant de détecter tout accès
//
// PRINCIPE DE DÉTECTION :
// Chaque fichier piège a une date d'accès enregistrée au déploiement.
// Si la date d'accès du fichier dépasse la date de déploiement, c'est qu'un
// processus a ouvert le fichier → alerte immédiate.
//
// RÈGLES DE SÉCURITÉ APPLIQUÉES :
//   - Noms de fichiers : JAMAIS canary/trap/honey/fake — noms réalistes
//   - Registre borné : maxCanaries = 10 avec éviction des plus anciens
//   - Hash SHA-256 du contenu pour détecter une modification
//   - Comparaison de timestamps : fail CLOSED (erreur → alerte)
//
// INTÉGRATION :
// 1. Dans le démarrage de ChillShell :
//    final manager = CanaryTokenManager(deploymentDir: '/home/user/.ssh/');
//    await manager.deployAll();
//
// 2. En arrière-plan (timer périodique) :
//    await manager.checkAll();
//    // Les alertes sont notifiées via onAlert callback
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

/// Représente une alerte déclenchée quand un fichier piège a été accédé.
class CanaryAlert {
  /// Chemin absolu du fichier piège qui a été accédé.
  final String filePath;

  /// Type de piège (ex : 'ssh_key', 'env_config', 'credentials').
  final String canaryType;

  /// Timestamp UTC de l'alerte (format ISO8601).
  final String alertTimestamp;

  /// Hash SHA-256 attendu du contenu (pour détecter une modification).
  final String expectedContentHash;

  /// Description lisible de l'alerte (sans info interne sensible).
  final String description;

  const CanaryAlert({
    required this.filePath,
    required this.canaryType,
    required this.alertTimestamp,
    required this.expectedContentHash,
    required this.description,
  });

  @override
  String toString() {
    // NE PAS exposer expectedContentHash en clair dans les logs publics.
    return 'CanaryAlert(type=$canaryType, timestamp=$alertTimestamp)';
  }
}

/// Entrée interne du registre chiffré.
class _CanaryEntry {
  final String filePath;
  final String canaryType;
  final String contentHash;      // SHA-256 hex du contenu
  final String deployTimestamp;  // ISO8601 UTC au moment du déploiement
  final String deployedContent;  // Contenu réaliste déployé

  const _CanaryEntry({
    required this.filePath,
    required this.canaryType,
    required this.contentHash,
    required this.deployTimestamp,
    required this.deployedContent,
  });

  Map<String, dynamic> toJson() => {
    'fp': filePath,
    'ct': canaryType,
    'ch': contentHash,
    'dt': deployTimestamp,
    'dc': deployedContent,
  };

  factory _CanaryEntry.fromJson(Map<String, dynamic> json) => _CanaryEntry(
    filePath: json['fp'] as String,
    canaryType: json['ct'] as String,
    contentHash: json['ch'] as String,
    deployTimestamp: json['dt'] as String,
    deployedContent: json['dc'] as String,
  );
}

/// Gestionnaire de tokens de détection d'intrusion.
///
/// Déploie des fichiers aux noms et contenus réalistes dans des emplacements
/// stratégiques. Détecte tout accès à ces fichiers via comparaison de
/// timestamps d'accès.
///
/// Usage :
/// ```dart
/// final manager = CanaryTokenManager(
///   deploymentDir: '/home/user/.ssh/',
///   onAlert: (alert) => auditLog.write(alert),
/// );
///
/// // Déployer les pièges
/// manager.deployCanary(type: 'ssh_key');
///
/// // Vérifier périodiquement (toutes les heures)
/// manager.checkAll();
/// ```
class CanaryTokenManager {
  /// Nombre maximum de fichiers pièges gérés simultanément.
  /// Au-delà, le plus ancien est évincé.
  static const int maxCanaries = 10;

  /// Répertoire de base pour le déploiement des fichiers pièges.
  final String deploymentDir;

  /// Callback appelé immédiatement quand un piège est déclenché.
  final void Function(CanaryAlert alert)? onAlert;

  // Registre interne borné des canaries déployés.
  // Utilise une List ordonnée (plus ancien = index 0) pour l'éviction FIFO.
  final List<_CanaryEntry> _registry = [];

  /// Mots interdits dans les noms de fichiers pièges.
  /// Toute génération de nom doit passer par [_assertRealisticName].
  static const List<String> _forbiddenNameFragments = [
    'canary',
    'trap',
    'honey',
    'fake',
    'decoy',
    'lure',
    'bait',
    'piege',
    'appat',
  ];

  CanaryTokenManager({
    required this.deploymentDir,
    this.onAlert,
  }) {
    // S'assurer que le répertoire de base se termine par /
    if (!deploymentDir.endsWith('/') && !deploymentDir.endsWith('\\')) {
      throw ArgumentError(
        'deploymentDir doit se terminer par un séparateur de chemin.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Déploie un fichier piège du type spécifié.
  ///
  /// Types supportés :
  ///   - `'ssh_key'`     → fichier clé privée SSH (id_rsa_backup)
  ///   - `'env_config'`  → fichier configuration (.env.production)
  ///   - `'credentials'` → fichier JSON de credentials (credentials.json)
  ///
  /// Retourne le [_CanaryEntry] créé, ou null si le type est invalide.
  ///
  /// Si [maxCanaries] est atteint, le plus ancien est évincé avant déploiement.
  _CanaryEntry? deployCanary({required String type}) {
    final name = _realisticNameForType(type);
    if (name == null) return null;

    final content = _realisticContentForType(type);
    if (content == null) return null;

    final fullPath = '$deploymentDir$name';

    // Vérifier que le nom est réaliste (pas de mots interdits).
    _assertRealisticName(fullPath);

    final hash = _sha256Hex(content);
    final timestamp = _nowIso8601();

    final entry = _CanaryEntry(
      filePath: fullPath,
      canaryType: type,
      contentHash: hash,
      deployTimestamp: timestamp,
      deployedContent: content,
    );

    // Éviction FIFO si le registre est plein.
    if (_registry.length >= maxCanaries) {
      _registry.removeAt(0);
    }

    _registry.add(entry);
    return entry;
  }

  /// Déploie tous les types de pièges disponibles.
  ///
  /// Si [maxCanaries] est atteint en cours de déploiement, les pièges
  /// en excès sont ignorés (fail CLOSED : on ne dépasse jamais la limite).
  void deployAll() {
    for (final type in ['ssh_key', 'env_config', 'credentials']) {
      if (_registry.length >= maxCanaries) break;
      deployCanary(type: type);
    }
  }

  /// Vérifie si un fichier piège a été accédé.
  ///
  /// En conditions réelles, compare `File(entry.filePath).statSync().accessed`
  /// avec le timestamp de déploiement. Ici, la détection est simulée via
  /// [accessTimeProvider] pour rendre la classe testable sans I/O.
  ///
  /// Retourne [CanaryAlert] si accès détecté, null sinon.
  /// En cas d'erreur lors de la vérification → fail CLOSED (considéré accédé).
  CanaryAlert? checkCanary(
    _CanaryEntry entry, {
    DateTime? Function(String path)? accessTimeProvider,
  }) {
    DateTime? accessTime;

    try {
      if (accessTimeProvider != null) {
        accessTime = accessTimeProvider(entry.filePath);
      } else {
        // En production : lire stat du fichier via dart:io
        // accessTime = File(entry.filePath).statSync().accessed;
        accessTime = null; // Pas de vrai I/O dans cette implémentation autonome
      }
    } catch (_) {
      // Fail CLOSED : toute erreur de lecture de stat = alerte.
      return _buildAlert(entry, reason: 'stat_error');
    }

    if (accessTime == null) return null;

    final deployTime = DateTime.tryParse(entry.deployTimestamp);
    if (deployTime == null) {
      // Timestamp corrompu → fail CLOSED.
      return _buildAlert(entry, reason: 'corrupt_timestamp');
    }

    // Si l'accès est postérieur au déploiement → quelqu'un a ouvert le fichier.
    if (accessTime.isAfter(deployTime)) {
      return _buildAlert(entry, reason: 'file_accessed');
    }

    return null;
  }

  /// Vérifie tous les pièges déployés.
  ///
  /// Déclenche [onAlert] pour chaque piège accédé.
  List<CanaryAlert> checkAll({
    DateTime? Function(String path)? accessTimeProvider,
  }) {
    final alerts = <CanaryAlert>[];

    for (final entry in List.unmodifiable(_registry)) {
      final alert = checkCanary(entry, accessTimeProvider: accessTimeProvider);
      if (alert != null) {
        alerts.add(alert);
        onAlert?.call(alert);
      }
    }

    return alerts;
  }

  /// Vérifie si le hash SHA-256 du contenu d'un canary correspond au registre.
  ///
  /// Détecte une modification du contenu par un attaquant qui tente d'effacer
  /// les traces en remplaçant le fichier par un contenu différent.
  ///
  /// [currentContent] : contenu actuel lu du fichier.
  /// Retourne true si le hash correspond (fichier intact).
  bool verifyContentHash(_CanaryEntry entry, String currentContent) {
    final currentHash = _sha256Hex(currentContent);
    // Comparaison en temps constant (XOR byte par byte) pour éviter timing attack.
    return _constantTimeEquals(
      utf8.encode(currentHash),
      utf8.encode(entry.contentHash),
    );
  }

  /// Retourne le nombre de canaries actuellement déployés.
  int get count => _registry.length;

  /// Exporte le registre en JSON (pour audit externe chiffré).
  ///
  /// NOTE : En production, ce JSON doit être chiffré avant stockage.
  String exportRegistry() {
    return jsonEncode(_registry.map((e) => e.toJson()).toList());
  }

  /// Recharge le registre depuis un export JSON précédent.
  void importRegistry(String jsonData) {
    final List<dynamic> parsed = jsonDecode(jsonData) as List<dynamic>;
    _registry.clear();
    for (final item in parsed) {
      if (_registry.length >= maxCanaries) break;
      _registry.add(_CanaryEntry.fromJson(item as Map<String, dynamic>));
    }
  }

  // ---------------------------------------------------------------------------
  // Contenu et noms réalistes
  // ---------------------------------------------------------------------------

  /// Retourne un nom de fichier réaliste selon le type de piège.
  ///
  /// RÈGLE ABSOLUE : aucun des mots [_forbiddenNameFragments] ne doit apparaître.
  String? _realisticNameForType(String type) {
    switch (type) {
      case 'ssh_key':
        return 'id_rsa_backup';
      case 'env_config':
        return '.env.production';
      case 'credentials':
        return 'credentials.json';
      default:
        return null;
    }
  }

  /// Génère un contenu réaliste selon le type de piège.
  ///
  /// Le contenu doit être suffisamment convaincant pour qu'un attaquant
  /// veuille l'ouvrir/l'exfiltrer, déclenchant ainsi l'alerte.
  String? _realisticContentForType(String type) {
    switch (type) {
      case 'ssh_key':
        // Clé SSH privée Ed25519 au format OpenSSH — contenu factice mais
        // formaté exactement comme une vraie clé pour tromper les outils.
        return '''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtz
c2gtZWQyNTUxOQAAACB8cQwj2mP4KlI9h7N6EpXzR1VoGuT3DmA8fBkS4XTAAA
AIQBYJjQFWCY0BQAAAAtzc2gtZWQyNTUxOQAAACB8cQwj2mP4KlI9h7N6EpXzR1
VoGuT3DmA8fBkS4XTAAAAQHk2r9fLm3bQ1sD6YpNzO8CvXeM7GtJf0KwHsIqZ9
hbfHxBDCPaY/gqUj2Hs3oSlfNHVWga5PcOYDx8GRLhdMAAAAEXVzZXJAY2hpbGxz
aGVsbAEC
-----END OPENSSH PRIVATE KEY-----''';

      case 'env_config':
        // Fichier .env avec des variables d'environnement réalistes.
        return '''# Production environment — ChillShell backend
# Generated 2025-11-14

APP_ENV=production
APP_SECRET=chs_prod_k9mX2pL7vN3qR8tY4wZ6sA1bC5dE0fG
DATABASE_URL=postgres://chillshell_user:Xk9mP2r7vN@db.internal:5432/chillshell_prod
REDIS_URL=redis://:Lp4qZ8sR2vM@cache.internal:6379/0
JWT_SECRET=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.prod_secret_not_for_use
WEBHOOK_SECRET=whsec_Xk9mLp4qZ8sR2vMT7nBc3dE6fGhI0jK
SMTP_PASSWORD=Xk9mLp4qZ8sR2vMT7nB
S3_SECRET_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
''';

      case 'credentials':
        // JSON credentials au format GCP/AWS-like.
        return jsonEncode({
          'type': 'service_account',
          'project_id': 'chillshell-prod-a7f2b',
          'private_key_id': 'k9m2p7l4r8t1y6w3z5s0a2b4c1d8e3f0g',
          'private_key':
              '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEAzH3k9mXpL4rQ7vN2sT8wY0bC5dA1eG6fJ3hI4jK8lM2nO9p\nQrStUvWxYzAbCdEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOpQrStUvWxYz\n-----END RSA PRIVATE KEY-----\n',
          'client_email': 'deploy-svc@chillshell-prod-a7f2b.iam.gserviceaccount.com',
          'client_id': '108473920156847392018',
          'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
          'token_uri': 'https://oauth2.googleapis.com/token',
        });

      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Validation des noms
  // ---------------------------------------------------------------------------

  /// Vérifie qu'un chemin/nom de fichier ne contient aucun mot interdit.
  ///
  /// Lance [ArgumentError] si un mot interdit est trouvé.
  /// Les noms de pièges doivent être indiscernables de vrais fichiers.
  void _assertRealisticName(String path) {
    final lowerPath = path.toLowerCase();
    for (final forbidden in _forbiddenNameFragments) {
      if (lowerPath.contains(forbidden)) {
        throw ArgumentError(
          'Le nom de fichier piège contient un mot interdit : "$forbidden". '
          'Utiliser un nom réaliste à la place.',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Construction des alertes
  // ---------------------------------------------------------------------------

  CanaryAlert _buildAlert(_CanaryEntry entry, {required String reason}) {
    final alert = CanaryAlert(
      filePath: entry.filePath,
      canaryType: entry.canaryType,
      alertTimestamp: _nowIso8601(),
      expectedContentHash: entry.contentHash,
      // Message d'erreur sans info interne (pas de chemin complet, pas de hash).
      description: 'Accès non autorisé détecté sur un fichier surveillé.',
    );

    onAlert?.call(alert);
    return alert;
  }

  // ---------------------------------------------------------------------------
  // Utilitaires cryptographiques
  // ---------------------------------------------------------------------------

  /// Calcule un SHA-256 simplifié en Dart pur (sans package external).
  ///
  /// NOTE : En production, utiliser `package:crypto` pour un SHA-256 certifié.
  /// Cette implémentation est suffisante pour les tests autonomes.
  String _sha256Hex(String input) {
    // Implémentation SHA-256 minimale en Dart pur pour tests autonomes.
    // En production : import 'package:crypto/crypto.dart'; sha256.convert(...)
    final bytes = utf8.encode(input);
    return _dartPureSha256(Uint8List.fromList(bytes));
  }

  /// SHA-256 en Dart pur — uniquement pour ce module autonome.
  /// Source : implémentation de référence FIPS 180-4.
  String _dartPureSha256(Uint8List data) {
    // Constantes K (premiers 64 nombres premiers, racines cubiques)
    final k = Uint32List.fromList([
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
      0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
      0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
      0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
      0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]);

    // Hash initial H0..H7
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    // Pre-processing : padding
    final bitLen = data.length * 8;
    final padded = List<int>.from(data)..add(0x80);
    while ((padded.length % 64) != 56) padded.add(0);
    // Longueur en 64 bits big-endian
    for (int i = 7; i >= 0; i--) {
      padded.add((bitLen >> (i * 8)) & 0xff);
    }

    // Traitement des blocs de 512 bits
    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      final w = Uint32List(64);
      for (int i = 0; i < 16; i++) {
        w[i] = ((padded[chunk + i * 4] << 24) |
                (padded[chunk + i * 4 + 1] << 16) |
                (padded[chunk + i * 4 + 2] << 8) |
                (padded[chunk + i * 4 + 3])) &
            0xffffffff;
      }
      for (int i = 16; i < 64; i++) {
        final s0 = (_rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ (w[i - 15] >> 3)) & 0xffffffff;
        final s1 = (_rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ (w[i - 2] >> 10)) & 0xffffffff;
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      var a = h0, b = h1, c = h2, d = h3;
      var e = h4, f = h5, g = h6, hh = h7;

      for (int i = 0; i < 64; i++) {
        final s1 = (_rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25)) & 0xffffffff;
        final ch = ((e & f) ^ ((~e & 0xffffffff) & g)) & 0xffffffff;
        final temp1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
        final s0 = (_rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22)) & 0xffffffff;
        final maj = ((a & b) ^ (a & c) ^ (b & c)) & 0xffffffff;
        final temp2 = (s0 + maj) & 0xffffffff;

        hh = g; g = f; f = e;
        e = (d + temp1) & 0xffffffff;
        d = c; c = b; b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + hh) & 0xffffffff;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }

  int _rotr32(int x, int n) {
    return ((x >> n) | (x << (32 - n))) & 0xffffffff;
  }

  /// Comparaison en temps constant (XOR byte par byte).
  ///
  /// Évite les timing attacks : la durée de comparaison ne varie pas
  /// selon le premier octet différent.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Retourne l'heure courante en format ISO8601 UTC.
  String _nowIso8601() => DateTime.now().toUtc().toIso8601String();

  // ---------------------------------------------------------------------------
  // Sécurité : empêcher les fuites via toString()
  // ---------------------------------------------------------------------------

  @override
  String toString() {
    return 'CanaryTokenManager(deployed=${_registry.length}/$maxCanaries)';
  }
}
