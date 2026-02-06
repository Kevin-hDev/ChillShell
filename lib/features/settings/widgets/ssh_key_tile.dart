import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
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
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text('Supprimer la clé ?', style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
        content: Text(
          'Cette action est irréversible.',
          style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: TextStyle(color: theme.danger)),
          ),
        ],
      ),
    );
  }

  void _showKeyDetails(BuildContext context, WidgetRef ref) {
    final theme = ref.read(vibeTermThemeProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.bgBlock,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sshKey.name, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
            const SizedBox(height: VibeTermSpacing.sm),
            Text('Type: ${sshKey.typeLabel}', style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
            Text('Hôte: ${sshKey.host}', style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
            Text('Dernière utilisation: ${sshKey.lastUsedLabel}', style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
            const SizedBox(height: VibeTermSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
