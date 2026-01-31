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

## 🔄 V1.2 - Interactions avancées (En cours)

### Priorité haute
- [ ] **Mode terminal local** - Utiliser l'app sans connexion SSH
- [ ] **Design raccourcis** - Comment intégrer Ctrl+D, Ctrl+R, etc. sans encombrer l'UI

### Priorité moyenne
- [ ] **Bouton Undo** - Revenir en arrière (10-20 actions)
- [ ] **Déplacement curseur tactile** - Swipe pour déplacer le curseur
- [ ] **Ctrl+D (EOF)** - Bouton discret pour quitter shell/programmes
- [ ] **Recherche dans l'historique** - Ctrl+R style

### Réflexion UX en cours
Le terminal mobile nécessite des raccourcis difficiles à intégrer :
- Ctrl+C ✅ (bouton Stop)
- Tab ✅ (swipe droite ou bouton ghost)
- Flèches ✅ (boutons ↑↓)
- Ctrl+D ❓ (EOF - quitter programmes)
- Ctrl+R ❓ (recherche historique)
- Ctrl+L ❓ (clear)
- Ctrl+Z ❓ (background)

Options envisagées :
1. **Barre de raccourcis** style Termux
2. **Menu contextuel** sur long-press
3. **Boutons intelligents** qui apparaissent selon le contexte

---

## 🚀 V1.3 - Navigation & Productivité (Planifié)

### Navigation
- [ ] **Bouton Snippets** - Commandes favorites en accordéon (style Warp)
- [ ] **Bouton Navigation Dossiers** - cd rapide avec liste (style Warp)

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

### À investiguer pour V1.3+
- `flutter_pty` pour terminal local
- `mosh` dart binding ou wrapper
- `sftp` via dartssh2

---

*Dernière mise à jour: 31 Janvier 2026*
