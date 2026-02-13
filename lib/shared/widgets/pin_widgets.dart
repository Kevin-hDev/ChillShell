import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';

/// Cercles indicateurs de PIN (nombre configurable)
class PinDots extends StatelessWidget {
  final int length;
  final int total;
  final VibeTermThemeData theme;
  final double dotSize;
  final double spacing;

  const PinDots({
    super.key,
    required this.length,
    this.total = 8,
    required this.theme,
    this.dotSize = 16,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isFilled = index < length;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: spacing),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? theme.accent : Colors.transparent,
            border: Border.all(
              color: isFilled ? theme.accent : theme.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

/// Clavier numerique pour saisie PIN
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VibeTermThemeData theme;
  final double keyWidth;
  final double keyHeight;
  final double fontSize;
  final double iconSize;
  final BorderRadius? keyBorderRadius;
  final Color? keyColor;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.theme,
    this.keyWidth = 72,
    this.keyHeight = 56,
    this.fontSize = 24,
    this.iconSize = 24,
    this.keyBorderRadius,
    this.keyColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = keyBorderRadius ?? BorderRadius.circular(VibeTermRadius.md);
    return Column(
      children: [
        _buildRow(['1', '2', '3'], radius),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6'], radius),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9'], radius),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: keyWidth, height: keyHeight),
            const SizedBox(width: 12),
            _buildKey('0', radius),
            const SizedBox(width: 12),
            SizedBox(
              width: keyWidth,
              height: keyHeight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                  child: Center(
                    child: Icon(
                      Icons.backspace_outlined,
                      color: theme.textMuted,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits, BorderRadius radius) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildKey(d, radius),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String digit, BorderRadius radius) {
    return SizedBox(
      width: keyWidth,
      height: keyHeight,
      child: Material(
        color: keyColor ?? theme.bgBlock,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            HapticFeedback.lightImpact();
            onDigit(digit);
          },
          child: Center(
            child: Text(
              digit,
              style: VibeTermTypography.appTitle.copyWith(
                color: theme.text,
                fontSize: fontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
