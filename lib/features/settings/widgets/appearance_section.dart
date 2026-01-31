import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
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
    final settings = ref.watch(settingsProvider);
    final currentTheme = settings.appSettings.theme;
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'APPARENCE'),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          padding: const EdgeInsets.all(VibeTermSpacing.md),
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thème',
                style: VibeTermTypography.sectionLabel.copyWith(color: theme.text),
              ),
              const SizedBox(height: VibeTermSpacing.md),
              // Grille de thèmes
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.85,
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
            ],
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
