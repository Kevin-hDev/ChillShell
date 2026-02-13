import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../settings/providers/wol_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/providers.dart';

class SessionInfoBar extends ConsumerWidget {
  const SessionInfoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final lastExecutionTime = ref.watch(terminalProvider.select((s) => s.lastExecutionTime));
    final theme = ref.watch(vibeTermThemeProvider);
    final wolNotifier = ref.read(wolProvider.notifier);
    final savedConnections = ref.watch(settingsProvider.select((s) => s.savedConnections));

    if (session == null) {
      return const SizedBox.shrink();
    }

    // Vérifier si une config WOL est associée à cette session
    // On cherche par host/username car session.id != savedConnection.id
    final wolConfig = wolNotifier.getConfigForSession(
      savedConnections,
      session.host,
      session.username,
    );

    // Afficher le temps d'exécution de la dernière commande terminée
    String? executionTimeText;
    if (lastExecutionTime != null) {
      executionTimeText = _formatDuration(lastExecutionTime);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.bg,  // Fond opaque pour éviter la superposition au scroll
        border: Border(
          bottom: BorderSide(color: theme.borderLight),
        ),
      ),
      child: Row(
        children: [
          // Partie gauche : tmux + IP (utilise l'espace disponible)
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '\u2190 tmux: ',
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: session.tmuxSession ?? 'vibe',
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.accent,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: ' \u2022 ',
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  TextSpan(
                    text: session.host,
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.text,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.sm),
          // Temps d'exécution (si présent)
          if (executionTimeText != null) ...[
            Icon(
              Icons.timer_outlined,
              size: 10,
              color: theme.textMuted,
            ),
            const SizedBox(width: 2),
            Text(
              executionTimeText,
              style: VibeTermTypography.caption.copyWith(
                color: theme.warning,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: VibeTermSpacing.xs),
          ],
          // Tailscale badge à droite
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
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
                fontSize: 9,
              ),
            ),
          ),
          // Bouton d'extinction (visible uniquement si config WOL associée)
          if (wolConfig != null) ...[
            const SizedBox(width: VibeTermSpacing.xs),
            _ShutdownButton(
              wolConfigName: wolConfig.name,
              detectedOS: wolConfig.detectedOS,
              sessionId: session.id,
            ),
          ],
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

/// Bouton d'extinction du PC distant.
///
/// Visible uniquement si une configuration WOL est associée à la session.
/// Affiche un dialog de confirmation avant d'envoyer la commande shutdown.
class _ShutdownButton extends ConsumerWidget {
  final String wolConfigName;
  final String? detectedOS;
  final String sessionId;

  const _ShutdownButton({
    required this.wolConfigName,
    required this.detectedOS,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(vibeTermThemeProvider);

    return GestureDetector(
      onTap: () => _showShutdownConfirmation(context, ref),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(VibeTermRadius.xs),
        ),
        child: Icon(
          Icons.power_settings_new,
          size: 14,
          color: theme.danger,
        ),
      ),
    );
  }

  Future<void> _showShutdownConfirmation(BuildContext context, WidgetRef ref) async {
    final theme = ref.read(vibeTermThemeProvider);
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          side: BorderSide(color: theme.borderLight),
        ),
        title: Row(
          children: [
            Icon(Icons.power_settings_new, color: theme.danger, size: 24),
            const SizedBox(width: VibeTermSpacing.sm),
            Text(
              l10n.shutdownPcTitle,
              style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
            ),
          ],
        ),
        content: Text(
          l10n.shutdownPcMessage(wolConfigName),
          style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.cancel,
              style: VibeTermTypography.sectionLabel.copyWith(color: theme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: theme.danger.withValues(alpha: 0.15),
            ),
            child: Text(
              l10n.shutdownAction,
              style: VibeTermTypography.sectionLabel.copyWith(color: theme.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeShutdown(ref);
    }
  }

  Future<void> _executeShutdown(WidgetRef ref) async {
    final sshNotifier = ref.read(sshProvider.notifier);
    final sshState = ref.read(sshProvider);

    // Récupérer le service SSH de l'onglet actif
    final currentTabId = sshState.currentTabId;
    if (currentTabId == null) return;

    // Déterminer l'OS à utiliser (détecté ou par défaut "linux")
    final os = detectedOS ?? 'linux';

    // Envoyer la commande shutdown via le provider
    // Note: \r (carriage return) au lieu de \n pour que la commande soit exécutée
    final command = (os == 'linux' || os == 'macos')
        ? 'sudo shutdown -h now\r'
        : 'shutdown /s /t 0\r';

    sshNotifier.write(command);

    // NE PAS fermer l'onglet automatiquement car :
    // 1. sudo peut demander un mot de passe
    // 2. L'utilisateur doit voir le résultat
    // La session se fermera d'elle-même quand le PC s'éteindra
  }
}
