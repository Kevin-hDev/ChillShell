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

VibeTerm is a Flutter mobile terminal app for controlling a PC remotely via SSH, inspired by Warp Terminal. Documentation is in French, code is in English.

## Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run on connected device
flutter run -d <device_id>   # Run on specific device
flutter test                 # Run tests
flutter analyze              # Code analysis
dart format lib/             # Format code
flutter build apk            # Build Android APK
flutter build ios            # Build iOS
```

For Riverpod code generation:
```bash
dart run build_runner build  # Generate provider code
```

## Architecture

**Feature-First + Riverpod Pattern:**
```
Screen (Widget) → Provider (State) → Service (Business Logic) → External libs
```

### Directory Structure
- `lib/core/theme/` - Colors, typography, spacing constants (Warp Dark theme)
- `lib/features/` - Feature modules (terminal/, settings/, auth/)
  - Each feature has: screens/, widgets/, providers/
- `lib/models/` - Data classes (Session, SSHKey, Command)
- `lib/services/` - Business logic wrappers (SSH, tmux, storage, biometric)
- `lib/shared/widgets/` - Reusable widgets

### Key Dependencies
| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `dartssh2` | SSH connections (Ed25519 preferred) |
| `xterm` | Terminal rendering |
| `flutter_secure_storage` | Secure key storage |
| `local_auth` | Biometric authentication |

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
