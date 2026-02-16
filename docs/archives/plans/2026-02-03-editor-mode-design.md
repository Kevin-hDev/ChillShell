# Mode Édition (nano, vim) - Design

> Date: 3 Février 2026

## Objectif

Permettre l'édition directe dans le terminal quand un éditeur (nano, vim, etc.) est ouvert, en masquant le champ de saisie et en affichant des boutons overlay.

## Détection automatique

### Séquences ANSI "Alternate Screen Mode"

| Séquence | Signification | Action |
|----------|---------------|--------|
| `\x1b[?1049h` | Entrée alternate screen | Activer mode édition |
| `\x1b[?1049l` | Sortie alternate screen | Désactiver mode édition |

### Implémentation

- Intercepter la sortie SSH dans `terminal_view.dart`
- Parser les séquences avant de les envoyer au terminal xterm
- Nouveau provider : `isEditorModeProvider` (`StateProvider<bool>`)

## Changements Terminal

| Propriété | Mode normal | Mode édition |
|-----------|-------------|--------------|
| `readOnly` | `true` | `false` |
| `hardwareKeyboardOnly` | `true` | `false` |
| `autofocus` | `false` | `true` |

## UI - Boutons Overlay

### Mode normal (3 boutons verticaux à droite)

```
                          ┌───┐
                          │ ⊞ │  ← Toggle D-pad
                          ├───┤
                          │CTL│  ← CTRL
                          ├───┤
                          │ ↵ │  ← Enter
                          └───┘
```

### D-pad activé (croix à gauche des 3 boutons)

```
              ┌───┐       ┌───┐
              │ ↑ │       │ ⊞ │
          ┌───┼───┼───┐   ├───┤
          │ ← │   │ → │   │CTL│
          └───┼───┼───┘   ├───┤
              │ ↓ │       │ ↵ │
              └───┘       └───┘
```

### Position

- `Positioned(right: 16, bottom: 16)` dans le Stack du terminal
- Juste au-dessus du clavier virtuel
- Accessible au pouce droit

## Fichiers à modifier

| Fichier | Modification |
|---------|--------------|
| `terminal_provider.dart` | Ajouter `isEditorModeProvider` |
| `terminal_view.dart` | Détecter séquences + ajuster `readOnly` + overlay boutons |
| `terminal_screen.dart` | Masquer `GhostTextInput` en mode édition |
| `terminal_action_buttons.dart` | Nouveau widget `EditorModeButtons` |

## Flux complet

```
1. User tape "nano fichier.txt"
           ↓
2. nano envoie \x1b[?1049h (alternate screen)
           ↓
3. On détecte → isEditorModeProvider = true
           ↓
4. Terminal: readOnly=false, clavier s'ouvre
   GhostTextInput: masqué
   Boutons overlay: affichés à droite
           ↓
5. User édite dans nano avec clavier + boutons
           ↓
6. User quitte nano (Ctrl+X)
           ↓
7. nano envoie \x1b[?1049l (sortie alternate screen)
           ↓
8. On détecte → isEditorModeProvider = false
           ↓
9. Retour mode normal (readOnly=true, GhostTextInput visible)
```

## Apps supportées

Toutes les apps qui utilisent l'alternate screen mode :
- nano, vim, nvim, emacs, micro, helix
- less, more, most
- htop, btop, top
- ranger, mc, nnn
- etc.
