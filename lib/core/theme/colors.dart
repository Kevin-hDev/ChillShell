import 'package:flutter/material.dart';

/// Palette de couleurs VibeTerm - Thème Warp Dark
class VibeTermColors {
  // Backgrounds
  static const Color bg = Color(0xFF0F0F0F);           // Fond principal
  static const Color bgBlock = Color(0xFF1A1A1A);      // Blocs, cartes
  static const Color bgElevated = Color(0xFF222222);   // Éléments surélevés
  
  // Borders
  static const Color border = Color(0xFF333333);       // Bordures principales
  static const Color borderLight = Color(0xFF2A2A2A);  // Séparateurs internes
  
  // Text
  static const Color text = Color(0xFFFFFFFF);         // Texte principal
  static const Color textOutput = Color(0xFFCCCCCC);   // Output terminal
  static const Color textMuted = Color(0xFF888888);    // Texte secondaire
  static const Color ghost = Color(0xFF555555);        // Ghost text
  
  // Accent
  static const Color accent = Color(0xFF10B981);       // Vert principal
  static const Color accentDim = Color(0xFF065F46);    // Vert sombre
  
  // Status
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Spécifiques
  static const Color scrollThumb = Color(0xFF444444);
  static const Color homeIndicator = Color(0xFF444444);
}

/// Thèmes alternatifs
class DraculaColors {
  static const Color bg = Color(0xFF282A36);
  static const Color bgBlock = Color(0xFF343746);
  static const Color border = Color(0xFF44475A);
  static const Color text = Color(0xFFF8F8F2);
  static const Color accent = Color(0xFFBD93F9);
}

class NordColors {
  static const Color bg = Color(0xFF2E3440);
  static const Color bgBlock = Color(0xFF3B4252);
  static const Color border = Color(0xFF434C5E);
  static const Color text = Color(0xFFECEFF4);
  static const Color accent = Color(0xFF88C0D0);
}
