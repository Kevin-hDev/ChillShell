import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../services/clipboard_security_service.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/ssh_provider.dart';
import '../providers/terminal_provider.dart';

/// Séquences ANSI pour l'alternate screen mode
/// Utilisées par nano, vim, less, htop, etc.
const _alternateScreenEnter = '\x1b[?1049h';
const _alternateScreenExit = '\x1b[?1049l';
// Variantes alternatives (certaines apps utilisent celles-ci)
const _alternateScreenEnterAlt = '\x1b[?47h';
const _alternateScreenExitAlt = '\x1b[?47l';

/// Liste blanche des vrais éditeurs qui nécessitent le mode éditeur
/// (saisie directe au clavier, pas de champ de texte)
/// Les CLI modernes (claude, opencode, vibe, codex, etc.) utilisent aussi
/// l'alternate screen mais attendent du texte via stdin → mode NORMAL
const _trueEditorCommands = <String>{
  // Éditeurs de texte
  'nano', 'vim', 'vi', 'nvim', 'neovim', 'emacs', 'micro', 'joe', 'pico',
  'ne', 'mcedit', 'ed', 'ex', 'view', 'rvim', 'rview', 'vimdiff',
  // Pagers (lecture seule avec navigation)
  'less', 'more', 'most', 'pg',
  // Moniteurs système avec interface interactive
  'htop', 'btop', 'top', 'atop', 'gtop', 'glances', 'nvtop', 'radeontop',
  's-tui', 'nmon', 'bmon', 'iotop', 'iftop', 'nethogs',
  // File managers
  'mc', 'ranger', 'nnn', 'lf', 'vifm', 'ncdu', 'fff', 'cfm',
  // TUI interactives nécessitant touches directes
  'alsamixer', 'ncmpcpp', 'cmus', 'mocp', 'tig', 'lazygit', 'lazydocker',
  'k9s', 'tmux', 'screen', 'byobu',
  // Menus et sélecteurs (quand lancés seuls, pas via pipe)
  'dialog', 'whiptail',
};

/// Widget principal pour afficher le terminal xterm connecte via SSH.
class VibeTerminalView extends ConsumerStatefulWidget {
  const VibeTerminalView({super.key});

  @override
  VibeTerminalViewState createState() => VibeTerminalViewState();
}

/// GlobalKey pour accéder à l'état du terminal depuis l'extérieur
final terminalViewKey = GlobalKey<VibeTerminalViewState>();

class VibeTerminalViewState extends ConsumerState<VibeTerminalView> {
  /// Map des terminaux par ID stable (pas par index!)
  final Map<String, Terminal> _terminals = {};
  final Map<String, StreamSubscription<Uint8List>?> _subscriptions = {};

  /// Dernière taille envoyée par tab (pour détecter les changements réels)
  final Map<String, (int, int)> _lastSentSize = {};

  late TerminalController terminalController;
  late ScrollController _scrollController;
  String? _currentTabId;

  // Cache pour le theme terminal
  TerminalTheme? _cachedTheme;
  VibeTermThemeData? _lastThemeData;

  /// Accumulateur pour le scroll tactile en alternate buffer
  /// Permet de convertir les pixels en PageUp/PageDown
  double _altBufferScrollAccumulator = 0.0;

  /// État du alternate buffer pour le terminal courant
  /// Utilisé pour déclencher un rebuild quand l'état change
  bool _isInAltBuffer = false;

  bool _lastIsEditorMode = false;

  /// Retourne le theme terminal depuis le cache ou le crée si nécessaire
  TerminalTheme _getTerminalTheme(
    VibeTermThemeData theme, {
    bool isEditorMode = false,
  }) {
    // Retourner le cache si le theme et le mode n'ont pas changé
    if (_cachedTheme != null &&
        _lastThemeData == theme &&
        _lastIsEditorMode == isEditorMode) {
      return _cachedTheme!;
    }

    // Créer et cacher le nouveau theme
    _lastThemeData = theme;
    _lastIsEditorMode = isEditorMode;
    _cachedTheme = TerminalTheme(
      // Curseur visible seulement en mode éditeur (transparent en mode normal)
      cursor: isEditorMode ? theme.accent : Colors.transparent,
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
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCurrentTab();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final sub in _subscriptions.values) {
      sub?.cancel();
    }
    _subscriptions.clear();
    _terminals.clear();
    terminalController.dispose();
    super.dispose();
  }

