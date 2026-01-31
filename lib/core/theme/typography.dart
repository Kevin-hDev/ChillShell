import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Styles de texte VibeTerm
class VibeTermTypography {
  // Police de base
  static String get fontFamily => GoogleFonts.jetBrainsMono().fontFamily!;
  
  // === Header ===
  static TextStyle get appTitle => GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: VibeTermColors.text,
  );

  static TextStyle get headerSubtitle => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: VibeTermColors.accent,
  );
  
  // === Onglets ===
  static TextStyle get tabActive => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    color: VibeTermColors.text,
  );

  static TextStyle get tabInactive => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    color: VibeTermColors.textMuted,
  );

  // === Terminal ===
  static TextStyle get command => GoogleFonts.jetBrainsMono(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get output => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    color: VibeTermColors.textOutput,
    height: 1.5,
  );

  static TextStyle get executionTime => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: const Color(0xFF666666),
  );

  static TextStyle get prompt => GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.accent,
  );

  // === Input ===
  static TextStyle get input => GoogleFonts.jetBrainsMono(
    fontSize: 17,
    color: VibeTermColors.text,
  );

  static TextStyle get placeholder => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    color: VibeTermColors.textMuted,
  );

  static TextStyle get ghostText => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    color: VibeTermColors.ghost,
  );
  
  // === Settings ===
  static TextStyle get settingsTitle => GoogleFonts.jetBrainsMono(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: VibeTermColors.text,
  );
  
  static TextStyle get settingsSubtitle => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: VibeTermColors.textMuted,
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

  static TextStyle get itemDescription => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: VibeTermColors.textMuted,
  );
  
  static TextStyle get badge => GoogleFonts.jetBrainsMono(
    fontSize: 10,
    color: VibeTermColors.accent,
  );
  
  static TextStyle get toggleLabel => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    color: VibeTermColors.textOutput,
  );
  
  // === Info bar ===
  static TextStyle get infoBar => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    color: VibeTermColors.textMuted,
  );

  static TextStyle get infoBarHighlight => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    color: VibeTermColors.text,
  );

  // === Additional styles for widgets ===
  static TextStyle get tabText => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get caption => GoogleFonts.jetBrainsMono(
    fontSize: 14,
    color: VibeTermColors.textMuted,
  );

  static TextStyle get commandHeader => GoogleFonts.jetBrainsMono(
    fontSize: 17,
    fontWeight: FontWeight.w500,
    color: VibeTermColors.text,
  );

  static TextStyle get terminalOutput => GoogleFonts.jetBrainsMono(
    fontSize: 16,
    color: VibeTermColors.textOutput,
    height: 1.5,
  );
}
