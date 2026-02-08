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

/// Traduit un code d'erreur SSH (stocké dans le provider) en message localisé.
/// Les codes suivent le format `ssh:<errorType>` ou `ssh:reconnecting:current/max`.
String translateSshError(AppLocalizations l10n, String? errorCode) {
  if (errorCode == null) return l10n.connectionError;

  // Codes SSH provider
  if (errorCode.startsWith('ssh:reconnecting:')) {
    final parts = errorCode.substring('ssh:reconnecting:'.length).split('/');
    if (parts.length == 2) {
      return l10n.reconnectingAttempt(parts[0], parts[1]);
    }
    return l10n.reconnecting;
  }

  switch (errorCode) {
    case 'ssh:connectionFailed':
      return l10n.sshConnectionFailed;
    case 'ssh:authenticationFailed':
      return l10n.sshAuthFailed;
    case 'ssh:keyNotFound':
      return l10n.sshKeyNotConfigured;
    case 'ssh:timeout':
      return l10n.sshTimeout;
    case 'ssh:hostUnreachable':
      return l10n.sshHostUnreachable;
    case 'ssh:connectionLost':
      return l10n.connectionLost;
    case 'ssh:privateKeyNotFound':
      return l10n.privateKeyNotFound;
    case 'ssh:localShellError':
      return l10n.localShellError;
    default:
      return l10n.unexpectedError;
  }
}
