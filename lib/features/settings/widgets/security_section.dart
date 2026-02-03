import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../terminal/providers/terminal_provider.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Déverrouillage biométrique
        SectionHeader(title: l10n.biometricUnlock.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              _BiometricToggleRow(
                icon: Icons.face,
                label: l10n.faceId,
                value: settings.appSettings.faceIdEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleFaceId(value);
                },
                theme: theme,
              ),
              Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
              _BiometricToggleRow(
                icon: Icons.fingerprint,
                label: l10n.fingerprint,
                value: settings.appSettings.fingerprintEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleFingerprint(value);
                },
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.lg),
        // Section Verrouillage automatique
        SectionHeader(title: l10n.autoLock.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              _SecurityToggle(
                title: l10n.autoLock,
                subtitle: l10n.autoLockTime,
                value: settings.appSettings.autoLockEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleAutoLock(value);
                },
                theme: theme,
              ),
              if (settings.appSettings.autoLockEnabled) ...[
                Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
                Padding(
                  padding: const EdgeInsets.all(VibeTermSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.autoLockTime,
                        style: VibeTermTypography.itemDescription.copyWith(
                          color: theme.textMuted,
                        ),
                      ),
                      const SizedBox(height: VibeTermSpacing.sm),
                      _AutoLockTimeSelector(
                        selectedMinutes: settings.appSettings.autoLockMinutes,
                        onChanged: (minutes) {
                          ref.read(settingsProvider.notifier).setAutoLockMinutes(minutes);
                        },
                        theme: theme,
                        minutesLabel: l10n.minutes,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.lg),
        // Section Historique des commandes
        SectionHeader(title: l10n.clearHistory.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(VibeTermSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.clearHistory,
                            style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.clearHistoryConfirm,
                            style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: theme.bgBlock,
                            title: Text(
                              l10n.clearHistoryConfirm,
                              style: TextStyle(color: theme.text),
                            ),
                            content: Text(
                              l10n.clearHistoryConfirm,
                              style: TextStyle(color: theme.textMuted),
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
                        if (confirmed == true) {
                          await ref.read(terminalProvider.notifier).clearCommandHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.historyCleared),
                                backgroundColor: theme.success,
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: theme.danger.withValues(alpha: 0.1),
                        foregroundColor: theme.danger,
                      ),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne toggle pour Face ID / Empreinte
class _BiometricToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VibeTermThemeData theme;

  const _BiometricToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
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
          Icon(icon, color: theme.accent, size: 22),
          const SizedBox(width: VibeTermSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: theme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Toggle générique pour les paramètres de sécurité
class _SecurityToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VibeTermThemeData theme;

  const _SecurityToggle({
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
        activeThumbColor: theme.accent,
        onChanged: onChanged,
      ),
    );
  }
}

/// Sélecteur de temps pour le verrouillage automatique (5 / 10 / 15 / 30 min)
class _AutoLockTimeSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final VibeTermThemeData theme;
  final String minutesLabel;

  const _AutoLockTimeSelector({
    required this.selectedMinutes,
    required this.onChanged,
    required this.theme,
    required this.minutesLabel,
  });

  static const List<int> _options = [5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((minutes) {
        final isSelected = selectedMinutes == minutes;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: minutes != _options.last ? VibeTermSpacing.xs : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(minutes),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: VibeTermSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? theme.accent : theme.bg,
                  borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                  border: Border.all(
                    color: isSelected ? theme.accent : theme.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$minutes min',
                    style: VibeTermTypography.itemTitle.copyWith(
                      color: isSelected ? theme.bg : theme.text,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
