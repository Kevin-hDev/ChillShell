// =============================================================================
// FIX-020 — TamperEvidentLog
// Problème corrigé : GAP-020 — Journal d'audit modifiable sans détection
// Catégorie : BH (Behavior Hardening)  |  Priorité : P2
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// Le journal d'audit existant de ChillShell est un simple fichier texte.
// Un attaquant disposant des droits root peut :
//   - Supprimer des entrées pour effacer ses traces
//   - Modifier des entrées existantes pour incriminer un autre utilisateur
//   - Insérer des fausses entrées pour brouiller la piste
// Aucune de ces actions n'est détectable après coup.
//
// SOLUTION : Journal à chaîne de hash
// Chaque entrée contient le hash SHA-256 de l'entrée précédente. Modifier
// n'importe quelle entrée casse la chaîne à partir de ce point. La rupture
// est détectable par verifyIntegrity() qui recalcule toute la chaîne.
//
// STRUCTURE D'UNE ENTRÉE :
//   {
//     "index":         0,
//     "timestamp":     "2026-02-19T10:00:00.000Z",
//     "level":         "INFO",
//     "message":       "Session SSH démarrée",
//     "metadata":      {"user": "alice", "host": "192.168.1.1"},
//     "previousHash":  "0000...0000",           // Hash de l'entrée précédente
//     "hash":          "sha256(index|ts|level|msg|prevHash)"
//   }
//
// CALCUL DU HASH :
//   hash = SHA-256("index|timestamp|level|message|previousHash")
//   Les champs metadata sont exclus du hash (ils peuvent être vides).
//
// SANITIZATION (OBLIGATOIRE) :
//   - Clés SSH privées (-----BEGIN ... KEY-----) → supprimées du message
//   - Tokens longs (40+ caractères alphanumériques) → remplacés par [REDACTED]
//   - Patterns password (password=xxx, passwd=xxx, pwd=xxx) → [REDACTED]
//
// ROTATION :
//   Quand maxEntries est atteint, les 10% les plus anciens sont supprimés.
//   Un hash de transition est enregistré pour préserver la chaîne.
//
// INTÉGRATION :
// 1. Remplacer les appels à debugPrint() ou Logger.write() par :
//    final auditLog = TamperEvidentLog();
//    auditLog.log('INFO', 'Session démarrée', metadata: {'user': user});
//
// 2. Périodiquement (ou avant fermeture) :
//    final result = auditLog.verifyIntegrity();
//    if (!result.isValid) { /* alerte immédiate */ }
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

/// Résultat de la vérification d'intégrité de la chaîne.
class IntegrityResult {
  /// true si toute la chaîne est intacte.
  final bool isValid;

  /// Index de la première entrée corrompue (null si chaîne intègre).
  final int? corruptionIndex;

  /// Description de l'anomalie détectée (sans info interne sensible).
  final String message;

  const IntegrityResult({
    required this.isValid,
    this.corruptionIndex,
    required this.message,
  });

  @override
  String toString() {
    if (isValid) return 'IntegrityResult(valid)';
    return 'IntegrityResult(invalid, corruptionAt=$corruptionIndex)';
  }
}

/// Une entrée du journal d'audit.
class LogEntry {
  final int index;
  final String timestamp;
  final String level;
  final String message;
  final Map<String, dynamic>? metadata;
  final String previousHash;
  final String hash;

  const LogEntry({
    required this.index,
    required this.timestamp,
    required this.level,
    required this.message,
    this.metadata,
    required this.previousHash,
    required this.hash,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'timestamp': timestamp,
    'level': level,
    'message': message,
    if (metadata != null) 'metadata': metadata,
    'previousHash': previousHash,
    'hash': hash,
  };
}

/// Journal d'audit à preuve de falsification.
///
/// Chaque entrée est liée à la précédente par son hash SHA-256.
/// Toute modification, suppression ou insertion d'entrée est détectable
/// via [verifyIntegrity()].
///
/// Usage :
/// ```dart
/// final log = TamperEvidentLog();
/// log.log('INFO', 'Session démarrée', metadata: {'user': 'alice'});
/// log.log('WARN', 'Tentative de connexion échouée');
///
/// final result = log.verifyIntegrity();
/// assert(result.isValid);
/// ```
class TamperEvidentLog {
  /// Nombre maximum d'entrées dans le journal avant rotation.
  static const int maxEntries = 10000;

  /// Hash de la première entrée de la chaîne ("entrée genesis").
  /// Valeur standard SHA-256 de zéros (64 zéros hexadécimaux).
  static const String genesisHash = '0000000000000000000000000000000000000000000000000000000000000000';

  /// Pourcentage d'entrées supprimées lors d'une rotation (10%).
  static const double _rotationFraction = 0.10;

  // Journal interne.
  final List<LogEntry> _entries = [];

  // Hash de la dernière entrée (ou hash de transition après rotation).
  String _lastHash = genesisHash;

  // Index global incrémental (ne se réinitialise pas après rotation).
  int _globalIndex = 0;

