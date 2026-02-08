// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'ChillShell';

  @override
  String get settings => 'Einstellungen';

  @override
  String get connection => 'Verbindung';

  @override
  String get access => 'Zugang';

  @override
  String get general => 'Allgemein';

  @override
  String get security => 'Sicherheit';

  @override
  String get wol => 'WOL';

  @override
  String get remoteAccess => 'Fernzugriff';

  @override
  String get tailscaleDescription =>
      'Verbinden Sie sich von überall auf der Welt mit Ihrem PC';

  @override
  String get playStore => 'Play Store';

  @override
  String get appStore => 'App Store';

  @override
  String get website => 'Webseite';

  @override
  String get noSshKeys =>
      'Keine SSH-Schlüssel. Erstellen Sie einen, um sich zu verbinden.';

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
  String get createSshKey => 'SSH-Schlüssel erstellen';

  @override
  String get importKey => 'Schlüssel importieren';

  @override
  String get importKeySubtitle => '.pem-Datei oder privater Schlüssel';

  @override
  String get selectFile => 'Datei auswählen';

  @override
  String get orPasteKey => 'Oder Schlüssel einfügen:';

  @override
  String get keyName => 'Schlüsselname';

  @override
  String get publicKey => 'Öffentlicher Schlüssel';

  @override
  String get privateKey => 'Privater Schlüssel';

  @override
  String get keyCopied => 'Schlüssel in Zwischenablage kopiert';

  @override
  String get deleteKey => 'Schlüssel löschen';

  @override
  String get savedConnections => 'Gespeicherte Verbindungen';

  @override
  String get autoConnection => 'Automatische Verbindung';

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
  String get unlock => 'Entsperrung';

  @override
  String get pinCode => 'PIN-Code';

  @override
  String get createPin => 'PIN erstellen';

  @override
  String get confirmPin => 'PIN bestätigen';

  @override
  String get enterPin => 'PIN eingeben';

  @override
  String get pinMismatch => 'PINs stimmen nicht überein';

  @override
  String get wrongPin => 'Falscher PIN';

  @override
  String get fingerprint => 'Fingerabdruck';

  @override
  String get fingerprintUnavailable =>
      'Kein Fingerabdruck auf diesem Gerät registriert';

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
  String get macAddress => 'MAC-Adresse';

  @override
  String get broadcastAddress => 'Broadcast-Adresse';

  @override
  String get wolStart => 'WOL START';

  @override
  String get pressKeyForCtrl => 'Taste drücken...';

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
  String get configRequired => 'Konfiguration erforderlich';

  @override
  String get wolDescription =>
      'Wake-on-LAN ermöglicht das Einschalten Ihres PCs über die App.';

  @override
  String get turnOnCableRequired => 'Einschalten: Ethernet-Kabel erforderlich';

  @override
  String get turnOffWifiOrCable => 'Ausschalten: WiFi oder Kabel';

  @override
  String get fullGuide => 'Vollständige Anleitung';

  @override
  String get linkCopied => 'Link kopiert';

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

  @override
  String get uploadingImage => 'Bild wird hochgeladen...';

  @override
  String get uploadFailed => 'Bild-Upload fehlgeschlagen';

  @override
  String get ok => 'OK';

  @override
  String errorMessage(String error) {
    return 'Fehler: $error';
  }

  @override
  String get invalidKeyFormat => 'Ungültiges Schlüsselformat';

  @override
  String keyImported(String name) {
    return 'Schlüssel \"$name\" importiert';
  }

  @override
  String get deleteKeyConfirmTitle => 'Schlüssel löschen?';

  @override
  String get actionIrreversible => 'Diese Aktion ist unwiderruflich.';

  @override
  String deleteKeysConfirm(int count) {
    return '$count Schlüssel löschen?';
  }

  @override
  String deleteConnectionsConfirm(int count) {
    return '$count Verbindung(en) löschen?';
  }

  @override
  String deleteWolConfigsConfirm(int count) {
    return '$count Konfiguration(en) löschen?';
  }

  @override
  String sshKeyTypeLabel(String type) {
    return 'Typ: $type';
  }

  @override
  String sshKeyHostLabel(String host) {
    return 'Host: $host';
  }

  @override
  String sshKeyLastUsedLabel(String date) {
    return 'Letzte Verwendung: $date';
  }

  @override
  String get shutdownPcTitle => 'PC herunterfahren';

  @override
  String shutdownPcMessage(String name) {
    return 'Möchten Sie $name wirklich herunterfahren?\n\nDie SSH-Verbindung wird geschlossen.';
  }

  @override
  String get shutdownAction => 'Herunterfahren';

  @override
  String get searchPlaceholder => 'Suchen...';

  @override
  String get autoDetect => 'Automatisch';

  @override
  String get wolBiosTitle => '1. BIOS';

  @override
  String get wolBiosEnablePcie => '\"Power On By PCI-E\" aktivieren';

  @override
  String get wolBiosDisableErp => '\"ErP Ready\" deaktivieren';

  @override
  String get wolFastStartupTitle => '2. Schnellstart';

  @override
  String get wolFastStep1 => 'Energieoptionen → Systemeinstellungen';

  @override
  String get wolFastStep2 => 'Nicht verfügbare Einstellungen ändern';

  @override
  String get wolFastStep3 => '\"Schnellstart aktivieren\" deaktivieren';

  @override
  String get wolDeviceManagerTitle => '3. Geräte-Manager';

  @override
  String get wolDevStep1 => 'Netzwerkadapter → Energieverwaltung';

  @override
  String get wolDevStep2 => '\"Nur Magic Packet\" aktivieren';

  @override
  String get wolDevStep3 => 'Netzwerkadapter → Erweitert';

  @override
  String get wolDevStep4 => '\"Wake on Magic Packet\" aktivieren';

  @override
  String get wolMacConfigTitle => 'Konfiguration';

  @override
  String get wolMacStep1 => '1. Apple-Menü → Systemeinstellungen';

  @override
  String get wolMacStep2 => '2. Energie sparen';

  @override
  String get wolMacStep3 =>
      '3. \"Für Netzwerkzugriff reaktivieren\" aktivieren';

  @override
  String get sshKeySecurityTitle => 'Ihre Schlüssel schützen';

  @override
  String get sshKeySecurityDesc =>
      'Ihre SSH-Schlüssel funktionieren wie Passwörter, die Zugang zu Ihren Servern gewähren. Der private Schlüssel darf NIEMALS geteilt werden — nicht per E-Mail, Messenger oder Cloud-Speicher. Teilen Sie nur den öffentlichen Schlüssel mit den Servern, mit denen Sie sich verbinden möchten. ChillShell speichert Ihre Schlüssel sicher und ausschließlich auf Ihrem Gerät. Wenn Sie vermuten, dass ein Schlüssel kompromittiert wurde, löschen Sie ihn sofort und erstellen Sie einen neuen.';

  @override
  String get sshHostKeyTitle => 'Neuer Server';

  @override
  String sshHostKeyMessage(String host) {
    return 'Sie verbinden sich zum ersten Mal mit $host.\nÜberprüfen Sie den Server-Fingerabdruck vor dem Fortfahren:';
  }

  @override
  String sshHostKeyType(String type) {
    return 'Typ: $type';
  }

  @override
  String get sshHostKeyFingerprint => 'Fingerabdruck:';

  @override
  String get sshHostKeyAccept => 'Vertrauen und verbinden';

  @override
  String get sshHostKeyReject => 'Ablehnen';

  @override
  String get sshHostKeyMismatchTitle => 'Warnung — Schlüssel geändert!';

  @override
  String sshHostKeyMismatchMessage(String host) {
    return 'Der Serverschlüssel für $host hat sich geändert!\n\nDies könnte auf einen Man-in-the-Middle-Angriff hindeuten. Wenn Sie die Serverkonfiguration nicht geändert haben, lehnen Sie diese Verbindung ab.';
  }
}
