import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wol_provider.dart';
import 'section_header.dart';

/// Section Wake-on-LAN dans les paramètres.
///
/// Permet d'activer/désactiver le WOL et de gérer les configurations
/// de PC à allumer à distance.
class WolSection extends ConsumerWidget {
  final VoidCallback? onAddConfig;

  const WolSection({super.key, this.onAddConfig});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final wolState = ref.watch(wolProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    final hasConfigs = wolState.configs.isNotEmpty;
    final wolEnabled = settings.appSettings.wolEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Activer Wake-on-LAN
        const SectionHeader(title: 'ACTIVER WAKE-ON-LAN'),
        const SizedBox(height: VibeTermSpacing.sm),
        _WolEnableCard(
          enabled: wolEnabled,
          canToggle: hasConfigs,
          onToggle: (value) {
            ref.read(settingsProvider.notifier).toggleWolEnabled(value);
          },
          theme: theme,
        ),
        const SizedBox(height: VibeTermSpacing.lg),

        // Section Configurations WOL
        const SectionHeader(title: 'CONFIGURATIONS WOL'),
        const SizedBox(height: VibeTermSpacing.sm),
        _WolConfigsCard(
          configs: wolState.configs,
          isLoading: wolState.isLoading,
          onAddConfig: onAddConfig,
          onDeleteConfig: (configId) {
            ref.read(wolProvider.notifier).deleteConfig(configId);
          },
          theme: theme,
        ),
        const SizedBox(height: VibeTermSpacing.lg),

        // Section Scan automatique (bientôt)
        const SectionHeader(title: 'SCAN AUTOMATIQUE'),
        const SizedBox(height: VibeTermSpacing.sm),
        _ComingSoonCard(theme: theme),
      ],
    );
  }
}

/// Carte pour activer/désactiver le WOL avec description.
class _WolEnableCard extends StatelessWidget {
  final bool enabled;
  final bool canToggle;
  final ValueChanged<bool> onToggle;
  final VibeTermThemeData theme;

  const _WolEnableCard({
    required this.enabled,
    required this.canToggle,
    required this.onToggle,
    required this.theme,
  });

  void _copyWolGuideUrl(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'https://chillshell.app/wol'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Lien copié : chillshell.app/wol',
          style: TextStyle(color: theme.text),
        ),
        backgroundColor: theme.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle principal
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: VibeTermSpacing.md,
              vertical: VibeTermSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: canToggle ? theme.accent : theme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: VibeTermSpacing.sm),
                Expanded(
                  child: Text(
                    'Activer Wake-on-LAN',
                    style: VibeTermTypography.itemTitle.copyWith(
                      color: canToggle ? theme.text : theme.textMuted,
                    ),
                  ),
                ),
                Switch(
                  value: enabled && canToggle,
                  activeThumbColor: theme.accent,
                  onChanged: canToggle ? onToggle : null,
                ),
              ],
            ),
          ),
          Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
          // Description
          Padding(
            padding: const EdgeInsets.all(VibeTermSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allumez votre PC à distance avant de vous connecter en SSH.',
                  style: VibeTermTypography.itemDescription.copyWith(
                    color: theme.textMuted,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.sm),
                GestureDetector(
                  onTap: () => _copyWolGuideUrl(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book,
                        color: theme.accent,
                        size: 16,
                      ),
                      const SizedBox(width: VibeTermSpacing.xs),
                      Text(
                        'Guide complet sur chillshell.app/wol',
                        style: VibeTermTypography.itemDescription.copyWith(
                          color: theme.accent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte affichant la liste des configurations WOL ou un état vide.
class _WolConfigsCard extends StatelessWidget {
  final List<dynamic> configs;
  final bool isLoading;
  final VoidCallback? onAddConfig;
  final void Function(String) onDeleteConfig;
  final VibeTermThemeData theme;

  const _WolConfigsCard({
    required this.configs,
    required this.isLoading,
    required this.onAddConfig,
    required this.onDeleteConfig,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(VibeTermSpacing.lg),
              child: CircularProgressIndicator(),
            )
          else if (configs.isEmpty)
            _EmptyState(theme: theme)
          else
            ...configs.asMap().entries.map((entry) {
              final index = entry.key;
              final config = entry.value;
              return Column(
                children: [
                  if (index > 0)
                    Divider(
                      color: theme.border.withValues(alpha: 0.5),
                      height: 1,
                    ),
                  _WolConfigItem(
                    config: config,
                    onDelete: () => onDeleteConfig(config.id),
                    theme: theme,
                  ),
                ],
              );
            }),
          Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
          // Bouton Ajouter un PC
          _AddConfigButton(onTap: onAddConfig, theme: theme),
        ],
      ),
    );
  }
}

/// État vide quand aucune configuration WOL n'existe.
class _EmptyState extends StatelessWidget {
  final VibeTermThemeData theme;

  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VibeTermSpacing.lg),
      child: Text(
        'Aucune configuration. Ajoutez-en une pour activer le WOL.',
        style: VibeTermTypography.itemDescription.copyWith(
          color: theme.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Item affichant une configuration WOL avec bouton de suppression.
class _WolConfigItem extends StatelessWidget {
  final dynamic config;
  final VoidCallback onDelete;
  final VibeTermThemeData theme;

  const _WolConfigItem({
    required this.config,
    required this.onDelete,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.desktop_windows,
            color: theme.accent,
            size: 22,
          ),
          const SizedBox(width: VibeTermSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: VibeTermTypography.itemTitle.copyWith(
                    color: theme.text,
                  ),
                ),
                Text(
                  config.macAddress,
                  style: VibeTermTypography.itemDescription.copyWith(
                    color: theme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.danger, size: 20),
            onPressed: () => _showDeleteConfirmation(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(
          'Supprimer la configuration ?',
          style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${config.name}" ?',
          style: VibeTermTypography.itemDescription.copyWith(
            color: theme.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Annuler',
              style: TextStyle(color: theme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            child: Text(
              'Supprimer',
              style: TextStyle(color: theme.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton pour ajouter une nouvelle configuration WOL.
class _AddConfigButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VibeTermThemeData theme;

  const _AddConfigButton({
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(VibeTermRadius.md),
        bottomRight: Radius.circular(VibeTermRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.accent, size: 20),
            const SizedBox(width: VibeTermSpacing.xs),
            Text(
              'Ajouter un PC',
              style: VibeTermTypography.itemTitle.copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte indiquant que le scan automatique arrive bientôt.
class _ComingSoonCard extends StatelessWidget {
  final VibeTermThemeData theme;

  const _ComingSoonCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgBlock.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.md,
          vertical: VibeTermSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi_find,
              color: theme.textMuted,
              size: 22,
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan automatique',
                    style: VibeTermTypography.itemTitle.copyWith(
                      color: theme.textMuted,
                    ),
                  ),
                  Text(
                    'Fonctionnalité en développement',
                    style: VibeTermTypography.itemDescription.copyWith(
                      color: theme.textMuted.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: VibeTermSpacing.sm,
                vertical: VibeTermSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              ),
              child: Text(
                'Bientôt',
                style: VibeTermTypography.itemDescription.copyWith(
                  color: theme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