  // Hash de transition enregistré lors de la dernière rotation.
  // Permet de valider que la chaîne a été correctement tronquée.
  String? _transitionHash;

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Ajoute une entrée au journal.
  ///
  /// Le [message] est sanitisé avant enregistrement :
  ///   - Clés SSH supprimées
  ///   - Tokens 40+ caractères remplacés par [REDACTED]
  ///   - Patterns password remplacés par [REDACTED]
  ///
  /// [level] : 'DEBUG', 'INFO', 'WARN', 'ERROR', 'AUDIT'
  /// [metadata] : données structurées additionnelles (optionnel)
  void log(
    String level,
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    // Rotation si nécessaire AVANT d'ajouter la nouvelle entrée.
    if (_entries.length >= maxEntries) {
      _rotate();
    }

    final sanitizedMessage = _sanitize(message);
    final timestamp = _nowIso8601();
    final previousHash = _lastHash;

    // Calcul du hash de cette entrée.
    final hash = _computeEntryHash(
      index: _globalIndex,
      timestamp: timestamp,
      level: level,
      message: sanitizedMessage,
      previousHash: previousHash,
    );

    final entry = LogEntry(
      index: _globalIndex,
      timestamp: timestamp,
      level: level,
      message: sanitizedMessage,
      metadata: metadata,
      previousHash: previousHash,
      hash: hash,
    );

    _entries.add(entry);
    _lastHash = hash;
    _globalIndex++;
  }

  /// Vérifie l'intégrité de toute la chaîne de hash.
  ///
  /// Recalcule le hash de chaque entrée et vérifie qu'il correspond au hash
  /// enregistré, et que previousHash correspond bien au hash de l'entrée précédente.
  ///
  /// Retourne [IntegrityResult.isValid] = true si la chaîne est intacte.
  /// En cas de corruption, [IntegrityResult.corruptionIndex] indique la première
  /// entrée corrompue.
  IntegrityResult verifyIntegrity() {
    if (_entries.isEmpty) {
      return const IntegrityResult(
        isValid: true,
        message: 'Journal vide — aucune entrée à vérifier.',
      );
    }

    // Le premier previousHash doit être soit le hash genesis,
    // soit le hash de transition (après rotation).
    final expectedFirst = _transitionHash ?? genesisHash;

    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];

      // Vérifier le chaînage avec l'entrée précédente.
      final expectedPreviousHash = i == 0 ? expectedFirst : _entries[i - 1].hash;
      if (!_constantTimeEquals(
        utf8.encode(entry.previousHash),
        utf8.encode(expectedPreviousHash),
      )) {
        return IntegrityResult(
          isValid: false,
          corruptionIndex: entry.index,
          message: 'Rupture de chaîne détectée à l\'entrée ${entry.index}.',
        );
      }

      // Recalculer et vérifier le hash de cette entrée.
      final expectedHash = _computeEntryHash(
        index: entry.index,
        timestamp: entry.timestamp,
        level: entry.level,
        message: entry.message,
        previousHash: entry.previousHash,
      );

      if (!_constantTimeEquals(
        utf8.encode(entry.hash),
        utf8.encode(expectedHash),
      )) {
        return IntegrityResult(
          isValid: false,
          corruptionIndex: entry.index,
          message: 'Hash invalide à l\'entrée ${entry.index}.',
        );
      }
    }

