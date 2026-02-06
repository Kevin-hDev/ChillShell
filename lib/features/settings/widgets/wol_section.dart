import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/settings_provider.dart';
import '../providers/wol_provider.dart';
import 'section_header.dart';

/// Section Wake-on-LAN dans les paramètres.
///
/// Permet d'activer/désactiver le WOL et de gérer les configurations
/// de PC à allumer à distance.
class WolSection extends ConsumerStatefulWidget {
  final VoidCallback? onAddConfig;

  const WolSection({super.key, this.onAddConfig});

  @override
  ConsumerState<WolSection> createState() => _WolSectionState();
}

class _WolSectionState extends ConsumerState<WolSection> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _enterSelectionMode(String configId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(configId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String configId) {
    setState(() {
      if (_selectedIds.contains(configId)) {
        _selectedIds.remove(configId);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(configId);
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
          'Supprimer $count config${count > 1 ? 's' : ''} ?',
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
        await ref.read(wolProvider.notifier).deleteConfig(id);
      }
      _exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final wolState = ref.watch(wolProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    final hasConfigs = wolState.configs.isNotEmpty;
    final wolEnabled = settings.appSettings.wolEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Activer Wake-on-LAN
        SectionHeader(title: l10n.wolEnabled.toUpperCase()),
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
        SectionHeader(
          title: l10n.wolConfigs.toUpperCase(),
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
              : null,
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        _WolConfigsCard(
          configs: wolState.configs,
          isLoading: wolState.isLoading,
          onAddConfig: widget.onAddConfig,
          onDeleteConfig: (configId) {
            ref.read(wolProvider.notifier).deleteConfig(configId);
          },
          isSelectionMode: _isSelectionMode,
          selectedIds: _selectedIds,
          onLongPress: _enterSelectionMode,
          onSelectionToggle: _toggleSelection,
          theme: theme,
        ),
        const SizedBox(height: VibeTermSpacing.lg),

        // Section Instructions
        SectionHeader(title: l10n.configRequired.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        _WolInstructionsCard(theme: theme),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    l10n.wolEnabled,
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
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final void Function(String) onLongPress;
  final void Function(String) onSelectionToggle;
  final VibeTermThemeData theme;

  const _WolConfigsCard({
    required this.configs,
    required this.isLoading,
    required this.onAddConfig,
    required this.onDeleteConfig,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onLongPress,
    required this.onSelectionToggle,
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
                    isSelectionMode: isSelectionMode,
                    isSelected: selectedIds.contains(config.id),
                    onLongPress: () => onLongPress(config.id),
                    onSelectionToggle: () => onSelectionToggle(config.id),
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
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(VibeTermSpacing.lg),
      child: Text(
        l10n.noWolConfig,
        style: VibeTermTypography.itemDescription.copyWith(
          color: theme.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Item affichant une configuration WOL avec swipe pour supprimer.
class _WolConfigItem extends StatelessWidget {
  final dynamic config;
  final VoidCallback onDelete;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onSelectionToggle;
  final VibeTermThemeData theme;

  const _WolConfigItem({
    required this.config,
    required this.onDelete,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onLongPress,
    required this.onSelectionToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);

    // En mode sélection, pas de swipe
    if (isSelectionMode) {
      return content;
    }

    return Dismissible(
      key: Key(config.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.danger,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: VibeTermSpacing.md),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _showDeleteConfirmation(context),
      onDismissed: (direction) => onDelete(),
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    return InkWell(
      onTap: isSelectionMode ? onSelectionToggle : null,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.md,
          vertical: VibeTermSpacing.sm,
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onSelectionToggle(),
                activeColor: theme.accent,
                side: BorderSide(color: theme.textMuted),
              )
            else
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
          ],
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(
          l10n.delete,
          style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
        ),
        content: Text(
          '${config.name}',
          style: VibeTermTypography.itemDescription.copyWith(
            color: theme.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: theme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.delete,
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
    final l10n = context.l10n;
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
            Flexible(
              child: Text(
                l10n.addWolConfig,
                style: VibeTermTypography.itemTitle.copyWith(
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

/// Carte avec les instructions de configuration WoL.
class _WolInstructionsCard extends StatefulWidget {
  final VibeTermThemeData theme;

  const _WolInstructionsCard({required this.theme});

  @override
  State<_WolInstructionsCard> createState() => _WolInstructionsCardState();
}

class _WolInstructionsCardState extends State<_WolInstructionsCard> {
  bool _windowsExpanded = false;
  bool _macExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = widget.theme;

    return Container(
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
            // Description
            Text(
              l10n.wolDescription,
              style: VibeTermTypography.itemDescription.copyWith(
                color: theme.textMuted,
              ),
            ),
            const SizedBox(height: VibeTermSpacing.md),

            // Infos Allumer/Éteindre
            Row(
              children: [
                Icon(Icons.bolt, color: theme.warning, size: 16),
                const SizedBox(width: VibeTermSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.turnOnCableRequired,
                    style: VibeTermTypography.caption.copyWith(color: theme.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VibeTermSpacing.xs),
            Row(
              children: [
                Icon(Icons.power_settings_new, color: theme.accent, size: 16),
                const SizedBox(width: VibeTermSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.turnOffWifiOrCable,
                    style: VibeTermTypography.caption.copyWith(color: theme.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VibeTermSpacing.md),

            // Card Windows
            _buildExpandableCard(
              title: 'Windows',
              icon: Icons.window,
              isExpanded: _windowsExpanded,
              onTap: () => setState(() => _windowsExpanded = !_windowsExpanded),
              content: _buildWindowsInstructions(theme),
              theme: theme,
            ),
            const SizedBox(height: VibeTermSpacing.sm),

            // Card Mac
            _buildExpandableCard(
              title: 'Mac',
              icon: Icons.apple,
              isExpanded: _macExpanded,
              onTap: () => setState(() => _macExpanded = !_macExpanded),
              content: _buildMacInstructions(theme),
              theme: theme,
            ),
            const SizedBox(height: VibeTermSpacing.md),

            // Lien vers guide complet
            GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'https://chillshell.app/wol'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.linkCopied,
                      style: TextStyle(color: theme.text),
                    ),
                    backgroundColor: theme.bgElevated,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: theme.accent, size: 16),
                  const SizedBox(width: VibeTermSpacing.xs),
                  Flexible(
                    child: Text(
                      '${l10n.fullGuide} : chillshell.app/wol',
                      style: VibeTermTypography.caption.copyWith(
                        color: theme.accent,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
    required VibeTermThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(VibeTermSpacing.sm),
              child: Row(
                children: [
                  Icon(icon, color: theme.accent, size: 18),
                  const SizedBox(width: VibeTermSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: VibeTermTypography.itemTitle.copyWith(
                        color: theme.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(
                left: VibeTermSpacing.md,
                right: VibeTermSpacing.md,
                bottom: VibeTermSpacing.md,
              ),
              child: content,
            ),
        ],
      ),
    );
  }

  Widget _buildWindowsInstructions(VibeTermThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep('1. BIOS', [
          '• Activer "Power On By PCI-E"',
          '• Désactiver "ErP Ready"',
        ], theme),
        const SizedBox(height: VibeTermSpacing.sm),
        _buildStep('2. Démarrage rapide', [
          '• Options d\'alimentation → Paramètre système',
          '• Modifier les paramètres non disponibles',
          '• Décocher "Activer le démarrage rapide"',
        ], theme),
        const SizedBox(height: VibeTermSpacing.sm),
        _buildStep('3. Gestionnaire de périphériques', [
          '• Carte réseau → Gestion alimentation',
          '• Cocher "Paquet magique uniquement"',
          '• Carte réseau → Avancé',
          '• Activer "Wake on Magic Packet"',
        ], theme),
      ],
    );
  }

  Widget _buildMacInstructions(VibeTermThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep('Configuration', [
          '1. Menu Apple → Préférences Système',
          '2. Économiseur d\'énergie',
          '3. Cocher "Réactiver pour l\'accès au réseau"',
        ], theme),
      ],
    );
  }

  Widget _buildStep(String title, List<String> items, VibeTermThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: VibeTermTypography.caption.copyWith(
            color: theme.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: VibeTermSpacing.xs),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: VibeTermSpacing.sm),
          child: Text(
            item,
            style: VibeTermTypography.caption.copyWith(
              color: theme.textMuted,
              fontSize: 11,
            ),
          ),
        )),
      ],
    );
  }
}
