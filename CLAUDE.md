# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## User Preferences

- **Langue** : L'utilisateur parle uniquement français. Toujours répondre en français, éviter l'anglais.
- **Recherche web** : Utiliser le MCP Brave Search (`mcp__brave-search__brave_web_search`) pour toutes les recherches web.
- **Skills** : Utiliser les skills disponibles selon la situation. Skills clés :
  - `superpowers:brainstorming` - Avant tout travail créatif (nouvelles features, composants)
  - `superpowers:writing-plans` - Pour planifier l'implémentation d'une tâche multi-étapes
  - `superpowers:test-driven-development` - Pour implémenter features/bugfixes
  - `superpowers:systematic-debugging` - Face à un bug ou comportement inattendu
  - `superpowers:verification-before-completion` - Avant de dire qu'un travail est terminé
  - `interface-design` - Pour le design d'interfaces (dashboards, apps)

## Project Overview

**ChillShell** (nom de code interne : VibeTerm) est une app mobile Flutter pour contrôler un PC à distance via SSH, inspirée de Warp Terminal. La documentation est en français, le code en anglais. L'app supporte Android et iOS.

### Fonctionnalités principales
- **Terminal SSH** : connexions SSH avec clés Ed25519, onglets multiples, reconnexion auto
- **Wake-on-LAN** : réveil de PC à distance via Magic Packet (config MAC + connexion SSH liée)
- **Sécurité** : verrouillage PIN/biométrie, protection screenshot, nettoyage presse-papier, détection root, journal d'audit
- **i18n** : 5 langues (EN, FR, ES, DE, ZH) via fichiers ARB
- **Thèmes** : Warp Dark (défaut), Dracula, Nord

## Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run on connected device
flutter run -d <device_id>   # Run on specific device
flutter test                 # Run tests (97 tests)
flutter analyze              # Code analysis
dart format lib/             # Format code
flutter build apk            # Build Android APK
flutter build ios            # Build iOS
```

For Riverpod code generation:
```bash
dart run build_runner build  # Generate provider code
```

For i18n (after modifying .arb files):
```bash
flutter gen-l10n             # Generate localization files from lib/l10n/app_*.arb
```

## Architecture

**Feature-First + Riverpod Pattern:**
```
Screen (Widget) → Provider (State) → Service (Business Logic) → External libs
```

### Directory Structure
- `lib/core/theme/` - Colors, typography, spacing constants (Warp Dark theme)
- `lib/core/l10n/` - Localization extension (`context.l10n`)
- `lib/l10n/` - ARB translation files (app_en.arb, app_fr.arb, etc.) + generated localizations
- `lib/features/` - Feature modules:
  - `terminal/` - SSH terminal, tabs, reconnection logic
  - `settings/` - App settings, SSH keys management, WOL configuration
  - `auth/` - PIN code, biometric lock, lock screen
  - Each feature has: screens/, widgets/, providers/
- `lib/models/` - Data classes (Session, SSHKey, SavedConnection, WolConfig, Command, AppSettings)
- `lib/services/` - Business logic:
  - `ssh_service.dart` - SSH connection handling
  - `secure_storage_service.dart` - Encrypted key/data storage
  - `wol_service.dart` - Wake-on-LAN packet sending
  - `biometric_service.dart` - Fingerprint/face auth
  - `pin_service.dart` - PIN code management
  - `audit_log_service.dart` - Security event logging
  - `screenshot_protection_service.dart` - Screenshot/screen recording protection
  - `device_security_service.dart` - Root/jailbreak detection
- `lib/shared/widgets/` - Reusable widgets

### Key Dependencies
| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `dartssh2` | SSH connections (Ed25519 preferred) |
| `xterm` | Terminal rendering |
| `flutter_secure_storage` | Secure key storage |
| `local_auth` | Biometric authentication |
| `wake_on_lan` | WOL Magic Packet sending |
| `cryptography` / `pointycastle` | SSH cryptographic operations |
| `flutter_foreground_task` | Background SSH connection persistence (Android) |
| `google_fonts` | JetBrains Mono font |
| `uuid` | Unique ID generation for models |

## Internationalization (i18n)

- 5 languages: English, French, Spanish, German, Chinese
- Translation files: `lib/l10n/app_{en,fr,es,de,zh}.arb`
- Access in code: `context.l10n.keyName` (via extension in `lib/core/l10n/l10n.dart`)
- Generated files: `lib/l10n/app_localizations*.dart` (do not edit manually)
- **Rule**: All user-facing strings must use l10n keys, never hardcode text

## Design System Reference

All design values are in `lib/core/theme/`:
- `colors.dart` - VibeTermColors (Warp Dark), DraculaColors, NordColors
- `typography.dart` - Text styles using JetBrains Mono
- `spacing.dart` - Padding, radius, sizing constants
- `app_theme.dart` - Material ThemeData

Core palette: bg=#0F0F0F, accent=#10B981 (emerald green)

## Critical Rules

1. **Security**: Never hardcode SSH keys or passwords. Use `flutter_secure_storage`.
2. **State**: Use Riverpod (`StateNotifierProvider` for complex state). No GetX/Bloc.
3. **Widgets**: Prefer StatelessWidget and ConsumerWidget for Riverpod integration.
4. **Dependencies**: Don't add packages without justification.
5. **i18n**: All user-visible text must go through l10n. Update all 5 ARB files + run `flutter gen-l10n`.
6. **Models**: Use immutable data classes with `copyWith()`. Never mutate state directly.

## Documentation

For detailed specs, consult in order:
1. `docs/VibeTerm_Design_System.md` - Design values (authoritative)
2. `docs/VibeTerm_Architecture.md` - Technical architecture
3. `docs/VibeTerm_SSH_Guide.md` - SSH/tmux implementation patterns
4. `VibeTerm_2026_Specifications_v2.md` - Functional requirements

## RAPPEL
1. Répond moi ou commence toujours par me parlé en Français, je ne parle pas anglais.
2. Pense à utiliser le PLUGIN superpowers et ces différents skills en fonction de la taches.
3.  Je n'ai pas de connaissance en programmation, je ne sais pas lire le code je peux vite être perdu dans le language de développer.
