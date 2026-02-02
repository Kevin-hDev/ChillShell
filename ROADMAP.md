# ChillShell Roadmap

> Terminal mobile pour vibe coder depuis n'importe où

---

## ✅ V1.0 - Core (Complété)

### Fonctionnalités de base
- [x] Connexion SSH avec dartssh2 (Ed25519/RSA)
- [x] Terminal xterm.dart fonctionnel
- [x] Multi-onglets avec connexions SSH indépendantes
- [x] Génération de clés SSH (Ed25519/RSA)
- [x] Stockage sécurisé des clés (flutter_secure_storage)
- [x] Authentification biométrique (FaceID/TouchID)
- [x] Auto-lock après 10 minutes d'inactivité
- [x] Thème Warp Dark
- [x] Ghost text / suggestions de commandes
- [x] Navigation dans l'historique des commandes (session)
- [x] Connexions sauvegardées
- [x] Auto-connexion au démarrage (optionnel)
- [x] Reconnexion automatique (optionnel)

### Corrections de bugs (30 Jan 2026)
- [x] Fix: Contenu des onglets qui se mélangeait à la fermeture
- [x] Fix: Numérotation des onglets (Terminal 3, 4 → 3 réutilisé au lieu de 5)
- [x] Fix: Message d'erreur fantôme lors de clics rapides sur "+"
- [x] Fix: Nouvel onglet affiche vide jusqu'à navigation
- [x] Fix: Commande PS1 visible dans le terminal (supprimée)

### Audit & Optimisations (30 Jan 2026)
- [x] Sécurité: Clés privées jamais stockées en mémoire (keyId reference)
- [x] Performance: Cache du thème terminal
- [x] Performance: Riverpod selectors (rebuilds ciblés)
- [x] Robustesse: Guard anti-double création d'onglet
- [x] Robustesse: Retry mechanism pour streams async

---

## ✅ V1.1 - Corrections UX (Complété - 31 Jan 2026)

### Priorité haute
- [x] **Historique persistant** - Sauvegarder l'historique entre sessions (200 commandes max)
- [x] **Sélection de texte** - Long press pour sélectionner dans le terminal (natif xterm)
- [x] **Bouton Send → Stop** - Ctrl+C pour commandes long-running, intelligent selon contexte
- [x] **Boutons flèches ↑↓** - Navigation dans menus interactifs (htop, fzf, etc.)
- [x] **Fix affichage ncurses** - Synchronisation taille PTY avec le terminal (htop, fzf, radeontop)

### Changements de design
- [x] ~~Swipe vertical~~ → **Boutons flèches** (swipe trop difficile dans le petit champ)

