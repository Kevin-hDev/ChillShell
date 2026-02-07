import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

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

/// Parse les clés SSH dans un isolate séparé pour ne pas bloquer le thread UI.
/// Fonction top-level requise par compute().
List<SSHKeyPair> _parseSSHKeys(String pem) => SSHKeyPair.fromPem(pem);

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
      // Parsing de la clé dans un ISOLATE SÉPARÉ (ne bloque pas le thread UI)
      final keys = await compute(_parseSSHKeys, privateKey);

      // Connexion TCP (async, ne bloque pas)
      final socket = await SSHSocket.connect(host, port);

      // Handshake SSH + authentification (avec vérification TOFU de la clé d'hôte)
      _client = SSHClient(
        socket,
        username: username,
        identities: keys,
        keepAliveInterval: keepAliveInterval,
        onVerifyHostKey: (type, fingerprint) async {
          try {
            final hexFingerprint = fingerprint
                .map((e) => e.toRadixString(16).padLeft(2, '0'))
                .join(':');

            final stored = await SecureStorageService.getHostFingerprint(host, port);

            if (stored == null) {
              // TOFU: Premier contact → sauvegarder et accepter
              await SecureStorageService.saveHostFingerprint(host, port, hexFingerprint);
              if (kDebugMode) debugPrint('SSH TOFU: Accepted new host key for $host:$port ($type)');
              return true;
            }

            // Contact suivant → vérifier
            final match = stored == hexFingerprint;
            if (kDebugMode) {
              debugPrint('SSH TOFU: Host key ${match ? 'OK' : 'MISMATCH'} for $host:$port');
            }
            return match;
          } catch (e) {
            // En cas d'erreur de stockage, accepter la connexion
            // plutôt que bloquer l'utilisateur
            if (kDebugMode) debugPrint('SSH TOFU: Storage error, accepting: $e');
            return true;
          }
        },
      );
      await _client!.authenticated;
      _isConnectionAlive = true;

      // Écouter la fermeture de connexion
      _client!.done.then((_) {
        if (kDebugMode) debugPrint('SSHService: Connection closed normally');
        _isConnectionAlive = false;
        onDisconnected?.call();
      }).onError((error, stackTrace) {
        if (kDebugMode) debugPrint('SSHService: Connection error: $error');
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
      if (kDebugMode) debugPrint('SSH RESIZE: Sending SIGWINCH ${width}x$height to remote PTY');
      _session!.resizeTerminal(width, height);
    } else {
      if (kDebugMode) debugPrint('SSH RESIZE: No session available!');
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
  /// Exécute une commande via le canal SSH exec (silencieux).
  /// La commande n'apparaît PAS dans le terminal interactif.
  /// Retourne la sortie de la commande ou null en cas d'erreur.
  Future<String?> executeCommandSilently(String command) async {
    if (_client == null) return null;

    try {
      final result = await _client!.run(command);
      return String.fromCharCodes(result);
    } catch (e) {
      if (kDebugMode) debugPrint('SSHService: executeCommandSilently error: $e');
      return null;
    }
  }

  /// Exécute `uname -s` et parse le résultat :
  /// - "Linux" → retourne "linux"
  /// - "Darwin" → retourne "macos"
  /// - Erreur/autre → retourne "windows"
  Future<String?> detectOS() async {
    if (_client == null) return null;

    try {
      final result = await _client!.run('uname -s');
      final output = String.fromCharCodes(result).trim().toLowerCase();

      if (kDebugMode) debugPrint('SSHService: uname -s result: $output');

      if (output.contains('linux')) {
        return 'linux';
      } else if (output.contains('darwin')) {
        return 'macos';
      } else {
        // Si uname échoue ou donne autre chose, c'est probablement Windows
        return 'windows';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SSHService: Error detecting OS: $e');
      // En cas d'erreur (probablement Windows où uname n'existe pas)
      return 'windows';
    }
  }

  /// Transfère un fichier local vers le serveur via SFTP.
  /// Retourne le chemin distant si succès, null si échec.
  Future<String?> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    if (_client == null) return null;

    try {
      final sftp = await _client!.sftp();
      final localFile = await File(localPath).readAsBytes();

      // Ouvrir/créer le fichier distant en écriture
      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      // Écrire les données
      await remoteFile.writeBytes(localFile);
      await remoteFile.close();

      if (kDebugMode) debugPrint('SSHService: File uploaded to $remotePath');
      return remotePath;
    } catch (e) {
      if (kDebugMode) debugPrint('SSHService: SFTP upload error: $e');
      return null;
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

      if (kDebugMode) debugPrint('SSHService: Sending shutdown command for $os: $command');
      _session!.stdin.add(Uint8List.fromList(command.codeUnits));
    } catch (e) {
      if (kDebugMode) debugPrint('SSHService: Error sending shutdown command: $e');
      rethrow;
    }
  }
}
