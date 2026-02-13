import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ssh_service.dart';
import 'ssh_isolate_messages.dart';
import 'secure_storage_service.dart';
import '../core/security/secure_buffer.dart';

/// Top-level entry point for Isolate.spawn.
///
/// args[0] = SendPort to communicate back to the main isolate
/// args[1] = RootIsolateToken for platform channel access in background
void sshIsolateEntry(List<dynamic> args) {
  final SendPort mainSendPort = args[0] as SendPort;
  final RootIsolateToken rootToken = args[1] as RootIsolateToken;

  // Initialize platform channels for background isolate
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

  final worker = SSHIsolateWorker(mainSendPort);
  worker.start();
}

/// Background isolate worker that manages ALL SSH connections.
///
/// Moves CPU-intensive SSH crypto operations (key parsing, handshake)
/// off the main UI thread. Communicates with the main isolate via
/// SendPort/ReceivePort using the message protocol defined in
/// [ssh_isolate_messages.dart].
class SSHIsolateWorker {
  final SendPort _mainSendPort;
  late final ReceivePort _receivePort;

  /// SSH services keyed by tab ID
  final Map<String, SSHService> _tabServices = {};

  /// Stdout stream subscriptions keyed by tab ID (for cleanup)
  final Map<String, StreamSubscription<Uint8List>> _stdoutSubscriptions = {};

  // Connection info stored for reconnection and new tab creation
  String? _connectionHost;
  String? _connectionUsername;
  String? _connectionKeyId;
  int _connectionPort = 22;

  /// Connection health monitor (checks every 10 seconds)
  Timer? _connectionCheckTimer;

  /// Pending TOFU host key verification requests awaiting user response
  final Map<String, Completer<bool>> _pendingHostKeyRequests = {};

  // Resize throttle state (same logic as ssh_provider.dart)
  static const _resizeThrottleMs = 150;
  final Map<String, (int, int)> _pendingResizes = {};
  final Map<String, (int, int)> _lastSentSizes = {};
  Timer? _resizeThrottleTimer;
  DateTime? _lastResizeSent;

  // Reconnection state (used by reconnectAll command)
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 3;
  static const _reconnectDelay = Duration(seconds: 5);

  SSHIsolateWorker(this._mainSendPort);

  /// Creates the ReceivePort, sends it back to the main isolate,
  /// and starts listening for commands.
  void start() {
    _receivePort = ReceivePort();
    // Send our ReceivePort's SendPort back so the main isolate can talk to us
    _mainSendPort.send(_receivePort.sendPort);

    _receivePort.listen(_handleMessage);

    if (kDebugMode) debugPrint('SSHWorker: Started and listening for commands');
  }

  // ============================================================
  // Main message dispatcher
  // ============================================================

  void _handleMessage(dynamic message) {
    if (message is! Map<String, dynamic>) {
      if (kDebugMode) debugPrint('SSHWorker: Ignoring non-map message: $message');
      return;
    }

    final type = message['type'] as String?;
    if (type == null) {
      if (kDebugMode) debugPrint('SSHWorker: Ignoring message without type');
      return;
    }

    switch (type) {
      case IsolateCommand.connect:
        _handleConnect(message);
      case IsolateCommand.createTab:
        _handleCreateTab(message);
      case IsolateCommand.closeTab:
        _handleCloseTab(message);
      case IsolateCommand.write:
        _handleWrite(message);
      case IsolateCommand.resize:
        _handleResize(message);
      case IsolateCommand.disconnect:
        _handleDisconnect();
      case IsolateCommand.uploadFile:
        _handleUploadFile(message);
      case IsolateCommand.executeCommand:
        _handleExecuteCommand(message);
      case IsolateCommand.detectOS:
        _handleDetectOS(message);
      case IsolateCommand.shutdown:
        _handleShutdown(message);
      case IsolateCommand.pauseMonitor:
        _connectionCheckTimer?.cancel();
        _connectionCheckTimer = null;
        if (kDebugMode) debugPrint('SSHWorker: Connection monitor paused');
      case IsolateCommand.resumeMonitor:
        _startConnectionMonitor();
        if (kDebugMode) debugPrint('SSHWorker: Connection monitor resumed');
      case IsolateCommand.hostKeyResponse:
        _handleHostKeyResponse(message);
      case IsolateCommand.reconnectTab:
        _handleReconnectTab(message);
      case IsolateCommand.reconnectAll:
        _handleReconnectAll(message);
      case IsolateCommand.testConnect:
        _handleTestConnect(message);
      case IsolateCommand.dispose:
        _handleDispose();
      default:
        if (kDebugMode) debugPrint('SSHWorker: Unknown command type: $type');
    }
  }

