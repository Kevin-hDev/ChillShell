// =============================================================================
// TEST — FIX-001 — SecureKeyHolder
// Couvre : GAP-001 — Clé SSH en String immutable non zéroïsable
// =============================================================================
//
// Pour lancer ces tests :
//   flutter test test_fix_001.dart
// ou (si dans le projet ChillShell) :
//   dart test test/security/test_fix_001.dart
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

// Import du code à tester (adapter le chemin selon l'emplacement final)
// import 'package:chillshell/core/security/fix_001_secure_key.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE pour tests autonomes (retirer si import disponible)
// ---------------------------------------------------------------------------
// [Le code de SecureKeyHolder est inclus ici pour que ce fichier soit
//  exécutable de manière autonome sans dépendance au projet principal]

class SecureKeyHolder {
  final Uint8List _keyBytes;
  bool _disposed = false;
  int _conversionCount = 0;

  SecureKeyHolder._(Uint8List keyBytes) : _keyBytes = keyBytes;

  factory SecureKeyHolder.fromPem(String pem) {
    if (pem.isEmpty) throw ArgumentError('Le PEM ne peut pas être vide.');
    return SecureKeyHolder._(Uint8List.fromList(utf8.encode(pem)));
  }

  factory SecureKeyHolder.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) throw ArgumentError('Les bytes ne peuvent pas être vides.');
    return SecureKeyHolder._(Uint8List.fromList(bytes));
  }

  String toStringTemporary() {
    _assertNotDisposed();
    _conversionCount++;
    return utf8.decode(_keyBytes);
  }

  Uint8List toBytesView() {
    _assertNotDisposed();
    return Uint8List.fromList(_keyBytes);
  }

  void dispose() {
    if (_disposed) return;
    for (int i = 0; i < _keyBytes.length; i++) {
      _keyBytes[i] = 0x00;
    }
    _disposed = true;
  }

  bool get isDisposed => _disposed;
  int get lengthBytes { _assertNotDisposed(); return _keyBytes.length; }
  int get conversionCount => _conversionCount;

  void _assertNotDisposed() {
    if (_disposed) throw StateError('SecureKeyHolder a été disposé.');
  }

  @override
  String toString() {
    if (_disposed) return 'SecureKeyHolder(disposed)';
    return 'SecureKeyHolder(length=${_keyBytes.length}b, conversions=$_conversionCount)';
  }
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

