# Local Shell - Plan d'implémentation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ajouter un mode "Local Shell" pour exécuter un terminal local sur Android (avec message explicatif sur iOS)

**Architecture:** Créer un `LocalShellService` qui utilise `flutter_pty` pour lancer un shell local. Le bouton "Local Shell" sera ajouté dans le dialog de connexion. Sur iOS, un message explicatif sera affiché.

**Tech Stack:** flutter_pty ^0.4.2, dart:io (Platform), xterm

---

## Task 1: Ajouter flutter_pty au projet

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Ajouter la dépendance**

Dans `pubspec.yaml`, section `dependencies`, ajouter :

```yaml
  flutter_pty: ^0.4.2
```

**Step 2: Installer les dépendances**

```bash
flutter pub get
```

Expected: Dépendance installée sans erreur

---

## Task 2: Créer LocalShellService

**Files:**
- Create: `lib/services/local_shell_service.dart`

**Step 1: Créer le service**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';

class LocalShellService {
  Pty? _pty;
  final _outputController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get outputStream => _outputController.stream;
  bool get isRunning => _pty != null;

  /// Démarre un shell local
  Future<void> startShell({int width = 80, int height = 24}) async {
    if (_pty != null) {
      debugPrint('LocalShell: Shell already running');
      return;
    }

    // Déterminer le shell à utiliser
    final shell = Platform.isAndroid ? 'sh' : Platform.environment['SHELL'] ?? '/bin/sh';

    debugPrint('LocalShell: Starting shell: $shell');

    _pty = Pty.start(
      shell,
      columns: width,
      rows: height,
    );

    // Écouter la sortie du PTY
    _pty!.output.listen(
      (data) {
        _outputController.add(data);
      },
      onError: (error) {
        debugPrint('LocalShell: Error: $error');
        _outputController.addError(error);
      },
      onDone: () {
        debugPrint('LocalShell: Shell exited');
        _pty = null;
      },
    );

    debugPrint('LocalShell: Shell started successfully');
  }

  /// Écrit des données dans le shell
  void write(String data) {
    if (_pty != null) {
      _pty!.write(utf8.encode(data));
    }
  }

  /// Redimensionne le terminal
  void resize(int width, int height) {
    if (_pty != null) {
      _pty!.resize(height, width);
    }
  }

  /// Ferme le shell
  Future<void> close() async {
    if (_pty != null) {
      _pty!.kill();
      _pty = null;
    }
    debugPrint('LocalShell: Closed');
  }

