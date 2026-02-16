# Mise à jour des dépendances (sans Riverpod) - Plan d'implémentation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Mettre à jour toutes les dépendances safe/moyennes et supprimer les packages inutilisés.

**Architecture:** Mise à jour séquentielle par ordre de risque croissant. Chaque package est testé individuellement avant de passer au suivant.

**Tech Stack:** Flutter, Dart, pubspec.yaml, flutter pub

---

### Task 1 : Supprimer permission_handler (inutilisé)

**Files:**
- Modify: `pubspec.yaml:41`

**Step 1: Supprimer la ligne permission_handler du pubspec.yaml**

Supprimer :
```yaml
  permission_handler: ^11.1.0       # Permissions
```

**Step 2: Lancer flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS, résolution sans erreur

**Step 3: Vérifier compilation**

Run: `flutter analyze lib/`
Expected: Pas d'erreur liée à permission_handler (aucun import dans le code)

---

### Task 2 : Mettre à jour les dev dependencies

**Files:**
- Modify: `pubspec.yaml:51-54`

**Step 1: Mettre à jour les versions dans pubspec.yaml**

```yaml
# Avant
  flutter_lints: ^3.0.1
  build_runner: ^2.4.7
  custom_lint: ^0.5.7

# Après
  flutter_lints: ^6.0.0
  build_runner: ^2.11.0
  custom_lint: ^0.8.1
```

Note: `riverpod_generator` reste à `^2.3.9` (lié à Riverpod 2.x, sera mis à jour avec la migration Riverpod 3).

**Step 2: Lancer flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS

**Step 3: Lancer flutter analyze et noter les nouveaux warnings**

Run: `flutter analyze lib/`
Expected: Possibles nouveaux warnings de `strict_top_level_inference` et `unnecessary_underscores`. Les corriger si nécessaire.

---

### Task 3 : Mettre à jour google_fonts (6 → 8)

**Files:**
- Modify: `pubspec.yaml:17`

**Step 1: Mettre à jour la version**

```yaml
# Avant
  google_fonts: ^6.1.0

# Après
  google_fonts: ^8.0.0
```

**Step 2: flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS

**Step 3: Vérifier compilation**

Run: `flutter analyze lib/`
Expected: Pas d'erreur - l'API `GoogleFonts.jetBrainsMono()` est identique en v8.

