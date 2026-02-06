# Migration Riverpod 2 → 3 - Plan d'implémentation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrer tous les providers de StateNotifier (Riverpod 2) vers Notifier (Riverpod 3) et débloquer les dev dependencies.

**Architecture:** Migration fichier par fichier en ordre de complexité croissante. Chaque StateNotifier devient un Notifier (constructeur → méthode `build()`). Les StateProvider deviennent des NotifierProvider. Les ~24 fichiers UI (ConsumerWidget, ref.watch, ref.read) ne changent PAS.

**Tech Stack:** Flutter, Riverpod 3.2.1, riverpod_annotation 4.0.2, riverpod_generator 4.0.3

---

### Task 1 : Mettre à jour pubspec.yaml

**Files:**
- Modify: `pubspec.yaml:21-54`

**Step 1: Mettre à jour les versions des dépendances**

```yaml
# dependencies — Avant
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

# dependencies — Après
  flutter_riverpod: ^3.2.1
  riverpod_annotation: ^4.0.2
```

```yaml
# dev_dependencies — Avant
  flutter_lints: ^6.0.0
  riverpod_generator: ^2.3.9
  build_runner: ^2.4.7
  custom_lint: ^0.5.7

# dev_dependencies — Après
  flutter_lints: ^6.0.0
  riverpod_generator: ^4.0.3
  build_runner: ^2.11.0
  custom_lint: ^0.8.1
  riverpod_lint: ^3.1.3
```

**Step 2: flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS — les conflits build/analyzer sont résolus grâce à riverpod_generator 4.x.
Si conflit: ajuster les versions ou retirer `riverpod_lint`.

**Step 3: flutter analyze (noter les erreurs attendues)**

Run: `flutter analyze lib/`
Expected: ERREURS sur les 6 fichiers providers (StateNotifier/StateNotifierProvider n'existent plus dans l'import principal). C'est normal — on les corrige dans les tâches suivantes.

---

### Task 2 : Migrer sessions_provider.dart (simple)

**Files:**
- Modify: `lib/features/terminal/providers/sessions_provider.dart`

**Step 1: Migrer SessionsNotifier**

```dart
// ❌ Avant (ligne 5)
class SessionsNotifier extends StateNotifier<List<Session>> {
  SessionsNotifier() : super([]);

// ✅ Après
class SessionsNotifier extends Notifier<List<Session>> {
  @override
  List<Session> build() => [];
```

```dart
// ❌ Avant (ligne 67)
final sessionsProvider = StateNotifierProvider<SessionsNotifier, List<Session>>(
  (ref) => SessionsNotifier(),
);

// ✅ Après
final sessionsProvider = NotifierProvider<SessionsNotifier, List<Session>>(
  SessionsNotifier.new,
);
```

**Step 2: Migrer activeSessionIndexProvider (StateProvider → Notifier)**

```dart
// ❌ Avant (ligne 71)
final activeSessionIndexProvider = StateProvider<int>((ref) => 0);

// ✅ Après
class _ActiveSessionIndex extends Notifier<int> {
  @override
  int build() => 0;
}

final activeSessionIndexProvider = NotifierProvider<_ActiveSessionIndex, int>(
  _ActiveSessionIndex.new,
);
```

Note: `activeSessionProvider` (ligne 73) est un `Provider` classique, pas besoin de le modifier.

**Step 3: Mettre à jour les consommateurs de activeSessionIndexProvider**

Chercher tous les usages de `ref.read(activeSessionIndexProvider.notifier).state = `:

```dart
// ❌ Avant (dans les fichiers UI)
ref.read(activeSessionIndexProvider.notifier).state = index;

// ✅ Après — le .state setter fonctionne aussi sur Notifier
ref.read(activeSessionIndexProvider.notifier).state = index;
```

**Pas de changement nécessaire dans les fichiers UI** car `Notifier` a aussi un setter `.state`.

**Step 4: Vérifier compilation**

Run: `flutter analyze lib/features/terminal/providers/sessions_provider.dart`

---

### Task 3 : Migrer folder_provider.dart (simple)

**Files:**
- Modify: `lib/features/terminal/providers/folder_provider.dart`

**Step 1: Migrer FolderNotifier**

```dart
// ❌ Avant (ligne 52)
class FolderNotifier extends StateNotifier<FolderState> {
  FolderNotifier() : super(const FolderState());

// ✅ Après
class FolderNotifier extends Notifier<FolderState> {
  @override
  FolderState build() => const FolderState();
```