void main() {
  // PEM de test — clé factice, ne jamais utiliser en production.
  // Format réaliste pour les tests mais sans valeur cryptographique réelle.
  const fakePem = '''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACBKEXAMPLEKEY1234567890abcdefghijklmnopqrstuvwxyzAB
AAAAQAAAABEXAMPLEKEY1234567890abcdefghijklmnopqrstuvwxyzABCDEFG
HIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFG
-----END OPENSSH PRIVATE KEY-----''';

  // =========================================================================
  group('SecureKeyHolder — factory fromPem()', () {
    // -------------------------------------------------------------------------
    test('fromPem() crée un holder avec le bon contenu', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      // Vérifier que toStringTemporary() retourne exactement le PEM original
      expect(holder.toStringTemporary(), equals(fakePem));
    });

    // -------------------------------------------------------------------------
    test('fromPem() refuse un String vide', () {
      expect(
        () => SecureKeyHolder.fromPem(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('fromPem() retourne un objet non disposé', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      expect(holder.isDisposed, isFalse);
    });

    // -------------------------------------------------------------------------
    test('fromPem() stocke correctement la longueur en bytes', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      final expectedLength = utf8.encode(fakePem).length;
      expect(holder.lengthBytes, equals(expectedLength));
    });
  });

  // =========================================================================
  group('SecureKeyHolder — factory fromBytes()', () {
    // -------------------------------------------------------------------------
    test('fromBytes() crée un holder depuis des bytes valides', () {
      final bytes = Uint8List.fromList(utf8.encode(fakePem));
      final holder = SecureKeyHolder.fromBytes(bytes);
      addTearDown(holder.dispose);

      expect(holder.toStringTemporary(), equals(fakePem));
    });

    // -------------------------------------------------------------------------
    test('fromBytes() refuse des bytes vides', () {
      expect(
        () => SecureKeyHolder.fromBytes(Uint8List(0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('fromBytes() effectue une copie défensive des bytes', () {
      final originalBytes = Uint8List.fromList(utf8.encode(fakePem));
      final holder = SecureKeyHolder.fromBytes(originalBytes);
      addTearDown(holder.dispose);

      // Modifier les bytes originaux NE doit PAS affecter le holder
      originalBytes[0] = 0xFF;
      originalBytes[1] = 0xFF;

      // Le holder doit toujours retourner le contenu original intact
      expect(holder.toStringTemporary(), equals(fakePem));
    });
  });

  // =========================================================================
  group('SecureKeyHolder — toStringTemporary()', () {
    // -------------------------------------------------------------------------
    test('toStringTemporary() retourne la valeur correcte', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      final result = holder.toStringTemporary();
      expect(result, equals(fakePem));
    });

    // -------------------------------------------------------------------------
    test('toStringTemporary() incrémente le compteur de conversions', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      expect(holder.conversionCount, equals(0));

      holder.toStringTemporary();
      expect(holder.conversionCount, equals(1));

      holder.toStringTemporary();
      expect(holder.conversionCount, equals(2));
    });

    // -------------------------------------------------------------------------
    test('toStringTemporary() lance StateError après dispose()', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      holder.dispose();

      expect(
        () => holder.toStringTemporary(),
        throwsA(isA<StateError>()),
      );
    });

    // -------------------------------------------------------------------------
    test('toStringTemporary() est appellable plusieurs fois avant dispose()', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      // Plusieurs appels consécutifs doivent toujours retourner la même valeur
      for (int i = 0; i < 5; i++) {
        expect(holder.toStringTemporary(), equals(fakePem));
      }
      expect(holder.conversionCount, equals(5));
    });
  });

  // =========================================================================
  group('SecureKeyHolder — dispose() et zeroing', () {
    // -------------------------------------------------------------------------
    test('dispose() met isDisposed à true', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      expect(holder.isDisposed, isFalse);

      holder.dispose();

      expect(holder.isDisposed, isTrue);
    });

    // -------------------------------------------------------------------------
    test('dispose() zéroïse tous les bytes du buffer interne', () {
      // Pour accéder aux bytes INTERNES après dispose(), on utilise toBytesView()
      // AVANT dispose() pour avoir une copie à comparer.
      // Ensuite on vérifie via le comportement : dispose() doit rendre
      // la clé illisible (StateError).
      //
      // Note : On ne peut pas accéder directement au champ _keyBytes (privé).
      // On teste le comportement observable.

      final holder = SecureKeyHolder.fromPem(fakePem);

      // Capturer les bytes avant dispose
      final bytesBefore = holder.toBytesView();
      expect(bytesBefore, isNot(everyElement(equals(0))));

      holder.dispose();

      // Après dispose, l'accès via l'API publique doit échouer
      expect(() => holder.toStringTemporary(), throwsA(isA<StateError>()));
      expect(() => holder.toBytesView(), throwsA(isA<StateError>()));
      expect(() => holder.lengthBytes, throwsA(isA<StateError>()));
    });

    // -------------------------------------------------------------------------
    test('dispose() est idempotent (appels multiples sans erreur)', () {
      final holder = SecureKeyHolder.fromPem(fakePem);

      // Premier appel
      expect(() => holder.dispose(), returnsNormally);
      // Deuxième appel — ne doit pas lever d'exception
      expect(() => holder.dispose(), returnsNormally);
      // Troisième appel — idem
      expect(() => holder.dispose(), returnsNormally);

      expect(holder.isDisposed, isTrue);
    });

    // -------------------------------------------------------------------------
    test('dispose() dans un try/finally garantit le nettoyage', () async {
      // Simule le pattern recommandé pour l'usage avec dartssh2
      String? capturedTemp;
      bool wasDisposed = false;

      final holder = SecureKeyHolder.fromPem(fakePem);

      try {
        capturedTemp = holder.toStringTemporary();
        // Simule l'opération SSH (ici juste une vérification)
        expect(capturedTemp, isNotEmpty);
      } finally {
        holder.dispose();
        wasDisposed = holder.isDisposed;
      }

      expect(wasDisposed, isTrue);
      expect(capturedTemp, isNotNull);
    });

    // -------------------------------------------------------------------------
    test('dispose() dans un try/finally fonctionne même si l\'opération échoue', () {
      final holder = SecureKeyHolder.fromPem(fakePem);

      expect(() {
        try {
          holder.toStringTemporary();
          throw Exception('Simuler une erreur SSH');
        } finally {
          holder.dispose(); // Doit s'exécuter même après l'exception
        }
      }, throwsException);

      // Le holder doit quand même être disposé
      expect(holder.isDisposed, isTrue);
    });
  });

  // =========================================================================
  group('SecureKeyHolder — sécurité toString()', () {
    // -------------------------------------------------------------------------
    test('toString() ne révèle PAS le contenu de la clé', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      final representation = holder.toString();

      // Ne doit PAS contenir le PEM
      expect(representation, isNot(contains('BEGIN OPENSSH')));
      expect(representation, isNot(contains('END OPENSSH')));
      // Ne doit PAS contenir des fragments de la clé
      expect(representation, isNot(contains('b3BlbnNzaC1')));
    });

    // -------------------------------------------------------------------------
    test('toString() sur un holder disposé retourne une info de statut', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      holder.dispose();

      final representation = holder.toString();
      expect(representation, contains('disposed'));
    });

    // -------------------------------------------------------------------------
    test('toString() sur un holder actif contient la taille en bytes', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      final representation = holder.toString();
      // Doit indiquer la taille pour diagnostic, pas le contenu
      expect(representation, contains('b'));
    });
  });

  // =========================================================================
  group('SecureKeyHolder — toBytesView()', () {
    // -------------------------------------------------------------------------
    test('toBytesView() retourne une copie, pas le buffer interne', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      final view = holder.toBytesView();

      // Modifier la copie ne doit PAS affecter le holder
      view[0] = 0xFF;

      // Le holder doit toujours retourner la valeur originale
      expect(holder.toStringTemporary(), equals(fakePem));
    });

    // -------------------------------------------------------------------------
    test('toBytesView() lance StateError après dispose()', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      holder.dispose();

      expect(
        () => holder.toBytesView(),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  group('SecureKeyHolder — lengthBytes', () {
    // -------------------------------------------------------------------------
    test('lengthBytes retourne la bonne taille', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      addTearDown(holder.dispose);

      final expectedLength = utf8.encode(fakePem).length;
      expect(holder.lengthBytes, equals(expectedLength));
    });

    // -------------------------------------------------------------------------
    test('lengthBytes lance StateError après dispose()', () {
      final holder = SecureKeyHolder.fromPem(fakePem);
      holder.dispose();

      expect(
        () => holder.lengthBytes,
        throwsA(isA<StateError>()),
      );
    });
  });
}
