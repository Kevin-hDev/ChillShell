import 'package:flutter/material.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/theme_provider.dart';

/// TextField stylisé avec le thème VibeTerm.
class ThemedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final VibeTermThemeData theme;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const ThemedTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.theme,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
        ),
        const SizedBox(height: VibeTermSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          style: VibeTermTypography.input.copyWith(color: theme.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: VibeTermTypography.input.copyWith(color: theme.textMuted),
            filled: true,
            fillColor: theme.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              borderSide: BorderSide(color: theme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              borderSide: BorderSide(color: theme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              borderSide: BorderSide(color: theme.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: VibeTermSpacing.md,
              vertical: VibeTermSpacing.sm,
            ),
          ),
        ),
      ],
    );
  }
}
