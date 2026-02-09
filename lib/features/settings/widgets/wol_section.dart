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
import 'selection_mixin.dart';

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

class _WolSectionState extends ConsumerState<WolSection>
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
          l10n.deleteWolConfigsConfirm(count),
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
        await ref.read(wolProvider.notifier).deleteConfig(id);
      }
      exitSelectionMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wolEnabled = ref.watch(settingsProvider.select((s) => s.appSettings.wolEnabled));
    final wolState = ref.watch(wolProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    final hasConfigs = wolState.configs.isNotEmpty;

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
          trailing: isSelectionMode
              ? buildSelectionActions(theme: theme, onDelete: _deleteSelected)
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
          onRenameConfig: (configId, newName) {
            final config = wolState.configs.firstWhere((c) => c.id == configId);
            ref.read(wolProvider.notifier).updateConfig(config.copyWith(name: newName));
          },
          isSelectionMode: isSelectionMode,
          selectedIds: selectedIds,
          onLongPress: enterSelectionMode,
          onSelectionToggle: toggleSelection,
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
  final void Function(String, String) onRenameConfig;
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
    required this.onRenameConfig,
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
                    onRename: (newName) => onRenameConfig(config.id, newName),
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
  final void Function(String) onRename;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onSelectionToggle;
  final VibeTermThemeData theme;

  const _WolConfigItem({
    required this.config,
    required this.onDelete,
    required this.onRename,
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
      onTap: isSelectionMode ? onSelectionToggle : () => _showRenameDialog(context),
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

  void _showRenameDialog(BuildContext context) {
    final l10n = context.l10n;
    final controller = TextEditingController(text: config.name);

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
                onRename(newName);
                Navigator.pop(dialogContext);
              }
            },
            child: Text(l10n.save, style: TextStyle(color: theme.accent)),
          ),
        ],
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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(l10n.wolBiosTitle, [
          '• ${l10n.wolBiosEnablePcie}',
          '• ${l10n.wolBiosDisableErp}',
        ], theme),
        const SizedBox(height: VibeTermSpacing.sm),
        _buildStep(l10n.wolFastStartupTitle, [
          '• ${l10n.wolFastStep1}',
          '• ${l10n.wolFastStep2}',
          '• ${l10n.wolFastStep3}',
        ], theme),
        const SizedBox(height: VibeTermSpacing.sm),
        _buildStep(l10n.wolDeviceManagerTitle, [
          '• ${l10n.wolDevStep1}',
          '• ${l10n.wolDevStep2}',
          '• ${l10n.wolDevStep3}',
          '• ${l10n.wolDevStep4}',
        ], theme),
      ],
    );
  }

  Widget _buildMacInstructions(VibeTermThemeData theme) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStep(l10n.wolMacConfigTitle, [
          l10n.wolMacStep1,
          l10n.wolMacStep2,
          l10n.wolMacStep3,
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