Fichiers utilisant google_fonts (vérifier qu'ils compilent) :
- `lib/core/theme/typography.dart`
- `lib/core/theme/app_theme.dart`
- `lib/features/terminal/widgets/wol_start_screen.dart`

---

### Task 4 : Mettre à jour file_picker (8 → 10)

**Files:**
- Modify: `pubspec.yaml:43`

**Step 1: Mettre à jour la version**

```yaml
# Avant
  file_picker: ^8.0.0+1

# Après
  file_picker: ^10.0.0
```

**Step 2: flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS

**Step 3: Vérifier compilation**

Run: `flutter analyze lib/`
Expected: Pas d'erreur - l'API `FilePicker.platform.pickFiles()` et `PlatformFile` sont identiques.

Fichier impacté : `lib/features/settings/widgets/add_ssh_key_sheet.dart`

---

### Task 5 : Mettre à jour flutter_secure_storage (9 → 10)

**Files:**
- Modify: `pubspec.yaml:34`
- Modify: `lib/services/secure_storage_service.dart:6-9`
- Modify: `lib/services/pin_service.dart:8-10`
- Modify: `lib/services/storage_service.dart:7-10`

**Step 1: Mettre à jour la version dans pubspec.yaml**

```yaml
# Avant
  flutter_secure_storage: ^9.0.0

# Après
  flutter_secure_storage: ^10.0.0
```

**Step 2: flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS

**Step 3: Supprimer `encryptedSharedPreferences: true` dans secure_storage_service.dart**

```dart
// Avant
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

// Après
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
```

**Step 4: Supprimer `encryptedSharedPreferences: true` dans pin_service.dart**

```dart
// Avant
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

// Après
static const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
);
```

**Step 5: Supprimer `encryptedSharedPreferences: true` dans storage_service.dart**

```dart
// Avant
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

// Après
final _storage = const FlutterSecureStorage(
  aOptions: AndroidOptions(),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
```

**Step 6: Vérifier compilation**

Run: `flutter analyze lib/`
Expected: SUCCESS - les méthodes read/write/delete/deleteAll sont identiques.

**Note importante** : La migration des données chiffrées (Jetpack Crypto → Google Tink) se fait automatiquement au premier lancement.

---

### Task 6 : Mettre à jour local_auth (2 → 3)

**Files:**
- Modify: `pubspec.yaml:35`
- Modify: `lib/services/biometric_service.dart:28-44`

**Step 1: Mettre à jour la version dans pubspec.yaml**

```yaml
# Avant
  local_auth: ^2.1.8

# Après
  local_auth: ^3.0.0
```

**Step 2: flutter pub get**

Run: `flutter pub get`
Expected: SUCCESS

**Step 3: Modifier authenticate() dans biometric_service.dart**

```dart
// Avant (v2.x)
static Future<bool> authenticate() async {
  try {
    return await _auth.authenticate(
      localizedReason: 'Déverrouillez ChillShell pour accéder à vos sessions SSH',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
  } on PlatformException catch (e) {
    if (e.code == 'NotAvailable') {
      return false;
    }
    return false;
  }
}

// Après (v3.0.0)
static Future<bool> authenticate() async {
  try {
    return await _auth.authenticate(
      localizedReason: 'Déverrouillez ChillShell pour accéder à vos sessions SSH',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  } on PlatformException catch (e) {
    if (e.code == 'NotAvailable') {
      return false;
    }
    return false;
  }
}
```

Changements :
- `options: AuthenticationOptions(stickyAuth: true, biometricOnly: true)` → `biometricOnly: true, persistAcrossBackgrounding: true`
- `stickyAuth` est renommé en `persistAcrossBackgrounding`
- Import `AuthenticationOptions` n'est plus nécessaire (mais ne cause pas d'erreur)

**Step 4: Vérifier compilation**

Run: `flutter analyze lib/`
Expected: SUCCESS

**Step 5: Vérifier que les autres usages de local_auth compilent**

Fichiers à vérifier :
- `lib/services/biometric_service.dart` (seul fichier qui importe local_auth)
- Méthodes `isAvailable()`, `getAvailableBiometrics()`, `getBiometricLabel()` ne changent pas.

---

### Task 7 : Mettre à jour le tableau des versions dans ROADMAP.md

**Files:**
- Modify: `ROADMAP.md`

Mettre à jour la section "Stack actuelle" :

```markdown
| Package | Version | Usage |
|---------|---------|-------|
| flutter_riverpod | 2.6.1 | State management |
| dartssh2 | 2.13.0 | Connexions SSH |
| xterm | 4.0.0 | Rendu terminal |
| flutter_secure_storage | 10.0.0 | Stockage clés |
| local_auth | 3.0.0 | Biométrie |
| flutter_foreground_task | 9.2.0 | Connexions persistantes |
| flutter_pty | 0.4.2 | Shell local Android |
| wake_on_lan | 4.1.1+3 | Réveil PC (Magic Packet) |
| google_fonts | 8.0.1 | Police JetBrains Mono |
| file_picker | 10.x | Import fichiers/clés SSH |
```

---

### Task 8 : Mettre à jour MAJ.md

**Files:**
- Modify: `docs/MAJ.md`

Marquer les packages mis à jour comme fait et mettre à jour la date.

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

| Task | Package | Risque | Changements code |
|------|---------|--------|------------------|
| 1 | permission_handler | Aucun | Suppression (inutilisé) |
| 2 | Dev deps (lints, build_runner, custom_lint) | Faible | Possibles warnings lint |
| 3 | google_fonts 6→8 | Faible | Aucun |
| 4 | file_picker 8→10 | Faible | Aucun |
| 5 | flutter_secure_storage 9→10 | Moyen | Supprimer encryptedSharedPreferences (3 fichiers) |
| 6 | local_auth 2→3 | Moyen | Changer authenticate() (1 fichier) |
| 7-8 | Docs | Aucun | Mise à jour ROADMAP + MAJ.md |
| 9 | Test final | - | Vérification globale |
