import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';

/// Bouton pour naviguer dans l'historique des commandes (taille réduite)
class TerminalHistoryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalHistoryButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Icon(
          icon,
          color: theme.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

/// Bouton pour accepter le ghost text (autocomplétion)
class TerminalGhostAcceptButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalGhostAcceptButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.keyboard_tab,
          color: theme.accent,
          size: 18,
        ),
      ),
    );
  }
}

/// Bouton CTRL+ pour les raccourcis clavier
/// - État normal : "CTRL" vert
/// - État armé : "+" jaune (attend une lettre)
class TerminalCtrlButton extends StatelessWidget {
  final bool isArmed;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalCtrlButton({
    super.key,
    required this.isArmed,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Couleurs selon l'état
    final bgColor = isArmed
        ? const Color(0xFFEAB308) // Jaune quand armé
        : theme.accent; // Vert par défaut
    final textColor = isArmed ? Colors.black : theme.bg;
    final text = isArmed ? '+' : 'CTRL';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: isArmed ? 18 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton toggle pour afficher/masquer le D-pad
class TerminalDpadToggle extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalDpadToggle({
    super.key,
    required this.isActive,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          color: isActive ? theme.accent : theme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? theme.accent : theme.border),
        ),
        child: Icon(
          Icons.gamepad_outlined,
          color: isActive ? theme.bg : theme.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

/// D-pad style PS5 avec 4 directions (haut, bas, gauche, droite)
class TerminalDpad extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VibeTermThemeData theme;

  const TerminalDpad({
    super.key,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 32;
    const double arrowSize = 16;
    final buttonColor = theme.bg;
    final arrowColor = theme.textMuted;
    final bgColor = theme.bgBlock;

    return Container(
      width: buttonSize * 3,
      height: buttonSize * 3,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Bouton HAUT
          Positioned(
            top: 0,
            left: buttonSize,
            child: _DpadButton(
              icon: Icons.keyboard_arrow_up,
              onTap: onUp,
              size: buttonSize,
              arrowSize: arrowSize,
              buttonColor: buttonColor,
              arrowColor: arrowColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
          ),
          // Bouton GAUCHE
          Positioned(
            top: buttonSize,
            left: 0,
            child: _DpadButton(
              icon: Icons.keyboard_arrow_left,
              onTap: onLeft,
              size: buttonSize,
              arrowSize: arrowSize,
              buttonColor: buttonColor,
              arrowColor: arrowColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
          ),
          // Bouton DROITE
          Positioned(
            top: buttonSize,
            right: 0,
            child: _DpadButton(
              icon: Icons.keyboard_arrow_right,
              onTap: onRight,
              size: buttonSize,
              arrowSize: arrowSize,
              buttonColor: buttonColor,
              arrowColor: arrowColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
          // Bouton BAS
          Positioned(
            bottom: 0,
            left: buttonSize,
            child: _DpadButton(
              icon: Icons.keyboard_arrow_down,
              onTap: onDown,
              size: buttonSize,
              arrowSize: arrowSize,
              buttonColor: buttonColor,
              arrowColor: arrowColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton individuel du D-pad
class _DpadButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double arrowSize;
  final Color buttonColor;
  final Color arrowColor;
  final BorderRadius borderRadius;

  const _DpadButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.arrowSize,
    required this.buttonColor,
    required this.arrowColor,
    required this.borderRadius,
  });

  @override
  State<_DpadButton> createState() => _DpadButtonState();
}

class _DpadButtonState extends State<_DpadButton> {
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
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _isPressed ? widget.arrowColor.withValues(alpha: 0.3) : widget.buttonColor,
          borderRadius: widget.borderRadius,
        ),
        child: Icon(
          widget.icon,
          color: widget.arrowColor,
          size: widget.arrowSize,
        ),
      ),
    );
  }
}

/// Bouton discret (ESC, saut de ligne) - sans encadré, animation au clic
class TerminalDiscreteButton extends StatefulWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalDiscreteButton({
    super.key,
    this.text,
    this.icon,
    required this.onTap,
    required this.theme,
  }) : assert(text != null || icon != null);

  @override
  State<TerminalDiscreteButton> createState() => _TerminalDiscreteButtonState();
}

class _TerminalDiscreteButtonState extends State<TerminalDiscreteButton> {
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

/// Bouton navigation dossiers (pour la barre des onglets)
class TerminalFolderButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalFolderButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_outlined,
              color: theme.textMuted,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '~',
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boutons overlay pour le mode édition (nano, vim, less, htop, etc.)
/// Affiche 3 boutons verticaux à droite : Toggle D-pad, CTRL, Enter
/// Quand le D-pad est activé, affiche la croix directionnelle à gauche
class EditorModeButtons extends StatefulWidget {
  final VoidCallback onEnter;
  final void Function(int ctrlCode) onCtrlKey;
  final void Function(String direction) onArrow;
  final VibeTermThemeData theme;

  const EditorModeButtons({
    super.key,
    required this.onEnter,
    required this.onCtrlKey,
    required this.onArrow,
    required this.theme,
  });

  @override
  State<EditorModeButtons> createState() => _EditorModeButtonsState();
}

class _EditorModeButtonsState extends State<EditorModeButtons> {
  bool _showDpad = false;
  bool _ctrlArmed = false;
  final _ctrlFocusNode = FocusNode();
  final _ctrlController = TextEditingController();

  @override
  void dispose() {
    _ctrlFocusNode.dispose();
    _ctrlController.dispose();
    super.dispose();
  }

  void _toggleDpad() {
    setState(() => _showDpad = !_showDpad);
  }

  void _toggleCtrl() {
    setState(() {
      _ctrlArmed = !_ctrlArmed;
      if (_ctrlArmed) {
        // Demander le focus et ouvrir le clavier
        _ctrlController.clear();
        Future.microtask(() {
          _ctrlFocusNode.requestFocus();
        });
      }
    });
  }

  /// Envoie CTRL+lettre et désarme le bouton
  void _sendCtrlKey(String letter) {
    if (!_ctrlArmed) return;

    final upperLetter = letter.toUpperCase();
    if (upperLetter.length == 1 &&
        upperLetter.codeUnitAt(0) >= 65 &&
        upperLetter.codeUnitAt(0) <= 90) {
      final ctrlCode = upperLetter.codeUnitAt(0) - 64; // A=1, B=2, etc.
      widget.onCtrlKey(ctrlCode);
    }

    _ctrlController.clear();
    setState(() => _ctrlArmed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // D-pad en croix (si activé)
        if (_showDpad) ...[
          TerminalDpad(
            onUp: () => widget.onArrow('A'),
            onDown: () => widget.onArrow('B'),
            onLeft: () => widget.onArrow('D'),
            onRight: () => widget.onArrow('C'),
            theme: widget.theme,
          ),
          const SizedBox(width: 8),
        ],
        // TextField invisible pour capturer les touches quand CTRL armé
        if (_ctrlArmed)
          SizedBox(
            width: 1,
            height: 1,
            child: TextField(
              controller: _ctrlController,
              focusNode: _ctrlFocusNode,
              autofocus: true,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 1),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _sendCtrlKey(value[value.length - 1]);
                }
              },
            ),
          ),
        // 3 boutons verticaux à droite
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle D-pad
            _EditorButton(
              icon: Icons.gamepad_outlined,
              isActive: _showDpad,
              onTap: _toggleDpad,
              theme: widget.theme,
            ),
            const SizedBox(height: 4),
            // CTRL - même logique toggle que GhostTextInput
            _EditorCtrlButton(
              isArmed: _ctrlArmed,
              onTap: _toggleCtrl,
              theme: widget.theme,
            ),
            const SizedBox(height: 4),
            // Enter
            _EditorButton(
              icon: Icons.keyboard_return,
              onTap: widget.onEnter,
              theme: widget.theme,
            ),
          ],
        ),
      ],
    );
  }
}

