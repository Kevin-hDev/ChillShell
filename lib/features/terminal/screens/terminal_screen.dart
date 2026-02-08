import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../models/wol_config.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/chillshell_loader.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/storage_service.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../features/settings/providers/wol_provider.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';
import '../widgets/wol_start_screen.dart';

/// Hauteur fixe de la zone overlay (boutons ESC/newline + GhostTextInput)
/// ESC row: ~37px, GhostTextInput: ~103px = 140px sans SafeArea
const double _kInputOverlayHeight = 140;

class TerminalScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsTap;

  const TerminalScreen({super.key, this.onSettingsTap});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  // GlobalKey pour accéder au GhostTextInput depuis le bouton saut de ligne
  final _ghostTextInputKey = GlobalKey<GhostTextInputState>();
  // GlobalKey pour préserver l'animation du loader entre les rebuilds
  final _loaderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSSHCallbacks();
      _tryAutoConnect();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pré-charger l'image du loader en mémoire AVANT d'en avoir besoin
    // Sinon le premier décodage PNG + upload GPU cause des saccades
    precacheImage(
      const AssetImage('assets/images/chillshell_loader.png'),
      context,
    );
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

  /// Affiche un dialogue pour confirmer une nouvelle clé d'hôte SSH (TOFU)
  Future<bool> _showHostKeyDialog(
    String host, int port, String keyType, String fingerprint,
  ) async {
    if (!mounted) return false;
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgBlock,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.border),
        ),
        title: Row(
          children: [
            Icon(Icons.shield_outlined, color: theme.accent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.sshHostKeyTitle,
                style: TextStyle(color: theme.text, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sshHostKeyMessage(host),
              style: TextStyle(color: theme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.sshHostKeyType(keyType),
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.sshHostKeyFingerprint,
              style: TextStyle(color: theme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.border),
              ),
              child: SelectableText(
                fingerprint,
                style: VibeTermTypography.command.copyWith(
                  color: theme.accent,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.sshHostKeyReject,
              style: TextStyle(color: theme.danger),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: theme.accent),
            child: Text(
              l10n.sshHostKeyAccept,
              style: TextStyle(color: theme.bg),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Affiche un dialogue d'alerte quand la clé d'hôte SSH a changé (MITM potentiel)
  Future<bool> _showHostKeyMismatchDialog(
    String host, int port, String keyType, String fingerprint,
  ) async {
    if (!mounted) return false;
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.bgBlock,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.danger),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: theme.danger, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.sshHostKeyMismatchTitle,
                style: TextStyle(color: theme.danger, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.sshHostKeyMismatchMessage(host),
              style: TextStyle(color: theme.text, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.danger.withValues(alpha: 0.5)),
              ),
              child: SelectableText(
                fingerprint,
                style: VibeTermTypography.command.copyWith(
                  color: theme.danger,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: FilledButton.styleFrom(backgroundColor: theme.danger),
            child: Text(
              l10n.sshHostKeyReject,
              style: TextStyle(color: theme.bg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.sshHostKeyAccept,
              style: TextStyle(color: theme.textMuted),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showDisconnectNotification() {
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.connectionLostSnack),
        backgroundColor: theme.danger,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: l10n.reconnect,
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

    // Trouver la connexion marquée comme auto-connexion (isQuickAccess = true)
    final autoConnection = connections.where((c) => c.isQuickAccess).firstOrNull;
    if (autoConnection == null) return;

    final lastConnection = autoConnection;

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
    final l10n = context.l10n;
    // Utiliser le compteur pour nommer l'onglet (évite répétition IP)
    final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();
    ref.read(sessionsProvider.notifier).addSession(
      name: l10n.terminalTab(tabNumber.toString()),
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
      onFirstHostKey: _showHostKeyDialog,
      onHostKeyMismatch: _showHostKeyMismatchDialog,
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
    final isConnected = sshState.connectionState == SSHConnectionState.connected;
    final isEditorMode = isConnected ? ref.watch(isEditorModeProvider) : false;

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
      // Ne PAS redimensionner le body quand le clavier s'ouvre.
      // Empêche xterm.dart de supprimer des lignes du buffer lors du resize,
      // ce qui causait la perte de texte sur Windows SSH.
      resizeToAvoidBottomInset: false,
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
            onScrollToBottom: () => terminalViewKey.currentState?.scrollToBottom(),
            onImageImport: _handleImageImport,
          ),
          if (sshState.connectionState == SSHConnectionState.connected)
            const SessionInfoBar(),
          Expanded(
            child: Stack(
              children: [
                // Contenu terminal : réserver l'espace en bas pour la zone de saisie
                // (uniquement en mode normal, pas en mode éditeur vim/nano)
                if (isConnected && !isEditorMode)
                  Positioned.fill(
                    bottom: _kInputOverlayHeight + MediaQuery.of(context).padding.bottom,
                    child: _buildContent(sshState, sessions, theme),
                  )
                else
                  _buildContent(sshState, sessions, theme),
                // Mode éditeur (vim/nano) : boutons overlay à droite
                if (isConnected && isEditorMode)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: EditorModeButtons(
                      onEnter: () => ref.read(sshProvider.notifier).write('\r'),
                      onCtrlKey: (ctrlCode) {
                        ref.read(sshProvider.notifier).write(String.fromCharCode(ctrlCode));
                      },
                      onArrow: (direction) {
                        final isAppMode = terminalViewKey.currentState?.isApplicationCursorMode ?? false;
                        final prefix = isAppMode ? '\x1bO' : '\x1b[';
                        ref.read(sshProvider.notifier).write('$prefix$direction');
                      },
                      theme: theme,
                    ),
                  ),
                // Mode normal : GhostTextInput + boutons ESC/saut de ligne
                // Positionnés au-dessus du clavier virtuel (flottant)
                if (isConnected && !isEditorMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Boutons ESC et saut de ligne
                        Padding(
                          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _DiscreteOverlayButton(
                                text: 'ESC',
                                onTap: () => ref.read(sshProvider.notifier).write('\x1b'),
                                theme: theme,
                              ),
                              _DiscreteOverlayButton(
                                icon: Icons.subdirectory_arrow_left,
                                onTap: () {
                                  _ghostTextInputKey.currentState?.insertNewLine();
                                },
                                theme: theme,
                              ),
                            ],
                          ),
                        ),
                        // Champ de saisie
                        GhostTextInput(key: _ghostTextInputKey),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(SSHState sshState, List<Session> sessions, VibeTermThemeData theme) {
    if (sshState.connectionState == SSHConnectionState.connected) {
      return VibeTerminalView(key: terminalViewKey);
    }

    if (sshState.connectionState == SSHConnectionState.connecting ||
        sshState.connectionState == SSHConnectionState.reconnecting) {
      final l10n = context.l10n;
      final isReconnecting = sshState.connectionState == SSHConnectionState.reconnecting;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChillShellLoader(
              key: _loaderKey, // Préserve l'animation entre rebuilds
              size: 220,
              style: LoaderAnimationStyle.rotateFloat,
              duration: const Duration(milliseconds: 2500),
            ),
            const SizedBox(height: VibeTermSpacing.lg),
            Text(
              sshState.errorMessage ?? (isReconnecting ? l10n.reconnecting : l10n.connectionInProgress),
              style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (sshState.connectionState == SSHConnectionState.error) {
      final l10n = context.l10n;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(VibeTermSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.danger),
              const SizedBox(height: VibeTermSpacing.md),
              Text(
                sshState.errorMessage ?? l10n.connectionError,
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
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
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
              l10n.noConnection,
              style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
            ),
            const SizedBox(height: VibeTermSpacing.xs),
            Text(
              l10n.connectToServer,
              style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            ),
            const SizedBox(height: VibeTermSpacing.lg),
            // Bouton WOL START
            _buildWolStartButton(theme),
            const SizedBox(height: VibeTermSpacing.md),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: theme.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeTermSpacing.lg,
                  vertical: VibeTermSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VibeTermRadius.md),
                  side: BorderSide(color: theme.accent),
                ),
                elevation: 0,
              ),
              onPressed: _showConnectionDialog,
              icon: const Icon(Icons.add),
              label: Text(l10n.newConnection),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit le bouton WOL START avec sa logique d'activation
  Widget _buildWolStartButton(VibeTermThemeData theme) {
    final l10n = context.l10n;
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          side: isEnabled ? BorderSide.none : BorderSide(color: theme.border),
        ),
        elevation: 0,
      ),
      onPressed: isEnabled ? _handleWolStartPress : null,
      icon: Icon(
        Icons.bolt,
        color: isEnabled ? theme.bg : theme.textMuted,
      ),
      label: Text(l10n.wolStart),
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
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    final storage = StorageService();
    final savedConnections = await storage.getSavedConnections();

    if (!mounted) return null;

    return showDialog<WolConfig>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeTermRadius.lg),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          l10n.wakeUpPc,
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
                  name: 'Unknown',
                  host: 'Unknown',
                  username: 'Unknown',
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
                onTap: () => Navigator.of(dialogContext).pop(config),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: Text(
              l10n.cancel,
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
    final l10n = context.l10n;
    final privateKey = await SecureStorageService.getPrivateKey(connection.keyId);
    if (privateKey == null || privateKey.isEmpty) return false;

    // Créer une session pour la connexion
    final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();
    ref.read(sessionsProvider.notifier).addSession(
      name: l10n.terminalTab(tabNumber.toString()),
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
      onFirstHostKey: _showHostKeyDialog,
      onHostKeyMismatch: _showHostKeyMismatchDialog,
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
    final l10n = context.l10n;
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
            content: Text(l10n.unableToCreateTab),
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
        name: l10n.terminalTab(tabNumber.toString()),
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
      ref.read(activeSessionIndexProvider.notifier).set(newSessions.length - 1);
    }
  }

  /// Gère l'import d'une image pour les agents IA CLI
  /// Transfère l'image vers le serveur SSH via SFTP, puis colle le chemin distant
  Future<void> _handleImageImport() async {
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    final sshState = ref.read(sshProvider);

    // Vérifier qu'on est connecté
    if (sshState.connectionState != SSHConnectionState.connected) {
      return;
    }

    // Pour les shells locaux, on utilise le chemin local directement
    final currentTabId = sshState.currentTabId;
    final isLocalTab = currentTabId != null && sshState.localTabIds.contains(currentTabId);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = pickedFile.path.split('.').last;

      if (isLocalTab) {
        // Shell local : copier vers /tmp local et coller le chemin
        final tempDir = await getTemporaryDirectory();
        final localPath = '${tempDir.path}/vibeterm_image_$timestamp.$extension';
        await File(pickedFile.path).copy(localPath);
        ref.read(sshProvider.notifier).write(localPath);
      } else {
        // SSH : transférer via SFTP vers le serveur
        final remotePath = '/tmp/vibeterm_image_$timestamp.$extension';

        // Afficher un indicateur de chargement
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.uploadingImage),
              backgroundColor: theme.accent,
              duration: const Duration(seconds: 30),
            ),
          );
        }

        final uploadedPath = await ref.read(sshProvider.notifier).uploadFile(
          localPath: pickedFile.path,
          remotePath: remotePath,
        );

        // Fermer le snackbar de chargement
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        if (uploadedPath != null) {
          // Succès : coller le chemin distant dans le terminal
          ref.read(sshProvider.notifier).write(uploadedPath);
        } else {
          // Échec : afficher une erreur
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.uploadFailed),
                backgroundColor: theme.danger,
              ),
            );
          }
        }
      }
    } catch (e) {
      // Erreur : afficher un message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.uploadFailed),
            backgroundColor: theme.danger,
          ),
        );
      }
    }
  }

  Future<void> _showDisconnectConfirmation() async {
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeTermRadius.lg),
          side: BorderSide(color: theme.border),
        ),
        title: Text(
          l10n.disconnectConfirmTitle,
          style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
        ),
        content: Text(
          l10n.disconnectConfirmMessage,
          style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: theme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.disconnect,
              style: TextStyle(color: theme.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sshProvider.notifier).disconnect();
      ref.read(sessionsProvider.notifier).clearSessions();
      ref.read(activeSessionIndexProvider.notifier).set(0);
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
    final l10n = context.l10n;
    final privateKey = await SecureStorageService.getPrivateKey(info.keyId);

    if (privateKey == null || privateKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.privateKeyNotFound)),
        );
      }
      return;
    }

    // Utiliser le compteur pour nommer l'onglet (évite répétition IP)
    final tabNumber = ref.read(sshProvider.notifier).getAndIncrementTabNumber();
    ref.read(sessionsProvider.notifier).addSession(
      name: l10n.terminalTab(tabNumber.toString()),
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
      onFirstHostKey: _showHostKeyDialog,
      onHostKeyMismatch: _showHostKeyMismatchDialog,
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

/// Bouton discret superposé sur le terminal (ESC, saut de ligne)
/// - Pas d'encadré par défaut (discret sur fond noir)
/// - Animation au clic : encadré temporaire
class _DiscreteOverlayButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const _DiscreteOverlayButton({
    this.text,
    this.icon,
    required this.onTap,
    required this.theme,
  }) : assert(text != null || icon != null);

  @override
  State<_DiscreteOverlayButton> createState() => _DiscreteOverlayButtonState();
}

class _DiscreteOverlayButtonState extends State<_DiscreteOverlayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          color: _isPressed ? widget.theme.border : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isPressed ? widget.theme.textMuted : Colors.transparent,
          ),
        ),
        child: Center(
          child: widget.text != null
              ? Text(
                  widget.text!,
                  style: TextStyle(
                    color: widget.theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(
                  widget.icon,
                  color: widget.theme.textMuted,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
