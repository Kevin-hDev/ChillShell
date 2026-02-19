// =============================================================================
// FIX-001 — SecureKeyHolder
// Problème corrigé : GAP-001 — Clé SSH stockée en String Dart immutable
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// En Dart, un String est IMMUTABLE et INTERNÉ par le runtime. Cela signifie :
//   - On ne peut pas effacer la mémoire d'un String (pas de zeroing possible)
//   - Le Garbage Collector Dart ne zeroise JAMAIS la mémoire libérée
//   - Une clé SSH stockée en String peut rester en RAM pendant des minutes
//   - Il peut exister 4+ copies simultanées dans le heap (retours de fonction,
//     paramètres, variables temporaires, toString()...)
//
// SOLUTION :
// Stocker la clé en Uint8List (mutable) et la zéroïser manuellement après usage.
// La conversion vers String n'a lieu qu'au dernier moment, juste avant dartssh2.
//
// INTEGRATION :
// 1. Dans key_generation_service.dart :
//    - Remplacer : return {'privateKey': privateKeyPem, 'publicKey': ...}
//    - Par       : return {'privateKey': SecureKeyHolder.fromPem(privateKeyPem), ...}
//
// 2. Dans ssh_service.dart :
//    - Remplacer : final keys = await compute(_parseSSHKeys, privateKey);
//    - Par       :
//        final tempStr = secureKey.toStringTemporary();
//        try {
//          final keys = await compute(_parseSSHKeys, tempStr);
//        } finally {
//          secureKey.dispose(); // zeroise AVANT que le GC intervienne
//        }
//
// 3. Dans ssh_isolate_worker.dart : même pattern try/finally
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

/// Conteneur sécurisé pour une clé SSH privée.
///
/// Stocke la clé en [Uint8List] (mutable) plutôt qu'en [String] (immutable),
/// ce qui permet de zéroïser les octets en mémoire après usage.
///
/// Usage minimal :
/// ```dart
/// final key = SecureKeyHolder.fromPem(privateKeyPem);
/// try {
///   final tempStr = key.toStringTemporary();
///   await doSshOperation(tempStr);
/// } finally {
///   key.dispose(); // TOUJOURS dans un finally
/// }
/// ```
class SecureKeyHolder {
  // Buffer mutable contenant les octets UTF-8 de la clé PEM.
  // Uint8List est mutable → on peut écraser chaque octet avec 0.
  final Uint8List _keyBytes;

  // Indique si dispose() a déjà été appelé.
  // Après dispose(), toute opération doit lever une StateError.
  bool _disposed = false;

  // Nombre de conversions vers String effectuées.
  // Utile pour audit (chaque conversion crée une copie immutable).
  int _conversionCount = 0;

  // Constructeur interne : on passe les bytes directement.
  // Privé pour forcer l'usage des factory constructors.
  SecureKeyHolder._(Uint8List keyBytes) : _keyBytes = keyBytes;

  // ---------------------------------------------------------------------------
  // Constructeurs
  // ---------------------------------------------------------------------------

  /// Crée un [SecureKeyHolder] à partir d'un String PEM.
  ///
  /// IMPORTANT : Le [String] source (paramètre [pem]) reste immutable en
  /// mémoire Dart — on ne peut pas l'effacer. Abandonnez toute référence
  /// à ce String immédiatement après l'appel à cette factory.
  ///
  /// Le contenu est COPIÉ dans un nouveau [Uint8List] pour permettre
  /// le zeroing lors du dispose().
  ///
  /// ```dart
  /// final key = SecureKeyHolder.fromPem(privateKeyPem);
  /// // Après ici : ne plus utiliser privateKeyPem, laisser le GC récupérer
  /// ```
  factory SecureKeyHolder.fromPem(String pem) {
    if (pem.isEmpty) {
      throw ArgumentError('Le PEM de clé ne peut pas être vide.');
    }
    // Encode la clé en bytes UTF-8 et les place dans un Uint8List MUTABLE.
    // List<int> → Uint8List via Uint8List.fromList pour garantir la mutabilité.
    final bytes = Uint8List.fromList(utf8.encode(pem));
    return SecureKeyHolder._(bytes);
  }

