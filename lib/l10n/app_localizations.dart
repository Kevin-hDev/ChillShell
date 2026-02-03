import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'VibeTerm'**
  String get appName;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @wol.
  ///
  /// In en, this message translates to:
  /// **'WOL'**
  String get wol;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @fontSizeXS.
  ///
  /// In en, this message translates to:
  /// **'XS (12px)'**
  String get fontSizeXS;

  /// No description provided for @fontSizeS.
  ///
  /// In en, this message translates to:
  /// **'S (14px)'**
  String get fontSizeS;

  /// No description provided for @fontSizeM.
  ///
  /// In en, this message translates to:
  /// **'M (17px)'**
  String get fontSizeM;

  /// No description provided for @fontSizeL.
  ///
  /// In en, this message translates to:
  /// **'L (20px)'**
  String get fontSizeL;

  /// No description provided for @fontSizeXL.
  ///
  /// In en, this message translates to:
  /// **'XL (24px)'**
  String get fontSizeXL;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnectAll.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all'**
  String get disconnectAll;

  /// No description provided for @disconnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectConfirmTitle;

  /// No description provided for @disconnectConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to close all SSH connections?'**
  String get disconnectConfirmMessage;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @connectToServer.
  ///
  /// In en, this message translates to:
  /// **'Connect to an SSH server'**
  String get connectToServer;

  /// No description provided for @newConnection.
  ///
  /// In en, this message translates to:
  /// **'New connection'**
  String get newConnection;

  /// No description provided for @connectionInProgress.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectionInProgress;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get reconnecting;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLost;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get connectionError;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @runCommands.
  ///
  /// In en, this message translates to:
  /// **'Run commands'**
  String get runCommands;

  /// No description provided for @localShell.
  ///
  /// In en, this message translates to:
  /// **'Local Shell'**
  String get localShell;

  /// No description provided for @localShellNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on iOS'**
  String get localShellNotAvailable;

  /// No description provided for @localShellIOSMessage.
  ///
  /// In en, this message translates to:
  /// **'iOS does not allow local shell access. SSH connections work normally.'**
  String get localShellIOSMessage;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @sshKeys.
  ///
  /// In en, this message translates to:
  /// **'SSH Keys'**
  String get sshKeys;

  /// No description provided for @generateKey.
  ///
  /// In en, this message translates to:
  /// **'Generate key'**
  String get generateKey;

  /// No description provided for @keyName.
  ///
  /// In en, this message translates to:
  /// **'Key name'**
  String get keyName;

  /// No description provided for @keyType.
  ///
  /// In en, this message translates to:
  /// **'Key type'**
  String get keyType;

  /// No description provided for @publicKey.
  ///
  /// In en, this message translates to:
  /// **'Public key'**
  String get publicKey;

  /// No description provided for @privateKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get privateKey;

  /// No description provided for @copyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key'**
  String get copyPublicKey;

  /// No description provided for @keyCopied.
  ///
  /// In en, this message translates to:
  /// **'Key copied to clipboard'**
  String get keyCopied;

  /// No description provided for @deleteKey.
  ///
  /// In en, this message translates to:
  /// **'Delete key'**
  String get deleteKey;

  /// No description provided for @deleteKeyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this SSH key?'**
  String get deleteKeyConfirm;

  /// No description provided for @savedConnections.
  ///
  /// In en, this message translates to:
  /// **'Saved connections'**
  String get savedConnections;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @selectKey.
  ///
  /// In en, this message translates to:
  /// **'Select key'**
  String get selectKey;

  /// No description provided for @saveConnection.
  ///
  /// In en, this message translates to:
  /// **'Save connection'**
  String get saveConnection;

  /// No description provided for @deleteConnection.
  ///
  /// In en, this message translates to:
  /// **'Delete connection'**
  String get deleteConnection;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get biometricUnlock;

  /// No description provided for @faceId.
  ///
  /// In en, this message translates to:
  /// **'Face ID'**
  String get faceId;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @autoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get autoLock;

  /// No description provided for @autoLockTime.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock time'**
  String get autoLockTime;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear command history'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete all command history?'**
  String get clearHistoryConfirm;

  /// No description provided for @historyCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// No description provided for @wolEnabled.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN enabled'**
  String get wolEnabled;

  /// No description provided for @wolConfigs.
  ///
  /// In en, this message translates to:
  /// **'WOL configurations'**
  String get wolConfigs;

  /// No description provided for @addWolConfig.
  ///
  /// In en, this message translates to:
  /// **'Add WOL configuration'**
  String get addWolConfig;

  /// No description provided for @wolName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get wolName;

  /// No description provided for @macAddress.
  ///
  /// In en, this message translates to:
  /// **'MAC address'**
  String get macAddress;

  /// No description provided for @broadcastAddress.
  ///
  /// In en, this message translates to:
  /// **'Broadcast address'**
  String get broadcastAddress;

  /// No description provided for @udpPort.
  ///
  /// In en, this message translates to:
  /// **'UDP port'**
  String get udpPort;

  /// No description provided for @linkedConnection.
  ///
  /// In en, this message translates to:
  /// **'Linked SSH connection'**
  String get linkedConnection;

  /// No description provided for @wolStart.
  ///
  /// In en, this message translates to:
  /// **'WOL START'**
  String get wolStart;

  /// No description provided for @wakingUp.
  ///
  /// In en, this message translates to:
  /// **'Waking up...'**
  String get wakingUp;

  /// No description provided for @waitingForBoot.
  ///
  /// In en, this message translates to:
  /// **'Waiting for boot...'**
  String get waitingForBoot;

  /// No description provided for @tryingToConnect.
  ///
  /// In en, this message translates to:
  /// **'Trying to connect...'**
  String get tryingToConnect;

  /// No description provided for @pcAwake.
  ///
  /// In en, this message translates to:
  /// **'PC is awake!'**
  String get pcAwake;

  /// No description provided for @wolFailed.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN failed'**
  String get wolFailed;

  /// No description provided for @shutdown.
  ///
  /// In en, this message translates to:
  /// **'Shutdown'**
  String get shutdown;

  /// No description provided for @shutdownConfirm.
  ///
  /// In en, this message translates to:
  /// **'Shutdown this PC?'**
  String get shutdownConfirm;

  /// No description provided for @pressKeyForCtrl.
  ///
  /// In en, this message translates to:
  /// **'Press a key...'**
  String get pressKeyForCtrl;

  /// No description provided for @swipeDownToReduce.
  ///
  /// In en, this message translates to:
  /// **'Swipe down to reduce...'**
  String get swipeDownToReduce;

  /// No description provided for @wolWakingUp.
  ///
  /// In en, this message translates to:
  /// **'Waking up {name}...'**
  String wolWakingUp(Object name);

  /// No description provided for @wolAttempt.
  ///
  /// In en, this message translates to:
  /// **'Attempt {attempt}/{maxAttempts}'**
  String wolAttempt(Object attempt, Object maxAttempts);

  /// No description provided for @wolConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected!'**
  String get wolConnected;

  /// No description provided for @wolPcAwake.
  ///
  /// In en, this message translates to:
  /// **'{name} is awake'**
  String wolPcAwake(Object name);

  /// No description provided for @wolSshEstablished.
  ///
  /// In en, this message translates to:
  /// **'SSH connection established'**
  String get wolSshEstablished;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @addPc.
  ///
  /// In en, this message translates to:
  /// **'Add a PC'**
  String get addPc;

  /// No description provided for @pcName.
  ///
  /// In en, this message translates to:
  /// **'PC name'**
  String get pcName;

  /// No description provided for @pcNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get pcNameRequired;

  /// No description provided for @macAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'MAC address is required'**
  String get macAddressRequired;

  /// No description provided for @macAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid format (e.g. AA:BB:CC:DD:EE:FF)'**
  String get macAddressInvalid;

  /// No description provided for @howToFindMac.
  ///
  /// In en, this message translates to:
  /// **'How to find the MAC address?'**
  String get howToFindMac;

  /// No description provided for @linkedSshConnection.
  ///
  /// In en, this message translates to:
  /// **'Linked SSH connection *'**
  String get linkedSshConnection;

  /// No description provided for @selectConnection.
  ///
  /// In en, this message translates to:
  /// **'Select a connection'**
  String get selectConnection;

  /// No description provided for @noSavedConnections.
  ///
  /// In en, this message translates to:
  /// **'No saved connections'**
  String get noSavedConnections;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced options (remote WOL)'**
  String get advancedOptions;

  /// No description provided for @broadcastOptional.
  ///
  /// In en, this message translates to:
  /// **'Broadcast address (optional)'**
  String get broadcastOptional;

  /// No description provided for @defaultBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Default: 255.255.255.255'**
  String get defaultBroadcast;

  /// No description provided for @udpPortOptional.
  ///
  /// In en, this message translates to:
  /// **'UDP port (optional)'**
  String get udpPortOptional;

  /// No description provided for @defaultPort.
  ///
  /// In en, this message translates to:
  /// **'Default: 9'**
  String get defaultPort;

  /// No description provided for @portRange.
  ///
  /// In en, this message translates to:
  /// **'Port between 1 and 65535'**
  String get portRange;

  /// No description provided for @pleaseSelectSshConnection.
  ///
  /// In en, this message translates to:
  /// **'Please select an SSH connection'**
  String get pleaseSelectSshConnection;

  /// No description provided for @configAdded.
  ///
  /// In en, this message translates to:
  /// **'Configuration \"{name}\" added'**
  String configAdded(Object name);

  /// No description provided for @findMacAddress.
  ///
  /// In en, this message translates to:
  /// **'Find MAC address'**
  String get findMacAddress;

  /// No description provided for @macAddressFormat.
  ///
  /// In en, this message translates to:
  /// **'MAC address looks like: AA:BB:CC:DD:EE:FF'**
  String get macAddressFormat;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get understood;

  /// No description provided for @quickConnections.
  ///
  /// In en, this message translates to:
  /// **'QUICK CONNECTIONS'**
  String get quickConnections;

  /// No description provided for @autoConnectOnStart.
  ///
  /// In en, this message translates to:
  /// **'Auto-connect on startup'**
  String get autoConnectOnStart;

  /// No description provided for @autoConnectOnStartDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically connect to the last connection'**
  String get autoConnectOnStartDesc;

  /// No description provided for @autoReconnect.
  ///
  /// In en, this message translates to:
  /// **'Auto reconnect'**
  String get autoReconnect;

  /// No description provided for @autoReconnectDesc.
  ///
  /// In en, this message translates to:
  /// **'Reconnect if connection is lost'**
  String get autoReconnectDesc;

  /// No description provided for @disconnectNotification.
  ///
  /// In en, this message translates to:
  /// **'Disconnect notification'**
  String get disconnectNotification;

  /// No description provided for @disconnectNotificationDesc.
  ///
  /// In en, this message translates to:
  /// **'Show notification on disconnection'**
  String get disconnectNotificationDesc;

  /// No description provided for @deleteConnectionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete connection?'**
  String get deleteConnectionConfirm;

  /// No description provided for @deleteConnectionConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete \"{name}\" from your saved connections?'**
  String deleteConnectionConfirmMessage(Object name);

  /// No description provided for @noWolConfig.
  ///
  /// In en, this message translates to:
  /// **'No configuration. Add one to enable WOL.'**
  String get noWolConfig;

  /// No description provided for @terminalTab.
  ///
  /// In en, this message translates to:
  /// **'Terminal {number}'**
  String terminalTab(Object number);

  /// No description provided for @wakeUpPc.
  ///
  /// In en, this message translates to:
  /// **'Wake up a PC'**
  String get wakeUpPc;

  /// No description provided for @connectionLostSnack.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLostSnack;

  /// No description provided for @unableToCreateTab.
  ///
  /// In en, this message translates to:
  /// **'Unable to create a new tab'**
  String get unableToCreateTab;

  /// No description provided for @privateKeyNotFound.
  ///
  /// In en, this message translates to:
  /// **'Private key not found'**
  String get privateKeyNotFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
