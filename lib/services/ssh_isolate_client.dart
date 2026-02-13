import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ssh_isolate_messages.dart';
import 'ssh_isolate_worker.dart';
import 'ssh_service.dart';

/// Facade côté main-isolate pour communiquer avec le background SSH isolate.
///
/// Expose des méthodes async propres utilisées par le SSHNotifier (provider).
/// Toutes les opérations SSH lourdes sont déléguées au worker isolate via
/// SendPort/ReceivePort, gardant le thread UI libre.
class SSHIsolateClient {
  // ── State ──────────────────────────────────────────────────────────────

  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _receivePort;
  StreamSubscription<dynamic>? _receiveSubscription;

  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<dynamic>? _exitSubscription;

  /// Stdout stream controllers par tab (broadcast avec buffer initial).
  final Map<String, StreamController<Uint8List>> _stdoutControllers = {};

  /// Buffer des données stdout reçues avant qu'un listener ne s'abonne.
  /// Évite de perdre les premières données (prompt bashrc, ~, etc.)
  /// quand le TerminalView n'est pas encore monté.
  final Map<String, List<Uint8List>> _stdoutBuffers = {};

  /// Requêtes en attente de réponse, identifiées par requestId.
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Timers de timeout annulables pour les requêtes en attente.
  final Map<String, Timer> _pendingTimers = {};

  bool _isSpawned = false;

  // ── Callbacks (définis par SSHNotifier avant connexion) ────────────────

  /// Callback TOFU : première clé d'hôte inconnue.
  HostKeyVerifyCallback? onFirstHostKey;

  /// Callback TOFU : clé d'hôte différente de celle enregistrée.
  HostKeyVerifyCallback? onHostKeyMismatch;

  /// Tab connectée avec succès.
  void Function(String tabId)? onConnected;

  /// Échec de connexion.
  void Function(String error, String? tabId)? onConnectionFailed;

  /// Nouvelle tab créée.
  void Function(String tabId)? onTabCreated;

  /// Échec de création de tab.
  void Function(String? error)? onTabCreateFailed;

  /// Tab fermée.
  void Function(String tabId)? onTabClosed;

  /// Une tab déconnectée.
  void Function(String tabId)? onDisconnected;

  /// Toutes les tabs déconnectées.
  void Function()? onAllDisconnected;

  /// Tab morte (stream fermé).
  void Function(String tabId)? onTabDead;

  /// Reconnexion en cours.
  void Function(int attempt, int maxAttempts)? onReconnecting;

  /// Reconnexion réussie.
  void Function(String tabId)? onReconnected;

  /// Erreur générique.
  void Function(String error, String? requestId)? onError;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Crée et démarre le background isolate SSH.
  ///
  /// Le premier message reçu du worker est son [SendPort].
  /// Les messages suivants sont des événements dispatchés par
  /// [_handleWorkerMessage].
  Future<void> spawn() async {
    if (_isSpawned) return;

    _receivePort = ReceivePort();

    final rootToken = RootIsolateToken.instance!;
    final completer = Completer<SendPort>();

    _receiveSubscription = _receivePort!.listen((message) {
      if (!completer.isCompleted) {
        // Premier message = SendPort du worker.
        if (message is SendPort) {
          completer.complete(message);
        } else {
          completer.completeError(
            Exception('SSHClient: expected SendPort, got ${message.runtimeType}'),
          );
        }
      } else {
        _handleWorkerMessage(message);
      }
    });

    _isolate = await Isolate.spawn(
      sshIsolateEntry,
      [_receivePort!.sendPort, rootToken],
    );

    // Écoute des erreurs / exit du background isolate.
    _errorPort = ReceivePort();
    _isolate!.addErrorListener(_errorPort!.sendPort);
    _errorSubscription = _errorPort!.listen((error) {
      if (kDebugMode) {
        debugPrint('SSHClient: isolate error: $error');
      }
      _onIsolateCrash('Isolate error: $error');
    });

    _exitPort = ReceivePort();
    _isolate!.addOnExitListener(_exitPort!.sendPort);
    _exitSubscription = _exitPort!.listen((_) {
      if (kDebugMode) {
        debugPrint('SSHClient: isolate exited');
      }
      _onIsolateCrash('Isolate exited unexpectedly');
    });

    _workerSendPort = await completer.future;
    _isSpawned = true;

    if (kDebugMode) {
      debugPrint('SSHClient: background isolate spawned');
    }
  }

