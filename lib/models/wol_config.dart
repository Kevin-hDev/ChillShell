import 'package:flutter/foundation.dart';

/// Configuration Wake-on-LAN pour réveiller un PC à distance.
///
/// Chaque configuration est liée à une connexion SSH sauvegardée
/// et permet d'envoyer un magic packet pour allumer le PC.
@immutable
class WolConfig {
  /// UUID unique de cette configuration
  final String id;

  /// Nom affiché (ex: "PC Bureau", "Serveur NAS")
  final String name;

  /// Adresse MAC de la carte réseau cible (format AA:BB:CC:DD:EE:FF)
  final String macAddress;

  /// Référence vers la connexion SSH sauvegardée associée
  final String sshConnectionId;

  /// Adresse de broadcast pour envoyer le magic packet
  final String broadcastAddress;

  /// Port UDP pour le magic packet (standard: 9)
  final int port;

  /// OS détecté automatiquement après première connexion SSH
  /// Valeurs possibles: "linux", "macos", "windows", null
  final String? detectedOS;

  const WolConfig({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.sshConnectionId,
    this.broadcastAddress = '255.255.255.255',
    this.port = 9,
    this.detectedOS,
  });

  WolConfig copyWith({
    String? id,
    String? name,
    String? macAddress,
    String? sshConnectionId,
    String? broadcastAddress,
    int? port,
    String? detectedOS,
  }) {
    return WolConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      sshConnectionId: sshConnectionId ?? this.sshConnectionId,
      broadcastAddress: broadcastAddress ?? this.broadcastAddress,
      port: port ?? this.port,
      detectedOS: detectedOS ?? this.detectedOS,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'macAddress': macAddress,
    'sshConnectionId': sshConnectionId,
    'broadcastAddress': broadcastAddress,
    'port': port,
    'detectedOS': detectedOS,
  };

  factory WolConfig.fromJson(Map<String, dynamic> json) => WolConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    macAddress: json['macAddress'] as String,
    sshConnectionId: json['sshConnectionId'] as String,
    broadcastAddress: json['broadcastAddress'] as String? ?? '255.255.255.255',
    port: json['port'] as int? ?? 9,
    detectedOS: json['detectedOS'] as String?,
  );
}
