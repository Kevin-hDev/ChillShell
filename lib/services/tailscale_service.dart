import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/tailscale_device.dart';

/// Service de communication avec le plugin natif Tailscale et l'API REST.
///
/// - MethodChannel pour les opérations locales (login, logout, getStatus, getMyIP)
/// - API REST Tailscale pour la liste des machines distantes
class TailscaleService {
  static const _channel = MethodChannel('com.chillshell.tailscale');
  static const _apiBase = 'https://api.tailscale.com/api/v2';

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
      if (kDebugMode) debugPrint('TailscaleService: login error: $e');
      return null;
    }
  }

  /// Déconnecte Tailscale (coupe le tunnel VPN).
  Future<void> logout() async {
    try {
      await _channel.invokeMethod<void>('logout');
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('TailscaleService: logout error: $e');
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
      if (kDebugMode) debugPrint('TailscaleService: getStatus error: $e');
      return {'isConnected': false};
    }
  }

  /// Retourne l'IP Tailscale locale (100.x.y.z).
  Future<String?> getMyIP() async {
    try {
      final result = await _channel.invokeMethod<String>('getMyIP');
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('TailscaleService: getMyIP error: $e');
      return null;
    }
  }

  /// Récupère la liste des machines via l'API REST Tailscale.
  /// Nécessite un token OAuth valide.
  Future<List<TailscaleDevice>> fetchDevices(String token) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('$_apiBase/tailnet/-/devices'),
      );
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('TailscaleService: API error ${response.statusCode}: $body');
        }
        client.close();
        return [];
      }

      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final devicesJson = json['devices'] as List<dynamic>? ?? [];

      return devicesJson
          .map((d) => TailscaleDevice.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('TailscaleService: fetchDevices error: $e');
      return [];
    }
  }
}
