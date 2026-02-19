// =============================================================================
// TEST — FIX-020 — TamperEvidentLog
// Couvre : GAP-020 — Journal d'audit modifiable sans détection
// =============================================================================
//
// Pour lancer ces tests :
//   dart test test_fix_020.dart
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE pour tests autonomes
// ---------------------------------------------------------------------------

class IntegrityResult {
  final bool isValid;
  final int? corruptionIndex;
  final String message;

  const IntegrityResult({
    required this.isValid,
    this.corruptionIndex,
    required this.message,
  });
}

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

class TamperEvidentLog {
  static const int maxEntries = 10000;
  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';
  static const double _rotationFraction = 0.10;

  final List<LogEntry> _entries = [];
  String _lastHash = genesisHash;
  int _globalIndex = 0;
  String? _transitionHash;

  void log(String level, String message, {Map<String, dynamic>? metadata}) {
    if (_entries.length >= maxEntries) _rotate();
    final sanitizedMessage = _sanitize(message);
    final timestamp = _nowIso8601();
    final previousHash = _lastHash;
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

  IntegrityResult verifyIntegrity() {
    if (_entries.isEmpty) {
      return const IntegrityResult(isValid: true, message: 'Journal vide.');
    }
    final expectedFirst = _transitionHash ?? genesisHash;
    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final expectedPreviousHash = i == 0 ? expectedFirst : _entries[i - 1].hash;
      if (!_constantTimeEquals(
        utf8.encode(entry.previousHash),
        utf8.encode(expectedPreviousHash),
      )) {
        return IntegrityResult(
          isValid: false,
          corruptionIndex: entry.index,
          message: 'Rupture de chaîne à l\'entrée ${entry.index}.',
        );
      }
      final expectedHash = _computeEntryHash(
        index: entry.index,
        timestamp: entry.timestamp,
        level: entry.level,
        message: entry.message,
        previousHash: entry.previousHash,
      );
      if (!_constantTimeEquals(utf8.encode(entry.hash), utf8.encode(expectedHash))) {
        return IntegrityResult(
          isValid: false,
          corruptionIndex: entry.index,
          message: 'Hash invalide à l\'entrée ${entry.index}.',
        );
      }
    }
    return const IntegrityResult(isValid: true, message: 'Chaîne intègre.');
  }

  String exportChain() {
    return jsonEncode({
      'version': 1,
      'genesisHash': genesisHash,
      if (_transitionHash != null) 'transitionHash': _transitionHash,
      'entries': _entries.map((e) => e.toJson()).toList(),
    });
  }

  int get length => _entries.length;
  String get lastHash => _lastHash;

  // Accès interne pour tests
  List<LogEntry> get entriesForTest => List.unmodifiable(_entries);

  String _sanitize(String message) {
    String result = message;
    result = result.replaceAll(
      RegExp(r'-----BEGIN [A-Z ]+-----[\s\S]*?-----END [A-Z ]+-----', multiLine: true),
      '[SSH_KEY_REDACTED]',
    );
    result = result.replaceAll(
      RegExp(r'(?<![0-9a-f])[A-Za-z0-9_\-]{40,}(?![0-9a-f])'),
      '[REDACTED]',
    );
    result = result.replaceAll(
      RegExp(r'(password|passwd|pwd|secret|token)\s*[=:]\s*\S+', caseSensitive: false),
      r'$1=[REDACTED]',
    );
    return result;
  }

  void _rotate() {
    final removeCount = (_entries.length * _rotationFraction).ceil().clamp(1, _entries.length);
    if (removeCount > 0) _transitionHash = _entries[removeCount - 1].hash;
    _entries.removeRange(0, removeCount);
  }

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

  String _sha256Hex(String input) =>
      _dartPureSha256(Uint8List.fromList(utf8.encode(input)));

