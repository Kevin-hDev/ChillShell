import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'SÉCURITÉ'),
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
                title: 'Déverrouillage biométrique',
                subtitle: 'Face ID / Empreinte digitale',
                value: settings.appSettings.biometricEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleBiometric(value);
                },
                theme: theme,
              ),
              Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
              _SecurityToggle(
                title: 'Verrouillage automatique',
                subtitle: 'Après 10 minutes d\'inactivité',
                value: settings.appSettings.autoLockEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleAutoLock(value);
                },
                theme: theme,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