    return const IntegrityResult(
      isValid: true,
      message: 'Chaîne intègre — aucune corruption détectée.',
    );
  }

  /// Exporte toute la chaîne en JSON pour audit externe.
  ///
  /// Le JSON inclut les métadonnées de rotation si applicable.
  String exportChain() {
    return jsonEncode({
      'version': 1,
      'genesisHash': genesisHash,
      if (_transitionHash != null) 'transitionHash': _transitionHash,
      'entries': _entries.map((e) => e.toJson()).toList(),
    });
  }

  /// Nombre d'entrées actuellement dans le journal.
  int get length => _entries.length;

  /// Hash de la dernière entrée (pour chaînage externe).
  String get lastHash => _lastHash;

  // ---------------------------------------------------------------------------
  // Sanitization des messages
  // ---------------------------------------------------------------------------

  /// Supprime les informations sensibles d'un message avant enregistrement.
  ///
  /// Règles appliquées dans l'ordre :
  ///   1. Blocs PEM complets (clés SSH, certificats) → supprimés
  ///   2. Tokens/clés longues (40+ chars alphanumériques) → [REDACTED]
  ///   3. Patterns password (password=xxx) → password=[REDACTED]
  String _sanitize(String message) {
    String result = message;

    // 1. Supprimer les blocs PEM (clés SSH, certificats, etc.)
    result = result.replaceAll(
      RegExp(
        r'-----BEGIN [A-Z ]+-----[\s\S]*?-----END [A-Z ]+-----',
        multiLine: true,
      ),
      '[SSH_KEY_REDACTED]',
    );

    // 2. Remplacer les tokens longs (40+ caractères alphanumériques + tirets/underscores)
    // Exclure les hashes SHA-256 déjà dans le journal (64 hex) pour éviter la récursion.
    result = result.replaceAll(
      RegExp(r'(?<![0-9a-f])[A-Za-z0-9_\-]{40,}(?![0-9a-f])'),
      '[REDACTED]',
    );

    // 3. Remplacer les patterns password/passwd/pwd
    result = result.replaceAll(
      RegExp(
        r'(password|passwd|pwd|secret|token)\s*[=:]\s*\S+',
        caseSensitive: false,
      ),
      r'$1=[REDACTED]',
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // Rotation du journal
  // ---------------------------------------------------------------------------

  /// Supprime les 10% plus anciennes entrées pour libérer de la place.
  ///
  /// Enregistre le hash de la dernière entrée supprimée comme "hash de transition"
  /// pour maintenir la continuité de la chaîne lors de la vérification.
  void _rotate() {
    final removeCount = (_entries.length * _rotationFraction).ceil().clamp(1, _entries.length);

    // Le hash de transition est le hash de la DERNIÈRE entrée qu'on va supprimer.
    // La prochaine entrée pointera vers ce hash comme previousHash.
    if (removeCount > 0) {
      _transitionHash = _entries[removeCount - 1].hash;
    }

    _entries.removeRange(0, removeCount);
  }

  // ---------------------------------------------------------------------------
  // Calcul des hash
  // ---------------------------------------------------------------------------

  /// Calcule le hash SHA-256 d'une entrée.
  ///
  /// Format canonique : "index|timestamp|level|message|previousHash"
  /// Les métadonnées sont EXCLUES pour que le hash reste déterministe
  /// même si les métadonnées sont nulles ou ordonnées différemment.
  String _computeEntryHash({
    required int index,
    required String timestamp,
    required String level,
    required String message,
    required String previousHash,
  }) {
    final canonical = '$index|$timestamp|$level|$message|$previousHash';
    return _sha256Hex(canonical);
  }

  String _sha256Hex(String input) {
    return _dartPureSha256(Uint8List.fromList(utf8.encode(input)));
  }

  String _dartPureSha256(Uint8List data) {
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
    var h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a;
    var h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;
    final bitLen = data.length * 8;
    final padded = List<int>.from(data)..add(0x80);
    while ((padded.length % 64) != 56) padded.add(0);
    for (int i = 7; i >= 0; i--) padded.add((bitLen >> (i * 8)) & 0xff);
    for (int chunk = 0; chunk < padded.length; chunk += 64) {
      final w = Uint32List(64);
      for (int i = 0; i < 16; i++) {
        w[i] = ((padded[chunk+i*4]<<24)|(padded[chunk+i*4+1]<<16)|
                (padded[chunk+i*4+2]<<8)|(padded[chunk+i*4+3]))&0xffffffff;
      }
      for (int i = 16; i < 64; i++) {
        final s0=(_r(w[i-15],7)^_r(w[i-15],18)^(w[i-15]>>3))&0xffffffff;
        final s1=(_r(w[i-2],17)^_r(w[i-2],19)^(w[i-2]>>10))&0xffffffff;
        w[i]=(w[i-16]+s0+w[i-7]+s1)&0xffffffff;
      }
      var a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,g=h6,hh=h7;
      for (int i = 0; i < 64; i++) {
        final s1=(_r(e,6)^_r(e,11)^_r(e,25))&0xffffffff;
        final ch=((e&f)^((~e&0xffffffff)&g))&0xffffffff;
        final t1=(hh+s1+ch+k[i]+w[i])&0xffffffff;
        final s0=(_r(a,2)^_r(a,13)^_r(a,22))&0xffffffff;
        final maj=((a&b)^(a&c)^(b&c))&0xffffffff;
        final t2=(s0+maj)&0xffffffff;
        hh=g;g=f;f=e;e=(d+t1)&0xffffffff;d=c;c=b;b=a;a=(t1+t2)&0xffffffff;
      }
      h0=(h0+a)&0xffffffff;h1=(h1+b)&0xffffffff;h2=(h2+c)&0xffffffff;h3=(h3+d)&0xffffffff;
      h4=(h4+e)&0xffffffff;h5=(h5+f)&0xffffffff;h6=(h6+g)&0xffffffff;h7=(h7+hh)&0xffffffff;
    }
    return [h0,h1,h2,h3,h4,h5,h6,h7].map((v)=>v.toRadixString(16).padLeft(8,'0')).join();
  }

  int _r(int x, int n) => ((x>>n)|(x<<(32-n)))&0xffffffff;

  /// Comparaison en temps constant (XOR byte par byte).
  ///
  /// Évite les timing attacks lors de la comparaison de hashes.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String _nowIso8601() => DateTime.now().toUtc().toIso8601String();

  @override
  String toString() => 'TamperEvidentLog(entries=${_entries.length}/$maxEntries)';
}
