import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class StorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // SSH Keys
  Future<void> saveSSHKey(SSHKey key) async {
    final keys = await getSSHKeys();
    final existingIndex = keys.indexWhere((k) => k.id == key.id);

    if (existingIndex >= 0) {
      keys[existingIndex] = key;
    } else {
      keys.add(key);
    }

    await _storage.write(
      key: 'ssh_keys',
      value: jsonEncode(keys.map((k) => k.toJson()).toList()),
    );
  }

  Future<List<SSHKey>> getSSHKeys() async {
    final data = await _storage.read(key: 'ssh_keys');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list
          .map((json) => SSHKey.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode)
        debugPrint('Error decoding SSH keys, returning empty list');
      return [];
    }
  }

  Future<SSHKey?> getSSHKeyForHost(String host) async {
    final keys = await getSSHKeys();
    try {
      return keys.firstWhere((k) => k.host == host);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSSHKey(String id) async {
    final keys = await getSSHKeys();
    keys.removeWhere((k) => k.id == id);
    await _storage.write(
      key: 'ssh_keys',
      value: jsonEncode(keys.map((k) => k.toJson()).toList()),
    );
  }

  Future<void> deleteAllKeys() async {
    await _storage.delete(key: 'ssh_keys');
  }

  // App Settings
  Future<void> saveSettings(AppSettings settings) async {
    await _storage.write(
      key: 'app_settings',
      value: jsonEncode(settings.toJson()),
    );
  }

  Future<AppSettings> getSettings() async {
    final data = await _storage.read(key: 'app_settings');
    if (data == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('Error decoding settings, returning defaults');
      return const AppSettings();
    }
  }

  // Saved Connections
  Future<void> saveConnection(SavedConnection connection) async {
    final connections = await getSavedConnections();
    final existingIndex = connections.indexWhere((c) => c.id == connection.id);

    if (existingIndex >= 0) {
      connections[existingIndex] = connection;
    } else {
      connections.add(connection);
    }

    await _storage.write(
      key: 'saved_connections',
      value: jsonEncode(connections.map((c) => c.toJson()).toList()),
    );
  }

  Future<List<SavedConnection>> getSavedConnections() async {
    final data = await _storage.read(key: 'saved_connections');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list
          .map((json) => SavedConnection.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode)
        debugPrint('Error decoding saved connections, returning empty list');
      return [];
    }
  }

  Future<void> deleteSavedConnection(String id) async {
    final connections = await getSavedConnections();
    connections.removeWhere((c) => c.id == id);
    await _storage.write(
      key: 'saved_connections',
      value: jsonEncode(connections.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> updateConnectionLastConnected(String id) async {
    final connections = await getSavedConnections();
    final index = connections.indexWhere((c) => c.id == id);
    if (index >= 0) {
      connections[index] = connections[index].copyWith(
        lastConnected: DateTime.now(),
      );
      await _storage.write(
        key: 'saved_connections',
        value: jsonEncode(connections.map((c) => c.toJson()).toList()),
      );
    }
  }

  // Command History (V2: with timestamps for TTL expiration)
  Future<void> saveCommandHistory(List<String> history) async {
    // Delegate to V2 format with current timestamp for all entries
    final now = DateTime.now().millisecondsSinceEpoch;
    final entries = history.map((c) => {'c': c, 't': now}).toList();
    await saveCommandHistoryV2(entries);
  }

  Future<List<String>> getCommandHistory() async {
    // Delegate to V2 and extract just the command strings
    final entries = await getCommandHistoryV2();
    return entries.map((e) => e['c'] as String).toList();
  }

  /// Saves command history with per-entry timestamps (V2 format).
  /// Each entry: {"c": "command", "t": timestamp_ms}
  Future<void> saveCommandHistoryV2(List<Map<String, dynamic>> entries) async {
    await _storage.write(key: 'command_history', value: jsonEncode(entries));
  }

  /// Loads command history with timestamps (V2 format).
  /// Handles migration from V1 (plain strings) to V2 automatically.
  Future<List<Map<String, dynamic>>> getCommandHistoryV2() async {
    final data = await _storage.read(key: 'command_history');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      if (list.isEmpty) return [];

      // V1 migration: plain strings → add current timestamp
      if (list.first is String) {
        final now = DateTime.now().millisecondsSinceEpoch;
        return list
            .map((e) => <String, dynamic>{'c': e.toString(), 't': now})
            .toList();
      }

      // V2 format: objects with 'c' and 't'
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      if (kDebugMode)
        debugPrint('Error decoding command history, returning empty list');
      return [];
    }
  }
}
