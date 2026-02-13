import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/models.dart';
import '../providers/settings_provider.dart';

class SSHKeyTile extends ConsumerWidget {
  final SSHKey sshKey;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectionToggle;

  const SSHKeyTile({
    super.key,
    required this.sshKey,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(vibeTermThemeProvider);

    // En mode sélection, pas de swipe
    if (isSelectionMode) {
      return _buildTile(context, ref, theme);
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Dismissible(
        key: Key(sshKey.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: theme.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: VibeTermSpacing.md),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) => _confirmDelete(context, ref),
        onDismissed: (direction) {
          ref.read(settingsProvider.notifier).removeSSHKey(sshKey.id);
        },
        child: _buildTileContent(context, ref, theme),
      ),
    );
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, VibeTermThemeData theme) {
    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (_) => onSelectionToggle?.call(),
        activeColor: theme.accent,
        side: BorderSide(color: theme.textMuted),
      ),
      title: Text(sshKey.name, style: VibeTermTypography.itemTitle.copyWith(color: theme.text)),
      subtitle: Text(
        '${sshKey.typeLabel} • ${_formatDate(sshKey.createdAt)}',
        style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
      ),
      onTap: onSelectionToggle,
    );
  }

  Widget _buildTileContent(BuildContext context, WidgetRef ref, VibeTermThemeData theme) {
    return ListTile(
      leading: Icon(Icons.key, color: theme.accent),
      title: Text(sshKey.name, style: VibeTermTypography.itemTitle.copyWith(color: theme.text)),
      subtitle: Text(
        '${sshKey.typeLabel} • ${_formatDate(sshKey.createdAt)}',
        style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
      ),
      onTap: () => _showKeyDetails(context, ref),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, WidgetRef ref) {
    final theme = ref.read(vibeTermThemeProvider);
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(l10n.deleteKeyConfirmTitle, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
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
  }

  void _showKeyDetails(BuildContext context, WidgetRef ref) {
    final theme = ref.read(vibeTermThemeProvider);
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bgBlock,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sshKey.name, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
            const SizedBox(height: VibeTermSpacing.sm),
            Text(l10n.sshKeyTypeLabel(sshKey.typeLabel), style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
            Text(l10n.sshKeyHostLabel(sshKey.host), style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
            Text(l10n.sshKeyLastUsedLabel(_formatLastUsed(l10n, sshKey.lastUsed)), style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
            const SizedBox(height: VibeTermSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.edit, color: theme.accent, size: 18),
                label: Text(l10n.rename, style: TextStyle(color: theme.accent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _showRenameDialog(context, ref);
                },
              ),
            ),
            const SizedBox(height: VibeTermSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final theme = ref.read(vibeTermThemeProvider);
    final l10n = context.l10n;
    final controller = TextEditingController(text: sshKey.name);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(l10n.rename, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: theme.text),
          decoration: InputDecoration(
            hintText: l10n.renameDialogHint,
            hintStyle: TextStyle(color: theme.textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(settingsProvider.notifier).renameSSHKey(sshKey.id, newName);
                Navigator.pop(dialogContext);
              }
            },
            child: Text(l10n.save, style: TextStyle(color: theme.accent)),
          ),
        ],
      ),
    );
  }

  String _formatLastUsed(AppLocalizations l10n, DateTime? lastUsed) {
    if (lastUsed == null) return l10n.sshKeyNeverUsed;
    final diff = DateTime.now().difference(lastUsed);
    if (diff.inDays == 0) return l10n.sshKeyUsedToday;
    if (diff.inDays == 1) return l10n.sshKeyUsedYesterday;
    return l10n.sshKeyUsedDaysAgo(diff.inDays);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