  /// Libère les ressources
  void dispose() {
    close();
    _outputController.close();
  }
}
```

**Step 2: Vérifier que le fichier compile**

```bash
flutter analyze lib/services/local_shell_service.dart
```

Expected: No issues found

---

## Task 3: Modifier SSHProvider pour supporter Local Shell

**Files:**
- Modify: `lib/features/terminal/providers/ssh_provider.dart`

**Step 1: Ajouter l'import et le type de connexion**

Au début du fichier, ajouter :

```dart
import '../../../services/local_shell_service.dart';
```

Dans `SSHState`, ajouter un champ pour identifier les onglets locaux :

```dart
final Set<String> localTabIds;
```

**Step 2: Ajouter la map des services locaux dans SSHNotifier**

```dart
final Map<String, LocalShellService> _localTabServices = {};
```

**Step 3: Ajouter la méthode connectLocal()**

```dart
/// Démarre un shell local (Android uniquement)
Future<void> connectLocal() async {
  state = state.copyWith(connectionState: SSHConnectionState.connecting);

  try {
    final tabId = DateTime.now().millisecondsSinceEpoch.toString();
    final tabNumber = state.nextTabNumber;

    final localService = LocalShellService();
    await localService.startShell();

    _localTabServices[tabId] = localService;

    state = state.copyWith(
      connectionState: SSHConnectionState.connected,
      currentTabId: tabId,
      tabIds: [...state.tabIds, tabId],
      localTabIds: {...state.localTabIds, tabId},
      tabNames: {...state.tabNames, tabId: 'Local $tabNumber'},
      nextTabNumber: tabNumber + 1,
      errorMessage: null,
    );

    debugPrint('Local shell connected: $tabId');
  } catch (e) {
    state = state.copyWith(
      connectionState: SSHConnectionState.error,
      errorMessage: 'Erreur shell local: $e',
    );
  }
}
```

**Step 4: Modifier getOutputStreamForTab() pour supporter local**

```dart
Stream<Uint8List>? getOutputStreamForTab(String tabId) {
  // Vérifier si c'est un onglet local
  if (state.localTabIds.contains(tabId)) {
    return _localTabServices[tabId]?.outputStream;
  }
  // Sinon, c'est SSH
  return _tabServices[tabId]?.outputStream;
}
```

**Step 5: Modifier writeToTab() pour supporter local**

```dart
void writeToTab(String tabId, String data) {
  if (state.localTabIds.contains(tabId)) {
    _localTabServices[tabId]?.write(data);
  } else {
    _tabServices[tabId]?.write(data);
  }
}
```

**Step 6: Modifier resizeTerminalForTab() pour supporter local**

```dart
void resizeTerminalForTab(String tabId, int width, int height) {
  if (state.localTabIds.contains(tabId)) {
    _localTabServices[tabId]?.resize(width, height);
  } else {
    _tabServices[tabId]?.resizeTerminal(width, height);
  }
}
```

**Step 7: Modifier closeTab() pour supporter local**

Dans la méthode `closeTab()`, ajouter la fermeture du service local :

```dart
// Fermer le service local si c'est un onglet local
if (state.localTabIds.contains(tabId)) {
  await _localTabServices[tabId]?.close();
  _localTabServices.remove(tabId);
}
```

Et mettre à jour l'état pour retirer du set localTabIds :

```dart
final newLocalTabIds = Set<String>.from(state.localTabIds)..remove(tabId);
// ... dans copyWith
localTabIds: newLocalTabIds,
```

**Step 8: Vérifier la compilation**

```bash
flutter analyze lib/features/terminal/providers/ssh_provider.dart
```

Expected: No issues found

---

## Task 4: Modifier SSHState pour inclure localTabIds

**Files:**
- Modify: `lib/features/terminal/providers/ssh_provider.dart`

**Step 1: Mettre à jour la classe SSHState**

Ajouter le champ et le mettre à jour dans copyWith et le constructeur :

```dart
class SSHState {
  // ... autres champs
  final Set<String> localTabIds;

  const SSHState({
    // ... autres paramètres
    this.localTabIds = const {},
  });

