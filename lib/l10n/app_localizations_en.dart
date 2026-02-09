// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ChillShell';

  @override
  String get settings => 'Settings';

  @override
  String get connection => 'Connection';

  @override
  String get access => 'Access';

  @override
  String get general => 'General';

  @override
  String get security => 'Security';

  @override
  String get wol => 'WOL';

  @override
  String get remoteAccess => 'Remote Access';

  @override
  String get tailscaleDescription =>
      'Connect to your PC from anywhere in the world';

  @override
  String get playStore => 'Play Store';

  @override
  String get appStore => 'App Store';

  @override
  String get website => 'Website';

  @override
  String get noSshKeys => 'No SSH keys. Create one to connect.';

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
  String get createSshKey => 'Create SSH Key';

  @override
  String get importKey => 'Import Key';

  @override
  String get importKeySubtitle => '.pem file or private key';

  @override
  String get selectFile => 'Select a file';

  @override
  String get orPasteKey => 'Or paste the key:';

  @override
  String get keyName => 'Key name';

  @override
  String get publicKey => 'Public key';

  @override
  String get privateKey => 'Private key';

  @override
  String get keyCopied => 'Key copied to clipboard';

  @override
  String get deleteKey => 'Delete key';

  @override
  String get savedConnections => 'Saved connections';

  @override
  String get autoConnection => 'Auto connection';

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
  String get unlock => 'Unlock';

  @override
  String get pinCode => 'PIN Code';

  @override
  String get createPin => 'Create your PIN';

  @override
  String get confirmPin => 'Confirm your PIN';

  @override
  String get enterPin => 'Enter your PIN';

  @override
  String get pinMismatch => 'PINs do not match';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String get fingerprintUnavailable =>
      'No fingerprint registered on this device';

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
  String get macAddress => 'MAC address';

  @override
  String get broadcastAddress => 'Broadcast address';

  @override
  String get wolStart => 'WOL START';

  @override
  String get pressKeyForCtrl => 'Press a key...';

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
  String get configRequired => 'Configuration required';

  @override
  String get wolDescription =>
      'Wake-on-LAN lets you turn on your PC from the app.';

  @override
  String get turnOnCableRequired => 'Turn on: Ethernet cable required';

  @override
  String get turnOffWifiOrCable => 'Turn off: WiFi or cable';

  @override
  String get fullGuide => 'Full guide';

  @override
  String get linkCopied => 'Link copied';

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

  @override
  String get uploadingImage => 'Uploading image...';

  @override
  String get uploadFailed => 'Image upload failed';

  @override
  String get ok => 'OK';

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get invalidKeyFormat => 'Invalid key format';

  @override
  String get keyFileTooLarge =>
      'File too large (max 16 KB). SSH keys should be small files.';

  @override
  String keyImported(String name) {
    return 'Key \"$name\" imported';
  }

  @override
  String get deleteKeyConfirmTitle => 'Delete key?';

  @override
  String get actionIrreversible => 'This action is irreversible.';

  @override
  String deleteKeysConfirm(int count) {
    return 'Delete $count key(s)?';
  }

  @override
  String deleteConnectionsConfirm(int count) {
    return 'Delete $count connection(s)?';
  }

  @override
  String deleteWolConfigsConfirm(int count) {
    return 'Delete $count config(s)?';
  }

  @override
  String sshKeyTypeLabel(String type) {
    return 'Type: $type';
  }

  @override
  String sshKeyHostLabel(String host) {
    return 'Host: $host';
  }

  @override
  String sshKeyLastUsedLabel(String date) {
    return 'Last used: $date';
  }

  @override
  String get shutdownPcTitle => 'Shutdown PC';

  @override
  String shutdownPcMessage(String name) {
    return 'Do you really want to shutdown $name?\n\nSSH connection will be closed.';
  }

  @override
  String get shutdownAction => 'Shutdown';

  @override
  String get searchPlaceholder => 'Search...';

  @override
  String get autoDetect => 'Auto';

  @override
  String get wolBiosTitle => '1. BIOS';

  @override
  String get wolBiosEnablePcie => 'Enable \"Power On By PCI-E\"';

  @override
  String get wolBiosDisableErp => 'Disable \"ErP Ready\"';

  @override
  String get wolFastStartupTitle => '2. Fast Startup';

  @override
  String get wolFastStep1 => 'Power Options → System Settings';

  @override
  String get wolFastStep2 => 'Change unavailable settings';

  @override
  String get wolFastStep3 => 'Uncheck \"Turn on fast startup\"';

  @override
  String get wolDeviceManagerTitle => '3. Device Manager';

  @override
  String get wolDevStep1 => 'Network adapter → Power Management';

  @override
  String get wolDevStep2 => 'Check \"Magic Packet only\"';

  @override
  String get wolDevStep3 => 'Network adapter → Advanced';

  @override
  String get wolDevStep4 => 'Enable \"Wake on Magic Packet\"';

  @override
  String get wolMacConfigTitle => 'Configuration';

  @override
  String get wolMacStep1 => '1. Apple Menu → System Preferences';

  @override
  String get wolMacStep2 => '2. Energy Saver';

  @override
  String get wolMacStep3 => '3. Check \"Wake for network access\"';

  @override
  String get sshKeySecurityTitle => 'Protect your keys';

  @override
  String get sshKeySecurityDesc =>
      'Your SSH keys work like passwords that give access to your servers. The private key must NEVER be shared — not by email, messaging, or cloud storage. Only share the public key with servers you want to connect to. ChillShell stores your keys securely on your device only. If you suspect a key has been compromised, delete it immediately and create a new one.';

  @override
  String get sshHostKeyTitle => 'New server';

  @override
  String sshHostKeyMessage(String host) {
    return 'You are connecting to $host for the first time.\nVerify the server fingerprint before connecting:';
  }

  @override
  String sshHostKeyType(String type) {
    return 'Type: $type';
  }

  @override
  String get sshHostKeyFingerprint => 'Fingerprint:';

  @override
  String get sshHostKeyAccept => 'Trust and connect';

  @override
  String get sshHostKeyReject => 'Reject';

  @override
  String get sshHostKeyMismatchTitle => 'Warning — Key changed!';

  @override
  String sshHostKeyMismatchMessage(String host) {
    return 'The server key for $host has changed!\n\nThis could indicate a man-in-the-middle attack. If you did not change the server configuration, reject this connection.';
  }

  @override
  String get rootedDeviceWarning =>
      'Warning: This device appears to be rooted. SSH key security may be compromised.';

  @override
  String tooManyAttempts(int seconds) {
    return 'Too many attempts. Try again in $seconds s';
  }

  @override
  String tryAgainIn(int seconds) {
    return 'Try again in $seconds s';
  }

  @override
  String get sshConnectionFailed =>
      'Could not connect. Check the server address.';

  @override
  String get sshAuthFailed => 'Authentication failed. Check your SSH key.';

  @override
  String get sshKeyNotConfigured => 'No SSH key configured for this host.';

  @override
  String get sshTimeout => 'Connection timed out.';

  @override
  String get sshHostUnreachable => 'Server unreachable. Check Tailscale.';

  @override
  String get connectionLost => 'Connection lost';

  @override
  String get biometricReason => 'Unlock ChillShell to access your SSH sessions';

  @override
  String get biometricFingerprint => 'Fingerprint';

  @override
  String get biometricIris => 'Iris';

  @override
  String get biometricGeneric => 'Biometrics';

  @override
  String get localShellError => 'Local shell error';

  @override
  String reconnectingAttempt(String current, String max) {
    return 'Reconnecting... (attempt $current/$max)';
  }

  @override
  String get unexpectedError => 'Unexpected error';

  @override
  String get allowScreenshots => 'Screenshots';

  @override
  String get allowScreenshotsWarning =>
      'When enabled, screenshots and screen recording are allowed. Be careful not to share sensitive information (SSH keys, passwords, server addresses).';

  @override
  String get rename => 'Rename';

  @override
  String get renameDialogHint => 'New name';

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty';
}