### UI actuelle
```
┌─────────────────────────────────────────────────────────────┐
│ Header: [Logo] ChillShell  [Déconnect] [Tmux] [Settings]   │
├─────────────────────────────────────────────────────────────┤
│ Tabs: [●192.168.1.93 ×] [Terminal 2 ×]              [+]    │
├─────────────────────────────────────────────────────────────┤
│ Session info: ← tmux: vibe • 192.168...  ⏱ 2m 34s  Tailsc │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    Terminal View (xterm)                    │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [▲] > [Input field...............] [↑] [↓] [Stop/Send]     │
│  ↑                                  ↑   ↑      ↑            │
│  │                                  │   │      └─ Rouge=Stop│
│  │                                  │   │         Vert=Send │
│  │                                  └───┴─ Flèches (si htop)│
│  └─ Historique                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 V1.2 - Boutons & Mode Édition (En cours)

### ✅ Foreground Service SSH (2 Fév 2026)

**Problème résolu** : Connexion SSH qui se coupait en arrière-plan Android.

- [x] **Foreground Service** - Maintient les connexions SSH actives en arrière-plan
- [x] **Suppression wakelock_plus** - Remplacé par le foreground service (plus efficace)
- [x] **Persistance session** - L'onglet et la session restent actifs même après fermeture de l'app !
- [x] **Fix double Enter** - Claude Code ne nécessite plus 2 Enter (`\n` → `\r`)

**Résultats testés** :
- ✅ Téléphone verrouillé 3 min → session active
- ✅ Navigation autre app → session active
- ✅ Fermeture complète app → session retrouvée !

### ✅ Améliorations UI (1er Fév 2026)

**Design System créé :**
- [x] `buttons.dart` - Constantes de tailles boutons
- [x] `icons.dart` - Constantes de tailles icônes
- [x] `animations.dart` - Durées et curves d'animation

**Réduction tailles (~25%) :**
- [x] Header : logo 36x36, boutons 33x33
- [x] Onglets : hauteur 32px, font 12px
- [x] Nommage : "Terminal 1" au lieu de l'IP
- [x] Barre session : font 11px, IP complète

**Fix bugs :**
- [x] Scroll terminal qui déborde sur la barre d'infos (ClipRect)

**Settings réorganisés :**
- [x] 3 onglets : Connexion | Thème | Sécurité
- [x] Face ID et Empreinte séparés avec toggles indépendants
- [x] Temps de verrouillage auto : 5min / 10min / 15min / 30min

### Décisions de design (brainstorming 31 Jan 2026)
- **Approche** : Boutons intelligents (contextuels) + quelques boutons permanents
- **Flèches** : ↑↓ uniquement (pas ←→)
- **Raccourcis abandonnés** : Ctrl+R, Ctrl+L, Ctrl+Z (pas essentiels sur mobile)

### Boutons à implémenter

| Bouton | Type | Condition d'affichage | Action |
|--------|------|----------------------|--------|
| **Ctrl+D** | Intelligent | Shell actif, pas de process | EOF / Quitter shell |
| **Navigation dossiers** | Permanent | Toujours | cd rapide (style Warp) |
| **Ctrl+O** (nano) | Intelligent | Éditeur nano ouvert | Sauvegarder |
| **Ctrl+X** (nano) | Intelligent | Éditeur nano ouvert | Quitter |

### Mode édition (nano, vim)
- [ ] **Détection éditeur** - Détecter quand nano/vim s'ouvre
- [ ] **Terminal éditable** - Passer `readOnly: false` en mode édition
- [ ] **Masquer champ saisie** - Le champ du bas disparaît
- [ ] **Boutons nano** - Ctrl+O (sauvegarder) + Ctrl+X (quitter)
- [ ] **Boutons vim** - Escape + possibilité de taper `:wq`, `:q!`
- [ ] **Retour mode normal** - Quand l'éditeur se ferme

### Corrections
- [ ] **Copier/coller terminal** - Menu contextuel natif après sélection
- [ ] **Commandes interactives** - Ajouter : alsamixer, pulsemixer, nmtui, cfdisk, journalctl

### UI cible V1.2
```
Mode normal:
┌─────────────────────────────────────────────────────────────┐
│ [📁~] [▲] > [Input field...........] [↑] [↓] [Ctrl+D] [Send]│
│   ↑    ↑                              ↑   ↑     ↑       ↑   │
│   │    │                              │   │     │       └─ Vert│
│   │    │                              │   │     └─ Intelligent │
│   │    │                              └───┴─ Si app interactive│
│   │    └─ Historique                                        │
│   └─ Navigation dossiers (permanent)                        │
└─────────────────────────────────────────────────────────────┘

Mode édition (nano):
┌─────────────────────────────────────────────────────────────┐
│                    Terminal éditable                        │
│                    (clavier virtuel actif)                  │
├─────────────────────────────────────────────────────────────┤
│              [Ctrl+O Sauvegarder] [Ctrl+X Quitter]          │
└─────────────────────────────────────────────────────────────┘
```

### Priorité basse (V1.2+)
- [x] **Mode terminal local** - Local Shell sur Android (message explicatif sur iOS)

---

## 🚀 V1.3 - Navigation & Productivité (Planifié)

### Navigation
- [ ] **Bouton Snippets** - Commandes favorites en accordéon (style Warp)

### Productivité
- [ ] **Complétion intelligente** - TAB chaîné, suggestions multiples
- [ ] **Alias rapides** - Commandes personnalisées

---

## 🌍 V2.0 - International & Premium (Futur)

### Multi-langues
- [ ] Anglais (défaut)
- [ ] Français
- [ ] Espagnol
- [ ] Allemand
- [ ] Chinois

### Features avancées
- [ ] **Mosh support** - Connexions persistantes sur réseaux instables
- [ ] **SFTP** - Transfert de fichiers intégré
- [ ] **Sync cross-device** - Synchronisation des connexions/snippets
- [ ] **Settings avancés** - Plus d'options de personnalisation

### Monétisation
- [ ] Version gratuite (1 connexion max)
- [ ] Premium: 2.99€/mois sans engagement
- [ ] 1 mois offert à la souscription
- [ ] Si abandon du projet → Open source complet

---

## 📱 Test sur appareil

```bash
# Android
flutter run -d <device_id>

# Lister les appareils
flutter devices

# Build APK debug
flutter build apk --debug

# Build APK release
flutter build apk --release
```

---

## 📝 Notes techniques

### Stack actuelle
| Package | Version | Usage |
|---------|---------|-------|
| flutter_riverpod | 2.4.9 | State management |
| dartssh2 | 2.13.0 | Connexions SSH |
| xterm | 4.0.0 | Rendu terminal |
| flutter_secure_storage | 9.0.0 | Stockage clés |
| local_auth | 2.1.8 | Biométrie |
| flutter_foreground_task | 9.2.0 | Connexions persistantes en arrière-plan |
| flutter_pty | 0.4.2 | Shell local Android |

### À investiguer pour V1.3+
- `mosh` dart binding ou wrapper
- `sftp` via dartssh2

---

*Dernière mise à jour: 2 Février 2026 (foreground service SSH + fix double Enter)*
