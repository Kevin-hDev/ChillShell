import 'package:flutter/material.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/theme_provider.dart';

/// Carte réutilisable pour les sections de paramètres.
/// Remplace le pattern Container + BoxDecoration répété partout.
class SettingsCard extends StatelessWidget {
  final Widget child;
  final VibeTermThemeData theme;
  final EdgeInsetsGeometry? padding;

  const SettingsCard({
    super.key,
    required this.child,
    required this.theme,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(VibeTermSpacing.md),
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: child,
    );
  }
}
