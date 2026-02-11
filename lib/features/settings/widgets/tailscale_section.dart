import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/tailscale_provider.dart';

/// Section Tailscale pour l'onglet Acces.
/// Affiche un formulaire de connexion ou un statut compact selon l'etat.
class TailscaleSection extends ConsumerWidget {
  const TailscaleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);
    final tailscaleState = ref.watch(tailscaleProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec icone
            Row(
              children: [
                Icon(
                  Icons.public,
                  color: theme.accent,
                  size: 22,
                ),
                const SizedBox(width: VibeTermSpacing.sm),
                Text(
                  'Tailscale',
                  style: VibeTermTypography.itemTitle.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VibeTermSpacing.sm),

            if (tailscaleState.isConnected)
              _ConnectedStatus(
                theme: theme,
                ip: tailscaleState.myIP,
              )
            else
              _LoginPrompt(theme: theme, l10n: l10n, ref: ref),

            const SizedBox(height: VibeTermSpacing.sm),

            // Accordeon "Qu'est-ce que Tailscale ?"
            _TailscaleExplainerTile(theme: theme, l10n: l10n),
          ],
        ),
      ),
    );
  }
}

/// Card compacte affichee quand Tailscale est connecte.
class _ConnectedStatus extends StatelessWidget {
  final VibeTermThemeData theme;
  final String? ip;

  const _ConnectedStatus({required this.theme, this.ip});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.sm,
        vertical: VibeTermSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: theme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.sm),
          Expanded(
            child: Text(
              ip != null
                  ? '${l10n.tailscaleConnected} - $ip'
                  : l10n.tailscaleConnected,
              style: VibeTermTypography.caption.copyWith(
                color: theme.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prompt de connexion quand Tailscale n'est pas connecte.
class _LoginPrompt extends StatelessWidget {
  final VibeTermThemeData theme;
  final AppLocalizations l10n;
  final WidgetRef ref;

  const _LoginPrompt({
    required this.theme,
    required this.l10n,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tailscaleAuthPrompt,
          style: VibeTermTypography.itemDescription.copyWith(
            color: theme.textMuted,
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.person_add,
                label: l10n.tailscaleCreateAccount,
                theme: theme,
                onTap: () => ref.read(tailscaleProvider.notifier).login(),
              ),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            Expanded(
              child: _ActionButton(
                icon: Icons.login,
                label: l10n.tailscaleLogin,
                theme: theme,
                onTap: () => ref.read(tailscaleProvider.notifier).login(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bouton d'action pour la section Tailscale.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VibeTermThemeData theme;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(VibeTermRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.sm,
          vertical: VibeTermSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.accent, size: 16),
            const SizedBox(width: VibeTermSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: VibeTermTypography.caption.copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ExpansionTile "Qu'est-ce que Tailscale ?"
class _TailscaleExplainerTile extends StatelessWidget {
  final VibeTermThemeData theme;
  final AppLocalizations l10n;

  const _TailscaleExplainerTile({
    required this.theme,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: VibeTermSpacing.sm),
        initiallyExpanded: false,
        title: Text(
          l10n.tailscaleWhatIs,
          style: VibeTermTypography.caption.copyWith(
            color: theme.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconColor: theme.textMuted,
        collapsedIconColor: theme.textMuted,
        children: [
          Text(
            l10n.tailscaleExplainer,
            style: VibeTermTypography.itemDescription.copyWith(
              color: theme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