  /// Détecte si l'utilisateur a scrollé vers le haut
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // On considère "scrollé vers le haut" si on n'est pas à moins de 50px du bas
    final isScrolledUp = (maxScroll - currentScroll) > 50;

    // Mettre à jour le provider seulement si la valeur change
    final currentValue = ref.read(terminalScrolledUpProvider);
    if (currentValue != isScrolledUp) {
      ref.read(terminalScrolledUpProvider.notifier).set(isScrolledUp);
    }
  }

  /// Scroll vers le bas du terminal (appelé depuis l'extérieur)
  void scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Retourne true si le terminal est en mode "application cursor keys"
  /// (certaines apps TUI comme alsamixer utilisent ce mode)
  bool get isApplicationCursorMode {
    if (_currentTabId == null) return false;
    final terminal = _terminals[_currentTabId];
    return terminal?.cursorKeysMode ?? false;
  }

  /// Gère le scroll tactile en alternate buffer
  /// Envoie des mouse wheel SGR au centre du terminal (position-aware pour
  /// les apps comme Crush qui routent les événements selon la position).
  /// Fallback clavier (flèches) pour les apps qui ne supportent pas la souris.
  void _handleAltBufferScroll(DragUpdateDetails details, Terminal terminal) {
    _altBufferScrollAccumulator += details.delta.dy;

    // Seuil pour un scroll fluide (environ 1 ligne)
    const scrollThreshold = 30.0;

    if (_altBufferScrollAccumulator.abs() > scrollThreshold) {
      // Doigt vers le haut (delta < 0) = scroll up
      // Doigt vers le bas (delta > 0) = scroll down
      final bool scrollUp = _altBufferScrollAccumulator < 0;

      // Vérifier si l'app courante a besoin de scroll clavier
      final sshState = ref.read(sshProvider);
      final tabId = sshState.currentTabId;
      final currentCmd = tabId != null
          ? sshState.tabCurrentCommand[tabId]
          : null;
      final cmdName = _extractCommandName(currentCmd);
      final useKeyboardScroll =
          cmdName != null && _keyboardScrollApps.contains(cmdName);

      if (useKeyboardScroll) {
        // Apps sans support souris (OpenCode) : envoyer Page Up/Down
        // OpenCode utilise PgUp/PgDown pour scroller, PAS les flèches.
        // Page Up: \x1b[5~ / Page Down: \x1b[6~
        final pageKey = scrollUp ? '\x1b[5~' : '\x1b[6~';
        ref.read(sshProvider.notifier).write(pageKey);
        if (kDebugMode)
          debugPrint(
            'ALT_SCROLL: Page ${scrollUp ? "UP" : "DOWN"} sent (keyboard scroll for $cmdName)',
          );
      } else {
        // Mouse wheel SGR 1006 — coordonnées au CENTRE du terminal
        // pour que les apps position-aware (Crush, etc.) routent l'événement
        // vers la zone de contenu, pas le header en (1,1).
        final int buttonCode = scrollUp ? 64 : 65;
        final int col = (terminal.viewWidth ~/ 2).clamp(1, terminal.viewWidth);
        final int row = (terminal.viewHeight ~/ 2).clamp(
          1,
          terminal.viewHeight,
        );
        final String sgrSequence = '\x1b[<$buttonCode;$col;${row}M';
        ref.read(sshProvider.notifier).write(sgrSequence);
        if (kDebugMode)
          debugPrint(
            'ALT_SCROLL: Mouse wheel ${scrollUp ? "UP" : "DOWN"} at ($col,$row) sent (SGR)',
          );
      }

      // Forcer un redraw du terminal local après le scroll
      terminal.notifyListeners();

      _altBufferScrollAccumulator = 0.0;
    }
  }

  /// Réinitialise l'accumulateur au début d'un nouveau geste
  void _resetAltBufferScroll() {
    _altBufferScrollAccumulator = 0.0;
  }

  /// Retourne ou crée le terminal pour l'onglet donné
  Terminal _getOrCreateTerminal(String tabId) {
    if (!_terminals.containsKey(tabId)) {
      final terminal = Terminal(maxLines: 10000);
      terminal.onOutput = (data) => _handleTerminalOutput(data, tabId);
      // Synchroniser la taille du terminal avec le PTY distant
      // MAIS pas pendant l'alternate screen mode (apps CLI modernes)
      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        // Ne pas envoyer de resize pendant l'alternate screen mode
        // pour éviter la corruption d'affichage (Codex, etc.)
        if (_isInAltBuffer) {
          if (kDebugMode)
            debugPrint('RESIZE: Skipped (alternate screen active)');
          return;
        }

        // Vérifier si la taille a réellement changé
        final lastSize = _lastSentSize[tabId];
        if (lastSize != null && lastSize.$1 == width && lastSize.$2 == height) {
          return; // Pas de changement, ignorer
        }

        // Guard agents CLI : autoriser les AUGMENTATIONS de hauteur (clavier fermé
        // → plus de lignes → Codex redessine avec plus de contenu visible),
        // mais BLOQUER les DIMINUTIONS (clavier ouvert → Codex redessinérait
        // avec moins de lignes → messages "disparaissent").
        if (lastSize != null && lastSize.$1 == width && lastSize.$2 != height) {
          final sshState = ref.read(sshProvider);
          final currentCommand = sshState.tabCurrentCommand[tabId];
          if (currentCommand != null && _isCliAgentCommand(currentCommand)) {
            if (height < lastSize.$2) {
              // Hauteur DIMINUE → bloquer (empêche Codex de redessiner avec moins de lignes)
              if (kDebugMode) {
                debugPrint(
                  'RESIZE: Blocked height shrink ${lastSize.$1}x${lastSize.$2} → ${width}x$height (CLI agent: $currentCommand)',
                );
              }
              return;
            }
            // Hauteur AUGMENTE → autoriser (Codex redessine avec plus de lignes)
            if (kDebugMode) {
              debugPrint(
                'RESIZE: Allowed height grow ${lastSize.$1}x${lastSize.$2} → ${width}x$height (CLI agent: $currentCommand)',
              );
            }
          }
        }

        if (kDebugMode) {
          final oldStr = lastSize != null
              ? '${lastSize.$1}x${lastSize.$2}'
              : 'initial';
          debugPrint('RESIZE: $oldStr → ${width}x$height (tab=$tabId)');
        }
        _lastSentSize[tabId] = (width, height);
        ref
            .read(sshProvider.notifier)
            .resizeTerminalForTab(tabId, width, height);
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
    if (sshState.connectionState == SSHConnectionState.connected &&
        sshState.currentTabId != null) {
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
          final decoded = utf8.decode(data, allowMalformed: true);
          // Wrapper dans try-catch car xterm.dart peut crasher lors de
          // race conditions entre write() et resize (bug connu avec TUI apps)
          try {
            terminal.write(decoded);
          } catch (e, stackTrace) {
            // Ignorer silencieusement les erreurs de buffer xterm.dart
            // Cela arrive quand resize et write sont concurrents
            if (kDebugMode) {
              debugPrint('XTERM: Buffer error (ignored): $e');
              debugPrint('XTERM: Data length: ${decoded.length} chars');
              // Afficher les 3 premières lignes de la stack trace pour identifier l'assertion
              final traceLines = stackTrace
                  .toString()
                  .split('\n')
                  .take(3)
                  .join('\n');
              debugPrint('XTERM: Stack: $traceLines');
            }
          }
          // Envoyer la sortie au provider pour détecter les erreurs de commande
          ref.read(terminalProvider.notifier).onTerminalOutput(decoded);
          // Détecter l'alternate screen mode (nano, vim, less, htop, etc.)
          _detectAlternateScreenMode(decoded);
        },
        onError: (error, stackTrace) {
          if (kDebugMode) debugPrint('SSH stream error for tab $tabId');
          _cleanupTab(tabId);
        },
        onDone: () {
          if (kDebugMode) debugPrint('SSH stream closed for tab $tabId');
          // Marquer l'onglet comme mort pour permettre la reconnexion
          ref.read(sshProvider.notifier).markTabAsDead(tabId);
          // Ne pas cleanup automatiquement - laisser l'utilisateur voir l'état final
        },
        cancelOnError:
            false, // Continuer même après erreur pour voir les messages
      );
      if (kDebugMode) debugPrint('Connected to SSH stream for tab $tabId');
      // Forcer un rebuild pour afficher le contenu
      if (mounted) setState(() {});
    } else {
      // Le stream n'est pas encore disponible (connexion en cours)
      // Réessayer après un court délai (max 10 tentatives = 2 secondes)
      if (retryCount < 10) {
        if (kDebugMode)
          debugPrint(
            'No output stream for tab $tabId, retrying (attempt ${retryCount + 1}/10)',
          );
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _subscriptions[tabId] == null) {
            _connectToSSH(tabId, retryCount: retryCount + 1);
          }
        });
      } else {
        if (kDebugMode)
          debugPrint(
            'Failed to connect to SSH stream for tab $tabId after 10 attempts',
          );
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
    _lastSentSize.remove(tabId);
    if (kDebugMode) debugPrint('Cleaned up resources for tab $tabId');
  }

  /// Détecte les séquences d'entrée/sortie de l'alternate screen mode
  /// et met à jour isEditorModeProvider UNIQUEMENT pour les vrais éditeurs
  void _detectAlternateScreenMode(String output) {
    // Entrée en alternate screen
    if (output.contains(_alternateScreenEnter) ||
        output.contains(_alternateScreenEnterAlt)) {
      // Mettre à jour l'état alt buffer pour le scroll custom
      if (!_isInAltBuffer) {
        _isInAltBuffer = true;
        if (mounted) setState(() {});
        if (kDebugMode) debugPrint('ALT_BUFFER: Entered alternate screen');
      }

      // Vérifier si la commande en cours est un vrai éditeur
      final currentTabId = ref.read(sshProvider).currentTabId;
      final currentCommand = currentTabId != null
          ? ref.read(sshProvider).tabCurrentCommand[currentTabId]
          : null;

      // Extraire le nom de la commande (premier mot, sans chemin)
      final commandName = _extractCommandName(currentCommand);

      if (commandName != null && _trueEditorCommands.contains(commandName)) {
        final currentMode = ref.read(isEditorModeProvider);
        if (!currentMode) {
          ref.read(isEditorModeProvider.notifier).set(true);
          if (kDebugMode) debugPrint('EDITOR MODE: Entered for "$commandName"');
        }
      } else {
        if (kDebugMode)
          debugPrint('EDITOR MODE: Skipped for "${commandName ?? "unknown"}"');
      }
    }
    // Sortie du mode alternate screen
    else if (output.contains(_alternateScreenExit) ||
        output.contains(_alternateScreenExitAlt)) {
      // Mettre à jour l'état alt buffer
      if (_isInAltBuffer) {
        _isInAltBuffer = false;
        if (mounted) setState(() {});
        if (kDebugMode) debugPrint('ALT_BUFFER: Exited alternate screen');
      }

      // Désactiver le mode éditeur si actif
      final currentMode = ref.read(isEditorModeProvider);
      if (currentMode) {
        ref.read(isEditorModeProvider.notifier).set(false);
        if (kDebugMode) debugPrint('EDITOR MODE: Exited alternate screen');
      }
    }
  }

  /// Agents CLI modernes qui redessinent leur TUI sur SIGWINCH.
  /// Le resize height-only est bloqué pour ces agents afin d'éviter
  /// la perte de messages (ils effacent et réécrivent tout à chaque resize).
  static const _cliAgentCommands = <String>{
    'claude',
    'codex',
    'opencode',
    'aider',
    'gemini',
    'cody',
    'amazon-q',
    'aws-q',
    'crush',
  };

  /// Apps sans support mouse wheel SGR.
  /// Pour ces apps, on envoie Page Up/Down au lieu de mouse wheel.
  /// OpenCode (Bubble Tea v1) : mouse désactivé, scroll = PgUp/PgDown/Ctrl+U/D.
  static const _keyboardScrollApps = <String>{'opencode'};

  /// Vérifie si la commande en cours est un agent CLI moderne
  bool _isCliAgentCommand(String command) {
    final name = _extractCommandName(command);
    return name != null && _cliAgentCommands.contains(name);
  }

  /// Extrait le nom de la commande (sans chemin, sans arguments)
  String? _extractCommandName(String? command) {
    if (command == null || command.isEmpty) return null;

    // Prendre le premier mot
    final parts = command.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    // Retirer le chemin (ex: /usr/bin/nano → nano)
    final fullPath = parts.first;
    final name = fullPath.split('/').last;

    return name.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    // Sélecteurs ciblés pour observer uniquement ce qui est nécessaire
    // Cela réduit les rebuilds inutiles quand des propriétés non-utilisées changent
    final connectionState = ref.watch(
      sshProvider.select((s) => s.connectionState),
    );
    final currentTabId = ref.watch(sshProvider.select((s) => s.currentTabId));
    final errorMessage = ref.watch(sshProvider.select((s) => s.errorMessage));
    final theme = ref.watch(vibeTermThemeProvider);
    final fontSize = ref.watch(
      settingsProvider.select((s) => s.appSettings.terminalFontSize.size),
    );

    // Listener pour les changements complets (nécessaire pour previous/next)
    ref.listen<SSHState>(sshProvider, (previous, next) {
      if (next.connectionState == SSHConnectionState.connected &&
          next.currentTabId != null) {
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
          final closedTabs = previous.tabIds.where(
            (id) => !next.tabIds.contains(id),
          );
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
        _lastSentSize.clear();
        _currentTabId = null;
      }
    });

    // Afficher un état de chargement si non connecté
    if (connectionState != SSHConnectionState.connected ||
        currentTabId == null) {
      final l10n = context.l10n;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (connectionState == SSHConnectionState.connecting)
              CircularProgressIndicator(color: theme.accent)
            else
              Icon(Icons.terminal, size: 64, color: theme.textMuted),
            const SizedBox(height: 16),
            Text(
              connectionState == SSHConnectionState.connecting
                  ? l10n.connectionInProgress
                  : errorMessage != null
                  ? translateSshError(l10n, errorMessage)
                  : l10n.noConnection,
              style: TextStyle(color: theme.textMuted),
            ),
          ],
        ),
      );
    }

    // Obtenir le terminal de l'onglet actif
    final terminal = _getOrCreateTerminal(currentTabId);

    // Mode édition : quand une app utilise l'alternate screen (nano, vim, etc.)
    final isEditorMode = ref.watch(isEditorModeProvider);

    // Détecter si un agent CLI est actif pour désactiver l'auto-resize.
    // Quand autoResize=false, xterm ne redimensionne PAS son buffer interne
    // lors des changements de taille du widget (ex: clavier qui se ferme/ouvre).
    // Sans ça, xterm fait lines.pop() en rétrécissant → lignes perdues → messages
    // qui disparaissent dans Codex CLI et autres agents TUI.
    final currentCommand = ref.watch(
      sshProvider.select((s) => s.tabCurrentCommand[s.currentTabId]),
    );
    final isCliAgentActive =
        currentCommand != null && _isCliAgentCommand(currentCommand);

    // Afficher le terminal xterm avec bouton Copier flottant
    // Key avec l'ID stable pour forcer Flutter à recréer le widget
    // ClipRect pour empêcher le contenu de déborder sur les barres au-dessus

    // Widget terminal de base
    final terminalWidget = TerminalView(
      terminal,
      key: ValueKey('terminal_${currentTabId}_$isEditorMode'),
      controller: terminalController,
      scrollController: _scrollController,
      // En mode édition : autofocus pour ouvrir le clavier, readOnly=false pour saisie directe
      autofocus: isEditorMode,
      readOnly:
          !isEditorMode, // Mode normal: true (champ en bas), Mode édition: false (saisie directe)
      hardwareKeyboardOnly:
          !isEditorMode, // Mode édition: clavier virtuel autorisé
      // Mode grow-only pour agents CLI : le buffer peut GRANDIR (clavier fermé
      // = plus de lignes visibles) mais ne RÉTRÉCIT PAS (clavier ouvert).
      // Empêche Buffer.resize() d'appeler lines.pop() qui supprime des lignes,
      // ET empêche Codex de redessiner avec moins de lignes (pas de SIGWINCH).
      growOnlyResize: isCliAgentActive,
      backgroundOpacity: 0,
      theme: _getTerminalTheme(theme, isEditorMode: isEditorMode),
      textStyle: TerminalStyle(fontSize: fontSize, fontFamily: 'JetBrainsMono'),
      // Désactiver simulateScroll car on gère nous-mêmes le scroll en alternate buffer
      // avec mouse wheel SGR au lieu de flèches (mieux pour les CLI modernes comme Vibe)
      simulateScroll: false,
      // Clic droit pour desktop
      onSecondaryTapDown: (details, _) =>
          _showContextMenu(context, details.globalPosition, terminal, theme),
    );

    return ClipRect(
      child: Stack(
        children: [
          // Terminal toujours en bas du stack
          terminalWidget,
          // En alternate buffer ET pas en mode éditeur (CLI modernes comme Vibe, Crush)
          // → GestureDetector transparent PAR-DESSUS le terminal pour capturer le scroll
          // → Mouse wheel SGR pour les apps qui supportent (Vibe, etc.)
          // → Flèches clavier pour les apps Bubble Tea (Crush, OpenCode)
          if (_isInAltBuffer && !isEditorMode)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragStart: (_) => _resetAltBufferScroll(),
                onVerticalDragUpdate: (details) =>
                    _handleAltBufferScroll(details, terminal),
              ),
            ),
          // Bouton Copier flottant (apparaît quand sélection active)
          ListenableBuilder(
            listenable: terminalController,
            builder: (context, _) {
              final hasSelection = terminalController.selection != null;
              if (!hasSelection) return const SizedBox.shrink();

              return Positioned(
                top: 8,
                right: 8,
                child: _CopyButton(
                  onCopy: () => _copySelection(terminal, theme),
                  theme: theme,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Copie le texte sélectionné dans le presse-papiers
  Future<void> _copySelection(
    Terminal terminal,
    VibeTermThemeData theme,
  ) async {
    final selection = terminalController.selection;
    if (selection == null) return;

    final text = terminal.buffer.getText(selection);
    final settings = ref.read(settingsProvider);
    await ClipboardSecurityService.copyWithAutoClear(
      text: text,
      autoClearEnabled: settings.appSettings.clipboardAutoClear,
      clearAfterSeconds: settings.appSettings.clipboardClearSeconds,
    );
    terminalController.clearSelection();
    // Pas de notification - le mobile en affiche déjà une native
  }

  /// Affiche le menu contextuel Copier/Coller (pour desktop clic droit)
  void _showContextMenu(
    BuildContext context,
    Offset position,
    Terminal terminal,
    VibeTermThemeData theme,
  ) {
    final l10n = context.l10n;
    final selection = terminalController.selection;
    final hasSelection = selection != null;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: theme.bgBlock,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.border),
      ),
      items: [
        if (hasSelection)
          PopupMenuItem<String>(
            value: 'copy',
            child: Row(
              children: [
                Icon(Icons.copy, size: 18, color: theme.text),
                const SizedBox(width: 8),
                Text(l10n.copy, style: TextStyle(color: theme.text)),
              ],
            ),
          ),
        PopupMenuItem<String>(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.paste, size: 18, color: theme.text),
              const SizedBox(width: 8),
              Text(l10n.paste, style: TextStyle(color: theme.text)),
            ],
          ),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      switch (value) {
        case 'copy':
          if (selection != null) {
            final text = terminal.buffer.getText(selection);
            final settings = ref.read(settingsProvider);
            await ClipboardSecurityService.copyWithAutoClear(
              text: text,
              autoClearEnabled: settings.appSettings.clipboardAutoClear,
              clearAfterSeconds: settings.appSettings.clipboardClearSeconds,
            );
            terminalController.clearSelection();
          }
          break;
        case 'paste':
          final data = await Clipboard.getData('text/plain');
          if (data?.text != null) {
            terminal.paste(data!.text!);
          }
          break;
      }
    });
  }
}

/// Bouton Copier flottant avec animation
class _CopyButton extends StatelessWidget {
  final VoidCallback onCopy;
  final VibeTermThemeData theme;

  const _CopyButton({required this.onCopy, required this.theme});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: theme.accent,
      borderRadius: BorderRadius.circular(8),
      elevation: 4,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 16, color: theme.bg),
              const SizedBox(width: 6),
              Text(
                l10n.copy,
                style: TextStyle(
                  color: theme.bg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
