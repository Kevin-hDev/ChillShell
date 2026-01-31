# 📁 VibeTerm - Architecture & Structure

> Guide pour Claude Code : structure des dossiers et organisation du code

---

## 1. Structure des Dossiers

```
vibeterm/
├── lib/
│   ├── main.dart                    # Point d'entrée
│   ├── core/                        # Core / Configuration
│   │   ├── theme/
│   │   │   ├── app_theme.dart       # ThemeData Flutter
│   │   │   ├── colors.dart          # VibeTermColors
│   │   │   ├── typography.dart      # Styles de texte
│   │   │   └── spacing.dart         # Constantes spacing
│   │   ├── constants/
│   │   │   └── app_constants.dart
│   │   └── utils/
│   │       └── extensions.dart
│   │
│   ├── features/
│   │   ├── terminal/
│   │   │   ├── screens/terminal_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── command_block.dart
│   │   │   │   ├── ghost_text_input.dart
│   │   │   │   ├── session_tab_bar.dart
│   │   │   │   ├── session_tab_item.dart
│   │   │   │   ├── session_info_bar.dart
│   │   │   │   └── send_button.dart
│   │   │   └── providers/
│   │   │       ├── terminal_provider.dart
│   │   │       └── sessions_provider.dart
│   │   │
│   │   ├── settings/
│   │   │   ├── screens/settings_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── ssh_key_card.dart
│   │   │   │   ├── toggle_switch.dart
│   │   │   │   ├── theme_selector.dart
│   │   │   │   └── settings_section.dart
│   │   │   └── providers/settings_provider.dart
│   │   │
│   │   └── auth/
│   │       ├── screens/biometric_screen.dart
│   │       └── providers/auth_provider.dart
│   │
│   ├── models/
│   │   ├── session.dart
│   │   ├── ssh_key.dart
│   │   ├── command.dart
│   │   └── app_settings.dart
│   │
│   ├── services/
│   │   ├── ssh_service.dart
│   │   ├── tmux_service.dart
│   │   ├── storage_service.dart
│   │   └── biometric_service.dart
│   │
│   └── shared/widgets/
│       ├── app_header.dart
│       └── nav_button.dart
│
├── assets/{fonts,images,icons}/
├── docs/
├── test/{unit,widget,integration}/
├── pubspec.yaml
└── README.md
```

---

## 2. Architecture : Feature-First + Riverpod

```
Screen (Widget) ← Provider (State) ← Service (Logic)
      ↓                 ↓                 ↓
    UI/UX           Riverpod         dartssh2, etc.
```

---

## 3. Fichiers Clés

### main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/terminal/screens/terminal_screen.dart';

void main() {
  runApp(const ProviderScope(child: VibeTermApp()));
}

class VibeTermApp extends StatelessWidget {
  const VibeTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeTerm',
      debugShowCheckedModeBanner: false,
      theme: VibeTermTheme.dark,
      home: const TerminalScreen(),
    );
  }
}
```

### Models

```dart
// session.dart
class Session {
  final String id;
  final String name;
  final String host;
  final String? user;
  final bool isConnected;
  final String tmuxSession;
}

// ssh_key.dart
enum SSHKeyType { ed25519, rsa }
class SSHKey {
  final String id, name, host;
  final SSHKeyType type;
  final DateTime lastUsed;
  final String privateKey;
}

// command.dart
class Command {
  final String id, command, output;
  final Duration executionTime;
  final DateTime timestamp;
}
```

---

## 4. Ordre d'Implémentation

| Phase | Tâches |
|-------|--------|
| **1. Setup** | pubspec.yaml ✅, core/theme/, main.dart |
| **2. UI Terminal** | header, terminal_screen, command_block, tabs, input |
| **3. UI Settings** | settings_screen, ssh_key_card, toggle, theme_selector |
| **4. State** | Models, providers, navigation |
| **5. SSH** | storage_service, ssh_service, tmux_service, xterm |
| **6. Polish** | biometric, animations, tests |

---

## 5. Dépendances

| Package | Usage |
|---------|-------|
| `dartssh2` | Connexion SSH |
| `xterm` | Rendu terminal |
| `flutter_riverpod` | State management |
| `flutter_secure_storage` | Clés SSH |
| `local_auth` | Biométrie |
| `google_fonts` | JetBrains Mono |

---

## 6. Notes pour Claude Code

- Consulter `VibeTerm_Design_System.md` pour toutes les valeurs exactes
- Commencer par `core/theme/` avant les widgets
- Utiliser `StateNotifierProvider` pour états complexes
- Pas de clés en dur → `flutter_secure_storage`
- Tester sur iOS et Android
