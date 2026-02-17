import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ssh_isolate_client.dart';
import '../../../services/ssh_service.dart'; // For HostKeyVerifyCallback typedef
import '../../../services/local_shell_service.dart';
import '../../../services/foreground_ssh_service.dart';
import '../../../services/audit_log_service.dart';
import '../../../models/audit_entry.dart';
import '../../settings/providers/settings_provider.dart';

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

/// Informations de connexion pour la reconnexion et les nouveaux onglets
class SSHConnectionInfo {
  final String host;
  final String username;
  final String keyId; // Référence vers la clé stockée de manière sécurisée
  final String sessionId;
  final int port;

  const SSHConnectionInfo({
    required this.host,
    required this.username,
    required this.keyId,
    required this.sessionId,
    required this.port,
  });
}

class SSHState {
  final SSHConnectionState connectionState;
  final String? errorMessage;
  final String? activeSessionId;
  final SSHConnectionInfo? lastConnectionInfo;
  final bool showDisconnectNotification;
  final int reconnectAttempts;

  /// ID de l'onglet actif (stable, ne change pas quand on ferme d'autres onglets)
  final String? currentTabId;

  /// Liste ordonnée des IDs d'onglets ouverts
  final List<String> tabIds;

  /// Compteur global pour nommer les onglets (ne décrémente jamais)
  final int nextTabNumber;

  /// État "process en cours" par onglet (pour bouton Send/Stop)
  final Map<String, bool> tabRunningState;

  /// Commande en cours par onglet (pour détecter si interactive)
  final Map<String, String> tabCurrentCommand;

  /// IDs des onglets qui sont des shells locaux (pas SSH)
  final Set<String> localTabIds;

  /// Noms personnalisés des onglets
  final Map<String, String> tabNames;

  /// IDs des onglets dont la connexion est morte (stream fermé)
  final Set<String> deadTabIds;

  const SSHState({
    this.connectionState = SSHConnectionState.disconnected,
    this.errorMessage,
    this.activeSessionId,
    this.lastConnectionInfo,
    this.showDisconnectNotification = false,
    this.reconnectAttempts = 0,
    this.currentTabId,
    this.tabIds = const [],
    this.nextTabNumber =
        1, // Commence à 1, tous les onglets utilisent ce compteur
    this.tabRunningState = const {},
    this.tabCurrentCommand = const {},
    this.localTabIds = const {},
    this.tabNames = const {},
    this.deadTabIds = const {},
  });

  int get tabCount => tabIds.length;
  int get currentTabIndex =>
      currentTabId != null ? tabIds.indexOf(currentTabId!) : 0;

  /// Vérifie si l'onglet actif a un process en cours
  bool get isCurrentTabRunning {
    if (currentTabId == null) return false;
    return tabRunningState[currentTabId] ?? false;
  }

  /// Récupère la commande en cours de l'onglet actif
  String? get currentTabCommand {
    if (currentTabId == null) return null;
    return tabCurrentCommand[currentTabId];
  }

  SSHState copyWith({
    SSHConnectionState? connectionState,
    String? errorMessage,
    String? activeSessionId,
    SSHConnectionInfo? lastConnectionInfo,
    bool? showDisconnectNotification,
    int? reconnectAttempts,
    String? currentTabId,
    List<String>? tabIds,
    int? nextTabNumber,
    Map<String, bool>? tabRunningState,
    Map<String, String>? tabCurrentCommand,
    Set<String>? localTabIds,
    Map<String, String>? tabNames,
    Set<String>? deadTabIds,
  }) {
    return SSHState(
      connectionState: connectionState ?? this.connectionState,
      errorMessage: errorMessage,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      lastConnectionInfo: lastConnectionInfo ?? this.lastConnectionInfo,
      showDisconnectNotification:
          showDisconnectNotification ?? this.showDisconnectNotification,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      currentTabId: currentTabId ?? this.currentTabId,
      tabIds: tabIds ?? this.tabIds,
      nextTabNumber: nextTabNumber ?? this.nextTabNumber,
      tabRunningState: tabRunningState ?? this.tabRunningState,
      tabCurrentCommand: tabCurrentCommand ?? this.tabCurrentCommand,
      localTabIds: localTabIds ?? this.localTabIds,
      tabNames: tabNames ?? this.tabNames,
      deadTabIds: deadTabIds ?? this.deadTabIds,
    );
  }
}

