import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/providers.dart';

class SessionInfoBar extends ConsumerWidget {
  const SessionInfoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final terminalState = ref.watch(terminalProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    if (session == null) {
      return const SizedBox.shrink();
    }

    // Afficher le temps d'exécution de la dernière commande terminée
    String? executionTimeText;
    if (terminalState.lastExecutionTime != null) {
      executionTimeText = _formatDuration(terminalState.lastExecutionTime!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.borderLight),
        ),
      ),
      child: Row(
        children: [
          Text(
            '\u2190',
            style: TextStyle(color: theme.textMuted, fontSize: 12),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Text(
            'tmux: ',
            style: VibeTermTypography.caption.copyWith(
              color: theme.textMuted,
            ),
          ),
          Flexible(
            child: Text(
              session.tmuxSession ?? 'vibe',
              style: VibeTermTypography.caption.copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Text(
            '\u2022',
            style: VibeTermTypography.caption.copyWith(
              color: theme.textMuted,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Flexible(
            child: Text(
              session.host,
              style: VibeTermTypography.caption.copyWith(
                color: theme.text,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          // Temps d'exécution
          if (executionTimeText != null) ...[
            Icon(
              Icons.timer_outlined,
              size: 12,
              color: theme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              executionTimeText,
              style: VibeTermTypography.caption.copyWith(
                color: theme.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
          ],
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VibeTermSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: theme.accentDim,
              borderRadius: BorderRadius.circular(VibeTermRadius.xs),
            ),
            child: Text(
              'Tailscale',
              style: VibeTermTypography.caption.copyWith(
                color: theme.accent,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    } else if (duration.inSeconds >= 1) {
      final seconds = duration.inMilliseconds / 1000;
      return '${seconds.toStringAsFixed(1)}s';
    } else {
      final ms = duration.inMilliseconds;
      return '${ms}ms';
    }
  }
}
