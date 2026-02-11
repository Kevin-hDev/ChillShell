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
}
