import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Données de thème VibeTerm
class VibeTermThemeData {
  final Color bg;
  final Color bgBlock;
  final Color bgElevated;
  final Color border;
  final Color borderLight;
  final Color text;
  final Color textOutput;
  final Color textMuted;
  final Color ghost;
  final Color accent;
  final Color accentDim;
  final Color success;
  final Color danger;
  final Color warning;
  final Color scrollThumb;

  const VibeTermThemeData({
    required this.bg,
    required this.bgBlock,
    required this.bgElevated,
    required this.border,
    required this.borderLight,
    required this.text,
    required this.textOutput,
    required this.textMuted,
    required this.ghost,
    required this.accent,
    required this.accentDim,
    required this.success,
    required this.danger,
    required this.warning,
    required this.scrollThumb,
  });

  /// Thème Warp Dark (par défaut)
  static const warpDark = VibeTermThemeData(
    bg: Color(0xFF0F0F0F),
    bgBlock: Color(0xFF1A1A1A),
    bgElevated: Color(0xFF222222),
    border: Color(0xFF333333),
    borderLight: Color(0xFF2A2A2A),
    text: Color(0xFFFFFFFF),
    textOutput: Color(0xFFCCCCCC),
    textMuted: Color(0xFF888888),
    ghost: Color(0xFF555555),
    accent: Color(0xFF10B981),
    accentDim: Color(0xFF065F46),
    success: Color(0xFF10B981),
    danger: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    scrollThumb: Color(0xFF444444),
  );

  /// Thème Dracula
  static const dracula = VibeTermThemeData(
    bg: Color(0xFF282A36),
    bgBlock: Color(0xFF343746),
    bgElevated: Color(0xFF3E4155),
    border: Color(0xFF44475A),
    borderLight: Color(0xFF3A3D4E),
    text: Color(0xFFF8F8F2),
    textOutput: Color(0xFFE0E0E0),
    textMuted: Color(0xFF6272A4),
    ghost: Color(0xFF4A5568),
    accent: Color(0xFFBD93F9),
    accentDim: Color(0xFF6D5AAE),
    success: Color(0xFF50FA7B),
    danger: Color(0xFFFF5555),
    warning: Color(0xFFFFB86C),
    scrollThumb: Color(0xFF555770),
  );

  /// Thème Nord
  static const nord = VibeTermThemeData(
    bg: Color(0xFF2E3440),
    bgBlock: Color(0xFF3B4252),
    bgElevated: Color(0xFF434C5E),
    border: Color(0xFF4C566A),
    borderLight: Color(0xFF434C5E),
    text: Color(0xFFECEFF4),
    textOutput: Color(0xFFD8DEE9),
    textMuted: Color(0xFF7B88A1),
    ghost: Color(0xFF5E6779),
    accent: Color(0xFF88C0D0),
    accentDim: Color(0xFF5E81AC),
    success: Color(0xFFA3BE8C),
    danger: Color(0xFFBF616A),
    warning: Color(0xFFEBCB8B),
    scrollThumb: Color(0xFF5E6779),
  );

  /// Thème Gruvbox Dark
  static const gruvbox = VibeTermThemeData(
    bg: Color(0xFF282828),
    bgBlock: Color(0xFF3C3836),
    bgElevated: Color(0xFF504945),
    border: Color(0xFF665C54),
    borderLight: Color(0xFF504945),
    text: Color(0xFFEBDBB2),
    textOutput: Color(0xFFD5C4A1),
    textMuted: Color(0xFFA89984),
    ghost: Color(0xFF7C6F64),
    accent: Color(0xFFFE8019),
    accentDim: Color(0xFFD65D0E),
    success: Color(0xFFB8BB26),
    danger: Color(0xFFFB4934),
    warning: Color(0xFFFABD2F),
    scrollThumb: Color(0xFF7C6F64),
  );

  /// Thème Afterglow
  static const afterglow = VibeTermThemeData(
    bg: Color(0xFF2C2C2C),
    bgBlock: Color(0xFF393939),
    bgElevated: Color(0xFF464646),
    border: Color(0xFF555555),
    borderLight: Color(0xFF464646),
    text: Color(0xFFD6D6D6),
    textOutput: Color(0xFFC0C0C0),
    textMuted: Color(0xFF797979),
    ghost: Color(0xFF5A5A5A),
    accent: Color(0xFFAC4142),
    accentDim: Color(0xFF8A3435),
    success: Color(0xFF90A959),
    danger: Color(0xFFAC4142),
    warning: Color(0xFFF4BF75),
    scrollThumb: Color(0xFF5A5A5A),
  );

  /// Thème Hybrid
  static const hybrid = VibeTermThemeData(
    bg: Color(0xFF1D1F21),
    bgBlock: Color(0xFF282A2E),
    bgElevated: Color(0xFF373B41),
    border: Color(0xFF4A4E54),
    borderLight: Color(0xFF373B41),
    text: Color(0xFFC5C8C6),
    textOutput: Color(0xFFB4B7B4),
    textMuted: Color(0xFF707880),
    ghost: Color(0xFF555960),
    accent: Color(0xFF81A2BE),
    accentDim: Color(0xFF5F7A8A),
    success: Color(0xFFB5BD68),
    danger: Color(0xFFCC6666),
    warning: Color(0xFFF0C674),
    scrollThumb: Color(0xFF555960),
  );

