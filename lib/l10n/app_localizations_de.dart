// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'VibeTerm';

  @override
  String get settings => 'Einstellungen';

  @override
  String get connection => 'Verbindung';

  @override
  String get general => 'Allgemein';

  @override
  String get security => 'Sicherheit';

  @override
  String get wol => 'WOL';

  @override
  String get theme => 'Thema';

  @override
  String get language => 'Sprache';

  @override
  String get fontSize => 'Schriftgröße';

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
  String get disconnect => 'Trennen';

  @override
  String get disconnectAll => 'Alle trennen';

  @override
  String get disconnectConfirmTitle => 'Trennen';

  @override
  String get disconnectConfirmMessage =>
      'Möchten Sie alle SSH-Verbindungen schließen?';

  @override
  String get connect => 'Verbinden';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get delete => 'Löschen';

  @override
  String get add => 'Hinzufügen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get retry => 'Wiederholen';

  @override
  String get noConnection => 'Keine Verbindung';

  @override
  String get connectToServer => 'Mit SSH-Server verbinden';

  @override
  String get newConnection => 'Neue Verbindung';

  @override
  String get connectionInProgress => 'Verbindung wird hergestellt...';

  @override
  String get reconnecting => 'Wiederverbinden...';

  @override
  String get connectionLost => 'Verbindung verloren';

  @override
  String get connectionError => 'Verbindungsfehler';

  @override
  String get reconnect => 'Wiederverbinden';

  @override
  String get terminal => 'Terminal';

  @override
  String get runCommands => 'Befehle ausführen';

  @override
  String get localShell => 'Lokale Shell';

  @override
  String get localShellNotAvailable => 'Nicht verfügbar auf iOS';

  @override
  String get localShellIOSMessage =>
      'iOS erlaubt keinen lokalen Shell-Zugriff. SSH-Verbindungen funktionieren normal.';

  @override
  String get copy => 'Kopieren';

  @override
  String get paste => 'Einfügen';

  @override
  String get sshKeys => 'SSH-Schlüssel';

  @override
  String get generateKey => 'Schlüssel generieren';

  @override
  String get keyName => 'Schlüsselname';

  @override
  String get keyType => 'Schlüsseltyp';

  @override
  String get publicKey => 'Öffentlicher Schlüssel';

  @override
  String get privateKey => 'Privater Schlüssel';

  @override
  String get copyPublicKey => 'Öffentlichen Schlüssel kopieren';

  @override
  String get keyCopied => 'Schlüssel in Zwischenablage kopiert';

  @override
  String get deleteKey => 'Schlüssel löschen';

  @override
  String get deleteKeyConfirm => 'Diesen SSH-Schlüssel löschen?';

  @override
  String get savedConnections => 'Gespeicherte Verbindungen';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get username => 'Benutzername';

  @override
  String get selectKey => 'Schlüssel auswählen';

  @override
  String get saveConnection => 'Verbindung speichern';

  @override
  String get deleteConnection => 'Verbindung löschen';

  @override
  String get biometricUnlock => 'Biometrische Entsperrung';

  @override
  String get faceId => 'Face ID';

  @override
  String get fingerprint => 'Fingerabdruck';

  @override
  String get autoLock => 'Automatische Sperre';

  @override
  String get autoLockTime => 'Sperrzeit';

  @override
  String get minutes => 'Minuten';

  @override
  String get clearHistory => 'Verlauf löschen';

  @override
  String get clearHistoryConfirm => 'Gesamten Befehlsverlauf löschen?';

  @override
  String get historyCleared => 'Verlauf gelöscht';

  @override
  String get wolEnabled => 'Wake-on-LAN aktiviert';

  @override
  String get wolConfigs => 'WOL-Konfigurationen';

  @override
  String get addWolConfig => 'WOL-Konfiguration hinzufügen';

  @override
  String get wolName => 'Name';

  @override
  String get macAddress => 'MAC-Adresse';

  @override
  String get broadcastAddress => 'Broadcast-Adresse';

  @override
  String get udpPort => 'UDP-Port';

  @override
  String get linkedConnection => 'Verknüpfte SSH-Verbindung';

  @override
  String get wolStart => 'WOL START';

  @override
  String get wakingUp => 'Aufwecken...';

  @override
  String get waitingForBoot => 'Warte auf Start...';

  @override
  String get tryingToConnect => 'Verbindungsversuch...';

  @override
  String get pcAwake => 'PC ist wach!';

  @override
  String get wolFailed => 'Wake-on-LAN fehlgeschlagen';

  @override
  String get shutdown => 'Herunterfahren';

  @override
  String get shutdownConfirm => 'Diesen PC herunterfahren?';

  @override
  String get pressKeyForCtrl => 'Taste drücken...';

  @override
  String get swipeDownToReduce => 'Nach unten wischen zum Verkleinern...';

  @override
  String wolWakingUp(Object name) {
    return '$name wird aufgeweckt...';
  }

  @override
  String wolAttempt(Object attempt, Object maxAttempts) {
    return 'Versuch $attempt/$maxAttempts';
  }

  @override
  String get wolConnected => 'Verbunden!';

  @override
  String wolPcAwake(Object name) {
    return '$name ist wach';
  }

  @override
  String get wolSshEstablished => 'SSH-Verbindung hergestellt';

  @override
  String get back => 'Zurück';

  @override
  String get addPc => 'PC hinzufügen';

  @override
  String get pcName => 'PC-Name';

  @override
  String get pcNameRequired => 'Name ist erforderlich';

  @override
  String get macAddressRequired => 'MAC-Adresse ist erforderlich';

  @override
  String get macAddressInvalid => 'Ungültiges Format (z.B. AA:BB:CC:DD:EE:FF)';

  @override
  String get howToFindMac => 'Wie finde ich die MAC-Adresse?';

  @override
  String get linkedSshConnection => 'Verknüpfte SSH-Verbindung *';

  @override
  String get selectConnection => 'Verbindung auswählen';

  @override
  String get noSavedConnections => 'Keine gespeicherten Verbindungen';

  @override
  String get advancedOptions => 'Erweiterte Optionen (Remote-WOL)';

  @override
  String get broadcastOptional => 'Broadcast-Adresse (optional)';

  @override
  String get defaultBroadcast => 'Standard: 255.255.255.255';

  @override
  String get udpPortOptional => 'UDP-Port (optional)';

  @override
  String get defaultPort => 'Standard: 9';

  @override
  String get portRange => 'Port zwischen 1 und 65535';

  @override
  String get pleaseSelectSshConnection =>
      'Bitte wählen Sie eine SSH-Verbindung';

  @override
  String configAdded(Object name) {
    return 'Konfiguration \"$name\" hinzugefügt';
  }

  @override
  String get findMacAddress => 'MAC-Adresse finden';

  @override
  String get macAddressFormat => 'MAC-Adresse sieht so aus: AA:BB:CC:DD:EE:FF';

  @override
  String get understood => 'Verstanden';

  @override
  String get quickConnections => 'SCHNELLVERBINDUNGEN';

  @override
  String get autoConnectOnStart => 'Automatisch beim Start verbinden';

  @override
  String get autoConnectOnStartDesc =>
      'Automatisch mit der letzten Verbindung verbinden';

  @override
  String get autoReconnect => 'Automatisch wiederverbinden';

  @override
  String get autoReconnectDesc => 'Bei Verbindungsverlust wiederverbinden';

  @override
  String get disconnectNotification => 'Trennungsbenachrichtigung';

  @override
  String get disconnectNotificationDesc =>
      'Benachrichtigung bei Trennung anzeigen';

  @override
  String get deleteConnectionConfirm => 'Verbindung löschen?';

  @override
  String deleteConnectionConfirmMessage(Object name) {
    return 'Möchten Sie \"$name\" aus Ihren gespeicherten Verbindungen löschen?';
  }

  @override
  String get noWolConfig =>
      'Keine Konfiguration. Fügen Sie eine hinzu, um WOL zu aktivieren.';

  @override
  String terminalTab(Object number) {
    return 'Terminal $number';
  }

  @override
  String get wakeUpPc => 'PC aufwecken';

  @override
  String get connectionLostSnack => 'Verbindung verloren';

  @override
  String get unableToCreateTab => 'Tab konnte nicht erstellt werden';

  @override
  String get privateKeyNotFound => 'Privater Schlüssel nicht gefunden';
}
