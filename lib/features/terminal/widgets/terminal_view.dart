import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/ssh_provider.dart';

/// Widget principal pour afficher le terminal xterm connecte via SSH.
class VibeTerminalView extends ConsumerStatefulWidget {
  const VibeTerminalView({super.key});

  @override
  ConsumerState<VibeTerminalView> createState() => _VibeTerminalViewState();
}

class _VibeTerminalViewState extends ConsumerState<VibeTerminalView> {
  /// Map des terminaux par ID stable (pas par index!)
  final Map<String, Terminal> _terminals = {};
  final Map<String, StreamSubscription<Uint8List>?> _subscriptions = {};

  late TerminalController terminalController;
  String? _currentTabId;

  // Cache pour le theme terminal
  TerminalTheme? _cachedTheme;
  VibeTermThemeData? _lastThemeData;

  /// Retourne le theme terminal depuis le cache ou le crée si nécessaire
  TerminalTheme _getTerminalTheme(VibeTermThemeData theme) {
    // Retourner le cache si le theme n'a pas changé
    if (_cachedTheme != null && _lastThemeData == theme) {
      return _cachedTheme!;
    }

    // Créer et cacher le nouveau theme
    _lastThemeData = theme;
    _cachedTheme = TerminalTheme(
      cursor: theme.accent,
      selection: theme.accent.withValues(alpha: 0.3),
      foreground: theme.text,
      background: theme.bg,
      black: const Color(0xFF000000),
      white: const Color(0xFFFFFFFF),
      red: theme.danger,
      green: theme.success,
      yellow: theme.warning,
      blue: const Color(0xFF3B82F6),
      magenta: const Color(0xFFA855F7),
      cyan: const Color(0xFF06B6D4),
      brightBlack: theme.textMuted,
      brightRed: const Color(0xFFF87171),
      brightGreen: const Color(0xFF34D399),
      brightYellow: const Color(0xFFFBBF24),
      brightBlue: const Color(0xFF60A5FA),
      brightMagenta: const Color(0xFFC084FC),
      brightCyan: const Color(0xFF22D3EE),
      brightWhite: const Color(0xFFFFFFFF),
      searchHitBackground: theme.accent.withValues(alpha: 0.3),
      searchHitBackgroundCurrent: theme.accent.withValues(alpha: 0.5),
      searchHitForeground: theme.text,
    );
    return _cachedTheme!;
  }

