## SUIVIE PATCH APP AGENT CLI - CHILLSHELL

> Derniere mise a jour: 11 Fevrier 2026

---

## Etat actuel des agents CLI

| Agent | Fonctionne | Crash | Notes |
|-------|-----------|-------|-------|
| Claude Code | Oui | Non | Patch 50ms Enter + `\r` au lieu de `\n` |
| Aider | Oui | Non | - |
| OpenCode | Oui | Non | - |
| Gemini CLI | Oui | Non | - |
| Cody | Oui | Non | - |
| Amazon Q | Oui | Non | - |
| Codex CLI | **Quasi OK** | Non | 1ere reponse peut disparaitre, sinon stable |

---

## Le probleme principal : Codex CLI sur Linux

### Les 3 problemes identifies

#### Probleme 1 — Les messages disparaissent (CRITIQUE → QUASI RESOLU)

**Symptome original** : Apres l'envoi d'un message, seul le DERNIER echange reste
visible. Apres environ 3 messages, plus rien ne s'affiche.

**Etat actuel (apres fix #5, #6, #7)** : GROSSE AMELIORATION.
- 3 messages envoyes/recus SANS disparition
- Seule la 1ere reponse GPT a disparu une fois
- Une reponse a moitie tronquee (apres "oui. je ne parle que francais")
- Ensuite plus aucun probleme

**Cause corrigee** : Combinaison de 3 bugs :
1. `_AssertionError` dans xterm.dart causait la perte de donnees (FIX #5 — CONFIRME)
2. `padding.bottom` qui oscillait avec le clavier causait des SIGWINCH inutiles (FIX #6 — CONFIRME)
3. Les SIGWINCH height-only forcaient Codex a redessiner et perdre des messages (FIX #7 — CONFIRME)

**Probleme residuel** : Le clavier se ferme et se rouvre brievement apres chaque envoi
(comportement de `TextField.onSubmitted`). Ce cycle cause un resize 35x20→35x19 que notre
guard bloque, mais le tout premier resize peut arriver avant que le guard ait enregistre
la taille initiale.

#### Probleme 2 — L'affichage deborde sur les cotes (VISUEL)

**Symptome** : Les boites et le texte de Codex depassent a droite et reviennent
a gauche du telephone.

**Explication** : Codex est concu pour 80+ colonnes. A 35 colonnes, les boites
decoratives wrappent. Ce n'est PAS un bug de l'app — c'est une limitation de Codex
a 35 colonnes.

**Piste** : Taille de police plus petite → plus de colonnes → moins de wrapping.

#### Probleme 3 — Double Enter intermittent (MINEUR)

**Symptome** : Il faut parfois appuyer 2 fois sur Enter. ~1 fois sur 4-5.

**Note** : Le patch 50ms `\r` fonctionne pour Claude Code mais pas toujours pour Codex.

---

### Indice cle

**Codex fonctionne sur Windows mais PAS sur Linux** via la meme app ChillShell.
Meme telephone, meme app, memes 35 colonnes, mais resultats differents.

Possibilites :
- Linux PTY passe les positions curseur telles quelles, Windows ConPTY les clippe
- Le rendering Ink (React pour TUI) se comporte differemment selon l'OS

---

### CORRECTIONS APPLIQUEES (11 Fevrier 2026)

#### Fix #5 — Fork xterm.dart : buffer crash (CONFIRME)

**Probleme** : `_AssertionError: 'attached': is not true` dans `circular_buffer.dart:312`.

**Fix** : Fork local de xterm 4.0.0 dans `packages/xterm/`.
```dart
// AVANT : assert(attached);
// APRES : if (!attached) return;
```

**Resultat** : ZERO `XTERM: Buffer error` — confirme sur 2 sessions de test.

#### Fix #6 — Stabilisation du terminal height (CONFIRME)

**Probleme** : `padding.bottom` changeait quand le clavier s'ouvrait (barre de nav Android).
Terminal oscillait 35x19 ↔ 35x21.

**Fix** : `terminal_screen.dart:440` — `viewPadding.bottom` (constant) au lieu de `padding.bottom`.

**Resultat** : Terminal stable a 35x20. Plus d'oscillation.

#### Fix #7 — Guard resize agents CLI (CONFIRME)

**Probleme** : Le clavier se ferme/rouvre apres chaque envoi de message (comportement
`TextField.onSubmitted`). Cela causait un resize 35x20→35x19 = SIGWINCH = redraw de Codex.

**Fix** : `terminal_view.dart` — Quand un agent CLI est actif, les resize height-only
sont bloques. Les changements de largeur passent toujours.

**Resultat** : 5 resize bloques pendant la session de test.
```
RESIZE: Blocked height-only 35x20 → 35x19 (CLI agent: codex)
```

**Agents proteges** : claude, codex, opencode, aider, gemini, cody, amazon-q, aws-q

#### Fix #8 — Iteration 1 : autoResize=false + onEditingComplete (ECHEC PARTIEL)

**Probleme identifie** : xterm resize son buffer INTERNE meme quand onResize est bloque.
`Terminal.resize()` appelle `_mainBuffer.resize()` → `lines.pop()` quand le buffer retrecit.

**Fix 8a** : `autoResize: false` pour CLI agents (RETIRE — empirait le probleme!)
Le buffer ne resize plus DU TOUT → bloque a 20 lignes meme quand clavier ferme.
L'utilisateur ne voit JAMAIS plus de 20 lignes de contenu Codex.

**Fix 8b** : `onEditingComplete` au lieu de `onSubmitted` (GARDE — marginal)
Le clavier ne se ferme plus automatiquement apres chaque envoi.
Mais l'utilisateur ferme/ouvre manuellement le clavier pour voir la sortie.

**Test 3 (apres 8a + 8b)** : ECHEC — plus de messages disparaissent qu'avant.
Cause : `autoResize=false` empechait le terminal de grandir quand le clavier
se ferme (manuellement par l'utilisateur). Codex reste bloque a 20 lignes.

#### Fix #9 — Mode grow-only dans xterm fork (A TESTER)

**Cause racine REELLE** : L'utilisateur ferme le clavier manuellement pour voir
la sortie de Codex (il n'a pas le choix). Quand il le rouvre pour taper :
1. xterm retrecit le buffer (lines.pop) → lignes perdues
2. SIGWINCH envoye avec taille reduite → Codex redessine avec moins de lignes
   → les anciens messages disparaissent car ils ne tiennent plus

**La solution : grow-only** — le terminal peut GRANDIR mais pas RETRECIR.
- Clavier ferme → terminal grandit → SIGWINCH → Codex redessine avec plus de lignes ✓
- Clavier ouvert → terminal NE retrecit PAS → PAS de SIGWINCH → Codex garde l'affichage ✓

**Modifications :**

1. **Fork xterm** (`packages/xterm/lib/src/ui/render.dart`) :
   - Ajout du flag `_growOnlyResize` avec setter public
   - `_resizeTerminalIfNeeded()` bloque les reductions de hauteur quand le flag est actif
   ```dart
   if (_growOnlyResize) {
     if (newWidth == currentWidth && newHeight <= currentHeight) {
       return; // Skip: height-only shrink or no change
     }
   }
   ```

2. **Fork xterm** (`packages/xterm/lib/src/terminal_view.dart`) :
   - Ajout du parametre `growOnlyResize` au widget `TerminalView`
   - Passe au `RenderTerminal` via `createRenderObject` et `updateRenderObject`

3. **terminal_view.dart** :
   - `growOnlyResize: isCliAgentActive` sur le widget TerminalView
   - Guard onResize modifie : autorise les augmentations, bloque les diminutions
   ```dart
   if (height < lastSize.$2) {
     // Bloquer — empêche SIGWINCH de réduction
     return;
   }
   // Autoriser — Codex redessine avec plus de lignes
   ```

**Resultat attendu** :
- Clavier ferme → terminal grandit → Codex affiche plus de messages ✓
- Clavier ouvert → terminal garde sa taille max → zero perte → zero redraw ✓

---

### Ce qu'on a fait (historique complet)

| # | Mitigation | Fichier | Effet | Etat |
|---|-----------|---------|-------|------|
| 1 | Try-catch autour de `terminal.write()` | `terminal_view.dart` | Evite le crash rouge | Actif |
| 2 | Skip resize en alternate screen | `terminal_view.dart` | Empeche SIGWINCH en alt screen | Actif |
| 3 | Throttle resize 150ms | `ssh_isolate_worker.dart` | Limite le spam de resize | Actif |
| 4 | `resizeToAvoidBottomInset: false` | `terminal_screen.dart` | Corps non resize par clavier | Actif |
| 5 | Fork xterm.dart `_move()` safe | `packages/xterm/.../circular_buffer.dart` | ZERO buffer error | **CONFIRME** |
| 6 | `viewPadding.bottom` stable | `terminal_screen.dart` | Terminal taille fixe 35x20 | **CONFIRME** |
| 7 | Guard resize CLI agents (grow-only) | `terminal_view.dart` | Augmentation OK, reduction bloquee | **MODIFIE v2** |
| 8b | `onEditingComplete` au lieu de `onSubmitted` | `ghost_text_input.dart` | Clavier reste ouvert auto | Actif |
| 9 | **growOnlyResize** dans fork xterm | `packages/xterm/.../render.dart` | Buffer grandit mais ne retrecit pas | **A TESTER** |

---

### Resultats des tests

#### Test 1 (apres fix #5 uniquement)
- ZERO buffer error ✓
- Messages apparaissent ENTIEREMENT ✓
- Messages disparaissent ENCORE ✗
- Resize oscillant 35x19↔35x21 ✗

#### Test 2 (apres fix #5 + #6 + #7)
- ZERO buffer error ✓
- Terminal stable 35x20 ✓
- 5 resize bloques par le guard ✓
- 3 messages envoyes/recus SANS disparition ✓
- 1ere reponse GPT a disparu une fois ✗ (probleme residuel)
- Une reponse a moitie tronquee ✗ (probleme residuel)

#### Test 3 (apres fix #8a + #8b) — ECHEC
- ZERO buffer error ✓
- ZERO message tronque ✓ (confirme fix #5)
- Messages 3-4 disparus apres envoi msg 5 ✗
- Message 6 disparu apres envoi msg 7 ✗
- **Cause** : `autoResize=false` empechait le terminal de grandir quand le clavier
  se ferme. L'utilisateur ferme le clavier MANUELLEMENT pour voir la sortie.
  Avec `autoResize=false`, le buffer reste bloque a 20 lignes → pas assez de place.

#### Test 4 (apres fix #9 : grow-only) — A REALISER
- [ ] ZERO buffer error
- [ ] ZERO message tronque
- [ ] Clavier ferme → terminal grandit (voir log `RESIZE: Allowed height grow`)
- [ ] Clavier ouvert → terminal garde sa taille max (voir log `RESIZE: Blocked height shrink`)
- [ ] 6+ messages envoyes/recus SANS disparition
- [ ] Messages anciens restent visibles quand on ferme le clavier

---

## Architecture actuelle du rendu terminal

### Pipeline de donnees

```
SSH Server (Linux)
    |
    v
SSHIsolateWorker (background isolate)
    | Uint8List via SendPort
    v
SSHIsolateClient (main isolate)
    | StreamController<Uint8List> (broadcast + buffer)
    v
TerminalView._connectToSSH()
    | utf8.decode(data)
    v
terminal.write(decoded)      <-- ZERO erreur maintenant (fix #5)
    |
    v
xterm.dart buffer interne    <-- fork local dans packages/xterm/
    |
    v
Ecran (widget TerminalView de xterm.dart)
```

### Protection contre le resize

```
xterm.onResize(width, height)
    |
    ├── Alternate screen actif? → SKIP (fix #2)
    ├── Meme taille que precedent? → SKIP (fix #7)
    ├── Height-only + agent CLI actif? → SKIP (fix #7)
    ├── Sinon → envoyer au PTY via SSHIsolateWorker
    |       |
    |       ├── Meme taille que precedent? → SKIP (worker check)
    |       ├── Throttle 150ms → attendre (fix #3)
    |       └── Envoyer PTY resize → SIGWINCH au process
    v
```

### Pourquoi le clavier se ferme apres chaque envoi

Le `TextField` avec `onSubmitted` ferme automatiquement le clavier.
Meme si on appelle `_focusNode.requestFocus()` juste apres, il y a un cycle :
1. Clavier se ferme (ime:null)
2. `requestFocus()` rouvre le clavier (ime:[0,0,0,1432])
3. Ce cycle provoque un resize 35x20→35x19 (1 ligne de moins)
4. Le guard bloque ce resize pour les agents CLI

---

## Patch Claude Code : double Enter

### Probleme original

Il fallait appuyer 2 fois sur Enter pour envoyer un message dans Claude Code.

### Fix applique

**Fichier** : `ghost_text_input.dart` (lignes 77-82)

```dart
sshNotifier.write(input);
Future.delayed(const Duration(milliseconds: 50), () {
  sshNotifier.write('\r');
});
```

### Impact

- Fonctionne pour TOUS les agents CLI, pas juste Claude Code
- Aucun effet negatif sur les commandes shell classiques

---

## Configuration xterm pour les agents CLI

| Propriete | Mode normal | Mode editeur | Agents CLI |
|-----------|------------|-------------|-----------|
| `readOnly` | `true` | `false` | `true` (mode normal) |
| `autofocus` | `false` | `true` | `false` (mode normal) |
| `hardwareKeyboardOnly` | `true` | `false` | `true` (mode normal) |
| `simulateScroll` | `false` | `false` | `false` |
| Input | GhostTextInput en bas | Clavier direct | GhostTextInput en bas |

---

## Prochaines etapes

- [x] Obtenir captures d'ecran + logs debug de Codex CLI
- [x] Identifier les 3 problemes distincts (messages perdus, debordement, double Enter)
- [x] Ameliorer le logging pour diagnostic precis
- [x] Identifier l'assertion : `circular_buffer.dart:312` — `_move()` sur element detache
- [x] Fix #5 : fork xterm.dart — CONFIRME (zero erreur)
- [x] Fix #6 : `viewPadding.bottom` stable — CONFIRME (terminal fixe 35x20)
- [x] Fix #7 : guard resize CLI agents — CONFIRME (5 bloques en test)
- [x] Tester : 3 messages envoyes/recus sans disparition
- [x] Investiguer la disparition de la 1ere reponse GPT (probleme residuel)
  → Cause : xterm resize son buffer INTERNE meme quand onResize est bloque
  → lines.pop() supprime des lignes quand le buffer retrecit
- [x] Considerer empecher le clavier de se fermer apres `onSubmitted`
  → Fix 8b : onEditingComplete remplace onSubmitted
- [x] Fix #8a : autoResize=false pour CLI agents — RETIRE (empirait le probleme)
- [x] Fix #8b : onEditingComplete — empeche le clavier de se fermer auto
- [x] Test 3 : ECHEC — autoResize=false bloquait le terminal a 20 lignes
- [x] Comprendre : l'utilisateur ferme le clavier MANUELLEMENT pour voir Codex
  → Le terminal DOIT pouvoir grandir quand le clavier se ferme
  → Le terminal NE DOIT PAS retrecir quand le clavier s'ouvre
- [x] Fix #9 : growOnlyResize dans fork xterm — terminal grandit mais ne retrecit pas
- [ ] **Tester fix #9 : 6+ messages sans disparition ni troncature**
- [ ] Explorer taille de police plus petite (plus de colonnes pour Codex)
- [ ] Verifier que Claude Code et les autres agents ne sont pas impactes

---