/// Bouton CTRL pour le mode édition (même style que GhostTextInput)
class _EditorCtrlButton extends StatelessWidget {
  final bool isArmed;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const _EditorCtrlButton({
    required this.isArmed,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isArmed
        ? const Color(0xFFEAB308) // Jaune quand armé
        : theme.bgBlock;
    final textColor = isArmed ? Colors.black : theme.text;
    final borderColor = isArmed ? const Color(0xFFEAB308) : theme.border;
    final text = isArmed ? '+' : 'CTRL';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: isArmed ? 20 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton standard pour le mode édition (supporte icône ou texte)
class _EditorButton extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final VoidCallback onTap;
  final VibeTermThemeData theme;
  final bool isActive;

  const _EditorButton({
    this.icon,
    this.text,
    required this.onTap,
    required this.theme,
    this.isActive = false,
  }) : assert(icon != null || text != null);

  @override
  State<_EditorButton> createState() => _EditorButtonState();
}

class _EditorButtonState extends State<_EditorButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _isPressed;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isHighlighted ? widget.theme.accent : widget.theme.bgBlock,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted ? widget.theme.accent : widget.theme.border,
          ),
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: isHighlighted ? widget.theme.bg : widget.theme.text,
                  size: 20,
                )
              : Text(
                  widget.text!,
                  style: TextStyle(
                    color: isHighlighted ? widget.theme.bg : widget.theme.text,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