  @override
  void initState() {
    super.initState();
    terminalController = TerminalController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrentTab();
    });
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _subscriptions.clear();
    _terminals.clear();
    terminalController.dispose();
    super.dispose();
  }

  /// Retourne ou crée le terminal pour l'onglet donné
  Terminal _getOrCreateTerminal(String tabId) {
    if (!_terminals.containsKey(tabId)) {
      final terminal = Terminal(maxLines: 10000);
      terminal.onOutput = (data) => _handleTerminalOutput(data, tabId);
      // Synchroniser la taille du terminal avec le PTY distant
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        ref.read(sshProvider.notifier).resizeTerminalForTab(tabId, width, height);
      };
      _terminals[tabId] = terminal;
    }
    return _terminals[tabId]!;
  }

  /// Envoie les données saisies par l'utilisateur vers le serveur SSH
  void _handleTerminalOutput(String data, String tabId) {
    ref.read(sshProvider.notifier).writeToTab(tabId, data);
  }

  /// Initialise l'onglet courant
  void _initializeCurrentTab() {
    final sshState = ref.read(sshProvider);
    if (sshState.connectionState == SSHConnectionState.connected && sshState.currentTabId != null) {
      _connectToSSH(sshState.currentTabId!);
      _currentTabId = sshState.currentTabId;
    }
  }

  /// Connecte le terminal au flux SSH pour un onglet donné
  void _connectToSSH(String tabId, {int retryCount = 0}) {
    // Si déjà connecté à cet onglet, ne rien faire
    if (_subscriptions[tabId] != null) return;

    final sshNotifier = ref.read(sshProvider.notifier);
    final outputStream = sshNotifier.getOutputStreamForTab(tabId);

    if (outputStream != null) {
      final terminal = _getOrCreateTerminal(tabId);
      _subscriptions[tabId] = outputStream.listen(
        (data) {
          terminal.write(utf8.decode(data, allowMalformed: true));
        },
        onError: (error, stackTrace) {
          debugPrint('SSH stream error for tab $tabId');
          _cleanupTab(tabId);
        },
        onDone: () {
          debugPrint('SSH stream closed for tab $tabId');
          // Ne pas cleanup automatiquement - laisser l'utilisateur voir l'état final
        },
        cancelOnError: false, // Continuer même après erreur pour voir les messages
      );
      debugPrint('Connected to SSH stream for tab $tabId');
      // Forcer un rebuild pour afficher le contenu
      if (mounted) setState(() {});
    } else {
      // Le stream n'est pas encore disponible (connexion en cours)
      // Réessayer après un court délai (max 10 tentatives = 2 secondes)
      if (retryCount < 10) {
        debugPrint('No output stream for tab $tabId, retrying in 200ms (attempt ${retryCount + 1}/10)');
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _subscriptions[tabId] == null) {
            _connectToSSH(tabId, retryCount: retryCount + 1);
          }
        });
      } else {
        debugPrint('Failed to connect to SSH stream for tab $tabId after 10 attempts');
      }
    }
  }

  /// Change d'onglet
  void _switchToTab(String newTabId) {
    if (_currentTabId == newTabId) return;

    _currentTabId = newTabId;

    // Connecter au nouveau flux si pas encore fait
    if (_subscriptions[newTabId] == null) {
      _connectToSSH(newTabId);
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Nettoie les ressources d'un onglet fermé
  void _cleanupTab(String tabId) {
    _subscriptions[tabId]?.cancel();
    _subscriptions.remove(tabId);
    _terminals.remove(tabId);
    debugPrint('Cleaned up resources for tab $tabId');
  }

  @override
  Widget build(BuildContext context) {
    // Sélecteurs ciblés pour observer uniquement ce qui est nécessaire
    // Cela réduit les rebuilds inutiles quand des propriétés non-utilisées changent
    final connectionState = ref.watch(sshProvider.select((s) => s.connectionState));
    final currentTabId = ref.watch(sshProvider.select((s) => s.currentTabId));
    final errorMessage = ref.watch(sshProvider.select((s) => s.errorMessage));
    final theme = ref.watch(vibeTermThemeProvider);

    // Listener pour les changements complets (nécessaire pour previous/next)
    ref.listen<SSHState>(sshProvider, (previous, next) {
      if (next.connectionState == SSHConnectionState.connected && next.currentTabId != null) {
        // Changement d'onglet
        if (previous != null && previous.currentTabId != next.currentTabId) {
          _switchToTab(next.currentTabId!);
        }
        // Nouvelle connexion initiale
        else if (previous?.connectionState != SSHConnectionState.connected) {
          _currentTabId = next.currentTabId;
          _connectToSSH(next.currentTabId!);
          if (mounted) setState(() {});
        }

        // Nettoyer les onglets fermés
        if (previous != null) {
          final closedTabs = previous.tabIds.where((id) => !next.tabIds.contains(id));
          for (final tabId in closedTabs) {
            _cleanupTab(tabId);
          }
        }
      } else if (next.connectionState == SSHConnectionState.disconnected) {
        // Nettoyer tout
        for (final sub in _subscriptions.values) {
          sub?.cancel();
        }
        _subscriptions.clear();
        _terminals.clear();
        _currentTabId = null;
      }
    });

    // Afficher un état de chargement si non connecté
    if (connectionState != SSHConnectionState.connected || currentTabId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (connectionState == SSHConnectionState.connecting)
              CircularProgressIndicator(color: theme.accent)
            else
              Icon(
                Icons.terminal,
                size: 64,
                color: theme.textMuted,
              ),
            const SizedBox(height: 16),
            Text(
              connectionState == SSHConnectionState.connecting
                  ? 'Connexion en cours...'
                  : errorMessage ?? 'Non connecte',
              style: TextStyle(color: theme.textMuted),
            ),
          ],
        ),
      );
    }

    // Obtenir le terminal de l'onglet actif
    final terminal = _getOrCreateTerminal(currentTabId);

    // Afficher le terminal xterm
    // Key avec l'ID stable pour forcer Flutter à recréer le widget
    return TerminalView(
      terminal,
      key: ValueKey('terminal_$currentTabId'),
      controller: terminalController,
      autofocus: false,
      readOnly: true,  // Empêche la saisie directe - utiliser le champ en bas
      hardwareKeyboardOnly: true,  // Pas de clavier virtuel sur le terminal
      backgroundOpacity: 0,
      theme: _getTerminalTheme(theme),
      textStyle: const TerminalStyle(
        fontSize: 17,
        fontFamily: 'JetBrainsMono',
      ),
    );
  }
}