  // ============================================================
  // Command handlers
  // ============================================================

  /// Handles initial SSH connection.
  /// Creates an SSHService, connects, starts shell, subscribes to stdout.
  Future<void> _handleConnect(Map<String, dynamic> message) async {
    final host = message['host'] as String;
    final username = message['username'] as String;
    final keyId = message['keyId'] as String;
    final port = message['port'] as int? ?? 22;
    final tabId = message['tabId'] as String;

    // Store connection info for future reconnection/new tabs
    _connectionHost = host;
    _connectionUsername = username;
    _connectionKeyId = keyId;
    _connectionPort = port;

    final requestId = message['requestId'] as String?;

    if (kDebugMode) debugPrint('SSHWorker: Connecting to $host:$port as $username (tab: $tabId)');

    // SECURITY: Read private key directly from SecureStorage in the worker
    // to avoid transmitting it via SendPort (which creates non-erasable copies)
    final privateKeyRaw = await SecureStorageService.getPrivateKey(keyId);
    if (privateKeyRaw == null || privateKeyRaw.isEmpty) {
      _mainSendPort.send({
        'type': IsolateEvent.connectionFailed,
        'requestId': requestId,
        'error': 'SSH key not found in secure storage',
        'tabId': tabId,
      });
      return;
    }

    final keyBuffer = SecureBuffer.fromString(privateKeyRaw);
    try {
      final service = SSHService();

      final success = await service.connect(
        host: host,
        username: username,
        privateKey: keyBuffer.toUtf8String(),
        port: port,
        onFirstHostKey: (host, port, keyType, fingerprint) async {
          return _requestHostKeyVerification(
            host: host,
            port: port,
            keyType: keyType,
            fingerprint: fingerprint,
            isNew: true,
          );
        },
        onHostKeyMismatch: (host, port, keyType, fingerprint) async {
          return _requestHostKeyVerification(
            host: host,
            port: port,
            keyType: keyType,
            fingerprint: fingerprint,
            isNew: false,
          );
        },
      );

      if (success) {
        await service.startShell();
        _tabServices[tabId] = service;
        _subscribeToStdout(tabId, service);
        _startConnectionMonitor();
        _reconnectAttempts = 0;

        _mainSendPort.send({
          'type': IsolateEvent.connected,
          'requestId': requestId,
          'tabId': tabId,
        });

        if (kDebugMode) debugPrint('SSHWorker: Connected successfully (tab: $tabId)');
      } else {
        _mainSendPort.send({
          'type': IsolateEvent.connectionFailed,
          'requestId': requestId,
          'error': 'ssh:connectionFailed',
          'tabId': tabId,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: Connection failed: $e');
      final errorMsg = e.toString();
      _mainSendPort.send({
        'type': IsolateEvent.connectionFailed,
        'requestId': requestId,
        'error': errorMsg.contains('timeout') ? 'ssh:timeout' : 'ssh:connectionFailed',
        'tabId': tabId,
      });
    } finally {
      keyBuffer.dispose();
    }
  }

  /// Sends a host key verification request to the main isolate and waits
  /// for the user's response via a Completer.
  ///
  /// The TOFU logic (reading/saving fingerprints) is handled inside
  /// SSHService.connect's onVerifyHostKey callback, which uses
  /// SecureStorageService directly (since BackgroundIsolateBinaryMessenger
  /// is initialized). Only the USER DIALOG round-trips to the main isolate.
  Future<bool> _requestHostKeyVerification({
    required String host,
    required int port,
    required String keyType,
    required String fingerprint,
    required bool isNew,
  }) async {
    final requestId = generateRequestId();
    final completer = Completer<bool>();
    _pendingHostKeyRequests[requestId] = completer;

    _mainSendPort.send({
      'type': IsolateEvent.hostKeyVerify,
      'requestId': requestId,
      'host': host,
      'port': port,
      'keyType': keyType,
      'fingerprint': fingerprint,
      'isNew': isNew,
    });

    if (kDebugMode) debugPrint('SSHWorker: Waiting for host key verification (requestId: $requestId)');

    final accepted = await completer.future;
    _pendingHostKeyRequests.remove(requestId);

    if (kDebugMode) debugPrint('SSHWorker: Host key ${accepted ? "accepted" : "rejected"} (requestId: $requestId)');

    return accepted;
  }

  /// Handles the host key response from the main isolate.
  void _handleHostKeyResponse(Map<String, dynamic> message) {
    final requestId = message['requestId'] as String?;
    final accepted = message['accepted'] as bool? ?? false;

    if (requestId == null) {
      if (kDebugMode) debugPrint('SSHWorker: hostKeyResponse without requestId');
      return;
    }

    final completer = _pendingHostKeyRequests[requestId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(accepted);
    } else {
      if (kDebugMode) debugPrint('SSHWorker: No pending request for requestId: $requestId');
    }
  }

  /// Subscribes to a service's stdout stream and forwards data to the main isolate.
  void _subscribeToStdout(String tabId, SSHService service) {
    // Cancel any existing subscription for this tab
    _stdoutSubscriptions[tabId]?.cancel();

    final session = service.session;
    if (session == null) {
      if (kDebugMode) debugPrint('SSHWorker: No session for tab $tabId, cannot subscribe to stdout');
      return;
    }

    try {
      final subscription = session.stdout.listen(
        (Uint8List data) {
          _mainSendPort.send({
            'type': IsolateEvent.stdout,
            'tabId': tabId,
            'data': data,
          });
        },
        onError: (error) {
          if (kDebugMode) debugPrint('SSHWorker: stdout error for tab $tabId: $error');
        },
        onDone: () {
          if (kDebugMode) debugPrint('SSHWorker: stdout stream closed for tab $tabId');
          _mainSendPort.send({
            'type': IsolateEvent.tabDead,
            'tabId': tabId,
          });
        },
      );

      _stdoutSubscriptions[tabId] = subscription;
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: Failed to subscribe to stdout for tab $tabId: $e');
    }
  }

  /// Creates a new tab, trying multiplexing first, then a full connection.
  Future<void> _handleCreateTab(Map<String, dynamic> message) async {
    final keyId = message['keyId'] as String? ?? _connectionKeyId;
    final tabId = message['tabId'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final requestId = message['requestId'] as String?;

    if (kDebugMode) debugPrint('SSHWorker: Creating new tab $tabId');

    try {
      // Fast path: try SSH multiplexing on an existing connection (~50ms)
      final existingService = _tabServices.values
          .where((s) => s.isConnected)
          .firstOrNull;

      if (existingService != null) {
        final multiplexed = await existingService.openMultiplexedShell();
        if (multiplexed != null) {
          _tabServices[tabId] = multiplexed;
          _subscribeToStdout(tabId, multiplexed);

          _mainSendPort.send({
            'type': IsolateEvent.tabCreated,
            'requestId': requestId,
            'tabId': tabId,
          });

          if (kDebugMode) debugPrint('SSHWorker: Tab $tabId created via SSH multiplexing (fast)');
          return;
        }
        if (kDebugMode) debugPrint('SSHWorker: Multiplexing failed, falling back to new connection');
      }

      // Slow path: new full SSH connection (~1-2s)
      if (_connectionHost == null || _connectionUsername == null || keyId == null) {
        _mainSendPort.send({
          'type': IsolateEvent.tabCreateFailed,
          'requestId': requestId,
          'tabId': tabId,
          'error': 'No connection info available',
        });
        return;
      }

      final privateKeyRaw = await SecureStorageService.getPrivateKey(keyId);
      if (privateKeyRaw == null || privateKeyRaw.isEmpty) {
        if (kDebugMode) debugPrint('SSHWorker: Failed to retrieve private key for tab creation');
        _mainSendPort.send({
          'type': IsolateEvent.tabCreateFailed,
          'requestId': requestId,
          'tabId': tabId,
          'error': 'Private key not found',
        });
        return;
      }

      final keyBuffer = SecureBuffer.fromString(privateKeyRaw);
      try {
        final newService = SSHService();
        final success = await newService.connect(
          host: _connectionHost!,
          username: _connectionUsername!,
          privateKey: keyBuffer.toUtf8String(),
          port: _connectionPort,
        );

        if (success) {
          await newService.startShell();
          _tabServices[tabId] = newService;
          _subscribeToStdout(tabId, newService);

          _mainSendPort.send({
            'type': IsolateEvent.tabCreated,
            'requestId': requestId,
            'tabId': tabId,
          });

          if (kDebugMode) debugPrint('SSHWorker: Tab $tabId created via new connection (slow)');
        } else {
          _mainSendPort.send({
            'type': IsolateEvent.tabCreateFailed,
            'requestId': requestId,
            'tabId': tabId,
            'error': 'Connection failed',
          });
        }
      } finally {
        keyBuffer.dispose();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: Failed to create tab $tabId: $e');
      _mainSendPort.send({
        'type': IsolateEvent.tabCreateFailed,
        'requestId': requestId,
        'tabId': tabId,
        'error': e.toString(),
      });
    }
  }

  /// Closes a single tab. If it shares a connection with other tabs,
  /// only closes the session; otherwise disconnects entirely.
  Future<void> _handleCloseTab(Map<String, dynamic> message) async {
    final tabId = message['tabId'] as String?;
    if (tabId == null) return;

    if (kDebugMode) debugPrint('SSHWorker: Closing tab $tabId');

    // Cancel stdout subscription
    await _stdoutSubscriptions[tabId]?.cancel();
    _stdoutSubscriptions.remove(tabId);

    final service = _tabServices[tabId];
    if (service != null) {
      // Check if other tabs share the same SSH client (multiplexing)
      final hasSharedConnection = _tabServices.entries
          .any((e) => e.key != tabId && service.sharesClientWith(e.value));

      if (hasSharedConnection) {
        service.closeSession();
      } else {
        await service.disconnect();
      }
      _tabServices.remove(tabId);
    }

    // Clean up resize state for this tab
    _pendingResizes.remove(tabId);
    _lastSentSizes.remove(tabId);

    _mainSendPort.send({
      'type': IsolateEvent.tabClosed,
      'tabId': tabId,
    });

    // If no more tabs remain, stop monitor and notify
    if (_tabServices.isEmpty) {
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
      _mainSendPort.send({
        'type': IsolateEvent.allDisconnected,
      });
      if (kDebugMode) debugPrint('SSHWorker: All tabs closed, connection monitor stopped');
    }
  }

  /// HIGH PERFORMANCE write path. No async, just pushes data to stdin.
  void _handleWrite(Map<String, dynamic> message) {
    final tabId = message['tabId'] as String?;
    final data = message['data'];
    if (tabId == null || data == null) return;

    final service = _tabServices[tabId];
    final session = service?.session;
    if (session != null) {
      if (data is Uint8List) {
        session.stdin.add(data);
      } else if (data is List<int>) {
        session.stdin.add(Uint8List.fromList(data));
      }
    }
  }

  /// Throttled resize to avoid spamming SIGWINCH during keyboard animation.
  /// Same logic as resizeTerminalForTab/flushPendingResizes in ssh_provider.dart.
  void _handleResize(Map<String, dynamic> message) {
    final tabId = message['tabId'] as String?;
    final width = message['width'] as int?;
    final height = message['height'] as int?;
    if (tabId == null || width == null || height == null) return;

    // Ignore invalid dimensions
    if (width <= 0 || height <= 0) return;

    // Check if dimensions are identical to last sent
    final lastSent = _lastSentSizes[tabId];
    if (lastSent != null && lastSent.$1 == width && lastSent.$2 == height) {
      return; // No change, ignore
    }

    // Store requested dimensions for this tab
    _pendingResizes[tabId] = (width, height);

    // Calculate time since last resize sent
    final now = DateTime.now();
    final timeSinceLastSend = _lastResizeSent == null
        ? _resizeThrottleMs
        : now.difference(_lastResizeSent!).inMilliseconds;

    if (timeSinceLastSend >= _resizeThrottleMs) {
      // Enough time elapsed: send immediately
      _flushPendingResizes();
    } else {
      // Not enough time: schedule send after remaining delay
      _resizeThrottleTimer?.cancel();
      final remainingDelay = _resizeThrottleMs - timeSinceLastSend;
      _resizeThrottleTimer = Timer(Duration(milliseconds: remainingDelay), () {
        _flushPendingResizes();
      });
    }
  }

  /// Sends all pending resize commands.
  void _flushPendingResizes() {
    _lastResizeSent = DateTime.now();

    for (final entry in _pendingResizes.entries) {
      final tabId = entry.key;
      final (width, height) = entry.value;

      // Double-check dimensions haven't been sent already
      final lastSent = _lastSentSizes[tabId];
      if (lastSent != null && lastSent.$1 == width && lastSent.$2 == height) {
        continue; // No change
      }

      if (kDebugMode) debugPrint('SSHWorker: PTY RESIZE SEND: tab=$tabId, ${width}x$height');
      _lastSentSizes[tabId] = (width, height);

      _tabServices[tabId]?.resizeTerminal(width, height);
    }
    _pendingResizes.clear();
  }

  /// Disconnects all SSH services and stops timers.
  Future<void> _handleDisconnect() async {
    if (kDebugMode) debugPrint('SSHWorker: Disconnecting all services');

    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _resizeThrottleTimer?.cancel();
    _resizeThrottleTimer = null;

    // Cancel all stdout subscriptions
    for (final sub in _stdoutSubscriptions.values) {
      await sub.cancel();
    }
    _stdoutSubscriptions.clear();

    // Disconnect all services
    for (final service in _tabServices.values) {
      await service.disconnect();
    }
    _tabServices.clear();

    // Clean up resize state
    _pendingResizes.clear();
    _lastSentSizes.clear();

    _mainSendPort.send({
      'type': IsolateEvent.allDisconnected,
    });
  }

  /// Uploads a file via SFTP using the first connected service.
  Future<void> _handleUploadFile(Map<String, dynamic> message) async {
    final requestId = message['requestId'] as String?;
    final localPath = message['localPath'] as String?;
    final remotePath = message['remotePath'] as String?;

    if (localPath == null || remotePath == null) {
      _mainSendPort.send({
        'type': IsolateEvent.uploadResult,
        'requestId': requestId,
        'success': false,
        'error': 'Missing localPath or remotePath',
      });
      return;
    }

    // Find a connected service to use for SFTP
    final service = _tabServices.values
        .where((s) => s.isConnected)
        .firstOrNull;

    if (service == null) {
      _mainSendPort.send({
        'type': IsolateEvent.uploadResult,
        'requestId': requestId,
        'success': false,
        'error': 'No connected SSH service',
      });
      return;
    }

    try {
      final result = await service.uploadFile(
        localPath: localPath,
        remotePath: remotePath,
      );

      _mainSendPort.send({
        'type': IsolateEvent.uploadResult,
        'requestId': requestId,
        'success': result != null,
        'remotePath': result,
      });
    } catch (e) {
      _mainSendPort.send({
        'type': IsolateEvent.uploadResult,
        'requestId': requestId,
        'success': false,
        'error': e.toString(),
      });
    }
  }

  /// Executes a command silently via SSH exec channel.
  Future<void> _handleExecuteCommand(Map<String, dynamic> message) async {
    final requestId = message['requestId'] as String?;
    final tabId = message['tabId'] as String?;
    final command = message['command'] as String?;

    if (tabId == null || command == null) {
      _mainSendPort.send({
        'type': IsolateEvent.commandResult,
        'requestId': requestId,
        'success': false,
        'error': 'Missing tabId or command',
      });
      return;
    }

    final service = _tabServices[tabId];
    if (service == null) {
      _mainSendPort.send({
        'type': IsolateEvent.commandResult,
        'requestId': requestId,
        'success': false,
        'error': 'No service for tab $tabId',
      });
      return;
    }

    try {
      final result = await service.executeCommandSilently(command);
      _mainSendPort.send({
        'type': IsolateEvent.commandResult,
        'requestId': requestId,
        'success': true,
        'output': result,
        'tabId': tabId,
      });
    } catch (e) {
      _mainSendPort.send({
        'type': IsolateEvent.commandResult,
        'requestId': requestId,
        'success': false,
        'error': e.toString(),
        'tabId': tabId,
      });
    }
  }

  /// Detects the remote OS via uname -s.
  Future<void> _handleDetectOS(Map<String, dynamic> message) async {
    final requestId = message['requestId'] as String?;
    final tabId = message['tabId'] as String?;

    if (tabId == null) {
      _mainSendPort.send({
        'type': IsolateEvent.osDetected,
        'requestId': requestId,
        'os': null,
      });
      return;
    }

    final service = _tabServices[tabId];
    if (service == null) {
      _mainSendPort.send({
        'type': IsolateEvent.osDetected,
        'requestId': requestId,
        'os': null,
      });
      return;
    }

    try {
      final os = await service.detectOS();
      _mainSendPort.send({
        'type': IsolateEvent.osDetected,
        'requestId': requestId,
        'os': os,
        'tabId': tabId,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: OS detection failed for tab $tabId: $e');
      _mainSendPort.send({
        'type': IsolateEvent.osDetected,
        'requestId': requestId,
        'os': null,
        'tabId': tabId,
      });
    }
  }

  /// Sends a shutdown command to the remote host.
  Future<void> _handleShutdown(Map<String, dynamic> message) async {
    final tabId = message['tabId'] as String?;
    final os = message['os'] as String?;

    if (tabId == null || os == null) return;

    final service = _tabServices[tabId];
    if (service == null) return;

    try {
      await service.shutdown(os);
      if (kDebugMode) debugPrint('SSHWorker: Shutdown command sent for tab $tabId (OS: $os)');
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: Shutdown command failed for tab $tabId: $e');
      _mainSendPort.send({
        'type': IsolateEvent.error,
        'error': 'Shutdown failed: $e',
        'tabId': tabId,
      });
    }
  }

  /// Reconnects a specific tab.
  Future<void> _handleReconnectTab(Map<String, dynamic> message) async {
    final tabId = message['tabId'] as String?;
    if (tabId == null) return;

    if (_connectionHost == null || _connectionUsername == null || _connectionKeyId == null) {
      if (kDebugMode) debugPrint('SSHWorker: Cannot reconnect tab $tabId, no connection info');
      return;
    }

    if (kDebugMode) debugPrint('SSHWorker: Reconnecting tab $tabId');

    _mainSendPort.send({
      'type': IsolateEvent.reconnecting,
      'tabId': tabId,
    });

    SecureBuffer? keyBuffer;
    try {
      final privateKey = await SecureStorageService.getPrivateKey(_connectionKeyId!);
      if (privateKey == null || privateKey.isEmpty) {
        _mainSendPort.send({
          'type': IsolateEvent.connectionFailed,
          'error': 'Private key not found',
          'tabId': tabId,
        });
        return;
      }

      keyBuffer = SecureBuffer.fromString(privateKey);

      // Cancel old stdout subscription and disconnect old service
      await _stdoutSubscriptions[tabId]?.cancel();
      _stdoutSubscriptions.remove(tabId);
      await _tabServices[tabId]?.disconnect();

      final newService = SSHService();
      final success = await newService.connect(
        host: _connectionHost!,
        username: _connectionUsername!,
        privateKey: keyBuffer.toUtf8String(),
        port: _connectionPort,
      );

      if (success) {
        await newService.startShell();
        _tabServices[tabId] = newService;
        _subscribeToStdout(tabId, newService);

        _mainSendPort.send({
          'type': IsolateEvent.reconnected,
          'tabId': tabId,
        });

        if (kDebugMode) debugPrint('SSHWorker: Tab $tabId reconnected successfully');
      } else {
        _mainSendPort.send({
          'type': IsolateEvent.connectionFailed,
          'error': 'Reconnection failed',
          'tabId': tabId,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: Tab $tabId reconnection failed: $e');
      _mainSendPort.send({
        'type': IsolateEvent.connectionFailed,
        'error': e.toString(),
        'tabId': tabId,
      });
    } finally {
      keyBuffer?.dispose();
    }
  }

  /// Reconnects all tabs: disconnects everything and creates a fresh connection.
  Future<void> _handleReconnectAll(Map<String, dynamic> message) async {
    if (_connectionHost == null || _connectionUsername == null || _connectionKeyId == null) {
      if (kDebugMode) debugPrint('SSHWorker: Cannot reconnect, no connection info');
      _mainSendPort.send({
        'type': IsolateEvent.connectionFailed,
        'error': 'No connection info available',
      });
      return;
    }

    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      if (kDebugMode) debugPrint('SSHWorker: Max reconnect attempts reached ($_reconnectAttempts/$_maxReconnectAttempts)');
      _mainSendPort.send({
        'type': IsolateEvent.connectionFailed,
        'error': 'Max reconnection attempts reached',
      });
      _reconnectAttempts = 0;
      return;
    }

    if (kDebugMode) debugPrint('SSHWorker: Reconnecting all (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

    _mainSendPort.send({
      'type': IsolateEvent.reconnecting,
    });

    // Wait before reconnecting
    await Future<void>.delayed(_reconnectDelay);

    SecureBuffer? keyBuffer;
    try {
      final privateKey = await SecureStorageService.getPrivateKey(_connectionKeyId!);
      if (privateKey == null || privateKey.isEmpty) {
        if (kDebugMode) debugPrint('SSHWorker: Private key not found for reconnection');
        _mainSendPort.send({
          'type': IsolateEvent.connectionFailed,
          'error': 'Private key not found',
        });
        return;
      }

      keyBuffer = SecureBuffer.fromString(privateKey);

      // Cancel all stdout subscriptions
      for (final sub in _stdoutSubscriptions.values) {
        await sub.cancel();
      }
      _stdoutSubscriptions.clear();

      // Disconnect all existing services
      for (final service in _tabServices.values) {
        await service.disconnect();
      }
      _tabServices.clear();

      // Create a fresh connection
      final tabId = DateTime.now().millisecondsSinceEpoch.toString();
      final newService = SSHService();
      final success = await newService.connect(
        host: _connectionHost!,
        username: _connectionUsername!,
        privateKey: keyBuffer.toUtf8String(),
        port: _connectionPort,
      );

      if (success) {
        await newService.startShell();
        _tabServices[tabId] = newService;
        _subscribeToStdout(tabId, newService);
        _startConnectionMonitor();
        _reconnectAttempts = 0;

        _mainSendPort.send({
          'type': IsolateEvent.reconnected,
          'tabId': tabId,
        });

        if (kDebugMode) debugPrint('SSHWorker: Reconnection successful (new tab: $tabId)');
      } else {
        _mainSendPort.send({
          'type': IsolateEvent.connectionFailed,
          'error': 'Reconnection failed',
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SSHWorker: Reconnection failed: $e');
      _mainSendPort.send({
        'type': IsolateEvent.connectionFailed,
        'error': e.toString(),
      });
    } finally {
      keyBuffer?.dispose();
    }
  }

  // ============================================================
  // Connection monitoring
  // ============================================================

  /// Starts a periodic timer (every 10s) that checks if any service
  /// is still connected. If none are, triggers auto-reconnection.
  void _startConnectionMonitor() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_tabServices.isEmpty) return;

      final anyConnected = _tabServices.values.any((s) => s.isConnected);
      if (!anyConnected) {
        if (kDebugMode) debugPrint('SSHWorker: All SSH connections lost');
        _connectionCheckTimer?.cancel();
        _connectionCheckTimer = null;
        // Notify main isolate — it decides whether to reconnect
        _mainSendPort.send({
          'type': IsolateEvent.allDisconnected,
        });
      }
    });
  }

  // ============================================================
  // Test connectivity (WOL polling)
  // ============================================================

  /// Test SSH connectivity without creating a tab or modifying state.
  /// Used by WOL polling to check if the remote host is reachable.
  /// Creates a temporary SSHService, connects, disconnects, returns result.
  Future<void> _handleTestConnect(Map<String, dynamic> message) async {
    final host = message['host'] as String;
    final username = message['username'] as String;
    final keyId = message['keyId'] as String;
    final port = message['port'] as int;
    final requestId = message['requestId'] as String?;

    if (kDebugMode) debugPrint('SSHWorker: Test connect to $host:$port as $username');

    // SECURITY: Read private key directly from SecureStorage
    final privateKeyRaw = await SecureStorageService.getPrivateKey(keyId);
    if (privateKeyRaw == null || privateKeyRaw.isEmpty) {
      _mainSendPort.send({
        'type': IsolateEvent.testConnectResult,
        'requestId': requestId,
        'success': false,
      });
      return;
    }

    final keyBuffer = SecureBuffer.fromString(privateKeyRaw);
    final testService = SSHService();
    try {
      final success = await testService.connect(
        host: host,
        username: username,
        privateKey: keyBuffer.toUtf8String(),
        port: port,
        onFirstHostKey: (host, port, keyType, fingerprint) =>
            _requestHostKeyVerification(
              host: host,
              port: port,
              keyType: keyType,
              fingerprint: fingerprint,
              isNew: true,
            ),
        onHostKeyMismatch: (host, port, keyType, fingerprint) =>
            _requestHostKeyVerification(
              host: host,
              port: port,
              keyType: keyType,
              fingerprint: fingerprint,
              isNew: false,
            ),
      );
      await testService.disconnect();

      if (kDebugMode) debugPrint('SSHWorker: Test connect result: $success');

      _mainSendPort.send({
        'type': IsolateEvent.testConnectResult,
        'requestId': requestId,
        'success': success,
      });
    } catch (e) {
      await testService.disconnect();

      if (kDebugMode) debugPrint('SSHWorker: Test connect failed: $e');

      _mainSendPort.send({
        'type': IsolateEvent.testConnectResult,
        'requestId': requestId,
        'success': false,
      });
    } finally {
      keyBuffer.dispose();
    }
  }

  // ============================================================
  // Cleanup & disposal
  // ============================================================

  /// Full cleanup: disconnect everything, close ReceivePort, kill isolate.
  Future<void> _handleDispose() async {
    if (kDebugMode) debugPrint('SSHWorker: Disposing...');

    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _resizeThrottleTimer?.cancel();
    _resizeThrottleTimer = null;

    // Cancel all stdout subscriptions
    for (final sub in _stdoutSubscriptions.values) {
      await sub.cancel();
    }
    _stdoutSubscriptions.clear();

    // Disconnect all services
    for (final service in _tabServices.values) {
      await service.disconnect();
    }
    _tabServices.clear();

    // Clean up state
    _pendingResizes.clear();
    _lastSentSizes.clear();
    _pendingHostKeyRequests.clear();

    _receivePort.close();

    if (kDebugMode) debugPrint('SSHWorker: Disposed, killing isolate');
    Isolate.exit();
  }
}