class SSHNotifier extends Notifier<SSHState> {
  /// Client isolate SSH — toutes les opérations SSH sont déléguées à un isolate séparé.
  /// Cela libère le thread UI et élimine les saccades d'animation pendant le handshake SSH.
  SSHIsolateClient? _isolateClient;

  /// Map des services de shell local par ID (restent dans le main isolate)
  final Map<String, LocalShellService> _localTabServices = {};

  bool _isCreatingTab = false;

  /// Indique si une création d'onglet est en cours
  bool get isCreatingTab => _isCreatingTab;
  bool _isDisposed = false;

  // Callbacks pour les settings (définis par terminal_screen)
  bool Function()? shouldReconnect;
  bool Function()? shouldNotifyOnDisconnect;

  @override
  SSHState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _isolateClient?.dispose();
      _isolateClient = null;
    });
    return const SSHState();
  }

  /// Génère un ID unique pour un nouvel onglet
  String _generateTabId() => DateTime.now().millisecondsSinceEpoch.toString();

  /// Retourne le prochain numéro d'onglet et l'incrémente
  /// Ce numéro ne décrémente jamais, même après fermeture d'onglets
  int getAndIncrementTabNumber() {
    final number = state.nextTabNumber;
    state = state.copyWith(nextTabNumber: number + 1);
    return number;
  }

  /// Retourne le flux de sortie d'un onglet spécifique par ID
  Stream<Uint8List>? getOutputStreamForTab(String tabId) {
    // Vérifier si c'est un onglet local
    if (state.localTabIds.contains(tabId)) {
      return _localTabServices[tabId]?.outputStream;
    }
    // SSH : flux provenant du background isolate via StreamController
    return _isolateClient?.getOutputStream(tabId);
  }

  /// Initialise ou retourne le client isolate SSH
  SSHIsolateClient _getOrCreateClient() {
    if (_isolateClient == null) {
      _isolateClient = SSHIsolateClient();
      _setupIsolateCallbacks();
    }
    return _isolateClient!;
  }

  /// Configure les callbacks de l'isolate client pour recevoir les événements du worker
  void _setupIsolateCallbacks() {
    final client = _isolateClient!;

    // Tab morte (stdout stream fermé)
    client.onTabDead = (tabId) {
      if (_isDisposed) return;
      markTabAsDead(tabId);
    };

    // Toutes les connexions SSH perdues (détecté par le connection monitor du worker)
    client.onAllDisconnected = () {
      if (_isDisposed) return;
      _handleDisconnection();
    };

    // Reconnexion en cours (du worker)
    client.onReconnecting = (attempt, maxAttempts) {
      if (_isDisposed) return;
      state = state.copyWith(
        connectionState: SSHConnectionState.reconnecting,
        errorMessage: 'ssh:reconnecting:$attempt/$maxAttempts',
        reconnectAttempts: attempt,
      );
    };

    // Reconnexion réussie
    client.onReconnected = (tabId) {
      if (_isDisposed) return;

      // Si le tabId est nouveau (reconnexion complète), mettre à jour tabIds
      if (!state.tabIds.contains(tabId)) {
        state = state.copyWith(
          connectionState: SSHConnectionState.connected,
          errorMessage: null,
          reconnectAttempts: 0,
          currentTabId: tabId,
          tabIds: [tabId],
        );
      } else {
        state = state.copyWith(
          connectionState: SSHConnectionState.connected,
          errorMessage: null,
          reconnectAttempts: 0,
          deadTabIds: state.deadTabIds.where((id) => id != tabId).toSet(),
        );
      }

      final info = state.lastConnectionInfo;
      if (info != null) {
        AuditLogService.log(
          AuditEventType.sshReconnect,
          details: {'host': info.host, 'port': '${info.port}'},
        );
        ref.read(settingsProvider.notifier).updateSSHKeyLastUsed(info.keyId);
      }
    };

    // Échec de connexion (provient de reconnectTab/reconnectAll)
    client.onConnectionFailed = (error, tabId) {
      if (_isDisposed) return;
      if (kDebugMode)
        debugPrint('SSH isolate connection failed: $error (tab: $tabId)');
      // Si on est en reconnexion, passer en état d'erreur
      if (state.connectionState == SSHConnectionState.reconnecting) {
        state = state.copyWith(
          connectionState: SSHConnectionState.disconnected,
          errorMessage: 'ssh:connectionLost',
        );
      }
    };

    // Erreur générique
    client.onError = (error, requestId) {
      if (_isDisposed) return;
      if (kDebugMode) debugPrint('SSH isolate error: $error');
    };
  }

  Future<bool> connect({
    required String host,
    required String username,
    required String keyId,
    required String sessionId,
    int port = 22,
    HostKeyVerifyCallback? onFirstHostKey,
    HostKeyVerifyCallback? onHostKeyMismatch,
  }) async {
    if (kDebugMode)
      debugPrint('SSHNotifier: connect() called — host=$host port=$port');

    state = state.copyWith(
      connectionState: SSHConnectionState.connecting,
      errorMessage: null,
      reconnectAttempts: 0,
    );

    // Plus besoin de Future.delayed(150ms) — le handshake SSH tourne maintenant
    // dans un isolate séparé, le thread UI reste libre pour l'animation.

    // Vérifier si annulé
    if (state.connectionState != SSHConnectionState.connecting) {
      if (kDebugMode)
        debugPrint(
          'SSHNotifier: connect cancelled before start (state changed)',
        );
      return false;
    }

    final connectionInfo = SSHConnectionInfo(
      host: host,
      username: username,
      keyId: keyId,
      sessionId: sessionId,
      port: port,
    );

    final tabId = _generateTabId();

    final client = _getOrCreateClient();
    client.onFirstHostKey = onFirstHostKey;
    client.onHostKeyMismatch = onHostKeyMismatch;

    try {
      await client.connect(
        host: host,
        username: username,
        keyId: keyId,
        sessionId: sessionId,
        tabId: tabId,
        port: port,
      );

      // Vérifier si annulé pendant la connexion SSH
      if (state.connectionState != SSHConnectionState.connecting) {
        if (kDebugMode)
          debugPrint(
            'SSHNotifier: connect cancelled DURING SSH handshake (state=${state.connectionState})',
          );
        client.closeTab(tabId);
        return false;
      }
      if (kDebugMode)
        debugPrint('SSHNotifier: connect SUCCESS to $host:$port (tab=$tabId)');

      state = state.copyWith(
        connectionState: SSHConnectionState.connected,
        activeSessionId: sessionId,
        lastConnectionInfo: connectionInfo,
        reconnectAttempts: 0,
        currentTabId: tabId,
        tabIds: [tabId],
      );

      // Démarrer le foreground service pour maintenir la connexion
      await ForegroundSSHService.start(connectionInfo: 'Connecté à $host');
      AuditLogService.log(
        AuditEventType.sshConnect,
        details: {'host': host, 'port': '$port'},
      );
      ref.read(settingsProvider.notifier).updateSSHKeyLastUsed(keyId);
      return true;
    } catch (e) {
      if (kDebugMode)
        debugPrint(
          'SSHNotifier: connect FAILED to $host:$port — ${e.runtimeType}: $e',
        );
      AuditLogService.log(
        AuditEventType.sshAuthFail,
        success: false,
        details: {'host': host, 'port': '$port'},
      );

      // Mapper le message d'erreur (l'exception vient de l'isolate, pas SSHException directe)
      final errorMsg = e.toString();
      String mappedError = 'ssh:connectionFailed';
      if (errorMsg.contains('timeout')) mappedError = 'ssh:timeout';
      if (errorMsg.contains('ssh:')) {
        // Si le worker a déjà encodé un code d'erreur SSH
        final match = RegExp(r'ssh:(\w+)').firstMatch(errorMsg);
        if (match != null) mappedError = 'ssh:${match.group(1)}';
      }

      state = state.copyWith(
        connectionState: SSHConnectionState.error,
        errorMessage: mappedError,
      );
      return false;
    }
  }

  /// Démarre un shell local (Android uniquement)
  Future<void> connectLocal() async {
    state = state.copyWith(connectionState: SSHConnectionState.connecting);

    try {
      final tabId = DateTime.now().millisecondsSinceEpoch.toString();
      final tabNumber = state.nextTabNumber;

      final localService = LocalShellService();
      await localService.startShell();

      _localTabServices[tabId] = localService;

      state = state.copyWith(
        connectionState: SSHConnectionState.connected,
        currentTabId: tabId,
        tabIds: [...state.tabIds, tabId],
        localTabIds: {...state.localTabIds, tabId},
        tabNames: {...state.tabNames, tabId: 'Local $tabNumber'},
        nextTabNumber: tabNumber + 1,
        errorMessage: null,
      );

      // Démarrer le foreground service
      await ForegroundSSHService.start(connectionInfo: 'Shell local actif');
      if (kDebugMode) debugPrint('Local shell connected: $tabId');
    } catch (e) {
      state = state.copyWith(
        connectionState: SSHConnectionState.error,
        errorMessage: 'ssh:localShellError',
      );
    }
  }

  /// Rollback : retire un onglet de la liste après un échec de création
  void _rollbackTab(String tabId) {
    final rollbackTabIds = state.tabIds.where((id) => id != tabId).toList();
    state = state.copyWith(
      tabIds: rollbackTabIds,
      currentTabId: rollbackTabIds.isNotEmpty ? rollbackTabIds.last : null,
    );
  }

  /// Crée un nouvel onglet avec une nouvelle connexion SSH
  /// Retourne l'ID du nouvel onglet ou null si échec
  Future<String?> createNewTab() async {
    // Guard contre les créations simultanées
    if (_isCreatingTab) {
      if (kDebugMode) debugPrint('Tab creation already in progress, ignoring');
      return null;
    }

    final info = state.lastConnectionInfo;
    if (info == null) return null;

    final client = _isolateClient;
    if (client == null) return null;

    _isCreatingTab = true;

    final tabId = _generateTabId();

    // FEEDBACK IMMÉDIAT: Ajouter l'onglet en état "connecting"
    final newTabIds = [...state.tabIds, tabId];
    state = state.copyWith(currentTabId: tabId, tabIds: newTabIds);

    try {
      // Délègue au worker : multiplexage SSH (~50ms) ou nouvelle connexion (~1-2s)
      final resultTabId = await client.createTab(
        keyId: info.keyId,
        tabId: tabId,
      );
      if (resultTabId != null) {
        if (kDebugMode) debugPrint('Tab $tabId created via isolate');
        return tabId;
      } else {
        _rollbackTab(tabId);
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to create new tab: $e');
      _rollbackTab(tabId);
      return null;
    } finally {
      _isCreatingTab = false;
    }
  }

  /// Change d'onglet actif par ID
  void selectTab(String tabId) {
    if (!state.tabIds.contains(tabId)) return;
    if (tabId == state.currentTabId) return;

    state = state.copyWith(currentTabId: tabId);
  }

  /// Change d'onglet actif par index (pour compatibilité UI)
  void selectTabByIndex(int index) {
    if (index < 0 || index >= state.tabIds.length) return;
    selectTab(state.tabIds[index]);
  }

  /// Ferme un onglet par ID
  Future<void> closeTab(String tabId) async {
    if (!state.tabIds.contains(tabId)) return;

    // Fermer le service local si c'est un onglet local
    if (state.localTabIds.contains(tabId)) {
      await _localTabServices[tabId]?.close();
      _localTabServices.remove(tabId);
    } else {
      // Fermer la tab SSH via l'isolate (le worker gère multiplexage/solo)
      _isolateClient?.closeTab(tabId);
    }

    // Retirer l'ID de la liste
    final newTabIds = state.tabIds.where((id) => id != tabId).toList();

    // Si c'était le dernier onglet, on est déconnecté
    if (newTabIds.isEmpty) {
      await ForegroundSSHService.stop();
      state = const SSHState();
      return;
    }

    // Si l'onglet fermé était l'onglet actif, sélectionner un autre
    String newCurrentTabId = state.currentTabId!;
    if (state.currentTabId == tabId) {
      final oldIndex = state.tabIds.indexOf(tabId);
      final newIndex = oldIndex >= newTabIds.length
          ? newTabIds.length - 1
          : oldIndex;
      newCurrentTabId = newTabIds[newIndex];
    }

    state = state.copyWith(
      tabIds: newTabIds,
      currentTabId: newCurrentTabId,
      localTabIds: Set<String>.from(state.localTabIds)..remove(tabId),
    );
  }

  /// Ferme un onglet par index (pour compatibilité UI)
  Future<void> closeTabByIndex(int index) async {
    if (index < 0 || index >= state.tabIds.length) return;
    await closeTab(state.tabIds[index]);
  }

  /// Pause le monitoring de connexion (app en arrière-plan)
  void pauseConnectionMonitor() {
    _isolateClient?.pauseMonitor();
  }

  /// Reprend le monitoring de connexion (app au premier plan)
  void resumeConnectionMonitor() {
    if (state.connectionState == SSHConnectionState.connected) {
      _isolateClient?.resumeMonitor();
    }
  }

  /// Gère la perte de connexion détectée par le worker
  void _handleDisconnection() {
    if (kDebugMode)
      debugPrint(
        'SSHNotifier: _handleDisconnection() called (state=${state.connectionState})',
      );
    if (state.connectionState == SSHConnectionState.disconnected) return;

    final wasConnected = state.connectionState == SSHConnectionState.connected;

    if (wasConnected && (shouldNotifyOnDisconnect?.call() ?? false)) {
      state = state.copyWith(showDisconnectNotification: true);
    }

    if (wasConnected &&
        (shouldReconnect?.call() ?? false) &&
        state.lastConnectionInfo != null) {
      // Passer en état "reconnecting" pour que l'UI montre le loader
      state = state.copyWith(
        connectionState: SSHConnectionState.reconnecting,
        errorMessage: 'ssh:reconnecting:1/3',
        reconnectAttempts: 1,
      );
      // Demander au worker de reconnecter l'onglet actif
      _isolateClient?.reconnectTab(state.currentTabId ?? '');
    } else {
      state = state.copyWith(
        connectionState: SSHConnectionState.disconnected,
        errorMessage: 'ssh:connectionLost',
      );
    }
  }

  void clearDisconnectNotification() {
    state = state.copyWith(showDisconnectNotification: false);
  }

  Future<void> disconnect() async {
    if (kDebugMode)
      debugPrint(
        'SSHNotifier: disconnect() called (state=${state.connectionState})',
      );
    final info = state.lastConnectionInfo;

    // Déconnecter toutes les sessions SSH via l'isolate
    await _isolateClient?.disconnect();

    // Fermer les services Local Shell
    for (final service in _localTabServices.values) {
      await service.close();
    }
    _localTabServices.clear();

    // Arrêter le foreground service
    await ForegroundSSHService.stop();

    if (info != null) {
      AuditLogService.log(
        AuditEventType.sshDisconnect,
        details: {'host': info.host, 'port': '${info.port}'},
      );
    }

    state = const SSHState();
  }

  /// Teste la connectivité SSH sans modifier l'état UI.
  /// Utilisé par le polling WOL pour vérifier si le PC est réveillé.
  /// Exécuté dans le background isolate → pas de saccade d'animation.
  Future<bool> testSshConnectivity({
    required String host,
    required String username,
    required String keyId,
    required int port,
  }) async {
    final client = _getOrCreateClient();
    return client.testConnect(
      host: host,
      username: username,
      keyId: keyId,
      port: port,
    );
  }

  /// Marque un onglet comme ayant une connexion morte (stream fermé)
  void markTabAsDead(String tabId) {
    if (kDebugMode) debugPrint('markTabAsDead: Tab $tabId marked as dead');
    state = state.copyWith(deadTabIds: {...state.deadTabIds, tabId});
  }

  /// Vérifie et reconnecte les onglets SSH si la connexion est perdue
  /// Appelé quand l'app revient au premier plan
  Future<void> checkAndReconnectIfNeeded() async {
    if (kDebugMode)
      debugPrint('checkAndReconnectIfNeeded: Checking SSH connections...');
    if (kDebugMode)
      debugPrint('checkAndReconnectIfNeeded: Dead tabs: ${state.deadTabIds}');

    // Pour chaque onglet SSH (pas local)
    for (final tabId in state.tabIds) {
      if (state.localTabIds.contains(tabId)) continue; // Skip local tabs

      // Vérifier si l'onglet est marqué comme mort
      final isDead = state.deadTabIds.contains(tabId);
      if (kDebugMode)
        debugPrint('checkAndReconnectIfNeeded: Tab $tabId - isDead: $isDead');

      if (isDead && state.lastConnectionInfo != null) {
        if (kDebugMode)
          debugPrint(
            'checkAndReconnectIfNeeded: Tab $tabId needs reconnection',
          );
        // Demander au worker de reconnecter cet onglet
        _isolateClient?.reconnectTab(tabId);
      }
    }
  }

  void write(String data) {
    final currentTabId = state.currentTabId;
    if (kDebugMode) debugPrint('SSH write: tabId=$currentTabId');
    if (currentTabId != null) {
      writeToTab(currentTabId, data);
    } else {
      if (kDebugMode)
        debugPrint('SSH write: currentTabId is NULL, data not sent!');
    }
  }

  /// Exécute une commande silencieusement via le canal SSH exec.
  /// La commande N'apparaît PAS dans le terminal interactif.
  /// Retourne la sortie de la commande ou null en cas d'erreur.
  Future<String?> executeCommandSilently(String command) async {
    final currentTabId = state.currentTabId;
    if (currentTabId == null) return null;

    // Ne fonctionne pas pour les shells locaux
    if (state.localTabIds.contains(currentTabId)) return null;

    try {
      return await _isolateClient?.executeCommand(
        tabId: currentTabId,
        command: command,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('executeCommandSilently error: $e');
      return null;
    }
  }

  /// Écrit vers un onglet spécifique par ID
  void writeToTab(String tabId, String data) {
    if (state.localTabIds.contains(tabId)) {
      _localTabServices[tabId]?.write(data);
      return;
    }
    // SSH : envoie via l'isolate (fire-and-forget, très rapide)
    _isolateClient?.write(tabId, Uint8List.fromList(utf8.encode(data)));
  }

  /// Redimensionne le PTY de l'onglet actif
  void resizeTerminal(int width, int height) {
    if (state.currentTabId != null) {
      resizeTerminalForTab(state.currentTabId!, width, height);
    }
  }

  /// Redimensionne le PTY d'un onglet spécifique par ID
  /// Le throttle de 150ms est maintenant géré par le worker dans l'isolate
  void resizeTerminalForTab(String tabId, int width, int height) {
    // Ignorer les dimensions invalides
    if (width <= 0 || height <= 0) return;

    if (state.localTabIds.contains(tabId)) {
      _localTabServices[tabId]?.resize(width, height);
    } else {
      // Le worker gère le throttle côté isolate
      _isolateClient?.resize(tabId, width, height);
    }
  }

  // === Gestion du bouton Send/Stop par onglet ===

  /// Liste des commandes qui lancent des process long-running
  static const _longRunningCommands = <String>[
    // AI Coding CLI (vibe coding tools)
    'claude', 'opencode', 'aider', 'gemini', 'codex', 'cody',
    'amazon-q', 'aws-q', 'crush',
    // Serveurs & Dev
    'npm', 'npx', 'yarn', 'pnpm', 'node', 'nodemon', 'ts-node',
    'python', 'python3', 'py', 'flask', 'uvicorn', 'gunicorn', 'django',
    'php', 'ruby', 'rails',
    'cargo', 'rustc',
    'go',
    'java', 'javac', 'gradle', 'mvn',
    'flutter',
    'dart',
    // Docker (sauf docker run qui est instant)
    'docker-compose', 'docker compose',
    // Réseau & Téléchargements
    'curl', 'wget', 'ssh', 'scp', 'rsync', 'ftp', 'sftp',
    // Installations & Updates
    'apt', 'apt-get', 'dpkg', 'snap',
    'yum', 'dnf', 'rpm', 'pacman', 'zypper',
    'brew', 'port',
    'pip', 'pip3', 'pipenv', 'poetry', 'conda',
    'gem', 'bundle',
    'composer',
    // Monitoring & Logs
    'top', 'htop', 'btop', 'atop', 'nmon', 'glances', 'dstat',
    'watch', 'journalctl',
    'iotop', 'iftop', 'nethogs', 'bmon', 'vnstat',
    'vmstat', 'iostat', 'mpstat', 'sar',
    // GPU monitoring (AMD, NVIDIA, Intel)
    'radeontop', 'nvtop', 'nvidia-smi', 'intel_gpu_top', 'gpu-viewer',
    // Hardware & sensors
    'sensors', 'powertop', 'turbostat', 's-tui',
    // Debug & profiling
    'strace', 'ltrace', 'perf', 'gdb', 'lldb', 'valgrind',
    // Builds & Tests
    'make', 'cmake', 'ninja', 'meson',
    'gcc', 'g++', 'clang',
    'pytest', 'jest', 'mocha', 'vitest',
    // Éditeurs interactifs
    'vim', 'vi', 'nvim', 'nano', 'emacs', 'micro',
    // Git (opérations longues)
    'git clone', 'git pull', 'git push', 'git fetch',
    // Archives
    'tar', 'zip', 'unzip', 'gzip', 'gunzip', '7z',
    // Recherche (peut être long)
    'find', 'grep', 'rg', 'ag', 'fd',
    // Autres
    'sudo', 'su',
    'sleep',
    'nc', 'netcat', 'nmap', 'tcpdump', 'wireshark', 'tshark',
    'ffmpeg', 'ffprobe', 'convert', 'mogrify', 'imagemagick',
    'kubectl', 'helm', 'terraform', 'ansible', 'vagrant',
    // Serveurs locaux
    'nginx', 'apache2', 'httpd', 'caddy', 'lighttpd',
    'mysql',
    'mysqld',
    'postgres',
    'psql',
    'redis-server',
    'redis-cli',
    'mongo',
    'mongod',
    // Process managers
    'pm2', 'forever', 'supervisord',
    // Shells interactifs
    'bash', 'zsh', 'fish', 'sh',
    // Fuzzy finders & selectors
    'fzf', 'fzy', 'sk', 'peco', 'percol',
    // Dialog & TUI
    'dialog', 'whiptail', 'zenity', 'yad',
    // Autres outils dev
    'webpack', 'vite', 'esbuild', 'parcel', 'rollup',
    'tsc', 'babel',
    'eslint', 'prettier',
    'black', 'flake8', 'mypy', 'ruff',
  ];

  /// Vérifie si une commande est "long-running"
  bool isLongRunningCommand(String command) {
    final trimmed = command.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    if (_isSpecialCaseLongRunning(trimmed)) return true;
    if (_isInteractiveCommand(trimmed)) return true;
    return _containsLongRunningInPipe(trimmed);
  }

  bool _isSpecialCaseLongRunning(String trimmed) {
    // Cas spéciaux avec arguments
    if (trimmed.startsWith('tail ') && trimmed.contains('-f')) return true;
    if (trimmed.startsWith('docker build')) return true;
    if (trimmed.startsWith('docker-compose') ||
        trimmed.startsWith('docker compose'))
      return true;
    return false;
  }

  bool _isInteractiveCommand(String trimmed) {
    // Commandes interactives avec -i (demandent confirmation y/n)
    return trimmed.contains(' -i') || trimmed.contains(' --interactive');
  }

  bool _containsLongRunningInPipe(String trimmed) {
    // Vérifier chaque commande dans un pipe (cmd1 | cmd2 | cmd3)
    final pipedCommands = trimmed.split('|');
    for (final pipeCmd in pipedCommands) {
      final cmdTrimmed = pipeCmd.trim();
      if (cmdTrimmed.isEmpty) continue;

      final firstWord = cmdTrimmed.split(RegExp(r'\s+')).first;

      // Scripts exécutables
      if (firstWord.startsWith('./') || firstWord.startsWith('/')) return true;
      if (firstWord.endsWith('.sh') ||
          firstWord.endsWith('.py') ||
          firstWord.endsWith('.rb'))
        return true;

      if (_longRunningCommands.contains(firstWord)) return true;
    }
    return false;
  }

  /// Marque l'onglet actif comme ayant un process en cours
  void setCurrentTabRunning(bool running, {String? command}) {
    final tabId = state.currentTabId;
    if (tabId == null) return;

    final newRunningState = Map<String, bool>.from(state.tabRunningState);
    final newCommandState = Map<String, String>.from(state.tabCurrentCommand);

    newRunningState[tabId] = running;
    if (running && command != null) {
      newCommandState[tabId] = command;
    } else if (!running) {
      newCommandState.remove(tabId);
    }

    state = state.copyWith(
      tabRunningState: newRunningState,
      tabCurrentCommand: newCommandState,
    );
  }

  /// Transfère un fichier vers le serveur SSH via SFTP.
  /// Retourne le chemin distant si succès, null si échec.
  Future<String?> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    final currentTabId = state.currentTabId;
    if (currentTabId == null) return null;

    // Ne fonctionne pas pour les shells locaux
    if (state.localTabIds.contains(currentTabId)) return null;

    try {
      return await _isolateClient?.uploadFile(
        localPath: localPath,
        remotePath: remotePath,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('uploadFile error: $e');
      return null;
    }
  }
}

final sshProvider = NotifierProvider<SSHNotifier, SSHState>(SSHNotifier.new);
