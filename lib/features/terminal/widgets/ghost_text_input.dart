import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/providers.dart';
import 'terminal_action_buttons.dart';

class GhostTextInput extends ConsumerStatefulWidget {
  const GhostTextInput({super.key});

  @override
  ConsumerState<GhostTextInput> createState() => _GhostTextInputState();
}

class _GhostTextInputState extends ConsumerState<GhostTextInput> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

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

  void _onSubmit() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final terminalNotifier = ref.read(terminalProvider.notifier);
    final sshNotifier = ref.read(sshProvider.notifier);

    // Marquer le début de la nouvelle commande (pour calculer le temps)
    terminalNotifier.startCommand();

    // Ajouter à l'historique du terminal provider
    terminalNotifier.addToHistory(input);

    // Envoyer la commande au SSH
    sshNotifier.write('$input\n');

    // Marquer l'onglet comme ayant un process en cours SEULEMENT si commande long-running
    if (sshNotifier.isLongRunningCommand(input)) {
      sshNotifier.setCurrentTabRunning(true, command: input);
    }

    // Effacer l'input
    _controller.clear();
    terminalNotifier.setInput('');
  }

  void _onStop() {
    final sshNotifier = ref.read(sshProvider.notifier);
    sshNotifier.sendInterrupt();
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
    final cmd = up ? terminalNotifier.previousCommand() : terminalNotifier.nextCommand();

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

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);
    final theme = ref.watch(vibeTermThemeProvider);
    final isProcessRunning = ref.watch(sshProvider.select((s) => s.isCurrentTabRunning));
    final sshNotifier = ref.read(sshProvider.notifier);
    final showArrowButtons = isProcessRunning && sshNotifier.isCurrentTabInteractive;

    // Stop uniquement si: process en cours ET champ de saisie vide
    final showStopButton = isProcessRunning && terminalState.currentInput.isEmpty;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 64,
        maxHeight: 150,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.bgBlock,
        border: Border(
          top: BorderSide(color: theme.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bouton historique haut
            TerminalHistoryButton(
              icon: Icons.keyboard_arrow_up,
              onTap: () => _navigateHistory(true),
              theme: theme,
            ),
            const SizedBox(width: VibeTermSpacing.xs),
            Text(
              '>',
              style: VibeTermTypography.prompt.copyWith(
                color: theme.accent,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  // Swipe droite
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 100) {
                    final terminalState = ref.read(terminalProvider);
                    final isProcessRunning = ref.read(sshProvider).isCurrentTabRunning;

                    if (terminalState.ghostText != null) {
                      // Ghost text disponible → TAB (accepter suggestion)
                      _acceptGhost();
                    } else if (isProcessRunning && terminalState.currentInput.isEmpty) {
                      // Process en cours + champ vide → Entrée (confirmer sélection)
                      ref.read(sshProvider.notifier).write('\n');
                    }
                  }
                },
                onVerticalDragEnd: (details) {
                  // Swipe haut/bas → flèches pour navigation dans les menus interactifs
                  if (details.primaryVelocity != null) {
                    final sshNotifier = ref.read(sshProvider.notifier);
                    if (details.primaryVelocity! < -100) {
                      // Swipe vers le haut → Flèche haut (ESC [ A)
                      sshNotifier.write('\x1b[A');
                    } else if (details.primaryVelocity! > 100) {
                      // Swipe vers le bas → Flèche bas (ESC [ B)
                      sshNotifier.write('\x1b[B');
                    }
                  }
                },
                child: Focus(
                  focusNode: FocusNode(),
                  onKeyEvent: _handleKeyEvent,
                  child: Stack(
                    children: [
                      // Ghost text layer
                      if (terminalState.ghostText != null &&
                          !terminalState.currentInput.contains('\n'))
                        Positioned(
                          left: 0,
                          bottom: 4,
                          child: Text(
                            terminalState.currentInput + terminalState.ghostText!,
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
                            selectionColor: theme.accent.withValues(alpha: 0.3),
                            selectionHandleColor: theme.accent,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          style: VibeTermTypography.input.copyWith(color: theme.text),
                          cursorColor: theme.accent,
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _onSubmit(),
                          decoration: InputDecoration(
                            hintText: 'Run commands',
                            hintStyle: VibeTermTypography.input.copyWith(
                              color: theme.textMuted,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (value) {
                            ref.read(terminalProvider.notifier).setInput(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bouton accepter ghost (si disponible)
            if (terminalState.ghostText != null) ...[
              const SizedBox(width: VibeTermSpacing.xs),
              TerminalGhostAcceptButton(onTap: _acceptGhost, theme: theme),
            ],
            // Boutons flèches pour menus interactifs (fzf, htop, etc.)
            if (showArrowButtons) ...[
              const SizedBox(width: VibeTermSpacing.xs),
              TerminalArrowButton(
                icon: Icons.keyboard_arrow_up,
                onTap: () => ref.read(sshProvider.notifier).write('\x1b[A'),
                theme: theme,
              ),
              const SizedBox(width: VibeTermSpacing.xs),
              TerminalArrowButton(
                icon: Icons.keyboard_arrow_down,
                onTap: () => ref.read(sshProvider.notifier).write('\x1b[B'),
                theme: theme,
              ),
            ],
            const SizedBox(width: VibeTermSpacing.sm),
            showStopButton
                ? TerminalStopButton(onTap: _onStop, theme: theme)
                : TerminalSendButton(onTap: _onSubmit, theme: theme),
          ],
        ),
      ),
    );
  }
}
