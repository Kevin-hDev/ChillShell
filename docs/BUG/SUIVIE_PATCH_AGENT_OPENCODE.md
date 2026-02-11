# SUIVIE PATCH APP OPENCODE CLI - CHILLSHELL

> Derniere mise a jour: 11 Fevrier 2026

---

## Etat actuel

| Fonctionnalite | Etat | Notes |
|----------------|------|-------|
| Affichage | **LIMITATION** | Bordures panneaux cassees a 45 colonnes (limitation OpenCode) |
| Envoi messages | OK | Texte envoye via GhostTextInput fonctionne |
| Scroll | **OK** | Fix #1 : PgUp/PgDown envoyes quand swipe (CONFIRME) |
| Resize protection | OK | growOnlyResize actif (CLI agent detecte) |
| SessionInfoBar | OK | Masquee automatiquement quand agent CLI actif |

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

### Fix #1 — Scroll PgUp/PgDown pour OpenCode (11 Fev 2026) — CONFIRME

**Probleme** : OpenCode n'a PAS de mouse scroll. Il utilise uniquement
PgUp/PgDown et Ctrl+U/Ctrl+D pour scroller.

**Fix** : Modifier `_keyboardScrollApps` pour envoyer **Page Up/Down**
(`\x1b[5~` / `\x1b[6~`) au lieu de fleches quand OpenCode est detecte.

**Sequences** :
- Page Up : `\x1b[5~`
- Page Down : `\x1b[6~`

**Resultat** : CONFIRME — le scroll fonctionne dans OpenCode via swipe.

### Fix #2 — SessionInfoBar masquee pour agents CLI (11 Fev 2026) — OK

**Probleme** : La barre d'info session (tmux, IP, Tailscale) prenait une
ligne d'espace vertical inutile quand un agent CLI est actif.

**Fix** : `terminal_screen.dart` — la `SessionInfoBar` est masquee
automatiquement quand `tabCurrentCommand` correspond a un agent CLI connu.

**Resultat** : Gain d'une ligne d'espace pour le terminal.

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

## Probleme d'affichage : bordures panneaux cassees

### Symptome

Les panneaux d'OpenCode (zone system prompt, zone chat) sont entoures de
bordures avec des caracteres box-drawing (`─`, `│`, `┌`, `┐`). Sur un ecran
mobile (~45 colonnes en taille 10px), ces bordures se superposent au texte
et creent un affichage confus avec des lignes horizontales qui traversent
le contenu.

### Cause

**Limitation OpenCode** — son layout Lip Gloss (framework CSS pour TUI) est
concu pour des terminaux de 80+ colonnes. A 45 colonnes, les panneaux sont
trop etroits pour afficher correctement les bordures + le contenu.

### Verdict

**NON CORRIGEABLE cote ChillShell.** C'est le code Go de Lip Gloss/Bubble Tea
qui gere le rendu des bordures. OpenCode devrait adapter son layout pour les
terminaux etroits.

Teste avec police 10px (~45 colonnes) : les bordures sont toujours cassees.
Descendre en dessous de 10px serait illisible sur mobile.

---

## Historique complet des tentatives

| # | Approche | Fichier | Effet | Etat |
|---|---------|---------|-------|------|
| 1 | SGR mouse (1,1) | terminal_view.dart | Ignore (pas de mouse tracking) | **ECHEC** |
| 2 | Fleches clavier | terminal_view.dart | Ignore (pas de binding fleches) | **ECHEC** |
| 3 | PgUp/PgDown | terminal_view.dart | Scroll fonctionne | **CONFIRME** |
| 4 | SessionInfoBar masquee | terminal_screen.dart | Gain 1 ligne d'espace | **OK** |

---

## Prochaines etapes

- [x] Analyser le repo OpenCode pour comprendre le systeme de scroll
- [x] Decouvrir que le mouse est DESACTIVE volontairement
- [x] Identifier les bons keybindings (PgUp/PgDown/Ctrl+U/D)
- [x] Implementer l'envoi de PgUp/PgDown pour le swipe
- [x] Tester avec OpenCode sur device — scroll CONFIRME
- [x] Masquer SessionInfoBar pour gagner de l'espace
- [x] Investiguer affichage casse (bordures panneaux) — limitation OpenCode
- [ ] Verifier que les autres agents ne sont pas impactes
