import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibeterm/core/security/secure_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/providers.dart';
import 'terminal_action_buttons.dart';
import 'terminal_view.dart';

class GhostTextInput extends ConsumerStatefulWidget {
  const GhostTextInput({super.key});

  @override
  GhostTextInputState createState() => GhostTextInputState();
}

class GhostTextInputState extends ConsumerState<GhostTextInput> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();
  bool _ctrlArmed = false; // État du bouton CTRL
  bool _isExpanded = false; // État du champ agrandi
  bool _showDpad = false; // État du D-pad (croix directionnelle)

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Méthode publique pour insérer une nouvelle ligne (appelée depuis l'extérieur)
  void insertNewLine() {
    final currentText = _controller.text;
    final selection = _controller.selection;
    final before = currentText.substring(0, selection.start);
    final after = currentText.substring(selection.end);
    final newText = '$before\n$after';
    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + 1),
    );
    ref.read(terminalProvider.notifier).setInput(newText);
    _focusNode.requestFocus(); // Garder le focus sur le champ
  }

  void _onSubmit() {
    final input = _controller.text.trim();
    final sshNotifier = ref.read(sshProvider.notifier);

    // Si champ vide, envoyer juste Enter (pour confirmer sélections dans apps interactives)
    // Note: \r (Carriage Return) est la touche Enter dans un terminal, pas \n (Line Feed)
    if (input.isEmpty) {
      sshNotifier.write('\r');
      // Garder le clavier ouvert
      _focusNode.requestFocus();
      return;
    }

    final terminalNotifier = ref.read(terminalProvider.notifier);

    // Marquer le début de la nouvelle commande (pour calculer le temps)
    terminalNotifier.startCommand();

    // Stocker la commande en attente (sera validée après vérification du code retour)
    terminalNotifier.setPendingCommand(input);

    // Envoyer la commande au SSH
    // Envoyer le texte d'abord, puis Enter séparément (requis par certaines apps comme Claude Code)
    sshNotifier.write(input);
    // Petit délai pour s'assurer que le texte arrive avant Enter
    Future.delayed(const Duration(milliseconds: 50), () {
      sshNotifier.write('\r');
    });

    // Marquer l'onglet comme ayant un process en cours SEULEMENT si commande long-running
    if (sshNotifier.isLongRunningCommand(input)) {
      sshNotifier.setCurrentTabRunning(true, command: input);
    }

    // Effacer l'input
    _controller.clear();
    terminalNotifier.setInput('');

    // Garder le clavier ouvert après submission
    // Cela évite les resize events pendant l'exécution de la commande
    // et améliore l'UX (on peut taper plusieurs commandes)
    _focusNode.requestFocus();

    // Valider la commande après un délai (si pas d'erreur détectée dans la sortie)
    _validateCommandAfterDelay(terminalNotifier);
  }

  /// Valide la commande après un délai (basé sur la détection d'erreurs dans la sortie)
  void _validateCommandAfterDelay(TerminalNotifier terminalNotifier) {
    // Attendre 500ms pour laisser le temps aux erreurs de s'afficher
    Future.delayed(const Duration(milliseconds: 500), () {
      // Si pas d'erreur détectée pendant ce délai, valider la commande
      terminalNotifier.validatePendingCommandAfterDelay();
    });
  }

  void _toggleCtrl() {
    setState(() {
      _ctrlArmed = !_ctrlArmed;
    });
    if (_ctrlArmed) {
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  void _sendCtrlKey(String letter) {
    if (!_ctrlArmed) return;

    // Convertir la lettre en code de contrôle (A=1, B=2, ..., Z=26)
    final upperLetter = letter.toUpperCase();
    if (upperLetter.length == 1 &&
        upperLetter.codeUnitAt(0) >= 65 &&
        upperLetter.codeUnitAt(0) <= 90) {
      final ctrlCode = upperLetter.codeUnitAt(0) - 64; // A=1, B=2, etc.
      final ctrlChar = String.fromCharCode(ctrlCode);
      ref.read(sshProvider.notifier).write(ctrlChar);
      SecureLogger.logDebugOnly('GhostTextInput', 'Sent CTRL key');
    }

    // Désarmer le bouton
    setState(() {
      _ctrlArmed = false;
    });
  }

  void _acceptGhost() {
    final state = ref.read(terminalProvider);
    if (state.ghostText != null) {
      ref.read(terminalProvider.notifier).acceptGhostText();
      _controller.text = state.currentInput + state.ghostText!;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  void _navigateHistory(bool up) {
    final terminalNotifier = ref.read(terminalProvider.notifier);
    final cmd = up
        ? terminalNotifier.previousCommand()
        : terminalNotifier.nextCommand();

    if (cmd != null) {
      _controller.text = cmd;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      // Ne pas réinitialiser l'index d'historique pendant la navigation
      terminalNotifier.setInput(cmd, resetHistory: false);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Si CTRL armé, intercepter la lettre
      if (_ctrlArmed) {
        final keyLabel = event.logicalKey.keyLabel;
        if (keyLabel.length == 1) {
          _sendCtrlKey(keyLabel);
          return KeyEventResult.handled;
        }
        // Si autre touche (Escape, etc.), désarmer
        setState(() {
          _ctrlArmed = false;
        });
        return KeyEventResult.handled;
      }

      // Flèche haut = historique précédent
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateHistory(true);
        return KeyEventResult.handled;
      }
      // Flèche bas = historique suivant
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _navigateHistory(false);
        return KeyEventResult.handled;
      }
      // Tab = accepter ghost text
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _acceptGhost();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _toggleDpad() {
    setState(() {
      _showDpad = !_showDpad;
    });
  }

  /// Envoie une touche flèche avec le bon code selon le mode du terminal
  /// En mode normal: \x1b[A (CSI)
  /// En mode application: \x1bOA (SS3) - utilisé par alsamixer, pulsemixer, etc.
  String _getArrowKeyPrefix() {
    final isAppMode =
        terminalViewKey.currentState?.isApplicationCursorMode ?? false;
    return isAppMode ? '\x1bO' : '\x1b[';
  }

  void _sendArrowKey(String direction) {
    final prefix = _getArrowKeyPrefix();
    ref.read(sshProvider.notifier).write('$prefix$direction');
  }

  @override
  Widget build(BuildContext context) {
    final ghostText = ref.watch(terminalProvider.select((s) => s.ghostText));
    final currentInput = ref.watch(
      terminalProvider.select((s) => s.currentInput),
    );
    final theme = ref.watch(vibeTermThemeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.sm,
        vertical: VibeTermSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.bgBlock,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Flèches historique empilées verticalement
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TerminalHistoryButton(
                  icon: Icons.keyboard_arrow_up,
                  onTap: () => _navigateHistory(true),
                  theme: theme,
                ),
                const SizedBox(height: 2),
                TerminalHistoryButton(
                  icon: Icons.keyboard_arrow_down,
                  onTap: () => _navigateHistory(false),
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            // D-pad (si activé)
            if (_showDpad) ...[
              TerminalDpad(
                onUp: () => _sendArrowKey('A'),
                onDown: () => _sendArrowKey('B'),
                onLeft: () => _sendArrowKey('D'),
                onRight: () => _sendArrowKey('C'),
                theme: theme,
              ),
              const SizedBox(width: VibeTermSpacing.sm),
            ],
            Expanded(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  // Swipe rapide vers le haut → agrandir le champ
                  // Swipe rapide vers le bas → réduire le champ
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -300 && !_isExpanded) {
                      // Swipe rapide vers le haut → agrandir
                      setState(() => _isExpanded = true);
                    } else if (details.primaryVelocity! > 300 && _isExpanded) {
                      // Swipe rapide vers le bas → réduire
                      setState(() => _isExpanded = false);
                    }
                  }
                },
                child: Focus(
                  focusNode: FocusNode(),
                  onKeyEvent: _handleKeyEvent,
                  // Contraindre la hauteur max pour éviter l'overflow derrière le clavier
                  // 9 lignes max (~225px) avant de scroller
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 225),
                    child: SingleChildScrollView(
                      reverse:
                          true, // Scroll automatique vers le bas (dernière ligne visible)
                      child: Stack(
                        children: [
                          // Ghost text layer (seulement si pas expanded)
                          if (ghostText != null && !currentInput.contains('\n'))
                            Positioned(
                              left: 0,
                              bottom: 4,
                              child: Text(
                                currentInput + ghostText,
                                style: VibeTermTypography.input.copyWith(
                                  color: theme.ghost,
                                ),
                              ),
                            ),
                          // Input field
                          Theme(
                            data: Theme.of(context).copyWith(
                              textSelectionTheme: TextSelectionThemeData(
                                cursorColor: theme.accent,
                                selectionColor: theme.accent.withValues(
                                  alpha: 0.3,
                                ),
                                selectionHandleColor: theme.accent,
                              ),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              style: VibeTermTypography.input.copyWith(
                                color: theme.text,
                              ),
                              cursorColor: theme.accent,
                              maxLines: null, // Permet plusieurs lignes
                              minLines: 1,
                              expands: false,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.send,
                              // onEditingComplete au lieu de onSubmitted :
                              // onSubmitted ferme le clavier (unfocus) avant notre callback,
                              // causant un cycle clavier fermé→ouvert qui redimensionne
                              // le widget terminal → xterm perd des lignes.
                              // onEditingComplete remplace le comportement par défaut
                              // (qui inclut l'unfocus), donc le clavier reste ouvert.
                              onEditingComplete: _onSubmit,
                              decoration: InputDecoration(
                                hintText: _ctrlArmed
                                    ? context.l10n.pressKeyForCtrl
                                    : context.l10n.runCommands,
                                hintStyle: VibeTermTypography.input.copyWith(
                                  color: _ctrlArmed
                                      ? const Color(0xFFEAB308)
                                      : theme.textMuted,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (value) {
                                // Si CTRL armé et l'utilisateur tape une lettre
                                if (_ctrlArmed && value.isNotEmpty) {
                                  final lastChar = value[value.length - 1];
                                  _sendCtrlKey(lastChar);
                                  // Effacer le caractère tapé
                                  _controller.text = value.substring(
                                    0,
                                    value.length - 1,
                                  );
                                  return;
                                }
                                ref
                                    .read(terminalProvider.notifier)
                                    .setInput(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bouton accepter ghost (si disponible)
            if (ghostText != null) ...[
              const SizedBox(width: VibeTermSpacing.xs),
              TerminalGhostAcceptButton(onTap: _acceptGhost, theme: theme),
            ],
            const SizedBox(width: VibeTermSpacing.sm),
            // Boutons CTRL et D-pad toggle empilés verticalement
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton CTRL
                TerminalCtrlButton(
                  isArmed: _ctrlArmed,
                  onTap: _toggleCtrl,
                  theme: theme,
                ),
                const SizedBox(height: 4),
                // Bouton toggle D-pad
                TerminalDpadToggle(
                  isActive: _showDpad,
                  onTap: _toggleDpad,
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
