import 'package:flutter/services.dart';
import '../models/tailscale_device.dart';
import '../core/security/secure_logger.dart';
// FIX-023 — TailscalePrivacy & TailscaleMonitor
// ignore: unused_import
import '../core/security/tailscale_privacy.dart';
// TODO FIX-023: Integrer TailscalePrivacy.monitorTraffic() pour detecter
// les patterns de botnet (SSHStalker, AyySSHush, burst patterns)

/// Service de communication avec le plugin natif Tailscale via MethodChannel.
///
/// - MethodChannel pour login, logout, getStatus, getMyIP, getPeers
/// - Les peers sont récupérés via la LocalAPI Go (pas besoin de token REST)
class TailscaleService {
  static const _channel = MethodChannel('com.chillshell.tailscale');

  /// Callback appelé par le natif quand l'état Tailscale change.
  void Function(Map<String, dynamic> state)? onStateChanged;

  TailscaleService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onStateChanged' && onStateChanged != null) {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      onStateChanged!(args);
    }
  }

  /// Démarre le flux OAuth Tailscale (côté Android: demande permission VPN + lance le service).
  /// Retourne une Map avec le résultat du login, ou null si erreur.
  Future<Map<String, dynamic>?> login() async {
    try {
      final result = await _channel.invokeMethod<Map>('login');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } on PlatformException catch (e) {
      SecureLogger.logError('TailscaleService', e);
      return null;
    }
  }

  /// Déconnecte Tailscale (coupe le tunnel VPN).
  Future<void> logout() async {
    try {
      await _channel.invokeMethod<void>('logout');
    } on PlatformException catch (e) {
      SecureLogger.logError('TailscaleService', e);
    }
  }

  /// Retourne le statut de connexion Tailscale.
  /// Retourne une Map avec les clés: 'isConnected' (bool), 'ip' (String?), 'deviceName' (String?)
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getStatus');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
      return {'isConnected': false};
    } on PlatformException catch (e) {
      SecureLogger.logError('TailscaleService', e);
      return {'isConnected': false};
    }
  }

  /// Récupère la liste des peers via la LocalAPI Go (pas besoin de token REST).
  Future<List<TailscaleDevice>> getPeers() async {
    try {
      final result = await _channel.invokeMethod<List>('getPeers');
      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return TailscaleDevice(
          name: map['name'] as String? ?? '',
          ip: map['ip'] as String? ?? '',
          isOnline: map['isOnline'] as bool? ?? false,
          os: map['os'] as String? ?? '',
          id: map['id'] as String? ?? '',
        );
      }).toList();
    } on PlatformException catch (e) {
      SecureLogger.logError('TailscaleService', e);
      return [];
    }
  }
}
