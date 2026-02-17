import 'package:flutter/foundation.dart';

@immutable
class SavedConnection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String keyId;
  final DateTime? lastConnected;
  final bool isQuickAccess;

  const SavedConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    required this.keyId,
    this.lastConnected,
    this.isQuickAccess = false,
  });

  SavedConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? keyId,
    DateTime? lastConnected,
    bool? isQuickAccess,
  }) {
    return SavedConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      keyId: keyId ?? this.keyId,
      lastConnected: lastConnected ?? this.lastConnected,
      isQuickAccess: isQuickAccess ?? this.isQuickAccess,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'keyId': keyId,
    'lastConnected': lastConnected?.toIso8601String(),
    'isQuickAccess': isQuickAccess,
  };

  factory SavedConnection.fromJson(Map<String, dynamic> json) =>
      SavedConnection(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int? ?? 22,
        username: json['username'] as String,
        keyId: json['keyId'] as String,
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'] as String)
            : null,
        isQuickAccess: json['isQuickAccess'] as bool? ?? false,
      );
}