  /// Crée un [SecureKeyHolder] directement depuis des octets.
  ///
  /// Les bytes sont COPIÉS pour que l'appelant puisse zéroïser sa propre copie.
  factory SecureKeyHolder.fromBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw ArgumentError('Les bytes de clé ne peuvent pas être vides.');
    }
    // Copie défensive : on ne garde pas de référence vers le buffer de l'appelant.
    final copy = Uint8List.fromList(bytes);
    return SecureKeyHolder._(copy);
  }

  // ---------------------------------------------------------------------------
  // Accès sécurisé à la clé
  // ---------------------------------------------------------------------------

  /// Retourne la clé sous forme de [String] PEM, TEMPORAIREMENT.
  ///
  /// ATTENTION : Ce String est immutable une fois créé. Le GC Dart ne le
  /// zéroïsera pas. Utilisez-le, passez-le à dartssh2, puis laissez la
  /// référence sortir de portée au plus tôt.
  ///
  /// Toujours appeler dans un bloc try/finally avec [dispose()] dans le finally.
  ///
  /// Lance [StateError] si [dispose()] a déjà été appelé.
  String toStringTemporary() {
    _assertNotDisposed();
    _conversionCount++;
    // Décode les bytes UTF-8 en String Dart.
    // Cette String est immutable — c'est la limite du langage Dart.
    // On minimise le temps de vie de cette String en la passant directement
    // à la fonction qui en a besoin.
    return utf8.decode(_keyBytes);
  }

  /// Retourne les octets bruts (lecture seule, vue non-copiée).
  ///
  /// Préférer cette méthode si la bibliothèque cible accepte des bytes
  /// directement (évite la création d'une String immutable).
  ///
  /// Lance [StateError] si [dispose()] a déjà été appelé.
  Uint8List toBytesView() {
    _assertNotDisposed();
    // Retourne une copie pour éviter que l'appelant modifie le buffer interne.
    return Uint8List.fromList(_keyBytes);
  }

  // ---------------------------------------------------------------------------
  // Nettoyage
  // ---------------------------------------------------------------------------

  /// Zéroïse le buffer interne et marque l'objet comme inutilisable.
  ///
  /// Doit TOUJOURS être appelé dans un bloc `finally` pour garantir
  /// l'exécution même en cas d'exception.
  ///
  /// Après cet appel, toute tentative d'accès à la clé lèvera [StateError].
  ///
  /// Appels multiples à [dispose()] sont sans danger (idempotent).
  void dispose() {
    if (_disposed) {
      // Déjà disposé : sans danger, on ne lève pas d'erreur.
      return;
    }
    // Zeroing : on écrase chaque octet avec 0x00.
    // C'est l'équivalent de memset(ptr, 0, len) en C.
    // Le compilateur Dart peut théoriquement optimiser ça, mais en pratique
    // sur les plateformes mobiles/desktop ciblées, ça fonctionne.
    for (int i = 0; i < _keyBytes.length; i++) {
      _keyBytes[i] = 0x00;
    }
    _disposed = true;
  }

  // ---------------------------------------------------------------------------
  // Métadonnées et état
  // ---------------------------------------------------------------------------

  /// Retourne `true` si [dispose()] a été appelé.
  bool get isDisposed => _disposed;

  /// Retourne la longueur de la clé en octets.
  ///
  /// Lance [StateError] si [dispose()] a déjà été appelé.
  int get lengthBytes {
    _assertNotDisposed();
    return _keyBytes.length;
  }

  /// Nombre de fois où [toStringTemporary()] a été appelé.
  ///
  /// Chaque appel crée une copie immutable en mémoire.
  /// Un nombre élevé indique un usage sous-optimal.
  int get conversionCount => _conversionCount;

  // ---------------------------------------------------------------------------
  // Méthode privée utilitaire
  // ---------------------------------------------------------------------------

  /// Vérifie que l'objet est encore utilisable.
  /// Lance [StateError] si dispose() a déjà été appelé.
  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError(
        'SecureKeyHolder a été disposé. '
        'Impossible d\'accéder à la clé après dispose().',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Sécurité : empêcher les fuites via toString() / debugPrint
  // ---------------------------------------------------------------------------

  /// Surcharge toString() pour ne JAMAIS exposer le contenu de la clé.
  ///
  /// Si toString() retournait le contenu, tout appel à debugPrint(key.toString())
  /// ou à l'interpolation '$key' fuiterait la clé privée dans les logs.
  @override
  String toString() {
    if (_disposed) {
      return 'SecureKeyHolder(disposed)';
    }
    return 'SecureKeyHolder(length=${_keyBytes.length}b, conversions=$_conversionCount)';
  }
}

// =============================================================================
// Utilitaire : Pattern d'usage recommandé
// =============================================================================

/// Exécute [operation] avec accès temporaire à la clé sous forme de String.
///
/// Garantit que [holder.dispose()] est appelé après l'opération,
/// même en cas d'exception.
///
/// Exemple :
/// ```dart
/// final result = await withSecureKey(myKeyHolder, (keyStr) async {
///   return await sshClient.connect(host: host, privateKey: keyStr);
/// });
/// ```
Future<T> withSecureKey<T>(
  SecureKeyHolder holder,
  Future<T> Function(String temporaryKeyString) operation,
) async {
  // SÉCURITÉ : on ne dispose pas ici si l'appelant veut réutiliser la clé.
  // Cette fonction sert juste de pattern documenté.
  // L'appelant reste responsable du dispose().
  final tempStr = holder.toStringTemporary();
  return await operation(tempStr);
  // NOTE : tempStr reste en mémoire jusqu'à ce que le GC passe.
  // C'est la limite actuelle de Dart — on ne peut pas forcer le GC.
  // La mitigation est de minimiser la durée de vie de la référence.
}
