import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/models.dart';
import '../../../models/wol_config.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/storage_service.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../features/settings/providers/wol_provider.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../widgets/wol_start_screen.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsTap;

  const TerminalScreen({super.key, this.onSettingsTap});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSSHCallbacks();
      _tryAutoConnect();
    });
  }

  void _setupSSHCallbacks() {
    final sshNotifier = ref.read(sshProvider.notifier);

    sshNotifier.shouldReconnect = () {
      final settings = ref.read(settingsProvider);
      return settings.appSettings.reconnectOnDisconnect;
    };

    sshNotifier.shouldNotifyOnDisconnect = () {
      final settings = ref.read(settingsProvider);
      return settings.appSettings.notifyOnDisconnect;
    };
  }

  void _showDisconnectNotification() {
    final theme = ref.read(vibeTermThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Connexion perdue'),
        backgroundColor: theme.danger,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Reconnecter',
          textColor: Colors.white,
          onPressed: _showConnectionDialog,
        ),
      ),
    );
  }

  Future<void> _tryAutoConnect() async {
    var settings = ref.read(settingsProvider);
    int attempts = 0;
    while (settings.isLoading && attempts < 10) {
      await Future.delayed(const Duration(milliseconds: 200));
      settings = ref.read(settingsProvider);
      attempts++;
    }

    final sshState = ref.read(sshProvider);

    if (!settings.appSettings.autoConnectOnStart) return;
    if (sshState.connectionState != SSHConnectionState.disconnected) return;

    final storage = StorageService();
    final connections = await storage.getSavedConnections();

    if (connections.isEmpty) return;

    connections.sort((a, b) => (b.lastConnected ?? DateTime(2000)).compareTo(a.lastConnected ?? DateTime(2000)));
    final lastConnection = connections.first;

    final privateKey = await SecureStorageService.getPrivateKey(lastConnection.keyId);
    if (privateKey == null || privateKey.isEmpty) return;

    // Vérifier si WOL auto doit être déclenché
    // Conditions: WOL activé ET config WOL existe pour la dernière connexion
    if (settings.appSettings.wolEnabled) {
      // Attendre que le provider WOL soit chargé
      var wolState = ref.read(wolProvider);
      int wolAttempts = 0;
      while (wolState.isLoading && wolAttempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        wolState = ref.read(wolProvider);
        wolAttempts++;
      }

      final wolConfig = ref.read(wolProvider.notifier).getConfigForSshConnection(lastConnection.id);

      if (wolConfig != null) {
        // WOL auto: lancer WolStartScreen au lieu de SSH directe
        if (mounted) {
          _launchWolStartScreenAuto(wolConfig, lastConnection);
        }
        return;
      }
    }

    // Comportement standard: tentative SSH directe
    await _performDirectSshConnect(lastConnection, privateKey);
  }

  /// Lance WolStartScreen automatiquement au démarrage de l'app.
  void _launchWolStartScreenAuto(WolConfig config, SavedConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WolStartScreen(
          config: config,
          tryConnect: () => _tryConnectForWol(connection),
          onSuccess: () {
            // Revenir à l'écran terminal (connexion établie)
            Navigator.of(context).pop();
          },
          onCancel: () {
            // Revenir à l'écran d'accueil normal
            Navigator.of(context).pop();
          },
          onError: (error) {
            // Revenir à l'écran d'accueil et afficher l'erreur
            Navigator.of(context).pop();
            _showWolErrorSnackBar(error);
          },
        ),
      ),
    );
  }

  /// Effectue une connexion SSH directe (comportement standard).
  Future<void> _performDirectSshConnect(SavedConnection connection, String privateKey) async {
    // Utiliser le compteur pour nommer l'onglet (évite répétition IP)
    final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();
    ref.read(sessionsProvider.notifier).addSession(
      name: 'Terminal $tabNumber',
      host: connection.host,
      username: connection.username,
      port: connection.port,
    );

    final sessions = ref.read(sessionsProvider);
    final sessionId = sessions.last.id;

    final success = await ref.read(sshProvider.notifier).connect(
      host: connection.host,
      username: connection.username,
      privateKey: privateKey,
      keyId: connection.keyId,
      sessionId: sessionId,
      port: connection.port,
    );

    if (success) {
      ref.read(sessionsProvider.notifier).updateSessionStatus(
        sessionId,
        ConnectionStatus.connected,
      );
      await StorageService().updateConnectionLastConnected(connection.id);
    } else {
      ref.read(sessionsProvider.notifier).removeSession(sessionId);
    }
  }

  /// Gère le changement d'onglet (par index UI)
  void _onTabChanged(int newIndex) {
    final sshState = ref.read(sshProvider);
    if (sshState.connectionState == SSHConnectionState.connected) {
      ref.read(sshProvider.notifier).selectTabByIndex(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sshState = ref.watch(sshProvider);
    final sessions = ref.watch(sessionsProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    // Écouter les changements d'onglet UI
    ref.listen<int>(activeSessionIndexProvider, (previous, next) {
      if (previous != null && previous != next) {
        _onTabChanged(next);
      }
    });

    // Écouter les notifications de déconnexion
    ref.listen<SSHState>(sshProvider, (previous, next) {
      if (next.showDisconnectNotification) {
        _showDisconnectNotification();
        ref.read(sshProvider.notifier).clearDisconnectNotification();
      }
    });

    return Scaffold(
      backgroundColor: theme.bg,
      body: Column(
        children: [
          AppHeader(
            isTerminalActive: true,
            onSettingsTap: widget.onSettingsTap,
            onDisconnect: _showDisconnectConfirmation,
          ),
          SessionTabBar(
            onAddTab: _addNewTab,
            onAddSession: _showConnectionDialog,
          ),
          if (sshState.connectionState == SSHConnectionState.connected)
            const SessionInfoBar(),
          Expanded(
            child: _buildContent(sshState, sessions, theme),
          ),
          if (sshState.connectionState == SSHConnectionState.connected)
            const GhostTextInput(),
        ],
      ),
    );
  }

  Widget _buildContent(SSHState sshState, List<Session> sessions, VibeTermThemeData theme) {
    if (sshState.connectionState == SSHConnectionState.connected) {
      return const VibeTerminalView();
    }

    if (sshState.connectionState == SSHConnectionState.connecting ||
        sshState.connectionState == SSHConnectionState.reconnecting) {
      final isReconnecting = sshState.connectionState == SSHConnectionState.reconnecting;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: isReconnecting ? theme.warning : theme.accent),
            const SizedBox(height: VibeTermSpacing.md),
            Text(
              sshState.errorMessage ?? (isReconnecting ? 'Reconnexion...' : 'Connexion en cours...'),
              style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (sshState.connectionState == SSHConnectionState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VibeTermSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.danger),
              const SizedBox(height: VibeTermSpacing.md),
              Text(
                sshState.errorMessage ?? 'Erreur de connexion',
                style: VibeTermTypography.caption.copyWith(color: theme.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: VibeTermSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  foregroundColor: theme.bg,
                ),
                onPressed: _showConnectionDialog,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.bgBlock,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.border),
              ),
              child: Icon(
                Icons.terminal,
                size: 40,
                color: theme.textMuted,
              ),
            ),
            const SizedBox(height: VibeTermSpacing.md),
            Text(
              'Aucune connexion',
              style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
            ),
            const SizedBox(height: VibeTermSpacing.xs),
            Text(
              'Connectez-vous à un serveur SSH',
              style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            ),
            const SizedBox(height: VibeTermSpacing.lg),
            // Bouton WOL START
            _buildWolStartButton(theme),
            const SizedBox(height: VibeTermSpacing.md),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.bg,
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeTermSpacing.lg,
                  vertical: VibeTermSpacing.md,
                ),
              ),
              onPressed: _showConnectionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle connexion'),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit le bouton WOL START avec sa logique d'activation
  Widget _buildWolStartButton(VibeTermThemeData theme) {
    final settings = ref.watch(settingsProvider);
    final wolState = ref.watch(wolProvider);

    // Le bouton est grisé si WOL désactivé OU aucune config
    final isEnabled = settings.appSettings.wolEnabled && wolState.configs.isNotEmpty;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? theme.accent : theme.bgBlock,
        foregroundColor: isEnabled ? theme.bg : theme.textMuted,
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.lg,
          vertical: VibeTermSpacing.md,
        ),
        side: isEnabled ? null : BorderSide(color: theme.border),
      ),
      onPressed: isEnabled ? _handleWolStartPress : null,
      icon: Icon(
        Icons.bolt,
        color: isEnabled ? theme.bg : theme.textMuted,
      ),
      label: const Text('WOL START'),
    );
  }

  /// Gère le clic sur le bouton WOL START
  Future<void> _handleWolStartPress() async {
    final wolState = ref.read(wolProvider);
    final configs = wolState.configs;

    if (configs.isEmpty) return;

    if (configs.length == 1) {
      // Une seule config → lancement direct
      await _launchWolStartScreen(configs.first);
    } else {
      // Plusieurs configs → afficher le dialog de sélection
      final selectedConfig = await _showWolSelectionDialog(configs);
      if (selectedConfig != null) {
        await _launchWolStartScreen(selectedConfig);
      }
    }
  }

  /// Affiche le dialog de sélection du PC à allumer
  Future<WolConfig?> _showWolSelectionDialog(List<WolConfig> configs) async {
    final theme = ref.read(vibeTermThemeProvider);
    final storage = StorageService();
    final savedConnections = await storage.getSavedConnections();

    if (!mounted) return null;

    return showDialog<WolConfig>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeTermRadius.lg),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          'Allumer un PC',
          style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: configs.length,
            itemBuilder: (context, index) {
              final config = configs[index];
              // Trouver la connexion SSH associée pour afficher les infos
              final sshConnection = savedConnections.firstWhere(
                (c) => c.id == config.sshConnectionId,
                orElse: () => const SavedConnection(
                  id: '',
                  name: 'Inconnu',
                  host: 'Inconnu',
                  username: 'Inconnu',
                  keyId: '',
                ),
              );

              return ListTile(
                leading: Icon(
                  Icons.computer,
                  color: theme.accent,
                ),
                title: Text(
                  config.name,
                  style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                ),
                subtitle: Text(
                  '${sshConnection.username}@${sshConnection.host}',
                  style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VibeTermRadius.md),
                ),
                onTap: () => Navigator.of(context).pop(config),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              'Annuler',
              style: TextStyle(color: theme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// Lance l'écran WolStartScreen avec la config sélectionnée
  Future<void> _launchWolStartScreen(WolConfig config) async {
    final storage = StorageService();
    final savedConnections = await storage.getSavedConnections();

    // Trouver la connexion SSH associée
    final sshConnection = savedConnections.firstWhere(
      (c) => c.id == config.sshConnectionId,
      orElse: () => throw Exception('Connexion SSH non trouvée'),
    );

    if (!mounted) return;

    // Naviguer vers WolStartScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WolStartScreen(
          config: config,
          tryConnect: () => _tryConnectForWol(sshConnection),
          onSuccess: () {
            // Revenir à l'écran terminal (connexion établie)
            Navigator.of(context).pop();
          },
          onCancel: () {
            // Revenir à l'écran d'accueil
            Navigator.of(context).pop();
          },
          onError: (error) {
            // Revenir à l'écran d'accueil et afficher l'erreur
            Navigator.of(context).pop();
            _showWolErrorSnackBar(error);
          },
        ),
      ),
    );
  }

  /// Tente une connexion SSH pour le WOL polling
  Future<bool> _tryConnectForWol(SavedConnection connection) async {
    final privateKey = await SecureStorageService.getPrivateKey(connection.keyId);
    if (privateKey == null || privateKey.isEmpty) return false;

    // Créer une session pour la connexion
    final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();
    ref.read(sessionsProvider.notifier).addSession(
      name: 'Terminal $tabNumber',
      host: connection.host,
      username: connection.username,
      port: connection.port,
    );

    final sessions = ref.read(sessionsProvider);
    final sessionId = sessions.last.id;

    final success = await ref.read(sshProvider.notifier).connect(
      host: connection.host,
      username: connection.username,
      privateKey: privateKey,
      keyId: connection.keyId,
      sessionId: sessionId,
      port: connection.port,
    );

    if (success) {
      ref.read(sessionsProvider.notifier).updateSessionStatus(
        sessionId,
        ConnectionStatus.connected,
      );
      await StorageService().updateConnectionLastConnected(connection.id);
    } else {
      // Nettoyer la session si échec
      ref.read(sessionsProvider.notifier).removeSession(sessionId);
    }

    return success;
  }

  /// Affiche une SnackBar d'erreur WOL
  void _showWolErrorSnackBar(String error) {
    if (!mounted) return;
    final theme = ref.read(vibeTermThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: theme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ajoute un nouvel onglet (nouvelle connexion SSH avec mêmes credentials)
  Future<void> _addNewTab() async {
    final sshNotifier = ref.read(sshProvider.notifier);
    final sshState = ref.read(sshProvider);

    // Si pas connecté, ouvrir le dialog de connexion
    if (sshState.connectionState != SSHConnectionState.connected) {
      _showConnectionDialog();
      return;
    }

    // Ignorer silencieusement si une création est déjà en cours (clics rapides)
    if (sshNotifier.isCreatingTab) {
      return;
    }

    // Créer un nouvel onglet avec nouvelle connexion SSH
    final tabId = await sshNotifier.createNewTab();

    if (tabId == null) {
      if (mounted) {
        final theme = ref.read(vibeTermThemeProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossible de créer un nouvel onglet'),
            backgroundColor: theme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Ajouter l'onglet dans l'UI
    final sessions = ref.read(sessionsProvider);
    if (sessions.isNotEmpty) {
      final firstSession = sessions.first;
      // Utiliser le compteur global qui ne décrémente jamais
      final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();

      ref.read(sessionsProvider.notifier).addSession(
        name: 'Terminal $tabNumber',
        host: firstSession.host,
        username: firstSession.username,
        port: firstSession.port,
      );

      final newSessions = ref.read(sessionsProvider);
      final newSessionId = newSessions.last.id;
      ref.read(sessionsProvider.notifier).updateSessionStatus(
        newSessionId,
        ConnectionStatus.connected,
      );

      // Sélectionner le nouvel onglet
      ref.read(activeSessionIndexProvider.notifier).state = newSessions.length - 1;
    }
  }

  Future<void> _showDisconnectConfirmation() async {
    final theme = ref.read(vibeTermThemeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeTermRadius.lg),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          'Déconnexion',
          style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
        ),
        content: Text(
          'Voulez-vous fermer toutes les connexions SSH ?',
          style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: TextStyle(color: theme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Déconnecter',
              style: TextStyle(color: theme.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sshProvider.notifier).disconnect();
      ref.read(sessionsProvider.notifier).clearSessions();
      ref.read(activeSessionIndexProvider.notifier).state = 0;
    }
  }

  Future<void> _showConnectionDialog() async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => const ConnectionDialog(),
    );

    // Gérer Local Shell
    if (result is LocalShellRequest) {
      if (!Platform.isIOS) {
        ref.read(sshProvider.notifier).connectLocal();
      }
      return;
    }

    // Gérer connexion SSH normale
    if (result != null && result is ConnectionInfo) {
      await _connect(result);
    }
  }

  Future<void> _connect(ConnectionInfo info) async {
    final privateKey = await SecureStorageService.getPrivateKey(info.keyId);

    if (privateKey == null || privateKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clé privée introuvable')),
        );
      }
      return;
    }

    // Utiliser le compteur pour nommer l'onglet (évite répétition IP)
    final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();
    ref.read(sessionsProvider.notifier).addSession(
      name: 'Terminal $tabNumber',
      host: info.host,
      username: info.username,
      port: info.port,
    );

    final sessions = ref.read(sessionsProvider);
    final sessionId = sessions.last.id;

    final success = await ref.read(sshProvider.notifier).connect(
      host: info.host,
      username: info.username,
      privateKey: privateKey,
      keyId: info.keyId,
      sessionId: sessionId,
      port: info.port,
    );

    if (success) {
      ref.read(sessionsProvider.notifier).updateSessionStatus(
        sessionId,
        ConnectionStatus.connected,
      );

      final storage = StorageService();
      if (info.isNewConnection) {
        final savedConnection = SavedConnection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: info.host,
          host: info.host,
          port: info.port,
          username: info.username,
          keyId: info.keyId,
          lastConnected: DateTime.now(),
        );
        await storage.saveConnection(savedConnection);
      } else if (info.savedConnectionId != null) {
        await storage.updateConnectionLastConnected(info.savedConnectionId!);
      }
    } else {
      ref.read(sessionsProvider.notifier).removeSession(sessionId);
    }
  }
}
