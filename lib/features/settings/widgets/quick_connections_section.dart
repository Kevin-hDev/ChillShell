import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/models.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';
import 'selection_mixin.dart';

class QuickConnectionsSection extends ConsumerStatefulWidget {
  const QuickConnectionsSection({super.key});

  @override
  ConsumerState<QuickConnectionsSection> createState() => _QuickConnectionsSectionState();
}

class _QuickConnectionsSectionState extends ConsumerState<QuickConnectionsSection>
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
          l10n.deleteConnectionsConfirm(count),
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
        ref.read(settingsProvider.notifier).deleteSavedConnection(id);
      }
      exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final savedConnections = settings.savedConnections;
    final appSettings = settings.appSettings;
    final theme = ref.watch(vibeTermThemeProvider);
    final autoConnectEnabled = appSettings.autoConnectOnStart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.quickConnections),
        const SizedBox(height: VibeTermSpacing.sm),
        // Options de comportement
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              _SettingsToggle(
                title: l10n.autoConnectOnStart,
                subtitle: l10n.autoConnectOnStartDesc,
                value: appSettings.autoConnectOnStart,
                onChanged: (value) => ref.read(settingsProvider.notifier).toggleAutoConnect(value),
                theme: theme,
              ),
              Divider(height: 1, color: theme.border),
              _SettingsToggle(
                title: l10n.autoReconnect,
                subtitle: l10n.autoReconnectDesc,
                value: appSettings.reconnectOnDisconnect,
                onChanged: (value) => ref.read(settingsProvider.notifier).toggleReconnect(value),
                theme: theme,
              ),
              Divider(height: 1, color: theme.border),
              _SettingsToggle(
                title: l10n.disconnectNotification,
                subtitle: l10n.disconnectNotificationDesc,
                value: appSettings.notifyOnDisconnect,
                onChanged: (value) => ref.read(settingsProvider.notifier).toggleNotifyOnDisconnect(value),
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        // Liste des connexions automatiques
        SectionHeader(
          title: l10n.autoConnection.toUpperCase(),
          trailing: isSelectionMode
              ? buildSelectionActions(theme: theme, onDelete: _deleteSelected)
              : null,
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: savedConnections.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(VibeTermSpacing.md),
                  child: Text(
                    l10n.noSavedConnections,
                    style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                  ),
                )
              : Column(
                  children: savedConnections.asMap().entries.map((entry) {
                    final index = entry.key;
                    final connection = entry.value;
                    return Column(
                      children: [
                        if (index > 0) Divider(height: 1, color: theme.border),
                        _ConnectionItem(
                          connection: connection,
                          theme: theme,
                          isEnabled: autoConnectEnabled,
                          isSelectionMode: isSelectionMode,
                          isSelected: selectedIds.contains(connection.id),
                          onSelect: () => ref.read(settingsProvider.notifier).selectAutoConnection(connection.id),
                          onDelete: () => _showDeleteDialog(context, connection.id, connection.name),
                          onLongPress: () => enterSelectionMode(connection.id),
                          onSelectionToggle: () => toggleSelection(connection.id),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, String id, String name) {
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text(l10n.deleteConnectionConfirm, style: TextStyle(color: theme.text)),
        content: Text(
          l10n.deleteConnectionConfirmMessage(name),
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).deleteSavedConnection(id);
              Navigator.pop(dialogContext);
            },
            child: Text(l10n.delete, style: TextStyle(color: theme.danger)),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VibeTermThemeData theme;

  const _SettingsToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: VibeTermTypography.itemTitle.copyWith(color: theme.text)),
      subtitle: Text(subtitle, style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
      trailing: Switch(
        value: value,
        activeTrackColor: theme.accent.withValues(alpha: 0.5),
        activeThumbColor: theme.accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _ConnectionItem extends StatelessWidget {
  final SavedConnection connection;
  final VibeTermThemeData theme;
  final bool isEnabled;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback onSelectionToggle;

  const _ConnectionItem({
    required this.connection,
    required this.theme,
    required this.isEnabled,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
    required this.onLongPress,
    required this.onSelectionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = connection.isQuickAccess;
    final isDisabled = !isEnabled;

    // En mode sélection, pas de swipe
    if (isSelectionMode) {
      return _buildTile(context, isActive, isDisabled);
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Dismissible(
        key: Key(connection.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: theme.danger,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: VibeTermSpacing.md),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) => _confirmDelete(context),
        onDismissed: (direction) => onDelete(),
        child: _buildTile(context, isActive, isDisabled),
      ),
    );
  }

  Widget _buildTile(BuildContext context, bool isActive, bool isDisabled) {
    final textColor = isDisabled ? theme.textMuted.withValues(alpha: 0.5) : theme.text;
    final subtitleColor = isDisabled ? theme.textMuted.withValues(alpha: 0.3) : theme.textMuted;

    return ListTile(
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => onSelectionToggle(),
              activeColor: theme.accent,
              side: BorderSide(color: theme.textMuted),
            )
          : Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive && !isDisabled ? theme.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDisabled ? theme.textMuted.withValues(alpha: 0.3) : (isActive ? theme.accent : theme.textMuted),
                  width: 2,
                ),
              ),
              child: isActive && !isDisabled
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
      title: Text(
        connection.name,
        style: VibeTermTypography.itemTitle.copyWith(color: textColor),
      ),
      subtitle: Text(
        '${connection.username}@${connection.host}:${connection.port}',
        style: VibeTermTypography.itemDescription.copyWith(color: subtitleColor),
      ),
      onTap: isSelectionMode
          ? onSelectionToggle
          : (isDisabled ? null : onSelect),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(
          l10n.deleteConnectionConfirm,
          style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
        ),
        content: Text(
          connection.name,
          style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete, style: TextStyle(color: theme.danger)),
          ),
        ],
      ),
    );
  }
}