  /// Nettoyage après crash ou exit inattendu de l'isolate.
  void _onIsolateCrash(String reason) {
    if (kDebugMode) {
      debugPrint('SSHClient: crash cleanup — $reason');
    }

    _isSpawned = false;
    _workerSendPort = null;

    // Fermer tous les stdout controllers.
    for (final controller in _stdoutControllers.values) {
      controller.close();
    }
    _stdoutControllers.clear();

    // Annuler tous les timers de timeout.
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();

    // Compléter toutes les requêtes en attente avec une erreur.
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          Exception('SSHClient: isolate crashed — $reason'),
        );
      }
    }
    _pendingRequests.clear();

    onAllDisconnected?.call();
  }

  // ── Message dispatch ───────────────────────────────────────────────────

  /// Dispatche un message reçu du worker vers le callback approprié.
  void _handleWorkerMessage(dynamic message) {
    if (message is! Map) {
      if (kDebugMode) {
        debugPrint('SSHClient: unexpected message type: ${message.runtimeType}');
      }
      return;
    }

    final map = Map<String, dynamic>.from(message);
    final type = map['type'] as String?;

    if (kDebugMode) {
      debugPrint('SSHClient: received event: $type');
    }

    switch (type) {
      case IsolateEvent.connected:
        final tabId = map['tabId'] as String;
        _completePendingRequest(map['requestId'] as String?, tabId);
        onConnected?.call(tabId);

      case IsolateEvent.connectionFailed:
        final error = map['error'] as String;
        final tabId = map['tabId'] as String?;
        _completePendingRequest(
          map['requestId'] as String?,
          null,
          error: error,
        );
        onConnectionFailed?.call(error, tabId);

      case IsolateEvent.tabCreated:
        final tabId = map['tabId'] as String;
        _completePendingRequest(map['requestId'] as String?, tabId);
        onTabCreated?.call(tabId);

      case IsolateEvent.tabCreateFailed:
        final error = map['error'] as String?;
        _completePendingRequest(
          map['requestId'] as String?,
          null,
          error: error,
        );
        onTabCreateFailed?.call(error);

      case IsolateEvent.stdout:
        final tabId = map['tabId'] as String;
        final data = map['data'] as Uint8List;
        _addStdoutData(tabId, data);

      case IsolateEvent.tabClosed:
        final tabId = map['tabId'] as String;
        _closeStdoutController(tabId);
        onTabClosed?.call(tabId);

      case IsolateEvent.disconnected:
        final tabId = map['tabId'] as String;
        _closeStdoutController(tabId);
        onDisconnected?.call(tabId);

      case IsolateEvent.allDisconnected:
        // Ne PAS fermer les stdout controllers ici — le provider décide
        // de la politique de reconnexion avant de libérer les ressources.
        onAllDisconnected?.call();

      case IsolateEvent.hostKeyVerify:
        _handleHostKeyVerify(map);

      case IsolateEvent.commandResult:
        final result = map['output'] as String?;
        _completePendingRequest(map['requestId'] as String?, result);

      case IsolateEvent.uploadResult:
        final result = map['remotePath'] as String?;
        _completePendingRequest(map['requestId'] as String?, result);

      case IsolateEvent.osDetected:
        final os = map['os'] as String?;
        _completePendingRequest(map['requestId'] as String?, os);

      case IsolateEvent.reconnecting:
        final attempt = map['attempt'] as int? ?? 1;
        final maxAttempts = map['maxAttempts'] as int? ?? 3;
        onReconnecting?.call(attempt, maxAttempts);

      case IsolateEvent.reconnected:
        final tabId = map['tabId'] as String;
        onReconnected?.call(tabId);

      case IsolateEvent.tabDead:
        final tabId = map['tabId'] as String;
        onTabDead?.call(tabId);

      case IsolateEvent.testConnectResult:
        final success = map['success'] as bool;
        _completePendingRequest(map['requestId'] as String?, success);

      case IsolateEvent.error:
        final error = map['error'] as String;
        final requestId = map['requestId'] as String?;
        _completePendingRequest(requestId, null, error: error);
        onError?.call(error, requestId);

      default:
        if (kDebugMode) {
          debugPrint('SSHClient: unknown event type: $type');
        }
    }
  }

  /// Gère la vérification TOFU de clé d'hôte de manière asynchrone.
  void _handleHostKeyVerify(Map<String, dynamic> map) {
    final requestId = map['requestId'] as String;
    final host = map['host'] as String;
    final port = map['port'] as int;
    final keyType = map['keyType'] as String;
    final fingerprint = map['fingerprint'] as String;
    final isNew = map['isNew'] as bool;

    final callback = isNew ? onFirstHostKey : onHostKeyMismatch;

    if (callback == null) {
      // Pas de callback → auto-accept.
      if (kDebugMode) {
        debugPrint('SSHClient: no TOFU callback, auto-accepting host key');
      }
      _workerSendPort?.send(
        buildHostKeyResponseMessage(requestId: requestId, accepted: true),
      );
      return;
    }

    // Appel async sans bloquer le listener.
    () async {
      try {
        final accepted = await callback(host, port, keyType, fingerprint);
        _workerSendPort?.send(
          buildHostKeyResponseMessage(
            requestId: requestId,
            accepted: accepted,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SSHClient: TOFU callback error: $e');
        }
        // En cas d'erreur, rejeter la clé par sécurité.
        _workerSendPort?.send(
          buildHostKeyResponseMessage(requestId: requestId, accepted: false),
        );
      }
    }();
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Connecte au serveur SSH. Le résultat arrive via [onConnected] /
  /// [onConnectionFailed].
  Future<void> connect({
    required String host,
    required String username,
    required String keyId,
    required String sessionId,
    required String tabId,
    int port = 22,
  }) async {
    await _ensureSpawned();

    final message = buildConnectMessage(
      host: host,
      username: username,
      keyId: keyId,
      sessionId: sessionId,
      port: port,
      tabId: tabId,
    );

    final requestId = message['requestId'] as String;
    // Timeout long (120s) car inclut le handshake SSH + dialogue TOFU (acceptation de clé)
    final completer = _createPendingRequest(
      requestId,
      timeout: const Duration(seconds: 120),
      debugLabel: 'connect',
    );

    _workerSendPort!.send(message);

    // Attendre la réponse (connected ou connectionFailed).
    await completer.future;
  }

  /// Crée une nouvelle tab SSH. Retourne le tabId ou null en cas d'échec.
  Future<String?> createTab({required String keyId, required String tabId}) async {
    await _ensureSpawned();

    final message = buildCreateTabMessage(keyId: keyId, tabId: tabId);
    final requestId = message['requestId'] as String;
    final completer = _createPendingRequest(requestId, debugLabel: 'createTab');

    _workerSendPort!.send(message);

    final result = await completer.future;
    return result as String?;
  }

  /// Ferme une tab SSH.
  void closeTab(String tabId) {
    _closeStdoutController(tabId);
    _workerSendPort?.send(buildCloseTabMessage(tabId: tabId));
  }

  /// Envoie des données stdin vers une tab. Synchrone et rapide.
  void write(String tabId, Uint8List data) {
    _workerSendPort?.send(buildWriteMessage(tabId: tabId, data: data));
  }

  /// Redimensionne le terminal d'une tab.
  void resize(String tabId, int width, int height) {
    _workerSendPort?.send(
      buildResizeMessage(tabId: tabId, width: width, height: height),
    );
  }

  /// Déconnecte toutes les sessions SSH.
  Future<void> disconnect() async {
    if (kDebugMode) debugPrint('SSHClient: disconnect() — cancelling ${_pendingRequests.length} pending requests');

    // Annuler tous les timers de timeout.
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();

    // Annuler toutes les requêtes en attente (connect, createTab, etc.)
    // pour éviter qu'un ancien connect() ne timeout plus tard et
    // n'écrase l'état d'une nouvelle connexion.
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          Exception('SSHClient: disconnected while request pending'),
        );
      }
    }
    _pendingRequests.clear();

    _workerSendPort?.send(buildDisconnectMessage());
  }

  /// Upload un fichier via SFTP. Retourne le chemin distant ou null.
  Future<String?> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    await _ensureSpawned();

    final message = buildUploadFileMessage(
      localPath: localPath,
      remotePath: remotePath,
    );
    final requestId = message['requestId'] as String;
    final completer = _createPendingRequest(requestId, debugLabel: 'uploadFile');

    _workerSendPort!.send(message);

    final result = await completer.future;
    return result as String?;
  }

  /// Exécute une commande dans une tab. Retourne la sortie ou null.
  Future<String?> executeCommand({
    required String tabId,
    required String command,
  }) async {
    await _ensureSpawned();

    final message = buildExecuteCommandMessage(
      tabId: tabId,
      command: command,
    );
    final requestId = message['requestId'] as String;
    final completer = _createPendingRequest(requestId, debugLabel: 'executeCommand');

    _workerSendPort!.send(message);

    final result = await completer.future;
    return result as String?;
  }

  /// Détecte l'OS distant. Retourne le nom de l'OS ou null.
  Future<String?> detectOS({required String tabId}) async {
    await _ensureSpawned();

    final message = buildDetectOSMessage(tabId: tabId);
    final requestId = message['requestId'] as String;
    final completer = _createPendingRequest(requestId, debugLabel: 'detectOS');

    _workerSendPort!.send(message);

    final result = await completer.future;
    return result as String?;
  }

  /// Envoie une commande d'arrêt au serveur distant.
  void shutdown({required String tabId, required String os}) {
    _workerSendPort?.send(buildShutdownMessage(tabId: tabId, os: os));
  }

  /// Met en pause le monitoring de connexion.
  void pauseMonitor() {
    _workerSendPort?.send(buildPauseMonitorMessage());
  }

  /// Reprend le monitoring de connexion.
  void resumeMonitor() {
    _workerSendPort?.send(buildResumeMonitorMessage());
  }

  /// Demande la reconnexion d'une tab spécifique.
  void reconnectTab(String tabId) {
    _workerSendPort?.send(buildReconnectTabMessage(tabId: tabId));
  }

  /// Teste la connectivité SSH sans créer de tab ni modifier l'état.
  /// Utilisé par le polling WOL pour vérifier si le PC est réveillé.
  /// Retourne true si la connexion SSH réussit, false sinon.
  Future<bool> testConnect({
    required String host,
    required String username,
    required String keyId,
    required int port,
  }) async {
    await _ensureSpawned();

    final message = buildTestConnectMessage(
      host: host,
      username: username,
      keyId: keyId,
      port: port,
    );
    final requestId = message['requestId'] as String;
    final completer = _createPendingRequest(
      requestId,
      timeout: const Duration(seconds: 30),
      debugLabel: 'testConnect',
    );

    _workerSendPort?.send(message);

    try {
      final result = await completer.future;
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Retourne le stream de sortie stdout pour une tab donnée.
  Stream<Uint8List> getOutputStream(String tabId) {
    return _getOrCreateStdoutController(tabId).stream;
  }

  /// Libère toutes les ressources : isolate, ports, controllers.
  Future<void> dispose() async {
    if (kDebugMode) {
      debugPrint('SSHClient: disposing');
    }

    // Demander au worker de se cleanup.
    _workerSendPort?.send(buildDisposeMessage());

    // Nettoyer les ports d'erreur et d'exit.
    await _errorSubscription?.cancel();
    _errorPort?.close();
    _errorPort = null;
    await _exitSubscription?.cancel();
    _exitPort?.close();
    _exitPort = null;

    // Annuler la souscription sur le receive port.
    await _receiveSubscription?.cancel();
    _receiveSubscription = null;

    // Fermer le receive port.
    _receivePort?.close();
    _receivePort = null;

    // Tuer l'isolate.
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    // Fermer tous les stdout controllers.
    _closeAllStdoutControllers();

    // Annuler tous les timers de timeout.
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();

    // Compléter toutes les requêtes en attente.
    for (final entry in _pendingRequests.entries) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(
          Exception('SSHClient: disposed while request pending'),
        );
      }
    }
    _pendingRequests.clear();

    _workerSendPort = null;
    _isSpawned = false;

    if (kDebugMode) {
      debugPrint('SSHClient: disposed');
    }
  }

  // ── Helpers privés ─────────────────────────────────────────────────────

  /// S'assure que l'isolate est spawné, le crée sinon.
  Future<void> _ensureSpawned() async {
    if (!_isSpawned) {
      await spawn();
    }
  }

  /// Retourne ou crée un broadcast StreamController pour le stdout d'une tab.
  ///
  /// Utilise un buffer pour stocker les données reçues avant qu'un listener
  /// ne s'abonne. Quand le premier listener arrive, les données bufferisées
  /// sont rejouées automatiquement.
  StreamController<Uint8List> _getOrCreateStdoutController(String tabId) {
    return _stdoutControllers.putIfAbsent(tabId, () {
      final controller = StreamController<Uint8List>.broadcast(
        onListen: () {
          // Premier listener : rejouer les données bufferisées.
          final buffer = _stdoutBuffers.remove(tabId);
          if (buffer != null && buffer.isNotEmpty) {
            final ctrl = _stdoutControllers[tabId];
            if (ctrl != null && !ctrl.isClosed) {
              for (final chunk in buffer) {
                ctrl.add(chunk);
              }
            }
          }
        },
      );
      return controller;
    });
  }

  /// Ajoute des données stdout pour une tab, avec buffering si pas de listener.
  void _addStdoutData(String tabId, Uint8List data) {
    final controller = _getOrCreateStdoutController(tabId);
    if (controller.isClosed) return;

    if (controller.hasListener) {
      controller.add(data);
    } else {
      // Pas encore de listener → bufferiser.
      _stdoutBuffers.putIfAbsent(tabId, () => []).add(data);
    }
  }

  /// Ferme et supprime le stdout controller d'une tab.
  void _closeStdoutController(String tabId) {
    _stdoutBuffers.remove(tabId);
    final controller = _stdoutControllers.remove(tabId);
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  /// Ferme tous les stdout controllers.
  void _closeAllStdoutControllers() {
    _stdoutBuffers.clear();
    for (final controller in _stdoutControllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _stdoutControllers.clear();
  }

  /// Crée un Completer pour une requête en attente avec timeout annulable.
  ///
  /// Le timeout par défaut est de 30 secondes pour les opérations courtes.
  /// Les opérations longues (connect avec TOFU) utilisent un timeout plus long.
  /// Utilise un Timer annulable (au lieu de Future.delayed) pour permettre
  /// l'annulation du timeout quand la requête est complétée.
  Completer<dynamic> _createPendingRequest(
    String requestId, {
    Duration timeout = const Duration(seconds: 30),
    String debugLabel = 'unknown',
  }) {
    final completer = Completer<dynamic>();

    _pendingRequests[requestId] = completer;

    // Timeout annulable : compléter avec une erreur si pas de réponse à temps.
    _pendingTimers[requestId] = Timer(timeout, () {
      _pendingTimers.remove(requestId);
      if (_pendingRequests.containsKey(requestId) && !completer.isCompleted) {
        if (kDebugMode) {
          debugPrint('SSHClient: request $requestId ($debugLabel) timed out after ${timeout.inSeconds}s');
        }
        completer.completeError(
          TimeoutException('SSHClient: request timed out', timeout),
        );
        _pendingRequests.remove(requestId);
      }
    });

    return completer;
  }

  /// Complète une requête en attente si elle existe.
  ///
  /// Si [error] est fourni, complète avec une erreur.
  void _completePendingRequest(
    String? requestId,
    dynamic result, {
    String? error,
  }) {
    if (requestId == null) return;

    // Annuler le timer de timeout associé à cette requête.
    _pendingTimers.remove(requestId)?.cancel();

    final completer = _pendingRequests.remove(requestId);
    if (completer == null || completer.isCompleted) return;

    if (error != null) {
      completer.completeError(Exception(error));
    } else {
      completer.complete(result);
    }
  }
}
