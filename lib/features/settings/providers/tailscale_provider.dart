import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/tailscale_device.dart';
import '../../../services/tailscale_service.dart';
import '../../../core/security/secure_logger.dart';
import 'settings_provider.dart';

class TailscaleState {
  final bool isConnected;
  final bool isLoading;
  final String? myIP;
  final String? deviceName;
  final List<TailscaleDevice> devices;
  final String? error;

  const TailscaleState({
    this.isConnected = false,
    this.isLoading = false,
    this.myIP,
    this.deviceName,
    this.devices = const [],
    this.error,
  });

  TailscaleState copyWith({
    bool? isConnected,
    bool? isLoading,
    String? myIP,
    bool clearMyIP = false,
    String? deviceName,
    bool clearDeviceName = false,
    List<TailscaleDevice>? devices,
    String? error,
    bool clearError = false,
  }) {
    return TailscaleState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      myIP: clearMyIP ? null : (myIP ?? this.myIP),
      deviceName: clearDeviceName ? null : (deviceName ?? this.deviceName),
      devices: devices ?? this.devices,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TailscaleNotifier extends Notifier<TailscaleState> {
  final TailscaleService _service = TailscaleService();

  @override
  TailscaleState build() {
    _service.onStateChanged = _onNativeStateChanged;
    ref.onDispose(() => _service.onStateChanged = null);
    Future.microtask(_init);
    return const TailscaleState();
  }

  void _onNativeStateChanged(Map<String, dynamic> data) {
    final wasConnected = state.isConnected;
    final isConnected = data['isConnected'] as bool? ?? state.isConnected;
    final ip = data['myIP'] as String?;
    final deviceName = data['deviceName'] as String?;

    state = state.copyWith(
      isConnected: isConnected,
      myIP: ip,
      deviceName: deviceName,
      isLoading: false,
      clearError: true,
    );

    if (isConnected && !wasConnected) {
      ref
          .read(settingsProvider.notifier)
          .updateTailscaleSettings(enabled: true);
      // Charger la liste des peers dès qu'on est connecté
      _fetchPeers();
    }
    if (deviceName != null) {
      ref
          .read(settingsProvider.notifier)
          .updateTailscaleSettings(deviceName: deviceName);
    }
  }

  /// Initialise l'état Tailscale au démarrage.
  /// Vérifie le statut actuel si Tailscale est activé.
  Future<void> _init() async {
    final settings = ref.read(settingsProvider).appSettings;

    if (!settings.tailscaleEnabled) return;

    state = state.copyWith(isLoading: true);

    try {
      final status = await _service.getStatus();
      final isConnected = status['isConnected'] as bool? ?? false;
      final ip = status['myIP'] as String?;
      final deviceName = status['deviceName'] as String?;

      state = state.copyWith(
        isConnected: isConnected,
        myIP: ip,
        deviceName: deviceName,
        isLoading: false,
        clearError: true,
      );

      if (isConnected) {
        await _fetchPeers();
      }
    } catch (e) {
      SecureLogger.logError('TailscaleNotifier', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Démarre le flux de connexion Tailscale (OAuth).
  Future<void> login() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final loginResult = await _service.login();
      if (loginResult == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      // Le plugin natif a démarré le VPN service.
      // Le token OAuth sera obtenu via l'API REST côté Dart.
      // Pour l'instant, on active Tailscale et on récupère le statut.
      ref
          .read(settingsProvider.notifier)
          .updateTailscaleSettings(enabled: true);

      // Récupérer le statut après connexion
      final status = await _service.getStatus();
      final isConnected = status['isConnected'] as bool? ?? false;
      final ip = status['myIP'] as String?;
      final deviceName = status['deviceName'] as String?;

      state = state.copyWith(
        isConnected: isConnected,
        myIP: ip,
        deviceName: deviceName,
        isLoading: false,
        clearError: true,
      );

      // Sauvegarder le nom de l'appareil
      if (deviceName != null) {
        ref
            .read(settingsProvider.notifier)
            .updateTailscaleSettings(deviceName: deviceName);
      }

      // Récupérer la liste des appareils via LocalAPI
      if (isConnected) {
        await _fetchPeers();
      }
    } catch (e) {
      SecureLogger.logError('TailscaleNotifier', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Déconnecte Tailscale.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.logout();

      // Nettoyer les settings
      ref
          .read(settingsProvider.notifier)
          .updateTailscaleSettings(enabled: false, clearDeviceName: true);

      state = const TailscaleState();
    } catch (e) {
      SecureLogger.logError('TailscaleNotifier', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Rafraîchit la liste des appareils.
  Future<void> refreshDevices() async {
    await _fetchPeers();
  }

  /// Récupère la liste des peers via la LocalAPI Go.
  Future<void> _fetchPeers() async {
    try {
      final devices = await _service.getPeers();
      // Trier: en ligne d'abord, hors ligne ensuite
      devices.sort((a, b) {
        if (a.isOnline == b.isOnline) return a.name.compareTo(b.name);
        return a.isOnline ? -1 : 1;
      });
      state = state.copyWith(devices: devices);
    } catch (e) {
      SecureLogger.logError('TailscaleNotifier', e);
    }
  }
}

final tailscaleProvider = NotifierProvider<TailscaleNotifier, TailscaleState>(
  TailscaleNotifier.new,
);
