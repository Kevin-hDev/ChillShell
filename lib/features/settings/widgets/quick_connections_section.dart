import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/models.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

class QuickConnectionsSection extends ConsumerWidget {
  const QuickConnectionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final savedConnections = settings.savedConnections;
    final appSettings = settings.appSettings;
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'CONNEXIONS RAPIDES'),
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
                title: 'Connexion auto au démarrage',
                subtitle: 'Se connecter automatiquement à la dernière connexion',
                value: appSettings.autoConnectOnStart,
                onChanged: (value) => ref.read(settingsProvider.notifier).toggleAutoConnect(value),
                theme: theme,
              ),
              Divider(height: 1, color: theme.border),
              _SettingsToggle(
                title: 'Reconnexion automatique',
                subtitle: 'Reconnecter en cas de perte de connexion',
                value: appSettings.reconnectOnDisconnect,
                onChanged: (value) => ref.read(settingsProvider.notifier).toggleReconnect(value),
                theme: theme,
              ),
              Divider(height: 1, color: theme.border),
              _SettingsToggle(
                title: 'Notification de déconnexion',
                subtitle: 'Afficher une notification en cas de déconnexion',
                value: appSettings.notifyOnDisconnect,
                onChanged: (value) => ref.read(settingsProvider.notifier).toggleNotifyOnDisconnect(value),
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        // Liste des connexions sauvegardées
        Text(
          'Connexions sauvegardées',
          style: VibeTermTypography.sectionLabel.copyWith(color: theme.textMuted),
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
                    'Aucune connexion sauvegardée',
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
                          onToggleQuickAccess: () => ref.read(settingsProvider.notifier).toggleQuickAccess(connection.id),
                          onDelete: () => _showDeleteDialog(context, ref, connection.id, connection.name),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String id, String name) {
    final theme = ref.read(vibeTermThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text('Supprimer la connexion ?', style: TextStyle(color: theme.text)),
        content: Text(
          'Voulez-vous supprimer "$name" de vos connexions sauvegardées ?',
          style: TextStyle(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: theme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).deleteSavedConnection(id);
              Navigator.pop(context);
            },
            child: Text('Supprimer', style: TextStyle(color: theme.danger)),
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
  final VoidCallback onToggleQuickAccess;
  final VoidCallback onDelete;

  const _ConnectionItem({
    required this.connection,
    required this.theme,
    required this.onToggleQuickAccess,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: connection.isQuickAccess ? theme.success : theme.textMuted,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        connection.name,
        style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
      ),
      subtitle: Text(
        '${connection.username}@${connection.host}:${connection.port}',
        style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: connection.isQuickAccess,
            activeTrackColor: theme.accent.withValues(alpha: 0.5),
            activeThumbColor: theme.accent,
            onChanged: (_) => onToggleQuickAccess(),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.textMuted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