```dart
// ❌ Avant (ligne 161)
final folderProvider = StateNotifierProvider<FolderNotifier, FolderState>(
  (ref) => FolderNotifier(),
);

// ✅ Après
final folderProvider = NotifierProvider<FolderNotifier, FolderState>(
  FolderNotifier.new,
);
```

**Step 2: Vérifier compilation**

Run: `flutter analyze lib/features/terminal/providers/folder_provider.dart`

---

### Task 4 : Migrer wol_provider.dart (simple)

**Files:**
- Modify: `lib/features/settings/providers/wol_provider.dart`

**Step 1: Migrer WolNotifier**

```dart
// ❌ Avant (ligne 34)
class WolNotifier extends StateNotifier<WolState> {
  // ... _storage static ...
  WolNotifier() : super(const WolState()) {
    loadConfigs();
  }

// ✅ Après
class WolNotifier extends Notifier<WolState> {
  // ... _storage static reste identique ...
  @override
  WolState build() {
    loadConfigs();
    return const WolState();
  }
```

```dart
// ❌ Avant (ligne 155)
final wolProvider = StateNotifierProvider<WolNotifier, WolState>(
  (ref) => WolNotifier(),
);

// ✅ Après
final wolProvider = NotifierProvider<WolNotifier, WolState>(
  WolNotifier.new,
);
```

**Step 2: Vérifier compilation**

Run: `flutter analyze lib/features/settings/providers/wol_provider.dart`

---

### Task 5 : Migrer settings_provider.dart (moyen)

**Files:**
- Modify: `lib/features/settings/providers/settings_provider.dart`

**Step 1: Migrer SettingsNotifier**

```dart
// ❌ Avant (ligne 35-40)
class SettingsNotifier extends StateNotifier<SettingsState> {
  final StorageService _storage = StorageService();

  SettingsNotifier() : super(const SettingsState(appSettings: AppSettings())) {
    _loadSettings();
  }

// ✅ Après
class SettingsNotifier extends Notifier<SettingsState> {
  final StorageService _storage = StorageService();

  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState(appSettings: AppSettings());
  }
```

```dart
// ❌ Avant (ligne 223-225)
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);

// ✅ Après
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
```

Toutes les méthodes (`addSSHKey`, `removeSSHKey`, `updateTheme`, etc.) restent identiques.

**Step 2: Vérifier compilation**

Run: `flutter analyze lib/features/settings/providers/settings_provider.dart`

---

### Task 6 : Migrer terminal_provider.dart (moyen + StateProviders)

**Files:**
- Modify: `lib/features/terminal/providers/terminal_provider.dart`

**Step 1: Migrer TerminalNotifier**

```dart
// ❌ Avant (ligne 51-54)
class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalNotifier() : super(const TerminalState()) {
    _loadHistory();
  }

// ✅ Après
class TerminalNotifier extends Notifier<TerminalState> {
  @override
  TerminalState build() {
    _loadHistory();
    return const TerminalState();
  }
```

Les champs d'instance (`_uuid`, `_storage`, `_pendingCommand`, etc.) restent identiques.

```dart
// ❌ Avant (ligne 1405-1406)
final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) => TerminalNotifier(),
);

// ✅ Après
final terminalProvider = NotifierProvider<TerminalNotifier, TerminalState>(
  TerminalNotifier.new,
);
```

**Step 2: Migrer terminalScrolledUpProvider et isEditorModeProvider**

```dart
// ❌ Avant (lignes 1411, 1415)
final terminalScrolledUpProvider = StateProvider<bool>((ref) => false);
final isEditorModeProvider = StateProvider<bool>((ref) => false);

// ✅ Après
class _TerminalScrolledUp extends Notifier<bool> {
  @override
  bool build() => false;
}

final terminalScrolledUpProvider = NotifierProvider<_TerminalScrolledUp, bool>(
  _TerminalScrolledUp.new,
);

class _IsEditorMode extends Notifier<bool> {
  @override
  bool build() => false;
}

final isEditorModeProvider = NotifierProvider<_IsEditorMode, bool>(
  _IsEditorMode.new,
);
```

**Step 3: Vérifier compilation**

Run: `flutter analyze lib/features/terminal/providers/terminal_provider.dart`

---

