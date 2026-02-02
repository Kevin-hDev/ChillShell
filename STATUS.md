# ChillShell - Status de développement

> Dernière mise à jour: 2 Février 2026

---

## Session 2 Février 2026 - Foreground Service SSH

### Problème résolu : Connexion SSH qui se coupe en arrière-plan

**Symptôme** : La connexion SSH se coupait immédiatement dès qu'on naviguait vers une autre app Android.

**Cause** : Android tue agressivement les sockets réseau des apps en arrière-plan pour économiser la batterie. `wakelock_plus` empêche seulement l'écran de s'éteindre, pas la fermeture des sockets.

**Solution** : Implémentation d'un Foreground Service avec `flutter_foreground_task` qui empêche Android de tuer les connexions SSH.

### Changements techniques

| Changement | Détail |
|------------|--------|
| **flutter_foreground_task** | Package ajouté (v9.2.0) |
| **wakelock_plus** | Supprimé (remplacé par foreground service) |
| **ForegroundSSHService** | Nouveau service wrapper créé |
| **AndroidManifest.xml** | Permissions FOREGROUND_SERVICE + FOREGROUND_SERVICE_DATA_SYNC |
| **Service type** | dataSync avec wakeLock et wifiLock activés |

### Fichiers modifiés/créés

| Fichier | Action |
|---------|--------|
| `lib/services/foreground_ssh_service.dart` | CRÉÉ - Service wrapper |
| `android/app/src/main/AndroidManifest.xml` | Permissions + déclaration service |
| `lib/main.dart` | Init ForegroundSSHService |
| `lib/features/terminal/providers/ssh_provider.dart` | Intégration start/stop |
| `pubspec.yaml` | +flutter_foreground_task, -wakelock_plus |
| `docs/plans/2026-02-02-foreground-service-ssh.md` | Plan d'implémentation |

### Résultats des tests

| Test | Résultat |
|------|----------|
| Téléphone verrouillé 3 min | ✅ Session active |
| Navigation vers autre app | ✅ Session active |
| Fermeture complète de l'app | ✅ Session retrouvée à la réouverture ! |

**Note** : La notification n'apparaît pas car Android 13+ requiert la permission POST_NOTIFICATIONS explicite (à ajouter plus tard si souhaité).

### Fix : Double Enter pour Claude Code

**Symptôme** : Il fallait appuyer deux fois sur Enter pour envoyer un message à Claude Code.

**Cause** : Le code envoyait `\n` (Line Feed) au lieu de `\r` (Carriage Return) pour la touche Entrée.

**Solution** :
1. Changé `\n` → `\r` dans `ghost_text_input.dart`
2. Ajouté un délai de 50ms entre le texte et le Enter pour éviter les problèmes de timing

---

## Session 1er Février 2026 - Refonte UI & Settings

### Améliorations UI globales

| Changement | Détail |
|------------|--------|
| **Header réduit** | Logo 36x36 (était 48x48), boutons 33x33 (était 44x44) |
| **Onglets réduits** | Hauteur 32px (était 44px), font 12px (était 14px), bouton + 26x26 |
| **Nommage onglets** | "Terminal 1", "Terminal 2" au lieu de l'adresse IP |
| **Barre session info** | Font 11px, IP complète visible, fond opaque |
| **Fix scroll terminal** | ClipRect pour empêcher le texte de déborder sur la barre d'infos |

### Design System - Nouveaux fichiers

| Fichier | Contenu |
|---------|---------|
| `lib/core/theme/buttons.dart` | Tailles boutons (small 32, medium 40, large 50), radius, opacity |
| `lib/core/theme/icons.dart` | Tailles icônes (xs 12, sm 18, md 24, lg 28, xl 32) |
| `lib/core/theme/animations.dart` | Durées (instant 50ms, fast 150ms, normal 250ms, slow 350ms), curves |

### Settings - Réorganisation en onglets

| Onglet | Contenu |
|--------|---------|
| **Connexion** | Clés SSH + Connexions rapides |
| **Thème** | Sélection des 12 thèmes disponibles |
| **Sécurité** | Déverrouillage biométrique + Verrouillage auto |

### Sécurité - Paramètres améliorés

| Nouveauté | Description |
|-----------|-------------|
| **Face ID séparé** | Toggle indépendant avec icône visage |
| **Empreinte séparée** | Toggle indépendant avec icône empreinte |
| **Temps verrouillage** | 4 cases cliquables : 5min / 10min / 15min / 30min |

### Fichiers modifiés

