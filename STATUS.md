# ChillShell - Status de développement

> Dernière mise à jour: 31 Janvier 2026

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
4. Réflexion en cours sur les raccourcis (Ctrl+D, Ctrl+R, etc.)
5. L'app est stable, pas de crash
