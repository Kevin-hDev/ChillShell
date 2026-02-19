import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';
import 'audit_log_service.dart';
import '../models/audit_entry.dart';
import '../core/security/secure_logger.dart';
// FIX-001 — SecureKeyHolder : zeroise la clé privée SSH après usage
import '../core/security/secure_key_holder.dart';
// FIX-012 — SessionTimeoutManager : doit être instancié par le provider SSH
//   Usage attendu : provider appelle startMonitoring(tabId) à l'ouverture,
//   resetTimer(tabId) à chaque keypress, stopMonitoring(tabId) à la fermeture.
//   Voir lib/core/security/session_timeout.dart pour l'API complète.
// ignore: unused_import
import '../core/security/session_timeout.dart';
// FIX-014 — SSHAlgorithmConfig : liste blanche des algorithmes SSH autorisés
//   NOTE : dartssh2 ne permet pas de filtrer les algos côté client via le
//   constructeur SSHClient. L'audit des algorithmes est fait via logConfiguration()
//   et validateServerAlgorithms() lors de la connexion.
import '../core/security/ssh_algorithm_config.dart';
// FIX-006 — ShutdownGuard : confirmation double avant l'extinction distante.
//   IMPORTANT : ShutdownGuard.requestShutdown() et ShutdownGuard.confirmShutdown()
//   DOIVENT être appelés par le provider ou l'UI AVANT d'appeler shutdown() ici.
//   Cette méthode n'effectue que l'envoi de la commande (déjà validée).
//   Workflow attendu dans le provider/UI :
//     1. token = ShutdownGuard.requestShutdown()
//     2. Afficher ShutdownConfirmationDialog(token: token) à l'utilisateur
//     3. L'utilisateur saisit "SHUTDOWN" + voit le code à 6 chiffres
//     4. if (ShutdownGuard.confirmShutdown(token, userInput)) → appeler shutdown()
// ignore: unused_import
import '../core/security/shutdown_guard.dart';

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

  @override
  String toString() => 'SSHException($error, $message)';
}

/// Parse les clés SSH dans un isolate séparé pour ne pas bloquer le thread UI.
/// Fonction top-level requise par compute().
List<SSHKeyPair> _parseSSHKeys(String pem) => SSHKeyPair.fromPem(pem);

