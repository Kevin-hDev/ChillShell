import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Styles de texte VibeTerm
class VibeTermTypography {
  // === Header ===
  static TextStyle get appTitle => GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: VibeTermColors.text,
  );

  // === Terminal ===
  static TextStyle get command => GoogleFonts.jetBrainsMono(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get commandHeader => GoogleFonts.jetBrainsMono(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get prompt => GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.accent,
  );

  static TextStyle get terminalOutput => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    color: VibeTermColors.textOutput,
    height: 1.5,
  );

  // === Input ===
  static TextStyle get input =>
      GoogleFonts.jetBrainsMono(fontSize: 17, color: VibeTermColors.text);

  static TextStyle get caption =>
      GoogleFonts.jetBrainsMono(fontSize: 14, color: VibeTermColors.textMuted);

  // === Settings ===
  static TextStyle get settingsTitle => GoogleFonts.jetBrainsMono(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: VibeTermColors.text,
  );

  static TextStyle get sectionLabel => GoogleFonts.jetBrainsMono(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get itemTitle => GoogleFonts.jetBrainsMono(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get itemDescription =>
      GoogleFonts.jetBrainsMono(fontSize: 13, color: VibeTermColors.textMuted);

  // === Tabs ===
  static TextStyle get tabText => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );
}
