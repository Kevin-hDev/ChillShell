import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import 'section_header.dart';
import 'ssh_keys_section.dart';
import 'tailscale_section.dart';

/// Section Accès : Tailscale + Clés SSH
///
/// Regroupe les outils d'accès distant (Tailscale) et les clés SSH
/// dans un onglet dédié pour simplifier la navigation.
class AccessSection extends ConsumerWidget {
  const AccessSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: [
        SectionHeader(title: l10n.remoteAccess.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        const TailscaleSection(),
        const SizedBox(height: VibeTermSpacing.lg),
        const SSHKeysSection(),
        const SizedBox(height: VibeTermSpacing.lg),
        const _SSHKeySecurityCard(),
        const SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Card dépliante avec conseils de sécurité sur les clés SSH.
class _SSHKeySecurityCard extends ConsumerStatefulWidget {
  const _SSHKeySecurityCard();

  @override
  ConsumerState<_SSHKeySecurityCard> createState() =>
      _SSHKeySecurityCardState();
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
