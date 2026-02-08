import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ssh_service.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/local_shell_service.dart';
import '../../../services/foreground_ssh_service.dart';
import '../../../services/audit_log_service.dart';
import '../../../models/audit_entry.dart';

enum SSHConnectionState { disconnected, connecting, connected, error, reconnecting }

/// Informations de connexion pour la reconnexion et les nouveaux onglets
class SSHConnectionInfo {
  final String host;
  final String username;
  final String keyId;  // Référence vers la clé stockée de manière sécurisée
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
    this.nextTabNumber = 1,  // Commence à 1, tous les onglets utilisent ce compteur
    this.tabRunningState = const {},
    this.tabCurrentCommand = const {},
    this.localTabIds = const {},
    this.tabNames = const {},
    this.deadTabIds = const {},
  });

  int get tabCount => tabIds.length;
  int get currentTabIndex => currentTabId != null ? tabIds.indexOf(currentTabId!) : 0;

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
      showDisconnectNotification: showDisconnectNotification ?? this.showDisconnectNotification,
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
  /// Map des services SSH par ID stable (pas par index!)
  final Map<String, SSHService> _tabServices = {};
  /// Map des services de shell local par ID
  final Map<String, LocalShellService> _localTabServices = {};

  Timer? _reconnectTimer;
  Timer? _connectionCheckTimer;
  bool _isCreatingTab = false;

  /// Throttle pour les resize PTY (évite le spam SIGWINCH pendant l'animation clavier)
  static const _resizeThrottleMs = 150;
  Timer? _resizeThrottleTimer;
  DateTime? _lastResizeSent;
  /// Dernières dimensions demandées par onglet (pour le throttle)
  final Map<String, (int, int)> _pendingResizes = {};
  /// Dernières dimensions envoyées par onglet (pour éviter les doublons)
  final Map<String, (int, int)> _lastSentSizes = {};

  /// Indique si une création d'onglet est en cours
  bool get isCreatingTab => _isCreatingTab;
  bool _isDisposed = false;

  // Callbacks pour les settings
  bool Function()? shouldReconnect;
  bool Function()? shouldNotifyOnDisconnect;

  static const _maxReconnectAttempts = 3;
  static const _reconnectDelay = Duration(seconds: 5);

  @override
  SSHState build() {
    ref.onDispose(() {
      _isDisposed = true;
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _resizeThrottleTimer?.cancel();
      _resizeThrottleTimer = null;
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

  /// Retourne le service de l'onglet actif
  SSHService? get service => state.currentTabId != null ? _tabServices[state.currentTabId] : null;

  /// Retourne le flux de sortie de l'onglet actif
  Stream<Uint8List>? get outputStream => service?.session?.stdout;

  /// Retourne le flux de sortie d'un onglet spécifique par ID
  Stream<Uint8List>? getOutputStreamForTab(String tabId) {
    // Vérifier si c'est un onglet local
    if (state.localTabIds.contains(tabId)) {
      return _localTabServices[tabId]?.outputStream;
    }
    return _tabServices[tabId]?.session?.stdout;
  }

  Future<bool> connect({
    required String host,
    required String username,
    required String privateKey,
    required String keyId,
    required String sessionId,
    int port = 22,
    HostKeyVerifyCallback? onFirstHostKey,
    HostKeyVerifyCallback? onHostKeyMismatch,
  }) async {
    state = state.copyWith(
      connectionState: SSHConnectionState.connecting,
      errorMessage: null,
      reconnectAttempts: 0,
    );

    // Laisser le temps au loader de s'afficher et démarrer son animation
    // avant de lancer les opérations crypto qui bloquent le thread UI
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final connectionInfo = SSHConnectionInfo(
      host: host,
      username: username,
      keyId: keyId,
      sessionId: sessionId,
      port: port,
    );

    final tabId = _generateTabId();

    try {
      final newService = SSHService();

      final success = await newService.connect(
        host: host,
        username: username,
        privateKey: privateKey,
        port: port,
        onFirstHostKey: onFirstHostKey,
        onHostKeyMismatch: onHostKeyMismatch,
      );

      if (success) {
        await newService.startShell();

        _tabServices[tabId] = newService;

        state = state.copyWith(
          connectionState: SSHConnectionState.connected,
          activeSessionId: sessionId,
          lastConnectionInfo: connectionInfo,
          reconnectAttempts: 0,
          currentTabId: tabId,
          tabIds: [tabId],
        );

        _startConnectionMonitor();
        // Démarrer le foreground service pour maintenir la connexion
        await ForegroundSSHService.start(
          connectionInfo: 'Connecté à $host',
        );
        AuditLogService.log(AuditEventType.sshConnect, details: {'host': host, 'port': '$port'});
        return true;
      } else {
        AuditLogService.log(AuditEventType.sshAuthFail, success: false, details: {'host': host, 'port': '$port'});
        state = state.copyWith(
          connectionState: SSHConnectionState.error,
          errorMessage: 'Connexion échouée',
        );
        return false;
      }
    } on SSHException catch (e) {
      AuditLogService.log(AuditEventType.sshAuthFail, success: false, details: {'host': host, 'port': '$port', 'error': e.error.name});
      state = state.copyWith(
        connectionState: SSHConnectionState.error,
        errorMessage: e.userMessage,
      );
      return false;
    } catch (e) {
      AuditLogService.log(AuditEventType.sshAuthFail, success: false, details: {'host': host, 'port': '$port'});
      state = state.copyWith(
        connectionState: SSHConnectionState.error,
        errorMessage: 'Erreur inattendue: $e',
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
      await ForegroundSSHService.start(
        connectionInfo: 'Shell local actif',
      );
      if (kDebugMode) debugPrint('Local shell connected: $tabId');
    } catch (e) {
      state = state.copyWith(
        connectionState: SSHConnectionState.error,
        errorMessage: 'Erreur shell local: $e',
      );
    }
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

    _isCreatingTab = true;

    final tabId = _generateTabId();

    try {
      if (kDebugMode) debugPrint('Creating new SSH connection for tab $tabId');

      // FEEDBACK IMMÉDIAT: Ajouter l'onglet en état "connecting"
      final newTabIds = [...state.tabIds, tabId];
      state = state.copyWith(
        currentTabId: tabId,
        tabIds: newTabIds,
      );

      // Récupérer la clé privée depuis le stockage sécurisé
      final privateKey = await SecureStorageService.getPrivateKey(info.keyId);
      if (privateKey == null || privateKey.isEmpty) {
        if (kDebugMode) debugPrint('Failed to retrieve private key for tab creation');
        // Rollback: retirer l'onglet ajouté
        final rollbackTabIds = state.tabIds.where((id) => id != tabId).toList();
        state = state.copyWith(
          tabIds: rollbackTabIds,
          currentTabId: rollbackTabIds.isNotEmpty ? rollbackTabIds.last : null,
        );
        return null;
      }

      final newService = SSHService();
      final success = await newService.connect(
        host: info.host,
        username: info.username,
        privateKey: privateKey,
        port: info.port,
      );

      if (success) {
        await newService.startShell();
        _tabServices[tabId] = newService;
        return tabId;
      } else {
        // Rollback
        final rollbackTabIds = state.tabIds.where((id) => id != tabId).toList();
        state = state.copyWith(
          tabIds: rollbackTabIds,
          currentTabId: rollbackTabIds.isNotEmpty ? rollbackTabIds.last : null,
        );
        return null;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to create new tab: $e');
      // Rollback
      final rollbackTabIds = state.tabIds.where((id) => id != tabId).toList();
      state = state.copyWith(
        tabIds: rollbackTabIds,
        currentTabId: rollbackTabIds.isNotEmpty ? rollbackTabIds.last : null,
      );
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
    }

    // Déconnecter le service de cet onglet
    final serviceToClose = _tabServices[tabId];
    if (serviceToClose != null) {
      await serviceToClose.disconnect();
      _tabServices.remove(tabId);
    }

    // Nettoyer les données de resize pour cet onglet
    _pendingResizes.remove(tabId);
    _lastSentSizes.remove(tabId);

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
      final newIndex = oldIndex >= newTabIds.length ? newTabIds.length - 1 : oldIndex;
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

  void _startConnectionMonitor() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isDisposed) return;
      final anyConnected = _tabServices.values.any((s) => s.isConnected);
      if (!anyConnected && state.connectionState == SSHConnectionState.connected) {
        if (kDebugMode) debugPrint('All SSH connections lost');
        _handleDisconnection();
      }
    });
  }

  /// Pause le timer de vérification de connexion (app en arrière-plan)
  void pauseConnectionMonitor() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }

  /// Reprend le timer de vérification de connexion (app au premier plan)
  void resumeConnectionMonitor() {
    if (state.connectionState == SSHConnectionState.connected) {
      _startConnectionMonitor();
    }
  }

  void _handleDisconnection() {
    if (state.connectionState == SSHConnectionState.disconnected) return;

    final wasConnected = state.connectionState == SSHConnectionState.connected;

    if (wasConnected && (shouldNotifyOnDisconnect?.call() ?? false)) {
      state = state.copyWith(showDisconnectNotification: true);
    }

    if (wasConnected &&
        (shouldReconnect?.call() ?? false) &&
        state.lastConnectionInfo != null &&
        state.reconnectAttempts < _maxReconnectAttempts) {
      _attemptReconnect();
    } else {
      state = state.copyWith(
        connectionState: SSHConnectionState.disconnected,
        errorMessage: 'Connexion perdue',
      );
    }
  }

  Future<void> _attemptReconnect() async {
    final info = state.lastConnectionInfo;
    if (info == null) return;

    final attempts = state.reconnectAttempts + 1;
    if (kDebugMode) debugPrint('Reconnect attempt $attempts/$_maxReconnectAttempts');

    state = state.copyWith(
      connectionState: SSHConnectionState.reconnecting,
      errorMessage: 'Reconnexion... (tentative $attempts/$_maxReconnectAttempts)',
      reconnectAttempts: attempts,
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      // Vérifier que le notifier n'est pas disposed avant toute opération
      if (_isDisposed) return;

      try {
        // Récupérer la clé privée depuis le stockage sécurisé
        final privateKey = await SecureStorageService.getPrivateKey(info.keyId);

        // Revérifier après l'opération async
        if (_isDisposed) return;

        if (privateKey == null) {
          if (kDebugMode) debugPrint('Failed to retrieve private key for reconnection');
          state = state.copyWith(
            connectionState: SSHConnectionState.error,
            errorMessage: 'Clé privée introuvable',
          );
          return;
        }

        for (final service in _tabServices.values) {
          await service.disconnect();
        }
        _tabServices.clear();

        // Revérifier après les déconnexions
        if (_isDisposed) return;

        final tabId = _generateTabId();
        final newService = SSHService();
        final success = await newService.connect(
          host: info.host,
          username: info.username,
          privateKey: privateKey,
          port: info.port,
        );

        // Revérifier après la connexion
        if (_isDisposed) {
          await newService.disconnect();
          return;
        }

        if (success) {
          await newService.startShell();

          // Revérifier après startShell
          if (_isDisposed) {
            await newService.disconnect();
            return;
          }

          _tabServices[tabId] = newService;

          state = state.copyWith(
            connectionState: SSHConnectionState.connected,
            errorMessage: null,
            reconnectAttempts: 0,
            currentTabId: tabId,
            tabIds: [tabId],
          );
          _startConnectionMonitor();
          AuditLogService.log(AuditEventType.sshReconnect, details: {'host': info.host, 'port': '${info.port}'});
          if (kDebugMode) debugPrint('Reconnection successful');
        } else {
          _handleDisconnection();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Reconnection failed');
        if (!_isDisposed) {
          _handleDisconnection();
        }
      }
    });
  }

  void clearDisconnectNotification() {
    state = state.copyWith(showDisconnectNotification: false);
  }

  Future<void> disconnect() async {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final info = state.lastConnectionInfo;

    // Fermer les services SSH
    for (final service in _tabServices.values) {
      await service.disconnect();
    }
    _tabServices.clear();

    // Fermer les services Local Shell
    for (final service in _localTabServices.values) {
      await service.close();
    }
    _localTabServices.clear();

    // Arrêter le foreground service
    await ForegroundSSHService.stop();

    if (info != null) {
      AuditLogService.log(AuditEventType.sshDisconnect, details: {'host': info.host, 'port': '${info.port}'});
    }

    state = const SSHState();
  }

  /// Marque un onglet comme ayant une connexion morte (stream fermé)
  void markTabAsDead(String tabId) {
    if (kDebugMode) debugPrint('markTabAsDead: Tab $tabId marked as dead');
    state = state.copyWith(
      deadTabIds: {...state.deadTabIds, tabId},
    );
  }

  /// Vérifie et reconnecte les onglets SSH si la connexion est perdue
  /// Appelé quand l'app revient au premier plan
  Future<void> checkAndReconnectIfNeeded() async {
    if (kDebugMode) debugPrint('checkAndReconnectIfNeeded: Checking SSH connections...');
    if (kDebugMode) debugPrint('checkAndReconnectIfNeeded: Dead tabs: ${state.deadTabIds}');

    // Pour chaque onglet SSH (pas local)
    for (final tabId in state.tabIds) {
      if (state.localTabIds.contains(tabId)) continue; // Skip local tabs

      // Vérifier si l'onglet est marqué comme mort
      final isDead = state.deadTabIds.contains(tabId);
      if (kDebugMode) debugPrint('checkAndReconnectIfNeeded: Tab $tabId - isDead: $isDead');

      if (isDead && state.lastConnectionInfo != null) {
        if (kDebugMode) debugPrint('checkAndReconnectIfNeeded: Tab $tabId needs reconnection');
        // Tenter une reconnexion
        final success = await _reconnectTab(tabId);
        if (success) {
          // Retirer de la liste des morts
          state = state.copyWith(
            deadTabIds: state.deadTabIds.where((id) => id != tabId).toSet(),
          );
        }
      }
    }
  }

  /// Reconnecte un onglet spécifique
  Future<bool> _reconnectTab(String tabId) async {
    final info = state.lastConnectionInfo;
    if (info == null) return false;

    try {
      if (kDebugMode) debugPrint('_reconnectTab: Reconnecting tab $tabId...');

      final privateKey = await SecureStorageService.getPrivateKey(info.keyId);
      if (privateKey == null || privateKey.isEmpty) return false;

      final service = _tabServices[tabId];
      if (service == null) return false;

      // Fermer l'ancienne connexion
      await service.disconnect();

      // Créer une nouvelle connexion
      final newService = SSHService();
      final success = await newService.connect(
        host: info.host,
        username: info.username,
        privateKey: privateKey,
        port: info.port,
      );

      if (success) {
        await newService.startShell();
        _tabServices[tabId] = newService;
        if (kDebugMode) debugPrint('_reconnectTab: Tab $tabId reconnected successfully');
        return true;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_reconnectTab: Failed to reconnect tab $tabId: $e');
    }
    return false;
  }

  void write(String data) {
    final currentTabId = state.currentTabId;
    if (kDebugMode) debugPrint('SSH write: tabId=$currentTabId');
    if (currentTabId != null) {
      writeToTab(currentTabId, data);
    } else {
      if (kDebugMode) debugPrint('SSH write: currentTabId is NULL, data not sent!');
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

    final sshService = _tabServices[currentTabId];
    return sshService?.executeCommandSilently(command);
  }

  /// Écrit vers un onglet spécifique par ID
  void writeToTab(String tabId, String data) {
    if (state.localTabIds.contains(tabId)) {
      _localTabServices[tabId]?.write(data);
      return;
    }
    // SSH path
    final sshService = _tabServices[tabId];
    if (sshService != null) {
      final session = sshService.session;
      if (session != null) {
        session.stdin.add(Uint8List.fromList(utf8.encode(data)));
      }
    }
  }

  /// Redimensionne le PTY de l'onglet actif
  void resizeTerminal(int width, int height) {
    if (state.currentTabId != null) {
      _tabServices[state.currentTabId]?.resizeTerminal(width, height);
    }
  }

  /// Redimensionne le PTY d'un onglet spécifique par ID
  /// Utilise un throttle de 150ms pour limiter le spam SIGWINCH pendant l'animation du clavier
  void resizeTerminalForTab(String tabId, int width, int height) {
    // Ignorer les dimensions invalides
    if (width <= 0 || height <= 0) return;

    // Vérifier si les dimensions sont identiques aux dernières envoyées
    final lastSent = _lastSentSizes[tabId];
    if (lastSent != null && lastSent.$1 == width && lastSent.$2 == height) {
      return; // Pas de changement, ignorer
    }

    // Stocker les dimensions demandées pour ce tab
    _pendingResizes[tabId] = (width, height);

    // Calculer le temps depuis le dernier resize envoyé
    final now = DateTime.now();
    final timeSinceLastSend = _lastResizeSent == null
        ? _resizeThrottleMs
        : now.difference(_lastResizeSent!).inMilliseconds;

    if (timeSinceLastSend >= _resizeThrottleMs) {
      // Assez de temps écoulé: envoyer immédiatement
      _flushPendingResizes();
    } else {
      // Pas assez de temps: programmer l'envoi après le délai restant
      _resizeThrottleTimer?.cancel();
      final remainingDelay = _resizeThrottleMs - timeSinceLastSend;
      _resizeThrottleTimer = Timer(Duration(milliseconds: remainingDelay), () {
        _flushPendingResizes();
      });
    }
  }

  /// Envoie tous les resize en attente
  void _flushPendingResizes() {
    _lastResizeSent = DateTime.now();

    for (final entry in _pendingResizes.entries) {
      final tabId = entry.key;
      final (width, height) = entry.value;

      // Vérifier à nouveau si les dimensions ont changé depuis le dernier envoi
      final lastSent = _lastSentSizes[tabId];
      if (lastSent != null && lastSent.$1 == width && lastSent.$2 == height) {
        continue; // Pas de changement
      }

      if (kDebugMode) debugPrint('PTY RESIZE SEND: tab=$tabId, ${width}x$height');
      _lastSentSizes[tabId] = (width, height);

      if (state.localTabIds.contains(tabId)) {
        _localTabServices[tabId]?.resize(width, height);
      } else {
        _tabServices[tabId]?.resizeTerminal(width, height);
      }
    }
    _pendingResizes.clear();
  }

  // === Gestion du bouton Send/Stop par onglet ===

  /// Liste des commandes avec menu interactif (nécessitent flèches ↑/↓)
  static const _interactiveMenuCommands = <String>[
    // AI Coding CLI (vibe coding tools)
    'claude', 'opencode', 'aider', 'gemini', 'codex', 'cody',
    'amazon-q', 'aws-q',
    // Fuzzy finders & selectors
    'fzf', 'fzy', 'sk', 'peco', 'percol',
    // Monitoring avec navigation
    'htop', 'btop', 'top', 'atop', 'gtop', 'glances',
    'nvtop', 'radeontop', 's-tui',
    // File managers & navigation
    'mc', 'ranger', 'nnn', 'lf', 'vifm', 'ncdu',
    // Dialog & TUI menus
    'dialog', 'whiptail', 'zenity',
    // Pagers
    'less', 'more', 'most',
    // Éditeurs (navigation avec flèches)
    'vim', 'vi', 'nvim', 'nano', 'emacs', 'micro',
    // Git interactif
    'tig', 'lazygit', 'gitui',
    // Docker TUI
    'lazydocker', 'ctop',
    // Autres TUI
    'k9s', 'bpytop', 'bashtop',
  ];

  /// Liste des commandes qui lancent des process long-running
  static const _longRunningCommands = <String>[
    // AI Coding CLI (vibe coding tools)
    'claude', 'opencode', 'aider', 'gemini', 'codex', 'cody',
    'amazon-q', 'aws-q',
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
    'mysql', 'mysqld', 'postgres', 'psql', 'redis-server', 'redis-cli', 'mongo', 'mongod',
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

  /// Vérifie si une commande a un menu interactif (nécessite flèches)
  bool isInteractiveMenuCommand(String command) {
    final trimmed = command.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    // Vérifier chaque commande dans un pipe
    final pipedCommands = trimmed.split('|');
    for (final pipeCmd in pipedCommands) {
      final cmdTrimmed = pipeCmd.trim();
      if (cmdTrimmed.isEmpty) continue;

      final firstWord = cmdTrimmed.split(RegExp(r'\s+')).first;
      if (_interactiveMenuCommands.contains(firstWord)) return true;
    }

    return false;
  }

  /// Vérifie si une commande est "long-running"
  bool isLongRunningCommand(String command) {
    final trimmed = command.trim().toLowerCase();
    if (trimmed.isEmpty) return false;

    // Cas spéciaux avec arguments
    if (trimmed.startsWith('tail ') && trimmed.contains('-f')) return true;
    if (trimmed.startsWith('docker build')) return true;
    if (trimmed.startsWith('docker-compose') || trimmed.startsWith('docker compose')) return true;

    // Commandes interactives avec -i (demandent confirmation y/n)
    if (trimmed.contains(' -i') || trimmed.contains(' --interactive')) return true;

    // Vérifier chaque commande dans un pipe (cmd1 | cmd2 | cmd3)
    final pipedCommands = trimmed.split('|');
    for (final pipeCmd in pipedCommands) {
      final cmdTrimmed = pipeCmd.trim();
      if (cmdTrimmed.isEmpty) continue;

      final firstWord = cmdTrimmed.split(RegExp(r'\s+')).first;

      // Scripts exécutables
      if (firstWord.startsWith('./') || firstWord.startsWith('/')) return true;
      if (firstWord.endsWith('.sh') || firstWord.endsWith('.py') || firstWord.endsWith('.rb')) return true;

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

  /// Vérifie si l'onglet actif a un menu interactif en cours
  bool get isCurrentTabInteractive {
    final command = state.currentTabCommand;
    if (command == null) return false;
    return isInteractiveMenuCommand(command);
  }

  /// Envoie Ctrl+C (interrupt) à l'onglet actif et le marque comme libre
  void sendInterrupt() {
    // Envoie le caractère Ctrl+C (ASCII 3)
    write('\x03');
    setCurrentTabRunning(false);
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

    final sshService = _tabServices[currentTabId];
    return sshService?.uploadFile(
      localPath: localPath,
      remotePath: remotePath,
    );
  }
}

final sshProvider = NotifierProvider<SSHNotifier, SSHState>(
  SSHNotifier.new,
);
