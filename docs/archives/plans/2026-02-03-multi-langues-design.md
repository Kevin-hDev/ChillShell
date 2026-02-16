# Multi-langues - Design

> Date: 3 Février 2026

## Objectif

Internationaliser VibeTerm avec 5 langues : Anglais (défaut), Français, Espagnol, Allemand, Chinois.

## Décisions

| Aspect | Choix |
|--------|-------|
| Approche technique | flutter_localizations + ARB files |
| Détection langue | Automatique (système) + choix manuel |
| Emplacement settings | Onglet "Général" (ex-Thème) |
| Taille police | 5 options (XS/S/M/L/XL) via dropdown |

## Architecture

### Structure des fichiers

```
lib/
├── l10n/
│   ├── app_en.arb          # Anglais (défaut)
│   ├── app_fr.arb          # Français
│   ├── app_es.arb          # Espagnol
│   ├── app_de.arb          # Allemand
│   └── app_zh.arb          # Chinois
├── core/
│   └── l10n/
│       └── l10n.dart       # Extension helper
```

### Configuration pubspec.yaml

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

### Fichier l10n.yaml (racine)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
```

## Fichiers ARB

### app_en.arb (template)

```json
{
  "@@locale": "en",
  "appName": "VibeTerm",
  "settings": "Settings",
  "connection": "Connection",
  "general": "General",
  "security": "Security",
  "wol": "WOL",
  "theme": "Theme",
  "language": "Language",
  "fontSize": "Font size",
  "disconnect": "Disconnect",
  "connect": "Connect",
  "cancel": "Cancel",
  "save": "Save",
  "delete": "Delete",
  "noConnection": "No connection",
  "connectToServer": "Connect to an SSH server",
  "newConnection": "New connection",
  "terminal": "Terminal",
  "runCommands": "Run commands",
  "copy": "Copy",
  "paste": "Paste"
}
```

### app_fr.arb

```json
{
  "@@locale": "fr",
  "appName": "VibeTerm",
  "settings": "Paramètres",
  "connection": "Connexion",
  "general": "Général",
  "security": "Sécurité",
  "wol": "WOL",
  "theme": "Thème",
  "language": "Langue",
  "fontSize": "Taille de police",
  "disconnect": "Déconnecter",
  "connect": "Connecter",
  "cancel": "Annuler",
  "save": "Enregistrer",
  "delete": "Supprimer",
  "noConnection": "Aucune connexion",
  "connectToServer": "Connectez-vous à un serveur SSH",
  "newConnection": "Nouvelle connexion",
  "terminal": "Terminal",
  "runCommands": "Exécuter des commandes",
  "copy": "Copier",
  "paste": "Coller"
}
```

## Intégration code

### Provider (AppSettings)

```dart
final String languageCode; // 'en', 'fr', 'es', 'de', 'zh'
final int terminalFontSize; // 12, 14, 17, 20, 24
```

### main.dart

```dart
MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'),
    Locale('fr'),
    Locale('es'),
    Locale('de'),
    Locale('zh'),
  ],
  locale: _getLocale(settings),
)
```

### Extension helper

```dart
extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
```

### Utilisation

```dart
// Avant
Text('Paramètres')

// Après
Text(context.l10n.settings)
```

## UI Onglet Général

```
┌─────────────────────────────────────────┐
│            GÉNÉRAL                       │
├─────────────────────────────────────────┤
│                                         │
│  Thème                                  │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│  │Warp │ │Drac │ │Nord │ │...  │       │
│  └─────┘ └─────┘ └─────┘ └─────┘       │
│                                         │
│  Langue                      [English ▼] │
│                                         │
│  Taille de police            [M (17px) ▼] │
│                                         │
└─────────────────────────────────────────┘
```

### Options Langue
- English (défaut)
- Français
- Español
- Deutsch
- 中文

### Options Taille
- XS (12px)
- S (14px)
- M (17px) ← défaut
- L (20px)
- XL (24px)

## Fichiers à modifier

| Fichier | Modification |
|---------|--------------|
| `pubspec.yaml` | Ajouter flutter_localizations + intl |
| `l10n.yaml` | Créer (config génération) |
| `lib/l10n/*.arb` | Créer (5 fichiers) |
| `lib/core/l10n/l10n.dart` | Créer (extension helper) |
| `lib/main.dart` | Ajouter localizationsDelegates |
| `lib/models/app_settings.dart` | Ajouter languageCode + terminalFontSize |
| `lib/features/settings/providers/settings_provider.dart` | Méthodes setLanguage + setFontSize |
| `lib/features/settings/widgets/theme_section.dart` | Renommer → general_section.dart |
| `lib/features/settings/screens/settings_screen.dart` | Renommer onglet |
| `lib/features/terminal/widgets/terminal_view.dart` | Utiliser fontSize du provider |
| **Tous les widgets avec texte** | Remplacer par context.l10n.xxx |