- `lib/core/theme/buttons.dart` (CRÉÉ)
- `lib/core/theme/icons.dart` (CRÉÉ)
- `lib/core/theme/animations.dart` (CRÉÉ)
- `lib/shared/widgets/app_header.dart` (réduit logo + boutons)
- `lib/features/terminal/widgets/session_tab_bar.dart` (réduit hauteur + font)
- `lib/features/terminal/screens/terminal_screen.dart` (nommage "Terminal X")
- `lib/features/terminal/providers/ssh_provider.dart` (nextTabNumber = 1)
- `lib/features/terminal/widgets/session_info_bar.dart` (fond opaque, font 11px)
- `lib/features/terminal/widgets/terminal_view.dart` (ClipRect)
- `lib/features/settings/screens/settings_screen.dart` (TabController 3 onglets)
- `lib/models/app_settings.dart` (faceIdEnabled, fingerprintEnabled, autoLockMinutes)
- `lib/features/settings/providers/settings_provider.dart` (toggleFaceId, toggleFingerprint, setAutoLockMinutes)
- `lib/features/settings/widgets/security_section.dart` (nouvelle UI sécurité)

### Local Shell - Nouvelle fonctionnalité

| Changement | Détail |
|------------|--------|
| **flutter_pty** | Ajout dépendance ^0.4.2 pour PTY local |
| **LocalShellService** | Nouveau service pour gérer le shell local |
| **SSHProvider** | Adapté pour supporter onglets SSH et locaux |
| **Bouton Local Shell** | Dans le dialog de connexion |
| **Message iOS** | Explication "Non disponible sur iOS" + "SSH fonctionne" |

**Fichiers créés/modifiés :**
- `pubspec.yaml` (ajout flutter_pty)
- `lib/services/local_shell_service.dart` (CRÉÉ)
- `lib/features/terminal/providers/ssh_provider.dart` (localTabIds, connectLocal)
- `lib/features/terminal/widgets/connection_dialog.dart` (bouton + dialog iOS)
- `lib/features/terminal/screens/terminal_screen.dart` (gestion LocalShellRequest)

---

## Session 31 Janvier 2026 (après-midi)

### Corrections de bugs

| Bug | Status | Fichier(s) |
|-----|--------|------------|
| **Affichage ncurses cassé** (htop, fzf, radeontop) | ✅ Corrigé | `ssh_service.dart`, `ssh_provider.dart`, `terminal_view.dart` |

**Cause** : Taille PTY fixée à 80x24 au lieu d'être synchronisée avec la taille réelle du terminal.

**Solution** :
- Ajout `resizeTerminal(width, height)` dans `SSHService`
- Ajout `resizeTerminal()` et `resizeTerminalForTab()` dans `SSHNotifier`
- Connexion de `terminal.onResize` callback au service SSH dans `terminal_view.dart`

---

## Session 30-31 Janvier 2026

### Corrections de bugs

| Bug | Status | Fichier(s) |
|-----|--------|------------|
| Overflow "RIGHT OVERFLOWED BY X PIXELS" sur plusieurs écrans | ✅ Corrigé | `connection_dialog.dart`, `add_ssh_key_sheet.dart`, `session_info_bar.dart` |
| Saisie directe dans le terminal (au lieu du champ en bas) | ✅ Corrigé | `terminal_view.dart` (readOnly: true) |
| Numérotation des onglets réutilisée après fermeture | ✅ Corrigé (session précédente) | `ssh_provider.dart` |
| Message d'erreur fantôme sur clics rapides "+" | ✅ Corrigé (session précédente) | `terminal_screen.dart` |

### Nouvelles fonctionnalités V1.1

| Feature | Status | Description |
|---------|--------|-------------|
| **Historique persistant** | ✅ Implémenté | 200 commandes max, sauvegardé à chaque commande via `flutter_secure_storage` |
| **Sélection de texte** | ✅ Natif | Déjà fonctionnel via xterm |
| **Bouton Send → Stop** | ✅ Implémenté | Ctrl+C pour commandes long-running, intelligent selon contexte |
| **Boutons flèches ↑↓** | ✅ Implémenté | Remplace le swipe vertical - boutons visibles pour commandes interactives |
| **Swipe droite → Entrée** | ✅ Implémenté | Confirme sélection quand process en cours + champ vide |
| ~~Swipe vertical~~ | ❌ Abandonné | Remplacé par boutons flèches (swipe trop difficile dans le petit champ) |

### Détails techniques

#### Bouton Send/Stop - Logique
```
Stop affiché si:
  - Commande "long-running" lancée
  - ET champ de saisie VIDE

Send affiché si:
  - Pas de process en cours
  - OU champ contient du texte (pour répondre aux prompts y/n, sudo, etc.)
```

#### Boutons flèches ↑↓ - Logique
```
Affichés si:
  - Process en cours (isCurrentTabRunning = true)
  - ET commande interactive (isCurrentTabInteractive = true)

Commandes interactives:
  - fzf, fzy, sk, peco, percol (fuzzy finders)
  - htop, btop, top, atop, glances, nvtop, radeontop (monitoring)
  - mc, ranger, nnn, lf, vifm, ncdu (file managers)
  - vim, vi, nvim, nano, emacs, micro (éditeurs)
  - less, more, most (pagers)
  - tig, lazygit, gitui, lazydocker, ctop (TUI apps)
```

