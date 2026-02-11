import 'package:flutter/foundation.dart';

enum AppTheme {
  warpDark,
  dracula,
  nord,
  gruvbox,
  hybrid,
  afterglow,
  atelierSavanna,
  base2ToneDesert,
  base2ToneSea,
  belafonteDay,
  lunariaLight,
  lunariaDark,
}

/// Tailles de police disponibles pour le terminal
enum TerminalFontSize {
  xxs(10.0, 'XXS'),
  xs(12.0, 'XS'),
  s(14.0, 'S'),
  m(17.0, 'M'),
  l(20.0, 'L'),
  xl(24.0, 'XL');

  final double size;
  final String label;
  const TerminalFontSize(this.size, this.label);
}

@immutable
class AppSettings {
  final AppTheme theme;
  final bool autoConnectOnStart;
  final bool reconnectOnDisconnect;
  final bool notifyOnDisconnect;
  final bool biometricEnabled;
  final bool autoLockEnabled;
  final bool pinLockEnabled;
  final bool fingerprintEnabled;
  final int autoLockMinutes;  // 5, 10, 15 ou 30
  final bool wolEnabled;  // Wake-on-LAN
  final bool allowScreenshots;  // Autoriser les captures d'écran (désactivé par défaut)
  // Multi-langues et taille de police
  final String? languageCode;  // null = auto-détection
  final TerminalFontSize terminalFontSize;
  // Tailscale
  final bool tailscaleEnabled;
  final String? tailscaleDeviceName;

  const AppSettings({
    this.theme = AppTheme.warpDark,
    this.autoConnectOnStart = true,
    this.reconnectOnDisconnect = true,
    this.notifyOnDisconnect = false,
    this.biometricEnabled = false,
    this.autoLockEnabled = false,
    this.pinLockEnabled = false,
    this.fingerprintEnabled = false,
    this.autoLockMinutes = 10,
    this.wolEnabled = false,
    this.allowScreenshots = false,
    this.languageCode,
    this.terminalFontSize = TerminalFontSize.m,
    this.tailscaleEnabled = false,
    this.tailscaleDeviceName,
  });

  AppSettings copyWith({
    AppTheme? theme,
    bool? autoConnectOnStart,
    bool? reconnectOnDisconnect,
    bool? notifyOnDisconnect,
    bool? biometricEnabled,
    bool? autoLockEnabled,
    bool? pinLockEnabled,
    bool? fingerprintEnabled,
    int? autoLockMinutes,
    bool? wolEnabled,
    bool? allowScreenshots,
    String? languageCode,
    bool clearLanguageCode = false,
    TerminalFontSize? terminalFontSize,
    bool? tailscaleEnabled,
    String? tailscaleDeviceName,
    bool clearTailscaleDeviceName = false,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      autoConnectOnStart: autoConnectOnStart ?? this.autoConnectOnStart,
      reconnectOnDisconnect: reconnectOnDisconnect ?? this.reconnectOnDisconnect,
      notifyOnDisconnect: notifyOnDisconnect ?? this.notifyOnDisconnect,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockEnabled: autoLockEnabled ?? this.autoLockEnabled,
      pinLockEnabled: pinLockEnabled ?? this.pinLockEnabled,
      fingerprintEnabled: fingerprintEnabled ?? this.fingerprintEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      wolEnabled: wolEnabled ?? this.wolEnabled,
      allowScreenshots: allowScreenshots ?? this.allowScreenshots,
      languageCode: clearLanguageCode ? null : (languageCode ?? this.languageCode),
      terminalFontSize: terminalFontSize ?? this.terminalFontSize,
      tailscaleEnabled: tailscaleEnabled ?? this.tailscaleEnabled,
      tailscaleDeviceName: clearTailscaleDeviceName ? null : (tailscaleDeviceName ?? this.tailscaleDeviceName),
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'autoConnectOnStart': autoConnectOnStart,
    'reconnectOnDisconnect': reconnectOnDisconnect,
    'notifyOnDisconnect': notifyOnDisconnect,
    'biometricEnabled': biometricEnabled,
    'autoLockEnabled': autoLockEnabled,
    'pinLockEnabled': pinLockEnabled,
    'fingerprintEnabled': fingerprintEnabled,
    'autoLockMinutes': autoLockMinutes,
    'wolEnabled': wolEnabled,
    'allowScreenshots': allowScreenshots,
    'languageCode': languageCode,
    'terminalFontSize': terminalFontSize.name,
    'tailscaleEnabled': tailscaleEnabled,
    'tailscaleDeviceName': tailscaleDeviceName,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme: AppTheme.values.byName(json['theme'] as String? ?? 'warpDark'),
    autoConnectOnStart: json['autoConnectOnStart'] as bool? ?? true,
    reconnectOnDisconnect: json['reconnectOnDisconnect'] as bool? ?? true,
    notifyOnDisconnect: json['notifyOnDisconnect'] as bool? ?? false,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    autoLockEnabled: json['autoLockEnabled'] as bool? ?? false,
    pinLockEnabled: json['pinLockEnabled'] as bool? ?? false,
    fingerprintEnabled: json['fingerprintEnabled'] as bool? ?? false,
    autoLockMinutes: json['autoLockMinutes'] as int? ?? 10,
    wolEnabled: json['wolEnabled'] as bool? ?? false,
    allowScreenshots: json['allowScreenshots'] as bool? ?? false,
    languageCode: json['languageCode'] as String?,
    terminalFontSize: TerminalFontSize.values.byName(
      json['terminalFontSize'] as String? ?? 'm',
    ),
    tailscaleEnabled: json['tailscaleEnabled'] as bool? ?? false,
    tailscaleDeviceName: json['tailscaleDeviceName'] as String?,
  );
}
