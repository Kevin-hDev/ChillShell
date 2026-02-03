import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';
import 'ssh_key_tile.dart';
import 'add_ssh_key_sheet.dart';

class SSHKeysSection extends ConsumerWidget {
  const SSHKeysSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.sshKeys.toUpperCase(),
          trailing: IconButton(
            icon: Icon(Icons.add, color: theme.accent),
            onPressed: () => _showAddKeySheet(context, theme),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: settings.sshKeys.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(VibeTermSpacing.md),
                  child: Text(
                    l10n.sshKeys,
                    style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                  ),
                )
              : Column(
                  children: settings.sshKeys
                      .map((key) => SSHKeyTile(sshKey: key))
                      .toList(),
                ),
        ),
      ],
    );
  }

  void _showAddKeySheet(BuildContext context, VibeTermThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bgBlock,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const AddSSHKeySheet(),
    );
  }
}
