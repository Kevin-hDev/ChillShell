import 'dart:convert';
import 'dart:typed_data';

/// Buffer sécurisé pour les données sensibles (clés SSH, secrets).
///
/// Stocke les données sous forme de [Uint8List] mutable (contrairement
/// à [String] qui est immutable en Dart). Permet un effacement explicite
/// via [dispose] qui remplit le buffer de zéros.
///
/// Limitation connue : le GC Dart peut copier les données avant le zeroing.
/// Cette classe réduit la fenêtre d'exposition de minutes à millisecondes.
class SecureBuffer {
  Uint8List _data;
  bool _disposed = false;

  SecureBuffer(this._data);

  /// Crée un SecureBuffer à partir d'une chaîne UTF-8.
  factory SecureBuffer.fromString(String value) {
    return SecureBuffer(Uint8List.fromList(utf8.encode(value)));
  }

  /// Retourne les données sous forme de String UTF-8.
  /// Lève une [StateError] si le buffer a été disposé.
  String toUtf8String() {
    if (_disposed) throw StateError('SecureBuffer already disposed');
    return utf8.decode(_data);
  }

  /// Taille du buffer en octets.
  int get length => _data.length;

  /// Indique si le buffer a été effacé.
  bool get isDisposed => _disposed;

  /// Efface le buffer en le remplissant de zéros.
  void dispose() {
    if (_disposed) return;
    _data.fillRange(0, _data.length, 0);
    _disposed = true;
  }
}
