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

@immutable
class AppSettings {
  final AppTheme theme;
  final bool autoConnectOnStart;
  final bool reconnectOnDisconnect;
  final bool notifyOnDisconnect;
  final bool biometricEnabled;
  final bool autoLockEnabled;
  // Nouveaux champs pour paramétrage fin
  final bool faceIdEnabled;
  final bool fingerprintEnabled;
  final int autoLockMinutes;  // 5, 10, 15 ou 30
  final bool wolEnabled;  // Wake-on-LAN

  const AppSettings({
    this.theme = AppTheme.warpDark,
    this.autoConnectOnStart = true,
    this.reconnectOnDisconnect = true,
    this.notifyOnDisconnect = false,
    this.biometricEnabled = false,
    this.autoLockEnabled = false,
    this.faceIdEnabled = false,
    this.fingerprintEnabled = false,
    this.autoLockMinutes = 10,
    this.wolEnabled = false,
  });

  AppSettings copyWith({
    AppTheme? theme,
    bool? autoConnectOnStart,
    bool? reconnectOnDisconnect,
    bool? notifyOnDisconnect,
    bool? biometricEnabled,
    bool? autoLockEnabled,
    bool? faceIdEnabled,
    bool? fingerprintEnabled,
    int? autoLockMinutes,
    bool? wolEnabled,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      autoConnectOnStart: autoConnectOnStart ?? this.autoConnectOnStart,
      reconnectOnDisconnect: reconnectOnDisconnect ?? this.reconnectOnDisconnect,
      notifyOnDisconnect: notifyOnDisconnect ?? this.notifyOnDisconnect,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockEnabled: autoLockEnabled ?? this.autoLockEnabled,
      faceIdEnabled: faceIdEnabled ?? this.faceIdEnabled,
      fingerprintEnabled: fingerprintEnabled ?? this.fingerprintEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      wolEnabled: wolEnabled ?? this.wolEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'autoConnectOnStart': autoConnectOnStart,
    'reconnectOnDisconnect': reconnectOnDisconnect,
    'notifyOnDisconnect': notifyOnDisconnect,
    'biometricEnabled': biometricEnabled,
    'autoLockEnabled': autoLockEnabled,
    'faceIdEnabled': faceIdEnabled,
    'fingerprintEnabled': fingerprintEnabled,
    'autoLockMinutes': autoLockMinutes,
    'wolEnabled': wolEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme: AppTheme.values.byName(json['theme'] as String? ?? 'warpDark'),
    autoConnectOnStart: json['autoConnectOnStart'] as bool? ?? true,
    reconnectOnDisconnect: json['reconnectOnDisconnect'] as bool? ?? true,
    notifyOnDisconnect: json['notifyOnDisconnect'] as bool? ?? false,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    autoLockEnabled: json['autoLockEnabled'] as bool? ?? false,
    faceIdEnabled: json['faceIdEnabled'] as bool? ?? false,
    fingerprintEnabled: json['fingerprintEnabled'] as bool? ?? false,
    autoLockMinutes: json['autoLockMinutes'] as int? ?? 10,
    wolEnabled: json['wolEnabled'] as bool? ?? false,
  );
}
