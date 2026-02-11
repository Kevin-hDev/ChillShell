# SUIVIE PATCH APP OPENCODE CLI - CHILLSHELL

> Derniere mise a jour: 11 Fevrier 2026

---

## Etat actuel

| Fonctionnalite | Etat | Notes |
|----------------|------|-------|
| Affichage | OK | TUI OpenCode s'affiche correctement |
| Envoi messages | OK | Texte envoye via GhostTextInput fonctionne |
| Scroll | **EN COURS** | Le scroll souris est DESACTIVE dans OpenCode |
| Resize protection | OK | growOnlyResize actif (CLI agent detecte) |

---

## Le probleme principal : Scroll dans OpenCode

### Symptome

Le scroll tactile ne fonctionne pas dans OpenCode. L'affichage est correct
mais le contenu reste fige quand l'utilisateur swipe.

### Contexte technique de OpenCode

- **Repository** : [opencode-ai/opencode](https://github.com/opencode-ai/opencode)
- **Framework TUI** : Bubble Tea **v1.3.5** (PAS v2 comme Crush)
- **Composant scroll** : `viewport.Model` standard de Bubbles
- **Predecesseur de** : Crush (fork Charmbracelet)

### DECOUVERTE CRITIQUE : Mouse scroll DESACTIVE

Le developpeur d'OpenCode a **volontairement desactive** le support souris.
Confirme dans [issue #166](https://github.com/opencode-ai/opencode/issues/166) :
> "Le scroll souris etait active avant mais je l'ai desactive car il
> causait des problemes."

**Code** (`cmd/root.go` ligne 120-123) :
```go
program := tea.NewProgram(
    tui.New(app),
    tea.WithAltScreen(),  // <-- SEULE option, PAS de tea.WithMouseAllMotion()
)
```

Cela signifie :
- **Aucun mode mouse** n'est active (`\x1b[?1000h`, etc. jamais envoyes)
- **SGR mouse events** : ignores (pas de tracking actif)
- **Seul le clavier** fonctionne pour scroller

### Keybindings de scroll d'OpenCode

Definis dans `internal/tui/components/chat/list.go` :

| Touches | Action |
|---------|--------|
| Page Up | Page entiere vers le haut |
| Page Down | Page entiere vers le bas |
| Ctrl+U | Demi-page vers le haut |
| Ctrl+D | Demi-page vers le bas |

**ATTENTION** : PAS de j/k, PAS de fleches ↑/↓ pour le scroll !
Les fleches sont reservees a la navigation dans l'editeur.

### Differences OpenCode vs Crush

| Aspect | OpenCode | Crush |
|--------|----------|-------|
| Bubble Tea | v1.3.5 | v2.0.0-rc2 |
| Mouse scroll | **DESACTIVE** | Active (5 lignes/cran) |
| Composant scroll | viewport standard | List personnalise (lazy) |
| Scroll clavier | PgUp/PgDown/Ctrl+U/D | j/k/f/b/d/u/g/G/PgUp/PgDown |
| Mouse click | Non | Oui (selection texte) |
| Mouse drag | Non | Oui (selection) |

---

## CORRECTIONS APPLIQUEES

### Fix #1 — Scroll PgUp/PgDown pour OpenCode (11 Fev 2026) — A TESTER

**Probleme** : OpenCode n'a PAS de mouse scroll. Il utilise uniquement
PgUp/PgDown et Ctrl+U/Ctrl+D pour scroller.

**Fix** : Modifier `_keyboardScrollApps` pour envoyer **Page Up/Down**
(`\x1b[5~` / `\x1b[6~`) au lieu de fleches quand OpenCode est detecte.

**Sequences** :
- Page Up : `\x1b[5~`
- Page Down : `\x1b[6~`

---

## Issues GitHub connues (OpenCode)

| Issue | Titre | Statut |
|-------|-------|--------|
| [#166](https://github.com/opencode-ai/opencode/issues/166) | Can't scroll inside terminal window | **OUVERT** |
| [#276](https://github.com/opencode-ai/opencode/issues/276) | Scroll position resets on new message | **OUVERT** |
| [#263](https://github.com/opencode-ai/opencode/issues/263) | I can't copy messages | OUVERT |

---

## Architecture du scroll dans OpenCode

```
OpenCode (Go, Bubble Tea v1)
    |
    ├── tea.NewProgram() — PAS de WithMouseAllMotion()
    |       → Mouse DESACTIVE
    |
    ├── viewport.Model (Bubbles standard)
    |       └── KeyMap:
    |           ├── PageUp   → pgup
    |           ├── PageDown → pgdown
    |           ├── HalfPageUp → ctrl+u
    |           └── HalfPageDown → ctrl+d
    |
    └── Update() — key.Matches(msg, messageKeys.PageUp/PageDown/...)
            → viewport.Update(msg)
            → Scroll du contenu
```

---

## Historique complet des tentatives

| # | Approche | Fichier | Effet | Etat |
|---|---------|---------|-------|------|
| 1 | SGR mouse (1,1) | terminal_view.dart | Ignore (pas de mouse tracking) | **ECHEC** |
| 2 | Fleches clavier | terminal_view.dart | Ignore (pas de binding fleches) | **ECHEC** |
| 3 | PgUp/PgDown | terminal_view.dart | Correspond aux bindings OpenCode | **A TESTER** |

---

## Prochaines etapes

- [x] Analyser le repo OpenCode pour comprendre le systeme de scroll
- [x] Decouvrir que le mouse est DESACTIVE volontairement
- [x] Identifier les bons keybindings (PgUp/PgDown/Ctrl+U/D)
- [ ] Implementer l'envoi de PgUp/PgDown pour le swipe
- [ ] Tester avec OpenCode sur device
- [ ] Verifier que les autres agents ne sont pas impactes
