// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'VibeTerm';

  @override
  String get settings => 'Settings';

  @override
  String get connection => 'Connection';

  @override
  String get general => 'General';

  @override
  String get security => 'Security';

  @override
  String get wol => 'WOL';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get fontSize => 'Font size';

  @override
  String get fontSizeXS => 'XS (12px)';

  @override
  String get fontSizeS => 'S (14px)';

  @override
  String get fontSizeM => 'M (17px)';

  @override
  String get fontSizeL => 'L (20px)';

  @override
  String get fontSizeXL => 'XL (24px)';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get disconnectAll => 'Disconnect all';

  @override
  String get disconnectConfirmTitle => 'Disconnect';

  @override
  String get disconnectConfirmMessage =>
      'Do you want to close all SSH connections?';

  @override
  String get connect => 'Connect';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Retry';

  @override
  String get noConnection => 'No connection';

  @override
  String get connectToServer => 'Connect to an SSH server';

  @override
  String get newConnection => 'New connection';

  @override
  String get connectionInProgress => 'Connecting...';

  @override
  String get reconnecting => 'Reconnecting...';

  @override
  String get connectionLost => 'Connection lost';

  @override
  String get connectionError => 'Connection error';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get terminal => 'Terminal';

  @override
  String get runCommands => 'Run commands';

  @override
  String get localShell => 'Local Shell';

  @override
  String get localShellNotAvailable => 'Not available on iOS';

  @override
  String get localShellIOSMessage =>
      'iOS does not allow local shell access. SSH connections work normally.';

  @override
  String get copy => 'Copy';

  @override
  String get paste => 'Paste';

  @override
  String get sshKeys => 'SSH Keys';

  @override
  String get generateKey => 'Generate key';

  @override
  String get keyName => 'Key name';

  @override
  String get keyType => 'Key type';

  @override
  String get publicKey => 'Public key';

  @override
  String get privateKey => 'Private key';

  @override
  String get copyPublicKey => 'Copy public key';

  @override
  String get keyCopied => 'Key copied to clipboard';

  @override
  String get deleteKey => 'Delete key';

  @override
  String get deleteKeyConfirm => 'Delete this SSH key?';

  @override
  String get savedConnections => 'Saved connections';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get username => 'Username';

  @override
  String get selectKey => 'Select key';

  @override
  String get saveConnection => 'Save connection';

  @override
  String get deleteConnection => 'Delete connection';

  @override
  String get biometricUnlock => 'Biometric unlock';

  @override
  String get faceId => 'Face ID';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get autoLock => 'Auto-lock';

  @override
  String get autoLockTime => 'Auto-lock time';

  @override
  String get minutes => 'minutes';

  @override
  String get clearHistory => 'Clear command history';

  @override
  String get clearHistoryConfirm => 'Delete all command history?';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get wolEnabled => 'Wake-on-LAN enabled';

  @override
  String get wolConfigs => 'WOL configurations';

  @override
  String get addWolConfig => 'Add WOL configuration';

  @override
  String get wolName => 'Name';

  @override
  String get macAddress => 'MAC address';

  @override
  String get broadcastAddress => 'Broadcast address';

  @override
  String get udpPort => 'UDP port';

  @override
  String get linkedConnection => 'Linked SSH connection';

  @override
  String get wolStart => 'WOL START';

  @override
  String get wakingUp => 'Waking up...';

  @override
  String get waitingForBoot => 'Waiting for boot...';

  @override
  String get tryingToConnect => 'Trying to connect...';

  @override
  String get pcAwake => 'PC is awake!';

  @override
  String get wolFailed => 'Wake-on-LAN failed';

  @override
  String get shutdown => 'Shutdown';

  @override
  String get shutdownConfirm => 'Shutdown this PC?';

  @override
  String get pressKeyForCtrl => 'Press a key...';

  @override
  String get swipeDownToReduce => 'Swipe down to reduce...';

  @override
  String wolWakingUp(Object name) {
    return 'Waking up $name...';
  }

  @override
  String wolAttempt(Object attempt, Object maxAttempts) {
    return 'Attempt $attempt/$maxAttempts';
  }

  @override
  String get wolConnected => 'Connected!';

  @override
  String wolPcAwake(Object name) {
    return '$name is awake';
  }

  @override
  String get wolSshEstablished => 'SSH connection established';

  @override
  String get back => 'Back';

  @override
  String get addPc => 'Add a PC';

  @override
  String get pcName => 'PC name';

  @override
  String get pcNameRequired => 'Name is required';

  @override
  String get macAddressRequired => 'MAC address is required';

  @override
  String get macAddressInvalid => 'Invalid format (e.g. AA:BB:CC:DD:EE:FF)';

  @override
  String get howToFindMac => 'How to find the MAC address?';

  @override
  String get linkedSshConnection => 'Linked SSH connection *';

  @override
  String get selectConnection => 'Select a connection';

  @override
  String get noSavedConnections => 'No saved connections';

  @override
  String get advancedOptions => 'Advanced options (remote WOL)';

  @override
  String get broadcastOptional => 'Broadcast address (optional)';

  @override
  String get defaultBroadcast => 'Default: 255.255.255.255';

  @override
  String get udpPortOptional => 'UDP port (optional)';

  @override
  String get defaultPort => 'Default: 9';

  @override
  String get portRange => 'Port between 1 and 65535';

  @override
  String get pleaseSelectSshConnection => 'Please select an SSH connection';

  @override
  String configAdded(Object name) {
    return 'Configuration \"$name\" added';
  }

  @override
  String get findMacAddress => 'Find MAC address';

  @override
  String get macAddressFormat => 'MAC address looks like: AA:BB:CC:DD:EE:FF';

  @override
  String get understood => 'Understood';

  @override
  String get quickConnections => 'QUICK CONNECTIONS';

  @override
  String get autoConnectOnStart => 'Auto-connect on startup';

  @override
  String get autoConnectOnStartDesc =>
      'Automatically connect to the last connection';

  @override
  String get autoReconnect => 'Auto reconnect';

  @override
  String get autoReconnectDesc => 'Reconnect if connection is lost';

  @override
  String get disconnectNotification => 'Disconnect notification';

  @override
  String get disconnectNotificationDesc => 'Show notification on disconnection';

  @override
  String get deleteConnectionConfirm => 'Delete connection?';

  @override
  String deleteConnectionConfirmMessage(Object name) {
    return 'Do you want to delete \"$name\" from your saved connections?';
  }

  @override
  String get noWolConfig => 'No configuration. Add one to enable WOL.';

  @override
  String terminalTab(Object number) {
    return 'Terminal $number';
  }

  @override
  String get wakeUpPc => 'Wake up a PC';

  @override
  String get connectionLostSnack => 'Connection lost';

  @override
  String get unableToCreateTab => 'Unable to create a new tab';

  @override
  String get privateKeyNotFound => 'Private key not found';
}
