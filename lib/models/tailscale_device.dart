import 'package:flutter/foundation.dart';

@immutable
class TailscaleDevice {
  final String name;
  final String ip;
  final bool isOnline;
  final String? os;
  final String id;

  const TailscaleDevice({
    required this.name,
    required this.ip,
    required this.isOnline,
    this.os,
    required this.id,
  });

  TailscaleDevice copyWith({
    String? name,
    String? ip,
    bool? isOnline,
    String? os,
    String? id,
  }) {
    return TailscaleDevice(
      name: name ?? this.name,
      ip: ip ?? this.ip,
      isOnline: isOnline ?? this.isOnline,
      os: os ?? this.os,
      id: id ?? this.id,
    );
  }

  factory TailscaleDevice.fromJson(Map<String, dynamic> json) {
    // Parse addresses: Tailscale API returns a list like ["100.x.y.z/32", "fd7a:..."]
    final addresses = json['addresses'] as List<dynamic>? ?? [];
    String ip = '';
    for (final addr in addresses) {
      final addrStr = addr.toString();
      // Take the first IPv4 address (starts with 100.)
      if (addrStr.startsWith('100.')) {
        ip = addrStr.split('/').first;
        break;
      }
    }
    // Fallback: take the first address if no 100.x address found
    if (ip.isEmpty && addresses.isNotEmpty) {
      ip = addresses.first.toString().split('/').first;
    }

    return TailscaleDevice(
      name: json['name'] as String? ?? '',
      ip: ip,
      isOnline: json['online'] as bool? ?? false,
      os: json['os'] as String?,
      id: json['id'] as String? ?? json['nodeId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'ip': ip,
    'isOnline': isOnline,
    'os': os,
    'id': id,
  };
}
