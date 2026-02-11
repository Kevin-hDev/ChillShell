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
  /// **'ChillShell'**
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

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get access;

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

  /// No description provided for @remoteAccess.
  ///
  /// In en, this message translates to:
  /// **'Remote Access'**
  String get remoteAccess;

  /// No description provided for @tailscaleDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect to your PC from anywhere in the world'**
  String get tailscaleDescription;

  /// No description provided for @playStore.
  ///
  /// In en, this message translates to:
  /// **'Play Store'**
  String get playStore;

  /// No description provided for @appStore.
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get appStore;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @noSshKeys.
  ///
  /// In en, this message translates to:
  /// **'No SSH keys. Create one to connect.'**
  String get noSshKeys;

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

  /// No description provided for @createSshKey.
  ///
  /// In en, this message translates to:
  /// **'Create SSH Key'**
  String get createSshKey;

  /// No description provided for @importKey.
  ///
  /// In en, this message translates to:
  /// **'Import Key'**
  String get importKey;

  /// No description provided for @importKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'.pem file or private key'**
  String get importKeySubtitle;

  /// No description provided for @selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select a file'**
  String get selectFile;

  /// No description provided for @orPasteKey.
  ///
  /// In en, this message translates to:
  /// **'Or paste the key:'**
  String get orPasteKey;

  /// No description provided for @keyName.
  ///
  /// In en, this message translates to:
  /// **'Key name'**
  String get keyName;

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

  /// No description provided for @savedConnections.
  ///
  /// In en, this message translates to:
  /// **'Saved connections'**
  String get savedConnections;

  /// No description provided for @autoConnection.
  ///
  /// In en, this message translates to:
  /// **'Auto connection'**
  String get autoConnection;

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

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @pinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN Code'**
  String get pinCode;

  /// No description provided for @createPin.
  ///
  /// In en, this message translates to:
  /// **'Create your PIN'**
  String get createPin;

  /// No description provided for @confirmPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get confirmPin;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get enterPin;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match'**
  String get pinMismatch;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @fingerprintUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint registered on this device'**
  String get fingerprintUnavailable;

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

  /// No description provided for @wolStart.
  ///
  /// In en, this message translates to:
  /// **'WOL START'**
  String get wolStart;

  /// No description provided for @pressKeyForCtrl.
  ///
  /// In en, this message translates to:
  /// **'Press a key...'**
  String get pressKeyForCtrl;

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

  /// No description provided for @configRequired.
  ///
  /// In en, this message translates to:
  /// **'Configuration required'**
  String get configRequired;

  /// No description provided for @wolDescription.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN lets you turn on your PC from the app.'**
  String get wolDescription;

  /// No description provided for @turnOnCableRequired.
  ///
  /// In en, this message translates to:
  /// **'Turn on: Ethernet cable required'**
  String get turnOnCableRequired;

  /// No description provided for @turnOffWifiOrCable.
  ///
  /// In en, this message translates to:
  /// **'Turn off: WiFi or cable'**
  String get turnOffWifiOrCable;

  /// No description provided for @fullGuide.
  ///
  /// In en, this message translates to:
  /// **'Full guide'**
  String get fullGuide;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

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

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get uploadingImage;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get uploadFailed;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorMessage(String error);

  /// No description provided for @invalidKeyFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid key format'**
  String get invalidKeyFormat;

  /// No description provided for @keyFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large (max 16 KB). SSH keys should be small files.'**
  String get keyFileTooLarge;

  /// No description provided for @keyImported.
  ///
  /// In en, this message translates to:
  /// **'Key \"{name}\" imported'**
  String keyImported(String name);

  /// No description provided for @deleteKeyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete key?'**
  String get deleteKeyConfirmTitle;

  /// No description provided for @actionIrreversible.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible.'**
  String get actionIrreversible;

  /// No description provided for @deleteKeysConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} key(s)?'**
  String deleteKeysConfirm(int count);

  /// No description provided for @deleteConnectionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} connection(s)?'**
  String deleteConnectionsConfirm(int count);

  /// No description provided for @deleteWolConfigsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} config(s)?'**
  String deleteWolConfigsConfirm(int count);

  /// No description provided for @sshKeyTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String sshKeyTypeLabel(String type);

  /// No description provided for @sshKeyHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Host: {host}'**
  String sshKeyHostLabel(String host);

  /// No description provided for @sshKeyLastUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Last used: {date}'**
  String sshKeyLastUsedLabel(String date);

  /// No description provided for @shutdownPcTitle.
  ///
  /// In en, this message translates to:
  /// **'Shutdown PC'**
  String get shutdownPcTitle;

  /// No description provided for @shutdownPcMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you really want to shutdown {name}?\n\nSSH connection will be closed.'**
  String shutdownPcMessage(String name);

  /// No description provided for @shutdownAction.
  ///
  /// In en, this message translates to:
  /// **'Shutdown'**
  String get shutdownAction;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchPlaceholder;

  /// No description provided for @autoDetect.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoDetect;

  /// No description provided for @wolBiosTitle.
  ///
  /// In en, this message translates to:
  /// **'1. BIOS'**
  String get wolBiosTitle;

  /// No description provided for @wolBiosEnablePcie.
  ///
  /// In en, this message translates to:
  /// **'Enable \"Power On By PCI-E\"'**
  String get wolBiosEnablePcie;

  /// No description provided for @wolBiosDisableErp.
  ///
  /// In en, this message translates to:
  /// **'Disable \"ErP Ready\"'**
  String get wolBiosDisableErp;

  /// No description provided for @wolFastStartupTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Fast Startup'**
  String get wolFastStartupTitle;

  /// No description provided for @wolFastStep1.
  ///
  /// In en, this message translates to:
  /// **'Power Options → System Settings'**
  String get wolFastStep1;

  /// No description provided for @wolFastStep2.
  ///
  /// In en, this message translates to:
  /// **'Change unavailable settings'**
  String get wolFastStep2;

  /// No description provided for @wolFastStep3.
  ///
  /// In en, this message translates to:
  /// **'Uncheck \"Turn on fast startup\"'**
  String get wolFastStep3;

  /// No description provided for @wolDeviceManagerTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Device Manager'**
  String get wolDeviceManagerTitle;

  /// No description provided for @wolDevStep1.
  ///
  /// In en, this message translates to:
  /// **'Network adapter → Power Management'**
  String get wolDevStep1;

  /// No description provided for @wolDevStep2.
  ///
  /// In en, this message translates to:
  /// **'Check \"Magic Packet only\"'**
  String get wolDevStep2;

  /// No description provided for @wolDevStep3.
  ///
  /// In en, this message translates to:
  /// **'Network adapter → Advanced'**
  String get wolDevStep3;

  /// No description provided for @wolDevStep4.
  ///
  /// In en, this message translates to:
  /// **'Enable \"Wake on Magic Packet\"'**
  String get wolDevStep4;

  /// No description provided for @wolMacConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get wolMacConfigTitle;

  /// No description provided for @wolMacStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Apple Menu → System Preferences'**
  String get wolMacStep1;

  /// No description provided for @wolMacStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Energy Saver'**
  String get wolMacStep2;

  /// No description provided for @wolMacStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Check \"Wake for network access\"'**
  String get wolMacStep3;

  /// No description provided for @sshKeySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect your keys'**
  String get sshKeySecurityTitle;

  /// No description provided for @sshKeySecurityDesc.
  ///
  /// In en, this message translates to:
  /// **'Your SSH keys work like passwords that give access to your servers. The private key must NEVER be shared — not by email, messaging, or cloud storage. Only share the public key with servers you want to connect to. ChillShell stores your keys securely on your device only. If you suspect a key has been compromised, delete it immediately and create a new one.'**
  String get sshKeySecurityDesc;

  /// No description provided for @sshHostKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'New server'**
  String get sshHostKeyTitle;

  /// No description provided for @sshHostKeyMessage.
  ///
  /// In en, this message translates to:
  /// **'You are connecting to {host} for the first time.\nVerify the server fingerprint before connecting:'**
  String sshHostKeyMessage(String host);

  /// No description provided for @sshHostKeyType.
  ///
  /// In en, this message translates to:
  /// **'Type: {type}'**
  String sshHostKeyType(String type);

  /// No description provided for @sshHostKeyFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint:'**
  String get sshHostKeyFingerprint;

  /// No description provided for @sshHostKeyAccept.
  ///
  /// In en, this message translates to:
  /// **'Trust and connect'**
  String get sshHostKeyAccept;

  /// No description provided for @sshHostKeyReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get sshHostKeyReject;

  /// No description provided for @sshHostKeyMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Warning — Key changed!'**
  String get sshHostKeyMismatchTitle;

  /// No description provided for @sshHostKeyMismatchMessage.
  ///
  /// In en, this message translates to:
  /// **'The server key for {host} has changed!\n\nThis could indicate a man-in-the-middle attack. If you did not change the server configuration, reject this connection.'**
  String sshHostKeyMismatchMessage(String host);

  /// No description provided for @rootedDeviceWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This device appears to be rooted. SSH key security may be compromised.'**
  String get rootedDeviceWarning;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s'**
  String tooManyAttempts(int seconds);

  /// No description provided for @tryAgainIn.
  ///
  /// In en, this message translates to:
  /// **'Try again in {seconds} s'**
  String tryAgainIn(int seconds);

  /// No description provided for @sshConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect. Check the server address.'**
  String get sshConnectionFailed;

  /// No description provided for @sshAuthFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Check your SSH key.'**
  String get sshAuthFailed;

  /// No description provided for @sshKeyNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No SSH key configured for this host.'**
  String get sshKeyNotConfigured;

  /// No description provided for @sshTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out.'**
  String get sshTimeout;

  /// No description provided for @sshHostUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Server unreachable. Check Tailscale.'**
  String get sshHostUnreachable;

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get connectionLost;

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock ChillShell to access your SSH sessions'**
  String get biometricReason;

  /// No description provided for @biometricFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get biometricFingerprint;

  /// No description provided for @biometricIris.
  ///
  /// In en, this message translates to:
  /// **'Iris'**
  String get biometricIris;

  /// No description provided for @biometricGeneric.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get biometricGeneric;

  /// No description provided for @localShellError.
  ///
  /// In en, this message translates to:
  /// **'Local shell error'**
  String get localShellError;

  /// No description provided for @reconnectingAttempt.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting... (attempt {current}/{max})'**
  String reconnectingAttempt(String current, String max);

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get unexpectedError;

  /// No description provided for @allowScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get allowScreenshots;

  /// No description provided for @allowScreenshotsWarning.
  ///
  /// In en, this message translates to:
  /// **'When enabled, screenshots and screen recording are allowed. Be careful not to share sensitive information (SSH keys, passwords, server addresses).'**
  String get allowScreenshotsWarning;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameDialogHint.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get renameDialogHint;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameCannotBeEmpty;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'ChillShell Premium'**
  String get premiumTitle;

  /// No description provided for @trialExpired.
  ///
  /// In en, this message translates to:
  /// **'Your 7-day free trial has ended'**
  String get trialExpired;

  /// No description provided for @trialExpiredDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock ChillShell permanently with a single purchase. No subscription.'**
  String get trialExpiredDesc;

  /// No description provided for @trialDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} day(s) remaining in your trial'**
  String trialDaysRemaining(int days);

  /// No description provided for @buyPremium.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium'**
  String get buyPremium;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchase;

  /// No description provided for @purchaseError.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get purchaseError;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store unavailable. Please check your connection.'**
  String get storeUnavailable;

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not available. Please try later.'**
  String get productNotFound;

  /// No description provided for @alreadyPremium.
  ///
  /// In en, this message translates to:
  /// **'You already have Premium access!'**
  String get alreadyPremium;

  /// No description provided for @premiumFeature1.
  ///
  /// In en, this message translates to:
  /// **'Unlimited SSH connections'**
  String get premiumFeature1;

  /// No description provided for @premiumFeature2.
  ///
  /// In en, this message translates to:
  /// **'Multiple tabs'**
  String get premiumFeature2;

  /// No description provided for @premiumFeature3.
  ///
  /// In en, this message translates to:
  /// **'Wake-on-LAN'**
  String get premiumFeature3;

  /// No description provided for @premiumFeature4.
  ///
  /// In en, this message translates to:
  /// **'All themes'**
  String get premiumFeature4;

  /// No description provided for @premiumFeature5.
  ///
  /// In en, this message translates to:
  /// **'Biometric lock'**
  String get premiumFeature5;

  /// No description provided for @oneTimePurchase.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase — no subscription'**
  String get oneTimePurchase;

  /// No description provided for @trialBanner.
  ///
  /// In en, this message translates to:
  /// **'Trial: {days} day(s) left'**
  String trialBanner(int days);
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
