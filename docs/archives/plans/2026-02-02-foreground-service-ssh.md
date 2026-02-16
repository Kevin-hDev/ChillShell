# Foreground Service SSH - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Maintenir les connexions SSH actives en arrière-plan via un Foreground Service Android.

**Architecture:** Utiliser `flutter_foreground_task` pour créer un service Android qui empêche le système de tuer les sockets SSH. Le service affiche une notification discrète et se gère automatiquement selon le cycle de vie de l'app.

**Tech Stack:** flutter_foreground_task ^9.2.0, Android Foreground Service, dataSync foregroundServiceType

---

## Task 1: Ajouter la dépendance flutter_foreground_task

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Ajouter le package**

```yaml
dependencies:
  flutter_foreground_task: ^9.2.0
```

**Step 2: Installer les dépendances**

Run: `flutter pub get`
Expected: Resolving dependencies... Done!

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add flutter_foreground_task for background SSH"
```

---

## Task 2: Configurer AndroidManifest.xml

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`

**Step 1: Ajouter les permissions (après les autres permissions)**

```xml
<!-- Foreground Service pour SSH -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
```

**Step 2: Déclarer le service (dans la balise <application>)**

```xml
<!-- Foreground Service -->
<service
    android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
    android:foregroundServiceType="dataSync"
    android:stopWithTask="false"
    android:exported="false" />
```

**Step 3: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "config: add foreground service permissions and declaration"
```

---

## Task 3: Créer le service ForegroundSSHService

**Files:**
- Create: `lib/services/foreground_ssh_service.dart`

**Step 1: Créer le fichier avec le service**

```dart
import 'package:flutter/material.dart';
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
  static Future<bool> start({
    required String connectionInfo,
  }) async {
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
      notificationIcon: null, // Utilise l'icône par défaut
    );

    _isRunning = result == ServiceRequestResult.success;
    debugPrint('ForegroundSSHService: Started = $_isRunning');
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
    debugPrint('ForegroundSSHService: Stopped');
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/foreground_ssh_service.dart
git commit -m "feat: create ForegroundSSHService for background SSH"
```

---

## Task 4: Initialiser le service dans main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Ajouter l'import**

```dart
import 'services/foreground_ssh_service.dart';
```

**Step 2: Initialiser dans main()**

Modifier la fonction `main()` :

```dart
void main() {
  ForegroundSSHService.init();
  runApp(const ProviderScope(child: VibeTermApp()));
}
```

**Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize ForegroundSSHService in main"
```

---

## Task 5: Intégrer avec SSHProvider

**Files:**
- Modify: `lib/features/terminal/providers/ssh_provider.dart`

**Step 1: Ajouter l'import**

```dart
import '../../../services/foreground_ssh_service.dart';
```

**Step 2: Démarrer le service après connexion SSH réussie**

Dans la méthode `connect()`, après `_startConnectionMonitor();` et `await _updateWakelock();` :

```dart
// Démarrer le foreground service pour maintenir la connexion
await ForegroundSSHService.start(
  connectionInfo: 'Connecté à $host',
);
```

**Step 3: Démarrer le service après connexion Local Shell**

Dans la méthode `connectLocal()`, après `await _updateWakelock();` :

```dart
// Démarrer le foreground service
await ForegroundSSHService.start(
  connectionInfo: 'Shell local actif',
);
```

**Step 4: Arrêter le service dans disconnect()**

Dans la méthode `disconnect()`, après `await _updateWakelock();` :

```dart
// Arrêter le foreground service
await ForegroundSSHService.stop();
```

**Step 5: Arrêter le service quand le dernier onglet est fermé**

Dans la méthode `closeTab()`, dans le bloc `if (newTabIds.isEmpty)`, après `await _updateWakelock();` :

```dart
await ForegroundSSHService.stop();
```

**Step 6: Commit**

```bash
git add lib/features/terminal/providers/ssh_provider.dart
git commit -m "feat: integrate ForegroundSSHService with SSH connections"
```

---

## Task 6: Supprimer wakelock_plus (redondant)

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/terminal/providers/ssh_provider.dart`

**Step 1: Retirer wakelock_plus du pubspec.yaml**

Supprimer la ligne :
```yaml
  wakelock_plus: ^1.4.0
```

**Step 2: Retirer l'import et la méthode _updateWakelock()**

Dans `ssh_provider.dart` :
- Supprimer `import 'package:wakelock_plus/wakelock_plus.dart';`
- Supprimer la méthode `_updateWakelock()` entière
- Supprimer tous les appels à `await _updateWakelock();`

**Step 3: Installer les dépendances**

Run: `flutter pub get`

**Step 4: Commit**

```bash
git add pubspec.yaml lib/features/terminal/providers/ssh_provider.dart
git commit -m "refactor: remove wakelock_plus (replaced by foreground service)"
```

---

## Task 7: Tester le build et vérifier

**Step 1: Build l'APK debug**

Run: `flutter build apk --debug`
Expected: ✓ Built build/app/outputs/flutter-apk/app-debug.apk

**Step 2: Tester sur le téléphone**

1. Installer l'APK
2. Se connecter en SSH
3. Vérifier que la notification "ChillShell - Connecté à X" apparaît
4. Naviguer vers une autre app
5. Attendre 30 secondes
6. Revenir sur ChillShell
7. Vérifier que la connexion SSH est toujours active

**Step 3: Commit final**

```bash
git add -A
git commit -m "feat: complete foreground service implementation for persistent SSH"
```

---

## Résumé des fichiers modifiés

| Fichier | Action |
|---------|--------|
| `pubspec.yaml` | Ajouter flutter_foreground_task, retirer wakelock_plus |
| `android/app/src/main/AndroidManifest.xml` | Permissions + déclaration service |
| `lib/services/foreground_ssh_service.dart` | CRÉER - Service wrapper |
| `lib/main.dart` | Init du service |
| `lib/features/terminal/providers/ssh_provider.dart` | Intégration start/stop |

---

## Notes importantes

- La notification est **basse priorité** = pas de son, pas de vibration
- Le service utilise `allowWakeLock: true` et `allowWifiLock: true`
- Le type `dataSync` est approprié pour les connexions SSH
- Le service s'arrête automatiquement si l'app est tuée (`stopWithTask="false"` permet de persister)
