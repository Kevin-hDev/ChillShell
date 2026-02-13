import 'package:flutter/foundation.dart';

enum SSHKeyType { ed25519, rsa }

@immutable
class SSHKey {
  final String id;
  final String name;
  final String host;
  final SSHKeyType type;
  final String privateKey;
  final DateTime createdAt;
  final DateTime? lastUsed;

  const SSHKey({
    required this.id,
    required this.name,
    required this.host,
    required this.type,
    required this.privateKey,
    required this.createdAt,
    this.lastUsed,
  });

  SSHKey copyWith({
    String? id,
    String? name,
    String? host,
    SSHKeyType? type,
    String? privateKey,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return SSHKey(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      type: type ?? this.type,
      privateKey: privateKey ?? this.privateKey,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'lastUsed': lastUsed?.toIso8601String(),
  };

  factory SSHKey.fromJson(Map<String, dynamic> json) => SSHKey(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    type: SSHKeyType.values.byName(json['type'] as String),
    privateKey: (json['privateKey'] as String?) ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastUsed: json['lastUsed'] != null
        ? DateTime.parse(json['lastUsed'] as String)
        : null,
  );

  String get typeLabel => type == SSHKeyType.ed25519 ? 'ED25519' : 'RSA';

  @override
  String toString() => 'SSHKey(id=$id, name=$name, type=${type.name})';
}
