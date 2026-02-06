import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import 'section_header.dart';
import 'ssh_keys_section.dart';

/// Section Accès : Tailscale + Clés SSH
///
/// Regroupe les outils d'accès distant (Tailscale) et les clés SSH
/// dans un onglet dédié pour simplifier la navigation.
class AccessSection extends ConsumerWidget {
  const AccessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: const [
        _TailscaleSection(),
        SizedBox(height: VibeTermSpacing.lg),
        SSHKeysSection(),
        SizedBox(height: VibeTermSpacing.lg),
        _SSHKeySecurityCard(),
        SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Section Tailscale pour l'accès distant
class _TailscaleSection extends ConsumerWidget {
  const _TailscaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: l10n.remoteAccess.toUpperCase()),
            const SizedBox(height: VibeTermSpacing.sm),
            Container(
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
                    // Header avec icône
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
                    // Description
                    Text(
                      l10n.tailscaleDescription,
                      style: VibeTermTypography.itemDescription.copyWith(
                        color: theme.textMuted,
                      ),
                    ),
                    const SizedBox(height: VibeTermSpacing.md),
                    // Boutons de téléchargement
                    Row(
                      children: [
                        Expanded(
                          child: _TailscaleButton(
                            icon: Icons.android,
                            label: l10n.playStore,
                            onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.tailscale.ipn'),
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: VibeTermSpacing.sm),
                        Expanded(
                          child: _TailscaleButton(
                            icon: Icons.apple,
                            label: l10n.appStore,
                            onTap: () => _launchUrl('https://apps.apple.com/app/tailscale/id1470499037'),
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: VibeTermSpacing.sm),
                    // Bouton site web
                    SizedBox(
                      width: double.infinity,
                      child: _TailscaleButton(
                        icon: Icons.language,
                        label: l10n.website,
                        onTap: () => _launchUrl('https://tailscale.com'),
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Fallback: ouvrir dans le navigateur interne
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }
  }
}

/// Card dépliante avec conseils de sécurité sur les clés SSH.
class _SSHKeySecurityCard extends ConsumerStatefulWidget {
  const _SSHKeySecurityCard();

  @override
  ConsumerState<_SSHKeySecurityCard> createState() => _SSHKeySecurityCardState();
}

class _SSHKeySecurityCardState extends ConsumerState<_SSHKeySecurityCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(VibeTermSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: theme.warning, size: 18),
                  const SizedBox(width: VibeTermSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.sshKeySecurityTitle,
                      style: VibeTermTypography.itemTitle.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(
                left: VibeTermSpacing.md,
                right: VibeTermSpacing.md,
                bottom: VibeTermSpacing.md,
              ),
              child: Text(
                l10n.sshKeySecurityDesc,
                style: VibeTermTypography.itemDescription.copyWith(
                  color: theme.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bouton pour télécharger Tailscale
class _TailscaleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const _TailscaleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
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