### Task 7 : Migrer ssh_provider.dart (complexe — dispose + timers)

**Files:**
- Modify: `lib/features/terminal/providers/ssh_provider.dart`

C'est le fichier le plus complexe à cause de `dispose()` et des timers.

**Step 1: Migrer SSHNotifier — classe et constructeur**

```dart
// ❌ Avant (ligne 120, 150)
class SSHNotifier extends StateNotifier<SSHState> {
  // ... instance fields ...
  SSHNotifier() : super(const SSHState());

// ✅ Après
class SSHNotifier extends Notifier<SSHState> {
  // ... instance fields restent identiques ...
  @override
  SSHState build() {
    // Remplacer dispose() par ref.onDispose()
    ref.onDispose(() {
      _isDisposed = true;
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _resizeThrottleTimer?.cancel();
      _resizeThrottleTimer = null;
    });
    return const SSHState();
  }
```

**Step 2: Supprimer la méthode dispose()**

Supprimer complètement les lignes 585-595 :
```dart
// ❌ Supprimer entièrement
@override
void dispose() {
  _isDisposed = true;
  _connectionCheckTimer?.cancel();
  _connectionCheckTimer = null;
  _reconnectTimer?.cancel();
  _reconnectTimer = null;
  _resizeThrottleTimer?.cancel();
  _resizeThrottleTimer = null;
  super.dispose();
}
```

La logique de cleanup est maintenant dans `ref.onDispose()` du `build()`.

**Step 3: Migrer le provider**

```dart
// ❌ Avant (ligne 988-990)
final sshProvider = StateNotifierProvider<SSHNotifier, SSHState>(
  (ref) => SSHNotifier(),
);

// ✅ Après
final sshProvider = NotifierProvider<SSHNotifier, SSHState>(
  SSHNotifier.new,
);
```

**Step 4: Vérifier compilation**

Run: `flutter analyze lib/features/terminal/providers/ssh_provider.dart`

---

### Task 8 : Migrer theme_provider.dart et vérifier les consumers

**Files:**
- Verify: `lib/core/theme/theme_provider.dart` — PAS de changement (c'est un `Provider` classique)
- Verify: Tous les fichiers UI (~24 fichiers)

**Step 1: Vérifier que theme_provider.dart compile**

`vibeTermThemeProvider` est un `Provider<VibeTermThemeData>` (pas un StateNotifierProvider), donc **aucun changement nécessaire**.

Run: `flutter analyze lib/core/theme/theme_provider.dart`

**Step 2: Analyse complète**

Run: `flutter analyze lib/`
Expected: 0 erreurs liées à Riverpod. Les fichiers UI utilisent `ConsumerWidget`, `ref.watch()`, `ref.read()` qui sont identiques en Riverpod 3.

Les patterns utilisés dans les fichiers UI ne changent PAS :
- `ref.watch(sshProvider)` → identique
- `ref.read(sshProvider.notifier).connect(...)` → identique
- `ref.watch(sshProvider.select((s) => s.connectionState))` → identique
- `ref.listen<SSHState>(sshProvider, ...)` → identique
- `ref.read(activeSessionIndexProvider.notifier).state = index` → identique (Notifier a aussi `.state` setter)

---

### Task 9 : Test final

**Step 1: flutter clean + pub get**

Run: `flutter clean && flutter pub get`

**Step 2: flutter analyze**

Run: `flutter analyze lib/`
Expected: 0 erreurs

**Step 3: Build APK debug**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL

---

## Résumé

| Task | Fichier | Changement principal |
|------|---------|---------------------|
| 1 | pubspec.yaml | Versions Riverpod 3 + build_runner + custom_lint |
| 2 | sessions_provider.dart | SessionsNotifier + activeSessionIndexProvider |
| 3 | folder_provider.dart | FolderNotifier |
| 4 | wol_provider.dart | WolNotifier |
| 5 | settings_provider.dart | SettingsNotifier |
| 6 | terminal_provider.dart | TerminalNotifier + 2 StateProviders |
| 7 | ssh_provider.dart | SSHNotifier + dispose → ref.onDispose |
| 8 | Vérification | theme_provider + consumers |
| 9 | Test final | clean + analyze + build |

**Fichiers modifiés :** 7 fichiers providers + pubspec.yaml = **8 fichiers**
**Fichiers UI inchangés :** ~24 fichiers (ConsumerWidget, ref.watch, ref.read identiques)
