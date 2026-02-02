import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

enum SSHError {
  connectionFailed,
  authenticationFailed,
  keyNotFound,
  timeout,
  hostUnreachable,
}

class SSHException implements Exception {
  final SSHError error;
  final String message;

  SSHException(this.error, this.message);

  String get userMessage {
    switch (error) {
      case SSHError.connectionFailed:
        return 'Connexion impossible. Vérifiez l\'adresse du serveur.';
      case SSHError.authenticationFailed:
        return 'Authentification échouée. Vérifiez votre clé SSH.';
      case SSHError.keyNotFound:
        return 'Aucune clé SSH configurée pour cet hôte.';
      case SSHError.timeout:
        return 'Délai d\'attente dépassé.';
      case SSHError.hostUnreachable:
        return 'Serveur injoignable. Vérifiez Tailscale.';
    }
  }
}

class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  bool _isConnectionAlive = false;

  /// Callback appelé quand la connexion se ferme
  VoidCallback? onDisconnected;

  Future<bool> connect({
    required String host,
    required String username,
    required String privateKey,
    int port = 22,
    Duration keepAliveInterval = const Duration(seconds: 30),
  }) async {
    try {
      final keys = SSHKeyPair.fromPem(privateKey);
      _client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        identities: keys,
        keepAliveInterval: keepAliveInterval,
      );
      await _client!.authenticated;
      _isConnectionAlive = true;

      // Écouter la fermeture de connexion
      _client!.done.then((_) {
        debugPrint('SSHService: Connection closed normally');
        _isConnectionAlive = false;
        onDisconnected?.call();
      }).onError((error, stackTrace) {
        debugPrint('SSHService: Connection error: $error');
        _isConnectionAlive = false;
        onDisconnected?.call();
      });

      return true;
    } catch (e) {
      _isConnectionAlive = false;
      throw SSHException(
        SSHError.connectionFailed,
        'SSH Error: $e',
      );
    }
  }

  Future<SSHSession?> startShell({int width = 80, int height = 24}) async {
    if (_client == null) return null;

    try {
      _session = await _client!.shell(
        pty: SSHPtyConfig(type: 'xterm-256color', width: width, height: height),
      );
      return _session;
    } catch (e) {
      throw SSHException(SSHError.connectionFailed, 'Shell Error: $e');
    }
  }

  /// Redimensionne le PTY distant pour correspondre à la taille du terminal
  void resizeTerminal(int width, int height) {
    if (_session != null) {
      _session!.resizeTerminal(width, height);
    }
  }

  Future<void> disconnect() async {
    _isConnectionAlive = false;
    _session?.close();
    _client?.close();
    _client = null;
    _session = null;
  }

  /// Vérifie si la connexion est vraiment active (pas juste si l'objet existe)
  bool get isConnected => _client != null && _isConnectionAlive;
  SSHSession? get session => _session;

  /// Détecte le système d'exploitation du serveur distant.
  ///
  /// Exécute `uname -s` et parse le résultat :
  /// - "Linux" → retourne "linux"
  /// - "Darwin" → retourne "macos"
  /// - Erreur/autre → retourne "windows"
  Future<String?> detectOS() async {
    if (_client == null) return null;

    try {
      final result = await _client!.run('uname -s');
      final output = String.fromCharCodes(result).trim().toLowerCase();

      debugPrint('SSHService: uname -s result: $output');

      if (output.contains('linux')) {
        return 'linux';
      } else if (output.contains('darwin')) {
        return 'macos';
      } else {
        // Si uname échoue ou donne autre chose, c'est probablement Windows
        return 'windows';
      }
    } catch (e) {
      debugPrint('SSHService: Error detecting OS: $e');
      // En cas d'erreur (probablement Windows où uname n'existe pas)
      return 'windows';
    }
  }

  /// Envoie la commande d'extinction appropriée selon l'OS.
  ///
  /// - Linux/macOS: `sudo shutdown -h now`
  /// - Windows: `shutdown /s /t 0`
  Future<void> shutdown(String os) async {
    if (_session == null) return;

    try {
      final command = (os == 'linux' || os == 'macos')
          ? 'sudo shutdown -h now\n'
          : 'shutdown /s /t 0\n';

      debugPrint('SSHService: Sending shutdown command for $os: $command');
      _session!.stdin.add(Uint8List.fromList(command.codeUnits));
    } catch (e) {
      debugPrint('SSHService: Error sending shutdown command: $e');
      rethrow;
    }
  }
}
