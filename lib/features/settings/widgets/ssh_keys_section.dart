import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';
import 'selection_mixin.dart';
import 'ssh_key_tile.dart';
import 'add_ssh_key_sheet.dart';

class SSHKeysSection extends ConsumerStatefulWidget {
  const SSHKeysSection({super.key});

  @override
  ConsumerState<SSHKeysSection> createState() => _SSHKeysSectionState();
}

class _SSHKeysSectionState extends ConsumerState<SSHKeysSection>
    with SelectionModeMixin {
  Future<void> _deleteSelected() async {
    final theme = ref.read(vibeTermThemeProvider);
    final l10n = context.l10n;
    final count = selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(
          l10n.deleteKeysConfirm(count),
          style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
        ),
        content: Text(
          l10n.actionIrreversible,
          style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: TextStyle(color: theme.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in selectedIds) {
        await ref.read(settingsProvider.notifier).removeSSHKey(id);
      }
      exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.sshKeys.toUpperCase(),
          trailing: isSelectionMode
              ? buildSelectionActions(theme: theme, onDelete: _deleteSelected)
              : IconButton(
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
                    l10n.noSshKeys,
                    style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                  ),
                )
              : Column(
                  children: settings.sshKeys.asMap().entries.map((entry) {
                    final index = entry.key;
                    final key = entry.value;
                    return Column(
                      children: [
                        if (index > 0)
                          Divider(
                            color: theme.border.withValues(alpha: 0.5),
                            height: 1,
                          ),
                        SSHKeyTile(
                          sshKey: key,
                          isSelectionMode: isSelectionMode,
                          isSelected: selectedIds.contains(key.id),
                          onLongPress: () => enterSelectionMode(key.id),
                          onSelectionToggle: () => toggleSelection(key.id),
                        ),
                      ],
                    );
                  }).toList(),
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
