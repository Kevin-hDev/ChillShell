import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../models/saved_connection.dart';
import '../../../models/wol_config.dart';

/// État du provider WOL contenant la liste des configurations.
class WolState {
  final List<WolConfig> configs;
  final bool isLoading;

  const WolState({
    this.configs = const [],
    this.isLoading = false,
  });

  WolState copyWith({
    List<WolConfig>? configs,
    bool? isLoading,
  }) {
    return WolState(
      configs: configs ?? this.configs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier pour gérer les configurations Wake-on-LAN.
///
/// Utilise flutter_secure_storage pour stocker les configurations
/// de manière sécurisée sur l'appareil.
class WolNotifier extends Notifier<WolState> {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _wolConfigsKey = 'wol_configs';

  @override
  WolState build() {
    Future.microtask(loadConfigs);
    return const WolState();
  }

  /// Charge les configurations WOL depuis le stockage sécurisé.
  Future<void> loadConfigs() async {
    state = state.copyWith(isLoading: true);
    try {
      final jsonString = await _storage.read(key: _wolConfigsKey);
      if (jsonString == null) {
        state = state.copyWith(configs: [], isLoading: false);
        return;
      }

      final jsonList = jsonDecode(jsonString) as List;
      final configs = jsonList
          .map((json) => WolConfig.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(configs: configs, isLoading: false);
      if (kDebugMode) debugPrint('WOL configs loaded: ${configs.length} configurations');
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading WOL configs: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Sauvegarde les configurations dans le stockage sécurisé.
  Future<void> _saveConfigs() async {
    try {
      final jsonList = state.configs.map((c) => c.toJson()).toList();
      await _storage.write(key: _wolConfigsKey, value: jsonEncode(jsonList));
      if (kDebugMode) debugPrint('WOL configs saved');
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving WOL configs: $e');
    }
  }

  /// Ajoute une nouvelle configuration WOL et la sauvegarde.
  Future<void> addConfig(WolConfig config) async {
    final newConfigs = [...state.configs, config];
    state = state.copyWith(configs: newConfigs);
    await _saveConfigs();
    if (kDebugMode) debugPrint('WOL config added: ${config.name}');
  }

  /// Met à jour une configuration existante par son ID.
  Future<void> updateConfig(WolConfig config) async {
    final newConfigs = state.configs.map((c) {
      return c.id == config.id ? config : c;
    }).toList();
    state = state.copyWith(configs: newConfigs);
    await _saveConfigs();
    if (kDebugMode) debugPrint('WOL config updated: ${config.name}');
  }

  /// Supprime une configuration par son ID.
  Future<void> deleteConfig(String configId) async {
    final newConfigs = state.configs.where((c) => c.id != configId).toList();
    state = state.copyWith(configs: newConfigs);
    await _saveConfigs();
    if (kDebugMode) debugPrint('WOL config deleted: $configId');
  }

  /// Récupère la configuration associée à une connexion SSH.
  ///
  /// Retourne null si aucune configuration n'est associée.
  WolConfig? getConfigForSshConnection(String sshConnectionId) {
    try {
      return state.configs.firstWhere(
        (c) => c.sshConnectionId == sshConnectionId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Récupère une configuration par son ID.
  ///
  /// Retourne null si la configuration n'existe pas.
  WolConfig? getConfigById(String id) {
    try {
      return state.configs.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Récupère la configuration WOL associée à une session active.
  ///
  /// Cherche en comparant les savedConnections avec host/username de la session.
  /// [savedConnections] Liste des connexions sauvegardées
  /// [sessionHost] Host de la session active
  /// [sessionUsername] Username de la session active
  WolConfig? getConfigForSession(
    List<SavedConnection> savedConnections,
    String sessionHost,
    String sessionUsername,
  ) {
    // Trouver la SavedConnection correspondante
    try {
      final savedConnection = savedConnections.firstWhere(
        (c) => c.host == sessionHost && c.username == sessionUsername,
      );
      // Chercher la WolConfig par l'ID de la SavedConnection
      return getConfigForSshConnection(savedConnection.id);
    } catch (_) {
      return null;
    }
  }
}

/// Provider global pour la gestion des configurations WOL.
final wolProvider = NotifierProvider<WolNotifier, WolState>(
  WolNotifier.new,
);