#### Commandes "long-running" détectées
- **Serveurs** : npm, yarn, node, python, flask, cargo, go, flutter...
- **Docker** : docker-compose, docker build
- **Réseau** : curl, wget, ssh, scp, rsync
- **Installations** : apt, pip, brew, npm install...
- **Monitoring** : htop, top, btop, radeontop, nvidia-smi, nvtop, glances, iotop...
- **Éditeurs** : vim, nano, emacs
- **Fuzzy finders** : fzf, fzy, sk, peco
- **Debug** : gdb, strace, valgrind, perf
- **Scripts** : ./script.sh, *.py, *.sh
- **Commandes avec -i** : rm -i, etc.
- **Pipes** : `echo | fzf` détecte `fzf` dans le pipe

#### Gestures conservés (champ de saisie)
| Geste | Condition | Action |
|-------|-----------|--------|
| Swipe → droite | Ghost text disponible | TAB (accepter suggestion) |
| Swipe → droite | Process en cours + champ vide | Entrée (confirmer) |

---

## Fichiers modifiés cette session (31 Jan après-midi)

### `lib/services/ssh_service.dart`
- Ajout paramètres `width`/`height` à `startShell()`
- Ajout méthode `resizeTerminal(int width, int height)`

### `lib/features/terminal/providers/ssh_provider.dart`
- Ajout `resizeTerminal()` pour l'onglet actif
- Ajout `resizeTerminalForTab(tabId, width, height)` pour onglet spécifique

### `lib/features/terminal/widgets/terminal_view.dart`
- Ajout callback `terminal.onResize` qui propage au service SSH

---

## Réflexion en cours : Raccourcis terminal sur mobile

### Problématique
Le terminal nécessite beaucoup de raccourcis clavier (Ctrl+C, Ctrl+D, Ctrl+R, Tab, flèches...) difficiles à gérer sur mobile :
- Écran petit
- Pas de vrai clavier
- Clavier virtuel ne supporte pas bien les raccourcis
- Champ de saisie séparé complique l'interaction

### Solutions implémentées
- **Bouton Send/Stop** : Gère Ctrl+C automatiquement
- **Boutons flèches** : Navigation dans menus interactifs
- **Swipe droite** : TAB ou Entrée selon contexte

### À explorer
- **Snippets** : Commandes favorites en un tap
- **Navigation dossiers** : cd rapide sans taper
- **Ctrl+D** : Bouton discret pour EOF
- **Ctrl+R** : Recherche dans historique
- **Barre de raccourcis** : Style Termux (mais risque d'encombrer)

---

## Prochaines étapes (ROADMAP V1.1)

- [ ] **Mode terminal local** - Sans connexion SSH
- [ ] **Bouton Undo** - Revenir en arrière
- [ ] **Déplacement curseur tactile** - Swipe pour déplacer le curseur
- [ ] **Design des raccourcis** - Décider comment intégrer les raccourcis manquants

---

## Notes pour prochaine session

1. Bug affichage ncurses ✅ CORRIGÉ
2. Boutons flèches ↑↓ fonctionnels pour htop/fzf
3. Swipe vertical abandonné (trop difficile à déclencher)
4. L'app est stable, pas de crash

---

## Session 31 Janvier 2026 (soir) - Brainstorming V1.2

### Décisions validées

**Approche générale :**
- Boutons intelligents (contextuels) + quelques boutons permanents
- Flèches ↑↓ uniquement (pas ←→ pour simplifier)
- Raccourcis abandonnés : Ctrl+R, Ctrl+L, Ctrl+Z (clavier natif suffit)

**Nouveaux boutons à implémenter :**

| Bouton | Type | Action |
|--------|------|--------|
| **Ctrl+D** | Intelligent | EOF / Quitter shell |
| **Navigation dossiers** | Permanent | cd rapide style Warp |
| **Ctrl+O** (nano) | Intelligent | Sauvegarder (mode édition) |
| **Ctrl+X** (nano) | Intelligent | Quitter (mode édition) |

**Mode édition (nano, vim) :**
- Détection automatique quand un éditeur s'ouvre
- Terminal passe en `readOnly: false` (écriture directe)
- Champ de saisie masqué
- Boutons Ctrl+O/X affichés pour nano
- Pour vim : Escape + possibilité de taper `:wq`

**Corrections à faire :**
- Copier/coller : menu contextuel natif après sélection (ne fonctionne pas actuellement)
- Commandes interactives : ajouter alsamixer, pulsemixer, nmtui, cfdisk, journalctl

### Récapitulatif boutons V1.2

```
Boutons permanents:
- [📁~] Navigation dossiers
- [▲] Historique commandes
- [Send/Stop] Exécuter/Interrompre

Boutons intelligents (selon contexte):
- [Tab] Si ghost text disponible
- [↑] [↓] Si app interactive (htop, fzf, etc.)
- [Ctrl+D] Si shell actif sans process
- [Ctrl+O] [Ctrl+X] Si nano ouvert
- [Escape] Si vim ouvert
```

### Prochaines étapes
1. Créer le design document détaillé
2. Implémenter la navigation dossiers
3. Implémenter Ctrl+D
4. Implémenter le mode édition
5. Corriger le copier/coller