  String _dartPureSha256(Uint8List data) {
    final k = Uint32List.fromList([
      0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
      0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
      0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
      0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
      0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
      0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
      0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
      0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    ]);
    var h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a;
    var h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;
    final bitLen=data.length*8;
    final padded=List<int>.from(data)..add(0x80);
    while((padded.length%64)!=56) padded.add(0);
    for(int i=7;i>=0;i--) padded.add((bitLen>>(i*8))&0xff);
    for(int chunk=0;chunk<padded.length;chunk+=64){
      final w=Uint32List(64);
      for(int i=0;i<16;i++){
        w[i]=((padded[chunk+i*4]<<24)|(padded[chunk+i*4+1]<<16)|(padded[chunk+i*4+2]<<8)|(padded[chunk+i*4+3]))&0xffffffff;
      }
      for(int i=16;i<64;i++){
        final s0=(_r(w[i-15],7)^_r(w[i-15],18)^(w[i-15]>>3))&0xffffffff;
        final s1=(_r(w[i-2],17)^_r(w[i-2],19)^(w[i-2]>>10))&0xffffffff;
        w[i]=(w[i-16]+s0+w[i-7]+s1)&0xffffffff;
      }
      var a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,g=h6,hh=h7;
      for(int i=0;i<64;i++){
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

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
    return diff == 0;
  }

  String _nowIso8601() => DateTime.now().toUtc().toIso8601String();
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  group('TamperEvidentLog — hash genesis', () {
    // -----------------------------------------------------------------------
    test('genesis hash est 64 zéros hexadécimaux', () {
      expect(TamperEvidentLog.genesisHash, hasLength(64));
      expect(TamperEvidentLog.genesisHash, equals('0' * 64));
    });

    // -----------------------------------------------------------------------
    test('première entrée a previousHash == genesisHash', () {
      final log = TamperEvidentLog();
      log.log('INFO', 'Premier message');
      final entry = log.entriesForTest.first;
      expect(entry.previousHash, equals(TamperEvidentLog.genesisHash));
    });
  });

  // =========================================================================
  group('TamperEvidentLog — intégrité de chaîne', () {
    // -----------------------------------------------------------------------
    test('chaîne de 1 entrée reste intègre', () {
      final log = TamperEvidentLog();
      log.log('INFO', 'Message unique');
      final result = log.verifyIntegrity();
      expect(result.isValid, isTrue);
    });

    // -----------------------------------------------------------------------
    test('chaîne de 10 entrées reste intègre', () {
      final log = TamperEvidentLog();
      for (int i = 0; i < 10; i++) {
        log.log('INFO', 'Message $i');
      }
      final result = log.verifyIntegrity();
      expect(result.isValid, isTrue);
    });

    // -----------------------------------------------------------------------
    test('chaîne de 100 entrées reste intègre', () {
      final log = TamperEvidentLog();
      for (int i = 0; i < 100; i++) {
        log.log('AUDIT', 'Événement $i', metadata: {'seq': i});
      }
      final result = log.verifyIntegrity();
      expect(result.isValid, isTrue);
    });

    // -----------------------------------------------------------------------
    test('journal vide retourne isValid=true', () {
      final log = TamperEvidentLog();
      final result = log.verifyIntegrity();
      expect(result.isValid, isTrue);
    });

    // -----------------------------------------------------------------------
    test('chaînage : le hash de chaque entrée devient previousHash de la suivante', () {
      final log = TamperEvidentLog();
      log.log('INFO', 'A');
      log.log('INFO', 'B');
      log.log('INFO', 'C');

      final entries = log.entriesForTest;
      expect(entries[1].previousHash, equals(entries[0].hash));
      expect(entries[2].previousHash, equals(entries[1].hash));
    });
  });

  // =========================================================================
  group('TamperEvidentLog — détection de modification', () {
    // -----------------------------------------------------------------------
    test('modification du message d\'une entrée → chaîne invalide', () {
      final log = TamperEvidentLog();
      for (int i = 0; i < 5; i++) {
        log.log('INFO', 'Message $i');
      }

      // Simuler la modification directe d'une entrée (attaquant root)
      // Pour le test, on remplace l'entrée dans la liste interne.
      final entries = log.entriesForTest;
      final targetIndex = 2; // Modifier l'entrée à l'index 2

      // Reconstruire la liste avec l'entrée modifiée
      // (Dans un vrai scénario, l'attaquant modifie le fichier sur disque)
      final corruptedEntry = LogEntry(
        index: entries[targetIndex].index,
        timestamp: entries[targetIndex].timestamp,
        level: entries[targetIndex].level,
        message: 'MESSAGE MODIFIÉ PAR L\'ATTAQUANT',  // Modification
        metadata: entries[targetIndex].metadata,
        previousHash: entries[targetIndex].previousHash,
        hash: entries[targetIndex].hash,  // Hash inchangé → rupture détectable
      );

      // Créer un log avec l'entrée corrompue
      final tamperedLog = _TamperedLogForTest(log.entriesForTest, corruptedEntry, targetIndex);
      final result = tamperedLog.verifyIntegrityPublic();

      expect(result.isValid, isFalse);
      expect(result.corruptionIndex, isNotNull);
    });

    // -----------------------------------------------------------------------
    test('corruption détectée : corruptionIndex est renseigné', () {
      final log = TamperEvidentLog();
      for (int i = 0; i < 5; i++) {
        log.log('INFO', 'Entrée $i');
      }
      final entries = log.entriesForTest;
      final corruptedEntry = LogEntry(
        index: entries[1].index,
        timestamp: entries[1].timestamp,
        level: 'WARN',  // Level modifié
        message: entries[1].message,
        previousHash: entries[1].previousHash,
        hash: entries[1].hash,  // Hash non mis à jour → détectable
      );
      final tamperedLog = _TamperedLogForTest(entries, corruptedEntry, 1);
      final result = tamperedLog.verifyIntegrityPublic();
      expect(result.isValid, isFalse);
      expect(result.corruptionIndex, isNotNull);
    });

    // -----------------------------------------------------------------------
    test('vérification d\'un log non modifié → isValid=true + corruptionIndex=null', () {
      final log = TamperEvidentLog();
      log.log('INFO', 'Test intégrité');
      final result = log.verifyIntegrity();
      expect(result.isValid, isTrue);
      expect(result.corruptionIndex, isNull);
    });
  });

  // =========================================================================
  group('TamperEvidentLog — sanitization des messages', () {
    // -----------------------------------------------------------------------
    test('clé SSH privée est supprimée du message', () {
      final log = TamperEvidentLog();
      const sshKey = '''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAA=
-----END OPENSSH PRIVATE KEY-----''';

      log.log('ERROR', 'Clé exposée : $sshKey');
      final entry = log.entriesForTest.first;
      expect(entry.message, isNot(contains('BEGIN OPENSSH')));
      expect(entry.message, contains('[SSH_KEY_REDACTED]'));
    });

    // -----------------------------------------------------------------------
    test('token long (40+ chars) est remplacé par [REDACTED]', () {
      final log = TamperEvidentLog();
      const longToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9abc123456789';
      // 49 caractères → doit être remplacé
      expect(longToken.length, greaterThanOrEqualTo(40));

      log.log('INFO', 'Token reçu : $longToken');
      final entry = log.entriesForTest.first;
      expect(entry.message, isNot(contains(longToken)));
      expect(entry.message, contains('[REDACTED]'));
    });

    // -----------------------------------------------------------------------
    test('pattern password=xxx est remplacé par password=[REDACTED]', () {
      final log = TamperEvidentLog();
      log.log('WARN', 'Tentative avec password=monMotDePasse123');
      final entry = log.entriesForTest.first;
      expect(entry.message, isNot(contains('monMotDePasse123')));
      expect(entry.message, contains('[REDACTED]'));
    });

    // -----------------------------------------------------------------------
    test('pattern passwd=xxx est remplacé', () {
      final log = TamperEvidentLog();
      log.log('WARN', 'Échec authentification passwd=secret42');
      final entry = log.entriesForTest.first;
      expect(entry.message, isNot(contains('secret42')));
      expect(entry.message, contains('[REDACTED]'));
    });

    // -----------------------------------------------------------------------
    test('pattern secret=xxx est remplacé', () {
      final log = TamperEvidentLog();
      log.log('AUDIT', 'Config chargée secret=topSecretValue');
      final entry = log.entriesForTest.first;
      expect(entry.message, isNot(contains('topSecretValue')));
      expect(entry.message, contains('[REDACTED]'));
    });

    // -----------------------------------------------------------------------
    test('message court sans secret n\'est pas modifié', () {
      final log = TamperEvidentLog();
      log.log('INFO', 'Session SSH démarrée');
      final entry = log.entriesForTest.first;
      expect(entry.message, equals('Session SSH démarrée'));
    });
  });

  // =========================================================================
  group('TamperEvidentLog — rotation et maxEntries', () {
    // -----------------------------------------------------------------------
    test('length ne dépasse pas maxEntries', () {
      // Utiliser un log avec maxEntries réduit pour le test
      final log = _SmallLog(maxE: 20);
      for (int i = 0; i < 30; i++) {
        log.log('INFO', 'Entrée $i');
      }
      expect(log.length, lessThanOrEqualTo(20));
    });

    // -----------------------------------------------------------------------
    test('après rotation, la chaîne reste vérifiable (intègre)', () {
      final log = _SmallLog(maxE: 10);
      for (int i = 0; i < 15; i++) {
        log.log('INFO', 'Entrée $i');
      }
      // Le log a subi au moins une rotation
      final result = log.verifyIntegrity();
      expect(result.isValid, isTrue);
    });
  });

  // =========================================================================
  group('TamperEvidentLog — export JSON', () {
    // -----------------------------------------------------------------------
    test('exportChain retourne un JSON valide', () {
      final log = TamperEvidentLog();
      for (int i = 0; i < 5; i++) {
        log.log('INFO', 'Message $i');
      }
      final exported = log.exportChain();
      expect(() => jsonDecode(exported), returnsNormally);
    });

    // -----------------------------------------------------------------------
    test('exportChain contient le genesisHash', () {
      final log = TamperEvidentLog();
      log.log('INFO', 'Test export');
      final exported = jsonDecode(log.exportChain()) as Map;
      expect(exported['genesisHash'], equals(TamperEvidentLog.genesisHash));
    });

    // -----------------------------------------------------------------------
    test('exportChain contient toutes les entrées', () {
      final log = TamperEvidentLog();
      for (int i = 0; i < 7; i++) {
        log.log('INFO', 'Message $i');
      }
      final exported = jsonDecode(log.exportChain()) as Map;
      final entries = exported['entries'] as List;
      expect(entries, hasLength(7));
    });

    // -----------------------------------------------------------------------
    test('entrée avec metadata est incluse dans l\'export', () {
      final log = TamperEvidentLog();
      log.log('AUDIT', 'Connexion', metadata: {'user': 'alice', 'ip': '10.0.0.1'});
      final exported = jsonDecode(log.exportChain()) as Map;
      final entries = exported['entries'] as List;
      final entry = entries.first as Map;
      expect(entry['metadata'], isNotNull);
      expect((entry['metadata'] as Map)['user'], equals('alice'));
    });
  });
}

// ---------------------------------------------------------------------------
// Classes utilitaires pour les tests
// ---------------------------------------------------------------------------

/// TamperEvidentLog avec accès aux entrées pour simuler une attaque.
class _TamperedLogForTest {
  final List<LogEntry> _tamperedEntries;

  _TamperedLogForTest(
    List<LogEntry> original,
    LogEntry corruptedEntry,
    int corruptedIndex,
  ) : _tamperedEntries = [
        ...original.sublist(0, corruptedIndex),
        corruptedEntry,
        ...original.sublist(corruptedIndex + 1),
      ];

  IntegrityResult verifyIntegrityPublic() {
    if (_tamperedEntries.isEmpty) {
      return const IntegrityResult(isValid: true, message: 'Vide.');
    }
    final expectedFirst = TamperEvidentLog.genesisHash;
    for (int i = 0; i < _tamperedEntries.length; i++) {
      final entry = _tamperedEntries[i];
      final expectedPrev = i == 0 ? expectedFirst : _tamperedEntries[i - 1].hash;
      if (entry.previousHash != expectedPrev) {
        return IntegrityResult(
          isValid: false,
          corruptionIndex: entry.index,
          message: 'Rupture de chaîne à ${entry.index}.',
        );
      }
      final expectedHash = _computeHash(
        index: entry.index,
        timestamp: entry.timestamp,
        level: entry.level,
        message: entry.message,
        previousHash: entry.previousHash,
      );
      if (entry.hash != expectedHash) {
        return IntegrityResult(
          isValid: false,
          corruptionIndex: entry.index,
          message: 'Hash invalide à ${entry.index}.',
        );
      }
    }
    return const IntegrityResult(isValid: true, message: 'Intègre.');
  }

  String _computeHash({
    required int index,
    required String timestamp,
    required String level,
    required String message,
    required String previousHash,
  }) {
    // Utiliser le même algorithme que TamperEvidentLog
    final canonical = '$index|$timestamp|$level|$message|$previousHash';
    return _sha256Hex(canonical);
  }

  String _sha256Hex(String input) {
    // Implémentation minimale pour valider le hash
    final bytes = utf8.encode(input);
    return _dartPureSha256(Uint8List.fromList(bytes));
  }

  String _dartPureSha256(Uint8List data) {
    final k = Uint32List.fromList([
      0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
      0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
      0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
      0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
      0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
      0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
      0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
      0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
    ]);
    var h0=0x6a09e667,h1=0xbb67ae85,h2=0x3c6ef372,h3=0xa54ff53a;
    var h4=0x510e527f,h5=0x9b05688c,h6=0x1f83d9ab,h7=0x5be0cd19;
    final bitLen=data.length*8;
    final padded=List<int>.from(data)..add(0x80);
    while((padded.length%64)!=56) padded.add(0);
    for(int i=7;i>=0;i--) padded.add((bitLen>>(i*8))&0xff);
    for(int chunk=0;chunk<padded.length;chunk+=64){
      final w=Uint32List(64);
      for(int i=0;i<16;i++){
        w[i]=((padded[chunk+i*4]<<24)|(padded[chunk+i*4+1]<<16)|(padded[chunk+i*4+2]<<8)|(padded[chunk+i*4+3]))&0xffffffff;
      }
      for(int i=16;i<64;i++){
        final s0=(_r(w[i-15],7)^_r(w[i-15],18)^(w[i-15]>>3))&0xffffffff;
        final s1=(_r(w[i-2],17)^_r(w[i-2],19)^(w[i-2]>>10))&0xffffffff;
        w[i]=(w[i-16]+s0+w[i-7]+s1)&0xffffffff;
      }
      var a=h0,b=h1,c=h2,d=h3,e=h4,f=h5,g=h6,hh=h7;
      for(int i=0;i<64;i++){
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
}

/// Version de TamperEvidentLog avec maxEntries configurable pour les tests.
class _SmallLog extends TamperEvidentLog {
  final int maxE;
  _SmallLog({required this.maxE});

  @override
  void log(String level, String message, {Map<String, dynamic>? metadata}) {
    // Rotation manuelle si nécessaire (contourne la constante maxEntries)
    if (_entries.length >= maxE) {
      final removeCount = (_entries.length * 0.10).ceil().clamp(1, _entries.length);
      if (removeCount > 0) _transitionHash = _entries[removeCount - 1].hash;
      _entries.removeRange(0, removeCount);
    }
    super.log(level, message, metadata: metadata);
  }
}
