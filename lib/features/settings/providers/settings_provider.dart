import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';
import '../../../services/storage_service.dart';
import '../../../services/secure_storage_service.dart';

class SettingsState {
  final List<SSHKey> sshKeys;
  final List<SavedConnection> savedConnections;
  final AppSettings appSettings;
  final bool isLoading;

  const SettingsState({
    this.sshKeys = const [],
    this.savedConnections = const [],
    required this.appSettings,
    this.isLoading = false,
  });

  SettingsState copyWith({
    List<SSHKey>? sshKeys,
    List<SavedConnection>? savedConnections,
    AppSettings? appSettings,
    bool? isLoading,
  }) {
    return SettingsState(
      sshKeys: sshKeys ?? this.sshKeys,
      savedConnections: savedConnections ?? this.savedConnections,
      appSettings: appSettings ?? this.appSettings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storage = StorageService();

  SettingsNotifier() : super(const SettingsState(appSettings: AppSettings())) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final settings = await _storage.getSettings();
      // Utiliser SecureStorageService pour les clés SSH (cohérence avec savePrivateKey)
      final sshKeys = await SecureStorageService.loadKeyMetadata();
      final savedConnections = await _storage.getSavedConnections();
      state = state.copyWith(
        appSettings: settings,
        sshKeys: sshKeys,
        savedConnections: savedConnections,
        isLoading: false,
      );
      debugPrint('Settings loaded');
    } catch (e) {
      debugPrint('Error loading settings: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _saveSettings() async {
    await _storage.saveSettings(state.appSettings);
  }

  Future<void> addSSHKey(SSHKey key) async {
    final newKeys = [...state.sshKeys, key];
    state = state.copyWith(sshKeys: newKeys);
    // Utiliser SecureStorageService pour la cohérence
    await SecureStorageService.saveKeyMetadata(newKeys);
    debugPrint('SSH key added');
  }

  Future<void> removeSSHKey(String id) async {
    final newKeys = state.sshKeys.where((k) => k.id != id).toList();
    state = state.copyWith(sshKeys: newKeys);
    // Supprimer la clé privée et mettre à jour les métadonnées
    await SecureStorageService.deleteKey(id, state.sshKeys);
    debugPrint('SSH key removed');
  }

  void updateTheme(AppTheme theme) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(theme: theme),
    );
    _saveSettings();
  }

  void toggleBiometric(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(biometricEnabled: enabled),
    );
    _saveSettings();
  }

  void toggleAutoLock(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(autoLockEnabled: enabled),
    );
    _saveSettings();
  }

  void toggleAutoConnect(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(autoConnectOnStart: enabled),
    );
    _saveSettings();
  }

  void toggleReconnect(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(reconnectOnDisconnect: enabled),
    );
    _saveSettings();
  }

  void toggleNotifyOnDisconnect(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(notifyOnDisconnect: enabled),
    );
    _saveSettings();
  }

  void toggleQuickAccess(String connectionId) {
    final connections = state.savedConnections.map((c) {
      if (c.id == connectionId) {
        return c.copyWith(isQuickAccess: !c.isQuickAccess);
      }
      return c;
    }).toList();
    state = state.copyWith(savedConnections: connections);
    // Sauvegarder chaque connexion modifiée
    for (final c in connections.where((c) => c.id == connectionId)) {
      _storage.saveConnection(c);
    }
  }

  void deleteSavedConnection(String id) {
    state = state.copyWith(
      savedConnections: state.savedConnections.where((c) => c.id != id).toList(),
    );
    _storage.deleteSavedConnection(id);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
