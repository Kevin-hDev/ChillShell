import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Service pour maintenir les connexions SSH actives en arrière-plan
class ForegroundSSHService {
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// Initialise le service (appeler dans main())
  static void init() {
    FlutterForegroundTask.initCommunicationPort();
  }

  /// Démarre le service foreground
  static Future<bool> start({required String connectionInfo}) async {
    if (_isRunning) return true;

    // Configurer les options Android
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'chillshell_ssh',
        channelName: 'ChillShell SSH',
        channelDescription: 'Maintient la connexion SSH active',
        onlyAlertOnce: true,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    // Démarrer le service
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'ChillShell',
      notificationText: connectionInfo,
      notificationIcon: null,
    );

    _isRunning = result is ServiceRequestSuccess;
    if (kDebugMode) debugPrint('ForegroundSSHService: Started = $_isRunning');
    return _isRunning;
  }

  /// Met à jour le texte de la notification
  static Future<void> updateNotification(String text) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: 'ChillShell',
      notificationText: text,
    );
  }

  /// Arrête le service foreground
  static Future<void> stop() async {
    if (!_isRunning) return;

    await FlutterForegroundTask.stopService();
    _isRunning = false;
    if (kDebugMode) debugPrint('ForegroundSSHService: Stopped');
  }
}
