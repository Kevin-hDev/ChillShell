# SUIVIE PATCH APP CRUSH CLI - CHILLSHELL

> Derniere mise a jour: 11 Fevrier 2026

---

## Etat actuel

| Fonctionnalite | Etat | Notes |
|----------------|------|-------|
| Affichage | OK | TUI Crush s'affiche correctement |
| Envoi messages | OK | Texte envoye via GhostTextInput fonctionne |
| Scroll | **OK** | Fix #3 : SGR mouse au centre du terminal (CONFIRME) |
| Resize protection | OK | growOnlyResize actif (CLI agent detecte) |

---

## Le probleme principal : Scroll fige dans Crush

### Symptome

L'affichage de Crush est correct mais le scroll est completement fige.
Quand l'utilisateur swipe vers le haut/bas, rien ne bouge dans l'interface de Crush.
Les messages longs ne sont pas scrollables.

### Contexte technique de Crush

- **Editeur** : Charmbracelet (meme equipe que Bubble Tea, Lip Gloss)
- **Framework TUI** : Bubble Tea (Go)
- **Successeur de** : OpenCode
- **Particularite** : Systeme de double focus (Tab pour basculer)
  - **Mode Editor** : la zone de saisie est active (fleches = historique prompts)
  - **Mode Chat** : la zone de messages est active (fleches = scroll)

### Keybindings de scroll de Crush (mode Chat uniquement)

| Touches | Action |
|---------|--------|
| ↑/↓ ou j/k | Scroll ligne par ligne |
| Shift+↑/↓ ou J/K | Scroll par message |
| Page Up/Down ou f/b | Page entiere |
| d/u | Demi-page |
| g/G | Debut/fin de conversation |
| Mouse wheel | Scroll (position-aware) |
| Tab | Basculer entre Editor et Chat |

### Support souris de Crush

Crush active le mouse tracking via Bubble Tea (`tea.WithMouseAllMotion()`).
Le mouse wheel est **position-aware** : l'evenement scroll affecte le composant
sous le curseur, pas un composant global. Si les coordonnees pointent sur le
header, le chat ne scrollera pas.

---

## CORRECTIONS APPLIQUEES

### Fix #1 — Ajout de Crush aux listes d'agents CLI (11 Fev 2026)

**Probleme** : Crush n'etait pas reconnu comme agent CLI.

**Fix** : Ajout de `'crush'` dans 3 listes :
- `_cliAgentCommands` (terminal_view.dart) — protection resize grow-only
- `_longRunningCommands` (ssh_provider.dart) — tracking du process en cours
- `_interactiveMenuCommands` (ssh_provider.dart) — support menu interactif

**Resultat** : Crush est maintenant detecte. Protection resize active.

### Fix #2 — Scroll clavier avec fleches (11 Fev 2026) — ECHEC

**Hypothese** : Envoyer des fleches ↑/↓ au lieu de SGR mouse pour Crush.

**Fix** : Liste `_keyboardScrollApps` avec `crush` et `opencode`.
Quand l'utilisateur swipe, on envoie `\x1b[A` (up) ou `\x1b[B` (down).

**Test** : Les logs montrent `Arrow UP/DOWN sent (keyboard scroll for crush)`.
Les fleches sont bien envoyees a Crush via SSH.

**Resultat** : **ECHEC** — Crush ne scrolle pas. Cause : Crush est en mode
**Editor** (la zone de saisie). En mode Editor, les fleches controlent
l'historique des prompts, pas le scroll du chat. Il faudrait appuyer Tab
pour passer en mode Chat avant que les fleches fonctionnent.

### Fix #3 — SGR mouse avec coordonnees centrees (11 Fev 2026) — CONFIRME

**Probleme identifie** : Les evenements mouse wheel SGR etaient envoyes avec
les coordonnees `(1,1)` = coin haut-gauche = barre de titre de Crush.
Le scroll est **position-aware** : seul le composant sous le curseur reagit.

**Fix** :
1. Calcul des coordonnees au **centre du terminal** au lieu de (1,1) :
   ```dart
   final int col = (terminal.viewWidth ~/ 2).clamp(1, terminal.viewWidth);
   final int row = (terminal.viewHeight ~/ 2).clamp(1, terminal.viewHeight);
   ```
2. Crush retire de `_keyboardScrollApps` (utilise SGR mouse a la place)

**Sequence envoyee** : `\x1b[<64;17;10M` (wheel up au centre ~17,10)
au lieu de `\x1b[<64;1;1M` (wheel up en haut a gauche)

**Resultat attendu** : Les logs devraient montrer
`Mouse wheel UP at (17,10) sent (SGR)` et Crush devrait scroller le chat.

**Risques** :
- tmux pourrait intercepter les evenements mouse et ne pas les transmettre
- Le format SGR pourrait ne pas etre reconnu par tmux
- Si `set -g mouse on` dans tmux, tmux gere lui-meme les mouse events

---

## Prochaines etapes si Fix #3 echoue

### Piste A — Verifier tmux mouse

Si SGR mouse ne marche pas meme avec les bonnes coordonnees, le probleme
est probablement **tmux** qui intercepte les events.

Test : lancer Crush directement (sans tmux) pour isoler.
```bash
crush   # directement, pas dans tmux
```

### Piste B — Envoyer Tab + scroll + Tab

Sequence : Tab (→ mode Chat) → fleches/j/k → Tab (→ retour Editor)
Complexe mais garanti de fonctionner si le probleme est le focus mode.

### Piste C — Tester Crush hors tmux

Si Crush fonctionne hors tmux mais pas dedans, le probleme est tmux.
Solutions possibles :
- Configurer tmux pour forwarder les mouse events
- Utiliser un mode pass-through pour les mouse events

### Piste D — Alternative : PageUp/PageDown

Les sequences `\x1b[5~` (Page Up) et `\x1b[6~` (Page Down) fonctionnent
dans Crush en mode Chat ET pourraient traverser tmux plus facilement.

---

## Historique complet des tentatives

| # | Approche | Fichier | Effet | Etat |
|---|---------|---------|-------|------|
| 1 | Ajout crush aux listes agents | ssh_provider + terminal_view | Detection OK | **OK** |
| 2 | Scroll fleches clavier | terminal_view.dart | Fleches envoyees mais ignorees (mode Editor) | **ECHEC** |
| 3 | SGR mouse coordonnees centrees | terminal_view.dart | Mouse wheel au centre du terminal | **CONFIRME** |

---

## Architecture du scroll en alternate buffer

```
Utilisateur swipe sur ecran
    |
    v
GestureDetector overlay (terminal_view.dart)
    |
    v
_handleAltBufferScroll()
    |
    ├── App dans _keyboardScrollApps? → Fleches clavier (↑/↓)
    |
    └── Sinon → Mouse wheel SGR au CENTRE du terminal
            |
            v
        sshProvider.write(sgrSequence)
            |
            v
        SSH channel → serveur PTY
            |
            ├── tmux actif? → tmux intercepte/forward
            |       |
            |       └── App avec mouse tracking? → Forward a l'app
            |
            └── Pas tmux → directement a l'app
                    |
                    v
                Crush / Bubble Tea
                    |
                    └── tea.MouseWheelMsg → scroll du composant sous le curseur
```
