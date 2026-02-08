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

class SettingsNotifier extends Notifier<SettingsState> {
  final StorageService _storage = StorageService();

  @override
  SettingsState build() {
    Future.microtask(_loadSettings);
    return const SettingsState(appSettings: AppSettings(), isLoading: true);
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final settings = await _storage.getSettings();
      // Utiliser SecureStorageService pour les clés SSH (cohérence avec savePrivateKey)
      final sshKeys = await SecureStorageService.loadKeyMetadata();
      var savedConnections = await _storage.getSavedConnections();

      // S'assurer qu'une seule connexion est marquée comme quick access
      final activeCount = savedConnections.where((c) => c.isQuickAccess).length;
      if (savedConnections.isNotEmpty && activeCount != 1) {
        // Si 0 ou plus de 1 connexion active, normaliser : seule la première est active
        savedConnections = savedConnections.asMap().entries.map((entry) {
          return entry.value.copyWith(isQuickAccess: entry.key == 0);
        }).toList();
        // Sauvegarder les connexions normalisées
        for (final c in savedConnections) {
          _storage.saveConnection(c);
        }
      }

      state = state.copyWith(
        appSettings: settings,
        sshKeys: sshKeys,
        savedConnections: savedConnections,
        isLoading: false,
      );
      if (kDebugMode) debugPrint('Settings loaded');
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading settings: $e');
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
    if (kDebugMode) debugPrint('SSH key added');
  }

  Future<void> removeSSHKey(String id) async {
    final newKeys = state.sshKeys.where((k) => k.id != id).toList();
    state = state.copyWith(sshKeys: newKeys);
    // Supprimer la clé privée et mettre à jour les métadonnées
    await SecureStorageService.deleteKey(id, state.sshKeys);
    if (kDebugMode) debugPrint('SSH key removed');
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

  void togglePinLock(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(pinLockEnabled: enabled),
    );
    _saveSettings();
  }

  void toggleFingerprint(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(fingerprintEnabled: enabled),
    );
    _saveSettings();
  }

  void setAutoLockMinutes(int minutes) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(autoLockMinutes: minutes),
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

  void toggleWolEnabled(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(wolEnabled: enabled),
    );
    _saveSettings();
  }

  void setLanguage(String? languageCode) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(
        languageCode: languageCode,
        clearLanguageCode: languageCode == null,
      ),
    );
    _saveSettings();
  }

  void setFontSize(TerminalFontSize fontSize) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(terminalFontSize: fontSize),
    );
    _saveSettings();
  }

  /// Sélectionne UNE connexion comme connexion automatique.
  /// Désélectionne automatiquement l'ancienne.
  Future<void> selectAutoConnection(String connectionId) async {
    final connections = state.savedConnections.map((c) {
      // La connexion sélectionnée devient active, les autres sont désactivées
      return c.copyWith(isQuickAccess: c.id == connectionId);
    }).toList();
    state = state.copyWith(savedConnections: connections);
    // Sauvegarder toutes les connexions modifiées (avec await pour persister avant fermeture)
    for (final c in connections) {
      await _storage.saveConnection(c);
    }
  }

  void deleteSavedConnection(String id) {
    final wasSelected = state.savedConnections.firstWhere(
      (c) => c.id == id,
      orElse: () => const SavedConnection(id: '', name: '', host: '', username: '', keyId: ''),
    ).isQuickAccess;

    var newConnections = state.savedConnections.where((c) => c.id != id).toList();

    // Si la connexion supprimée était sélectionnée, sélectionner la première de la liste
    if (wasSelected && newConnections.isNotEmpty) {
      newConnections = newConnections.asMap().entries.map((entry) {
        final index = entry.key;
        final c = entry.value;
        return c.copyWith(isQuickAccess: index == 0);
      }).toList();
      // Sauvegarder la nouvelle sélection
      if (newConnections.isNotEmpty) {
        _storage.saveConnection(newConnections.first);
      }
    }

    state = state.copyWith(savedConnections: newConnections);
    _storage.deleteSavedConnection(id);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
