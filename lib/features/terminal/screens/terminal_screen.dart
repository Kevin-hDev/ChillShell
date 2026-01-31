import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/models.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/storage_service.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

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

    ref.read(sessionsProvider.notifier).addSession(
      name: lastConnection.host,
      host: lastConnection.host,
      username: lastConnection.username,
      port: lastConnection.port,
    );

    final sessions = ref.read(sessionsProvider);
    final sessionId = sessions.last.id;

    final success = await ref.read(sshProvider.notifier).connect(
      host: lastConnection.host,
      username: lastConnection.username,
      privateKey: privateKey,
      keyId: lastConnection.keyId,
      sessionId: sessionId,
      port: lastConnection.port,
    );

    if (success) {
      ref.read(sessionsProvider.notifier).updateSessionStatus(
        sessionId,
        ConnectionStatus.connected,
      );
      await storage.updateConnectionLastConnected(lastConnection.id);
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
    final result = await showDialog<ConnectionInfo>(
      context: context,
      builder: (context) => const ConnectionDialog(),
    );

    if (result != null) {
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

    ref.read(sessionsProvider.notifier).addSession(
      name: info.host,
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