  /// Thème Atelier Savanna
  static const atelierSavanna = VibeTermThemeData(
    bg: Color(0xFF171C19),
    bgBlock: Color(0xFF232A25),
    bgElevated: Color(0xFF2C3631),
    border: Color(0xFF5F6D64),
    borderLight: Color(0xFF2C3631),
    text: Color(0xFFECF4EE),
    textOutput: Color(0xFFDFE7E2),
    textMuted: Color(0xFF78877D),
    ghost: Color(0xFF526057),
    accent: Color(0xFF55859B),
    accentDim: Color(0xFF406A7C),
    success: Color(0xFF489963),
    danger: Color(0xFFB16139),
    warning: Color(0xFFA07E3B),
    scrollThumb: Color(0xFF526057),
  );

  /// Thème Base2Tone Desert
  static const base2ToneDesert = VibeTermThemeData(
    bg: Color(0xFF292321),
    bgBlock: Color(0xFF3D3532),
    bgElevated: Color(0xFF4A4240),
    border: Color(0xFF6B5F5A),
    borderLight: Color(0xFF4A4240),
    text: Color(0xFFF5EDEB),
    textOutput: Color(0xFFE8DFDD),
    textMuted: Color(0xFFA08F89),
    ghost: Color(0xFF7A6B65),
    accent: Color(0xFFD9A96C),
    accentDim: Color(0xFFB8894F),
    success: Color(0xFFC4A265),
    danger: Color(0xFFD47766),
    warning: Color(0xFFD9A96C),
    scrollThumb: Color(0xFF7A6B65),
  );

  /// Thème Base2Tone Sea
  static const base2ToneSea = VibeTermThemeData(
    bg: Color(0xFF1D262F),
    bgBlock: Color(0xFF2A3744),
    bgElevated: Color(0xFF354659),
    border: Color(0xFF4A6078),
    borderLight: Color(0xFF354659),
    text: Color(0xFFEBF4FF),
    textOutput: Color(0xFFD9E8F7),
    textMuted: Color(0xFF7A92A9),
    ghost: Color(0xFF5A7189),
    accent: Color(0xFF47A8BD),
    accentDim: Color(0xFF358999),
    success: Color(0xFF5EB3A1),
    danger: Color(0xFFE57983),
    warning: Color(0xFFDCA060),
    scrollThumb: Color(0xFF5A7189),
  );

  /// Thème Belafonte Day (CLAIR)
  static const belafonteDay = VibeTermThemeData(
    bg: Color(0xFFF5EDDC),
    bgBlock: Color(0xFFE8E0CF),
    bgElevated: Color(0xFFDDD5C4),
    border: Color(0xFFB8B09F),
    borderLight: Color(0xFFDDD5C4),
    text: Color(0xFF45373C),
    textOutput: Color(0xFF5A4C51),
    textMuted: Color(0xFF8A7B70),
    ghost: Color(0xFFB0A090),
    accent: Color(0xFF5A7B62),
    accentDim: Color(0xFF486350),
    success: Color(0xFF5A7B62),
    danger: Color(0xFFBE100E),
    warning: Color(0xFFA17C38),
    scrollThumb: Color(0xFFB0A090),
  );

  /// Thème Lunaria Light (CLAIR)
  static const lunariaLight = VibeTermThemeData(
    bg: Color(0xFFF8F5F1),
    bgBlock: Color(0xFFEBE8E4),
    bgElevated: Color(0xFFE0DDD9),
    border: Color(0xFFD0CCC6),
    borderLight: Color(0xFFE0DDD9),
    text: Color(0xFF3D3A36),
    textOutput: Color(0xFF4D4A46),
    textMuted: Color(0xFF8A8680),
    ghost: Color(0xFFB5B0A8),
    accent: Color(0xFF6B8E7B),
    accentDim: Color(0xFF567260),
    success: Color(0xFF6B8E7B),
    danger: Color(0xFFBF616A),
    warning: Color(0xFFCDA052),
    scrollThumb: Color(0xFFB5B0A8),
  );

  /// Thème Lunaria Dark
  static const lunariaDark = VibeTermThemeData(
    bg: Color(0xFF21201E),
    bgBlock: Color(0xFF2D2C29),
    bgElevated: Color(0xFF3A3835),
    border: Color(0xFF504D48),
    borderLight: Color(0xFF3A3835),
    text: Color(0xFFE8E4DF),
    textOutput: Color(0xFFD5D1CC),
    textMuted: Color(0xFF8A8680),
    ghost: Color(0xFF5F5C57),
    accent: Color(0xFF8FB391),
    accentDim: Color(0xFF6E9070),
    success: Color(0xFF8FB391),
    danger: Color(0xFFD08785),
    warning: Color(0xFFDEB974),
    scrollThumb: Color(0xFF5F5C57),
  );

  /// Obtient le thème à partir de l'enum
  static VibeTermThemeData fromAppTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.warpDark:
        return warpDark;
      case AppTheme.dracula:
        return dracula;
      case AppTheme.nord:
        return nord;
      case AppTheme.gruvbox:
        return gruvbox;
      case AppTheme.hybrid:
        return hybrid;
      case AppTheme.afterglow:
        return afterglow;
      case AppTheme.atelierSavanna:
        return atelierSavanna;
      case AppTheme.base2ToneDesert:
        return base2ToneDesert;
      case AppTheme.base2ToneSea:
        return base2ToneSea;
      case AppTheme.belafonteDay:
        return belafonteDay;
      case AppTheme.lunariaLight:
        return lunariaLight;
      case AppTheme.lunariaDark:
        return lunariaDark;
    }
  }
}

/// Provider qui retourne le thème actuel basé sur les settings
final vibeTermThemeProvider = Provider<VibeTermThemeData>((ref) {
  final settings = ref.watch(settingsProvider);
  return VibeTermThemeData.fromAppTheme(settings.appSettings.theme);
});
