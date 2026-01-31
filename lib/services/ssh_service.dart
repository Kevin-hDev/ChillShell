import 'package:dartssh2/dartssh2.dart';

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

  Future<bool> connect({
    required String host,
    required String username,
    required String privateKey,
    int port = 22,
  }) async {
    try {
      final keys = SSHKeyPair.fromPem(privateKey);
      _client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        identities: keys,
      );
      await _client!.authenticated;
      return true;
    } catch (e) {
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
    _session?.close();
    _client?.close();
    _client = null;
    _session = null;
  }

  bool get isConnected => _client != null;
  SSHSession? get session => _session;
}