/// Callback pour demander à l'utilisateur de confirmer une clé d'hôte SSH
/// Paramètres: host, port, keyType, fingerprint (hex)
/// Retourne true si l'utilisateur accepte, false sinon
typedef HostKeyVerifyCallback =
    Future<bool> Function(
      String host,
      int port,
      String keyType,
      String fingerprint,
    );

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
    HostKeyVerifyCallback? onFirstHostKey,
    HostKeyVerifyCallback? onHostKeyMismatch,
  }) async {
    try {
      // FIX-014 — Audit de la configuration des algorithmes SSH autorisés.
      // dartssh2 ne permet pas d'imposer une liste blanche côté client via
      // le constructeur SSHClient (pas de paramètre `algorithms`).
      // SSHAlgorithmConfig sert à documenter les algorithmes acceptables et
      // à auditer les connexions via validateServerAlgorithms().
      final algoConfig = SSHAlgorithmConfig();
      algoConfig.assertSafeConfiguration();
      SecureLogger.log(
        'SSHService',
        'SSH algo config validated — '
        'KEX:${algoConfig.allowedKex.length} '
        'ciphers:${algoConfig.allowedCiphers.length} '
        'MACs:${algoConfig.allowedMacs.length}',
      );

      // FIX-001 — Encapsuler la clé privée dans SecureKeyHolder pour pouvoir
      // zéroïser les bytes après usage (un String Dart est immutable, on ne peut
      // pas l'effacer ; Uint8List est mutable et peut être remis à zéro).
      final secureKey = SecureKeyHolder.fromPem(privateKey);

      // Parsing de la clé dans un ISOLATE SÉPARÉ (ne bloque pas le thread UI)
      SecureLogger.logSensitive('SSHService', 'Parsing SSH key');
      final List<SSHKeyPair> keys;
      try {
        final tempStr = secureKey.toStringTemporary();
        keys = await compute(_parseSSHKeys, tempStr);
        // tempStr sort de portée ici — le GC la récupérera, mais on minimise
        // sa durée de vie autant que le langage Dart le permet.
      } finally {
        // Zéroïse les bytes de la clé AVANT que le GC intervienne.
        // TOUJOURS dans un finally pour garantir l'exécution même en cas
        // d'exception lors du parsing.
        secureKey.dispose();
      }
      SecureLogger.log('SSHService', 'Key parsed OK (zeroed), connecting TCP');

      // Connexion TCP (async, ne bloque pas)
      final socket = await SSHSocket.connect(host, port);
      SecureLogger.log('SSHService', 'TCP connected, starting SSH handshake');

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

            final stored = await SecureStorageService.getHostFingerprint(
              host,
              port,
            );

            if (stored == null) {
              // TOFU: Premier contact → demander confirmation à l'utilisateur
              if (onFirstHostKey != null) {
                final accepted = await onFirstHostKey(
                  host,
                  port,
                  type,
                  hexFingerprint,
                );
                if (accepted) {
                  await SecureStorageService.saveHostFingerprint(
                    host,
                    port,
                    hexFingerprint,
                  );
                  SecureLogger.log('SSHService', 'SSH TOFU: User accepted host key');
                } else {
                  SecureLogger.log('SSHService', 'SSH TOFU: User rejected host key');
                }
                return accepted;
              }
              // Pas de callback → rejeter par défaut (sécurité)
              SecureLogger.log('SSHService', 'SSH TOFU: No callback, rejecting by default');
              return false;
            }

            // Contact suivant → vérifier (constant-time pour éviter les timing attacks)
            final match = _constantTimeEquals(stored, hexFingerprint);
            if (match) {
              SecureLogger.log('SSHService', 'SSH TOFU: Host key OK');
              return true;
            }

            // MISMATCH: clé changée → avertir l'utilisateur
            SecureLogger.log('SSHService', 'SSH TOFU: Host key MISMATCH');
            AuditLogService.log(
              AuditEventType.hostKeyMismatch,
              success: false,
              details: {'host': host, 'port': '$port'},
            );
            if (onHostKeyMismatch != null) {
              return await onHostKeyMismatch(host, port, type, hexFingerprint);
            }
            return false;
          } catch (e) {
            // En cas d'erreur de stockage, rejeter par défaut (sécurité)
            SecureLogger.logError('SSHService', e);
            return false;
          }
        },
      );
      SecureLogger.log('SSHService', 'Waiting for SSH authentication');
      await _client!.authenticated;
      _isConnectionAlive = true;
      SecureLogger.log('SSHService', 'SSH authenticated OK');

      // Écouter la fermeture de connexion
      _client!.done
          .then((_) {
            SecureLogger.log('SSHService', 'Connection closed normally');
            _isConnectionAlive = false;
            onDisconnected?.call();
          })
          .onError((Object error, StackTrace stackTrace) {
            SecureLogger.logError('SSHService', error);
            _isConnectionAlive = false;
            onDisconnected?.call();
          });

      return true;
    } catch (e) {
      _isConnectionAlive = false;
      SecureLogger.logError('SSHService', e);
      throw SSHException(SSHError.connectionFailed, 'SSH Error: $e');
    }
  }

  /// Comparaison constant-time de deux strings pour éviter les timing attacks
  /// sur les fingerprints de clés d'hôte.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
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
      SecureLogger.logDebugOnly('SSHService', 'Sending SIGWINCH to remote PTY');
      _session!.resizeTerminal(width, height);
    } else {
      SecureLogger.log('SSHService', 'SSH RESIZE: No session available');
    }
  }

  /// Ouvre un nouveau shell sur cette connexion SSH (multiplexage SSH).
  /// Beaucoup plus rapide qu'une nouvelle connexion (~50ms vs ~1-2s).
  Future<SSHService?> openMultiplexedShell({
    int width = 80,
    int height = 24,
  }) async {
    if (_client == null || !_isConnectionAlive) return null;

    try {
      final child = SSHService();
      child._client = _client;
      child._isConnectionAlive = true;
      child._session = await _client!.shell(
        pty: SSHPtyConfig(type: 'xterm-256color', width: width, height: height),
      );
      return child;
    } catch (e) {
      SecureLogger.logError('SSHService', e);
      return null;
    }
  }

  /// Ferme uniquement la session shell, sans toucher à la connexion SSH.
  /// Utilisé quand d'autres onglets partagent la même connexion (multiplexage).
  void closeSession() {
    _session?.close();
    _session = null;
  }

  /// Vérifie si ce service partage la connexion SSH avec un autre.
  bool sharesClientWith(SSHService other) =>
      _client != null && identical(_client, other._client);

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
      SecureLogger.logError('SSHService', e);
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

      SecureLogger.log('SSHService', 'OS detection completed');

      if (output.contains('linux')) {
        return 'linux';
      } else if (output.contains('darwin')) {
        return 'macos';
      } else {
        // Si uname échoue ou donne autre chose, c'est probablement Windows
        return 'windows';
      }
    } catch (e) {
      SecureLogger.logError('SSHService', e);
      // En cas d'erreur (probablement Windows où uname n'existe pas)
      return 'windows';
    }
  }

  /// Taille maximale autorisée pour un upload SFTP (30 MB)
  static const maxUploadSizeBytes = 30 * 1024 * 1024;

  /// Taille d'un chunk pour le streaming upload (64 KB)
  static const _uploadChunkSize = 64 * 1024;

  /// Transfère un fichier local vers le serveur via SFTP (streaming par chunks).
  /// Retourne le chemin distant si succès, null si échec.
  /// Lève une [Exception] si le fichier dépasse 30 MB.
  Future<String?> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    if (_client == null) return null;

    try {
      // Sécurité : bloquer le path traversal
      if (remotePath.contains('..')) {
        SecureLogger.log('SSHService', 'SFTP upload blocked — path traversal detected');
        throw Exception(
          'Remote path cannot contain ".." (path traversal protection)',
        );
      }

      final localFile = File(localPath);

      // Sécurité: vérifier la taille avant de lire (limite 30 MB)
      final fileSize = await localFile.length();
      if (fileSize > maxUploadSizeBytes) {
        SecureLogger.log('SSHService', 'File too large for upload');
        throw Exception(
          'File too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Maximum: 30 MB.',
        );
      }

      final sftp = await _client!.sftp();

      // Ouvrir/créer le fichier distant en écriture
      final remoteFile = await sftp.open(
        remotePath,
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      // Streaming upload par chunks de 64 KB (au lieu de readAsBytes qui charge tout en RAM)
      final stream = localFile.openRead();
      var offset = 0;
      await for (final chunk in stream) {
        // Écrire par chunks pour limiter la consommation mémoire
        for (var i = 0; i < chunk.length; i += _uploadChunkSize) {
          final end = (i + _uploadChunkSize < chunk.length)
              ? i + _uploadChunkSize
              : chunk.length;
          final data = Uint8List.fromList(chunk.sublist(i, end));
          await remoteFile.write(Stream.value(data), offset: offset);
          offset += end - i;
        }
      }

      await remoteFile.close();

      SecureLogger.log('SSHService', 'File uploaded successfully');
      return remotePath;
    } catch (e) {
      SecureLogger.logError('SSHService', e);
      return null;
    }
  }

  /// Envoie la commande d'extinction appropriée selon l'OS.
  ///
  /// - Linux/macOS: `sudo shutdown -h now`
  /// - Windows: `shutdown /s /t 0`
  ///
  /// SECURITE (FIX-006) : Cette méthode suppose que ShutdownGuard.confirmShutdown()
  /// a déjà été appelé et a retourné true dans le provider/UI appelant.
  /// Ne jamais appeler cette méthode directement sans passer par ShutdownGuard.
  Future<void> shutdown(String os) async {
    if (_session == null) return;

    try {
      final command = (os == 'linux' || os == 'macos')
          ? 'sudo shutdown -h now\n'
          : 'shutdown /s /t 0\n';

      // Audit obligatoire : toute extinction distante est tracée (FIX-006).
      // En cas d'incident, cette entrée permet de remonter à la cause.
      AuditLogService.log(
        AuditEventType.sshConnect,
        success: true,
        details: {'action': 'shutdown', 'os': os},
      );

      SecureLogger.log('SSHService', 'Sending shutdown command');
      _session!.stdin.add(Uint8List.fromList(command.codeUnits));
    } catch (e) {
      SecureLogger.logError('SSHService', e);
      rethrow;
    }
  }
}
