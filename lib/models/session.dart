import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

@immutable
class Session {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final ConnectionStatus status;
  final String? tmuxSession;
  final DateTime? lastConnected;
  final bool isQuickAccess;

  const Session({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.status = ConnectionStatus.disconnected,
    this.tmuxSession,
    this.lastConnected,
    this.isQuickAccess = true,
  });

  Session copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    ConnectionStatus? status,
    String? tmuxSession,
    DateTime? lastConnected,
    bool? isQuickAccess,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      status: status ?? this.status,
      tmuxSession: tmuxSession ?? this.tmuxSession,
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
    'tmuxSession': tmuxSession,
    'lastConnected': lastConnected?.toIso8601String(),
    'isQuickAccess': isQuickAccess,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int? ?? 22,
    username: json['username'] as String,
    tmuxSession: json['tmuxSession'] as String?,
    lastConnected: json['lastConnected'] != null
        ? DateTime.parse(json['lastConnected'] as String)
        : null,
    isQuickAccess: json['isQuickAccess'] as bool? ?? true,
  );
}
