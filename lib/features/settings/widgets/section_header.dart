import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: VibeTermTypography.sectionLabel),
        if (trailing != null) trailing!,
      ],
    );
  }
}
