# Terminal Action Buttons Refactoring - Plan d'implémentation

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extraire les 5 widgets de boutons de `ghost_text_input.dart` vers un fichier séparé `terminal_action_buttons.dart` pour améliorer la maintenabilité et faciliter l'ajout de nouveaux raccourcis.

**Architecture:** Créer un nouveau fichier contenant tous les boutons d'action du terminal avec des widgets publics réutilisables. Le fichier `ghost_text_input.dart` importera ces boutons au lieu de les définir en interne.

**Tech Stack:** Flutter, Riverpod, Design System ChillShell (VibeTermThemeData)

---

## Task 1: Créer le fichier terminal_action_buttons.dart

**Files:**
- Create: `lib/features/terminal/widgets/terminal_action_buttons.dart`

**Step 1: Créer le fichier avec les imports et l'export barrel**

```dart
/// Terminal Action Buttons
///
/// Boutons d'action pour la barre de saisie du terminal.
/// Séparés pour faciliter la maintenance et l'ajout de nouveaux raccourcis.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';

// Export tous les boutons
part 'terminal_action_buttons/history_button.dart';
part 'terminal_action_buttons/send_button.dart';
part 'terminal_action_buttons/stop_button.dart';
part 'terminal_action_buttons/arrow_button.dart';
part 'terminal_action_buttons/ghost_accept_button.dart';
```

**Note:** On va utiliser une approche plus simple - un seul fichier avec tous les boutons exportés publiquement.

---

## Task 2: Créer terminal_action_buttons.dart (version simple)

**Files:**
- Create: `lib/features/terminal/widgets/terminal_action_buttons.dart`

**Step 1: Écrire le fichier complet avec tous les boutons**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/theme_provider.dart';

/// Bouton pour naviguer dans l'historique des commandes
class TerminalHistoryButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalHistoryButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.border),
        ),
        child: Icon(
          icon,
          color: theme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

/// Bouton pour accepter le ghost text (autocomplétion)
class TerminalGhostAcceptButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalGhostAcceptButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.keyboard_tab,
          color: theme.accent,
          size: 18,
        ),
      ),
    );
  }
}

/// Bouton pour envoyer une commande
class TerminalSendButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalSendButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.arrow_upward,
          color: theme.bg,
          size: 28,
        ),
      ),
    );
  }
}

/// Bouton pour arrêter un processus (Ctrl+C)
class TerminalStopButton extends StatelessWidget {
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalStopButton({
    super.key,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: theme.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.stop,
          color: theme.bg,
          size: 28,
        ),
      ),
    );
  }
}

/// Bouton flèche pour navigation dans les menus interactifs (htop, fzf, etc.)
class TerminalArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const TerminalArrowButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
        ),
        child: Icon(
          icon,
          color: theme.accent,
          size: 24,
        ),
      ),
    );
  }
}
```

**Step 2: Vérifier que le fichier compile**

Run: `flutter analyze lib/features/terminal/widgets/terminal_action_buttons.dart`
Expected: No issues found

---

## Task 3: Mettre à jour ghost_text_input.dart

**Files:**
- Modify: `lib/features/terminal/widgets/ghost_text_input.dart`

**Step 1: Ajouter l'import du nouveau fichier**

Ajouter après la ligne 7 (`import '../providers/providers.dart';`):

```dart
import 'terminal_action_buttons.dart';
```

**Step 2: Remplacer les appels aux boutons privés par les boutons publics**

Remplacer dans la méthode `build()`:

| Ancien (privé) | Nouveau (public) |
|----------------|------------------|
| `_HistoryButton` | `TerminalHistoryButton` |
| `_AcceptGhostButton` | `TerminalGhostAcceptButton` |
| `_SendButton` | `TerminalSendButton` |
| `_StopButton` | `TerminalStopButton` |
| `_ArrowButton` | `TerminalArrowButton` |

**Step 3: Supprimer les définitions de classes privées (lignes 278-422)**

Supprimer les classes suivantes du fichier:
- `_HistoryButton` (lignes 278-306)
- `_AcceptGhostButton` (lignes 308-334)
- `_SendButton` (lignes 336-361)
- `_StopButton` (lignes 363-388)
- `_ArrowButton` (lignes 390-422)

**Step 4: Vérifier que tout compile**

Run: `flutter analyze lib/features/terminal/widgets/`
Expected: No issues found

---

## Task 4: Vérifier le build complet

**Step 1: Analyser tout le projet**

Run: `flutter analyze`
Expected: No issues found

**Step 2: Test de build (optionnel)**

Run: `flutter build apk --debug`
Expected: Build successful

---

## Task 5: Commit

**Step 1: Commit les changements**

```bash
git add lib/features/terminal/widgets/terminal_action_buttons.dart
git add lib/features/terminal/widgets/ghost_text_input.dart
git commit -m "refactor: extract terminal action buttons to separate file

- Create terminal_action_buttons.dart with 5 public button widgets
- TerminalHistoryButton, TerminalGhostAcceptButton, TerminalSendButton
- TerminalStopButton, TerminalArrowButton
- Prepare for adding new shortcut buttons (Ctrl+D, Ctrl+R, etc.)
- No functional changes"
```

---

## Résumé des fichiers

### Avant
```
lib/features/terminal/widgets/
├── ghost_text_input.dart (423 lignes, 5 boutons privés)
└── ...
```

### Après
```
lib/features/terminal/widgets/
├── ghost_text_input.dart (~280 lignes, utilise boutons importés)
├── terminal_action_buttons.dart (~150 lignes, 5 boutons publics)
└── ...
```

### Avantages
- `ghost_text_input.dart` passe de 423 à ~280 lignes (-34%)
- Boutons réutilisables et testables séparément
- Facile d'ajouter de nouveaux boutons dans `terminal_action_buttons.dart`
- Pas de changement fonctionnel, juste réorganisation

---

*Plan créé le 31 Janvier 2026*