  SSHState copyWith({
    // ... autres paramètres
    Set<String>? localTabIds,
  }) {
    return SSHState(
      // ... autres champs
      localTabIds: localTabIds ?? this.localTabIds,
    );
  }
}
```

---

## Task 5: Ajouter le bouton Local Shell dans ConnectionDialog

**Files:**
- Modify: `lib/features/terminal/widgets/connection_dialog.dart`

**Step 1: Ajouter l'import dart:io**

```dart
import 'dart:io' show Platform;
```

**Step 2: Ajouter le bouton Local Shell**

Dans `_buildSavedConnectionsList()`, après le bouton "Nouvelle connexion", ajouter :

```dart
const SizedBox(height: VibeTermSpacing.sm),
_buildLocalShellButton(theme),
```

**Step 3: Créer la méthode _buildLocalShellButton()**

```dart
Widget _buildLocalShellButton(VibeTermThemeData theme) {
  return Center(
    child: OutlinedButton.icon(
      onPressed: _onLocalShellPressed,
      icon: Icon(Icons.computer, color: theme.accent),
      label: Text(
        'Local Shell',
        style: TextStyle(color: theme.accent),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: theme.accent),
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.md,
          vertical: VibeTermSpacing.sm,
        ),
      ),
    ),
  );
}
```

**Step 4: Créer la méthode _onLocalShellPressed()**

```dart
void _onLocalShellPressed() {
  if (Platform.isIOS) {
    _showIOSNotAvailableDialog();
  } else {
    Navigator.pop(context, const LocalShellRequest());
  }
}
```

**Step 5: Créer la méthode _showIOSNotAvailableDialog()**

```dart
void _showIOSNotAvailableDialog() {
  final theme = ref.read(vibeTermThemeProvider);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.bgBlock,
      title: Row(
        children: [
          Icon(Icons.info_outline, color: theme.warning),
          const SizedBox(width: VibeTermSpacing.sm),
          Expanded(
            child: Text(
              'Non disponible sur iOS',
              style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apple ne permet pas aux applications d\'accéder au shell système de l\'iPhone pour des raisons de sécurité.',
            style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
          ),
          const SizedBox(height: VibeTermSpacing.md),
          Container(
            padding: const EdgeInsets.all(VibeTermSpacing.sm),
            decoration: BoxDecoration(
              color: theme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              border: Border.all(color: theme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: theme.success, size: 18),
                const SizedBox(width: VibeTermSpacing.xs),
                Expanded(
                  child: Text(
                    'Le mode SSH fonctionne normalement sur iOS !',
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accent,
            foregroundColor: theme.bg,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Compris'),
        ),
      ],
    ),
  );
}
```

**Step 6: Ajouter la classe LocalShellRequest**

À la fin du fichier, après `ConnectionInfo` :

```dart
class LocalShellRequest {
  const LocalShellRequest();
}
```

**Step 7: Ajouter le bouton aussi dans _buildNewConnectionForm()**

Après les boutons Annuler/Connexion, ajouter une section pour Local Shell :

```dart
const SizedBox(height: VibeTermSpacing.md),
Divider(color: theme.border),
const SizedBox(height: VibeTermSpacing.sm),
_buildLocalShellButton(theme),
```

---

## Task 6: Modifier TerminalScreen pour gérer LocalShellRequest

**Files:**
- Modify: `lib/features/terminal/screens/terminal_screen.dart`

**Step 1: Ajouter l'import**

```dart
import 'dart:io' show Platform;
```

**Step 2: Modifier _showConnectionDialog()**

Modifier le type de retour et gérer `LocalShellRequest` :

```dart
Future<void> _showConnectionDialog() async {
  final result = await showDialog<dynamic>(
    context: context,
    builder: (context) => const ConnectionDialog(),
  );

  if (result == null) return;

  // Gérer Local Shell
  if (result is LocalShellRequest) {
    if (!Platform.isIOS) {
      ref.read(sshProvider.notifier).connectLocal();
    }
    return;
  }

  // Gérer connexion SSH (code existant)
  if (result is ConnectionInfo) {
    // ... code existant pour SSH
  }
}
```

---

## Task 7: Vérifier et tester

**Step 1: Analyser le code**

```bash
flutter analyze
```

Expected: No issues found (ou seulement des warnings mineurs)

**Step 2: Build APK debug**

```bash
flutter build apk --debug
```

Expected: Build successful

**Step 3: Tester sur Android**

- Installer l'APK sur un appareil Android
- Ouvrir le dialog de connexion
- Cliquer sur "Local Shell"
- Vérifier que le terminal s'ouvre avec un shell local
- Taper `ls` et vérifier que ça fonctionne

**Step 4: Tester sur iOS (simulateur ou appareil)**

- Ouvrir le dialog de connexion
- Cliquer sur "Local Shell"
- Vérifier que le message explicatif s'affiche
- Vérifier que le bouton "Compris" ferme le dialog

---

## Task 8: Mettre à jour la documentation

**Files:**
- Modify: `STATUS.md`
- Modify: `ROADMAP.md`

**Step 1: Ajouter dans STATUS.md**

Ajouter une section pour documenter l'implémentation de Local Shell.

**Step 2: Cocher dans ROADMAP.md**

Marquer la feature "Mode terminal local" comme complétée.

---

## Récapitulatif des fichiers

| Action | Fichier |
|--------|---------|
| Modify | `pubspec.yaml` |
| Create | `lib/services/local_shell_service.dart` |
| Modify | `lib/features/terminal/providers/ssh_provider.dart` |
| Modify | `lib/features/terminal/widgets/connection_dialog.dart` |
| Modify | `lib/features/terminal/screens/terminal_screen.dart` |
| Modify | `STATUS.md` |
| Modify | `ROADMAP.md` |

---

## Notes importantes

1. **iOS** : Le shell local ne fonctionnera PAS sur iOS même avec flutter_pty car Apple bloque l'accès au shell système. Le message explicatif est donc essentiel.

2. **Android** : Le shell par défaut sera `sh`. Si Termux est installé, l'utilisateur pourra avoir accès à bash et d'autres outils.

3. **Compatibilité** : Le code est conçu pour être non-intrusif - si flutter_pty échoue, l'app continue de fonctionner normalement en mode SSH.
