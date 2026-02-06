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

class SSHKeysSection extends ConsumerStatefulWidget {
  const SSHKeysSection({super.key});

  @override
  ConsumerState<SSHKeysSection> createState() => _SSHKeysSectionState();
}

class _SSHKeysSectionState extends ConsumerState<SSHKeysSection> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String keyId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(keyId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String keyId) {
    setState(() {
      if (_selectedIds.contains(keyId)) {
        _selectedIds.remove(keyId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(keyId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final theme = ref.read(vibeTermThemeProvider);
    final l10n = context.l10n;
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(
          'Supprimer $count clé${count > 1 ? 's' : ''} ?',
          style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
        ),
        content: Text(
          'Cette action est irréversible.',
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
      for (final id in _selectedIds) {
        await ref.read(settingsProvider.notifier).removeSSHKey(id);
      }
      _exitSelectionMode();
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
          trailing: _isSelectionMode
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete, color: theme.danger),
                      onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.textMuted),
                      onPressed: _exitSelectionMode,
                    ),
                  ],
                )
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
                          isSelectionMode: _isSelectionMode,
                          isSelected: _selectedIds.contains(key.id),
                          onLongPress: () => _enterSelectionMode(key.id),
                          onSelectionToggle: () => _toggleSelection(key.id),
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
