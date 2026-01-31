import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';

/// Bouton pour naviguer dans l'historique des commandes
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border),
        ),
        child: Icon(
          icon,
          color: theme.textMuted,
          size: 20,
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

/// Bouton pour envoyer une commande
class TerminalSendButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalSendButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.arrow_upward,
          color: theme.bg,
          size: 28,
        ),
      ),
    );
  }
}

/// Bouton pour arrêter un processus (Ctrl+C)
class TerminalStopButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalStopButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: theme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.stop,
          color: theme.bg,
          size: 28,
        ),
      ),
    );
  }
}

/// Bouton flèche pour navigation dans les menus interactifs (htop, fzf, etc.)
class TerminalArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalArrowButton({
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
        ),
        child: Icon(
          icon,
          color: theme.accent,
          size: 24,
        ),
      ),
    );
  }
}
