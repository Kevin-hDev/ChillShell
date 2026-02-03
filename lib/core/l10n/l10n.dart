import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

/// Extension pour accéder facilement aux traductions
/// Usage: context.l10n.settings
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// Liste des langues supportées avec leurs noms natifs
const supportedLanguages = <String, String>{
  'en': 'English',
  'fr': 'Français',
  'es': 'Español',
  'de': 'Deutsch',
  'zh': '中文',
};
