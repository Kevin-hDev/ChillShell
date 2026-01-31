import 'package:flutter/material.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/theme_provider.dart';

/// Affiche un dialog de confirmation réutilisable.
/// Retourne `true` si confirmé, `false` ou `null` si annulé.
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required VibeTermThemeData theme,
  required String title,
  required String content,
  String confirmText = 'Confirmer',
  String cancelText = 'Annuler',
  Color? confirmColor,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.bgBlock,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.border),
      ),
      title: Text(
        title,
        style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
      ),
      content: Text(
        content,
        style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: TextStyle(color: theme.textMuted),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmText,
            style: TextStyle(color: confirmColor ?? theme.danger),
          ),
        ),
      ],
    ),
  );
}
