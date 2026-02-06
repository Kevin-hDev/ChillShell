import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/models.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

/// Données d'affichage pour un thème
class ThemeDisplayData {
  final AppTheme theme;
  final String name;
  final Color bgColor;
  final Color accentColor;

  const ThemeDisplayData({
    required this.theme,
    required this.name,
    required this.bgColor,
    required this.accentColor,
  });
}

/// Liste des thèmes disponibles avec leurs métadonnées
const List<ThemeDisplayData> availableThemes = [
  // Thèmes sombres
  ThemeDisplayData(
    theme: AppTheme.warpDark,
    name: 'Warp Dark',
    bgColor: Color(0xFF0F0F0F),
    accentColor: Color(0xFF10B981),
  ),
  ThemeDisplayData(
    theme: AppTheme.dracula,
    name: 'Dracula',
    bgColor: Color(0xFF282A36),
    accentColor: Color(0xFFBD93F9),
  ),
  ThemeDisplayData(
    theme: AppTheme.nord,
    name: 'Nord',
    bgColor: Color(0xFF2E3440),
    accentColor: Color(0xFF88C0D0),
  ),
  ThemeDisplayData(
    theme: AppTheme.gruvbox,
    name: 'Gruvbox',
    bgColor: Color(0xFF282828),
    accentColor: Color(0xFFFE8019),
  ),
  ThemeDisplayData(
    theme: AppTheme.hybrid,
    name: 'Hybrid',
    bgColor: Color(0xFF1D1F21),
    accentColor: Color(0xFF81A2BE),
  ),
  ThemeDisplayData(
    theme: AppTheme.afterglow,
    name: 'Afterglow',
    bgColor: Color(0xFF2C2C2C),
    accentColor: Color(0xFFAC4142),
  ),
  ThemeDisplayData(
    theme: AppTheme.atelierSavanna,
    name: 'Atelier Savanna',
    bgColor: Color(0xFF171C19),
    accentColor: Color(0xFF55859B),
  ),
  ThemeDisplayData(
    theme: AppTheme.base2ToneDesert,
    name: 'Desert',
    bgColor: Color(0xFF292321),
    accentColor: Color(0xFFD9A96C),
  ),
  ThemeDisplayData(
    theme: AppTheme.base2ToneSea,
    name: 'Sea',
    bgColor: Color(0xFF1D262F),
    accentColor: Color(0xFF47A8BD),
  ),
  ThemeDisplayData(
    theme: AppTheme.lunariaDark,
    name: 'Lunaria Dark',
    bgColor: Color(0xFF21201E),
    accentColor: Color(0xFF8FB391),
  ),
  // Thèmes clairs
  ThemeDisplayData(
    theme: AppTheme.belafonteDay,
    name: 'Belafonte Day',
    bgColor: Color(0xFFF5EDDC),
    accentColor: Color(0xFF5A7B62),
  ),
  ThemeDisplayData(
    theme: AppTheme.lunariaLight,
    name: 'Lunaria Light',
    bgColor: Color(0xFFF8F5F1),
    accentColor: Color(0xFF6B8E7B),
  ),
];

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentTheme = ref.watch(settingsProvider.select((s) => s.appSettings.theme));
    final currentLanguage = ref.watch(settingsProvider.select((s) => s.appSettings.languageCode));
    final currentFontSize = ref.watch(settingsProvider.select((s) => s.appSettings.terminalFontSize));
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l10n.general.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          padding: const EdgeInsets.fromLTRB(
            VibeTermSpacing.md, VibeTermSpacing.sm,
            VibeTermSpacing.md, VibeTermSpacing.md,
          ),
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Thème
              Text(
                l10n.theme,
                style: VibeTermTypography.sectionLabel.copyWith(color: theme.text),
              ),
              const SizedBox(height: VibeTermSpacing.xs),
              // Grille de thèmes
              GridView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: VibeTermSpacing.sm,
                  mainAxisSpacing: VibeTermSpacing.sm,
                ),
                itemCount: availableThemes.length,
                itemBuilder: (context, index) {
                  final themeData = availableThemes[index];
                  final isSelected = currentTheme == themeData.theme;
                  return _ThemeCard(
                    data: themeData,
                    isSelected: isSelected,
                    currentTheme: theme,
                    onTap: () => ref.read(settingsProvider.notifier).updateTheme(themeData.theme),
                  );
                },
              ),
              const SizedBox(height: VibeTermSpacing.lg),
              Divider(color: theme.border),
              const SizedBox(height: VibeTermSpacing.lg),
              // Section Langue
              _LanguageSelector(
                theme: theme,
                currentLanguage: currentLanguage,
                onChanged: (code) => ref.read(settingsProvider.notifier).setLanguage(code),
              ),
              const SizedBox(height: VibeTermSpacing.lg),
              Divider(color: theme.border),
              const SizedBox(height: VibeTermSpacing.lg),
              // Section Taille de police
              _FontSizeSelector(
                theme: theme,
                currentSize: currentFontSize,
                onChanged: (size) => ref.read(settingsProvider.notifier).setFontSize(size),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sélecteur de langue
class _LanguageSelector extends StatelessWidget {
  final VibeTermThemeData theme;
  final String? currentLanguage;
  final ValueChanged<String?> onChanged;

  const _LanguageSelector({
    required this.theme,
    required this.currentLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.language,
          style: VibeTermTypography.sectionLabel.copyWith(color: theme.text),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.md),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            border: Border.all(color: theme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: currentLanguage,
              isExpanded: true,
              dropdownColor: theme.bgBlock,
              style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
              icon: Icon(Icons.expand_more, color: theme.textMuted),
              items: [
                // Option auto-détection
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    l10n.autoDetect,
                    style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                  ),
                ),
                // Langues disponibles
                ...supportedLanguages.entries.map((entry) {
                  return DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                    ),
                  );
                }),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sélecteur de taille de police
class _FontSizeSelector extends StatelessWidget {
  final VibeTermThemeData theme;
  final TerminalFontSize currentSize;
  final ValueChanged<TerminalFontSize> onChanged;

  const _FontSizeSelector({
    required this.theme,
    required this.currentSize,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    // Labels localisés pour les tailles
    final sizeLabels = {
      TerminalFontSize.xs: l10n.fontSizeXS,
      TerminalFontSize.s: l10n.fontSizeS,
      TerminalFontSize.m: l10n.fontSizeM,
      TerminalFontSize.l: l10n.fontSizeL,
      TerminalFontSize.xl: l10n.fontSizeXL,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fontSize,
          style: VibeTermTypography.sectionLabel.copyWith(color: theme.text),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.md),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            border: Border.all(color: theme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TerminalFontSize>(
              value: currentSize,
              isExpanded: true,
              dropdownColor: theme.bgBlock,
              style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
              icon: Icon(Icons.expand_more, color: theme.textMuted),
              items: TerminalFontSize.values.map((size) {
                return DropdownMenuItem<TerminalFontSize>(
                  value: size,
                  child: Text(
                    sizeLabels[size] ?? size.label,
                    style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                  ),
                );
              }).toList(),
              onChanged: (size) {
                if (size != null) onChanged(size);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemeDisplayData data;
  final bool isSelected;
  final VibeTermThemeData currentTheme;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.data,
    required this.isSelected,
    required this.currentTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: data.bgColor,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(
            color: isSelected ? data.accentColor : currentTheme.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: data.accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview du terminal
            Container(
              width: 50,
              height: 35,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: data.accentColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 3,
                    decoration: BoxDecoration(
                      color: data.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 38,
                    height: 2,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 25,
                    height: 2,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
            // Nom du thème
            Text(
              data.name,
              style: VibeTermTypography.caption.copyWith(
                color: isSelected ? data.accentColor : currentTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Indicateur de sélection
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.check_circle,
                  color: data.accentColor,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
