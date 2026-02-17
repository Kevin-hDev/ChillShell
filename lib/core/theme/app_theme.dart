import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// ThemeData principal pour VibeTerm
class VibeTermTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Couleurs
    scaffoldBackgroundColor: VibeTermColors.bg,
    colorScheme: const ColorScheme.dark(
      surface: VibeTermColors.bg,
      primary: VibeTermColors.accent,
      secondary: VibeTermColors.accent,
      error: VibeTermColors.danger,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: VibeTermColors.bg,
      elevation: 0,
      titleTextStyle: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: VibeTermColors.text,
      ),
    ),

    // Texte
    textTheme: TextTheme(
      bodyLarge: GoogleFonts.jetBrainsMono(color: VibeTermColors.text),
      bodyMedium: GoogleFonts.jetBrainsMono(color: VibeTermColors.textOutput),
      bodySmall: GoogleFonts.jetBrainsMono(color: VibeTermColors.textMuted),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VibeTermColors.bgBlock,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: VibeTermColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: VibeTermColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: VibeTermColors.accent),
      ),
      hintStyle: GoogleFonts.jetBrainsMono(color: VibeTermColors.textMuted),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: VibeTermColors.border,
      thickness: 1,
    ),

    // Scrollbar
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(VibeTermColors.scrollThumb),
      radius: const Radius.circular(4),
    ),
  );
}
