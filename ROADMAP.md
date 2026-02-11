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
- [x] Authentification biométrique (Code PIN / Empreinte digitale)
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

## ✅ V1.2 - Boutons & Mode Édition (Complété - 3 Fév 2026)

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

### ✅ Wake-on-LAN (2 Fév 2026 nuit)

**Feature complète** : Allumer son PC à distance avant de se connecter en SSH.

- [x] **Bouton WOL START** - Sur l'écran d'accueil, lance le réveil du PC
- [x] **Settings WOL** - 4ème onglet dans les paramètres avec toggle + configs
- [x] **Formulaire config** - Nom, MAC, connexion SSH, options avancées
- [x] **Écran animation** - Animation stylée pendant le réveil avec compteur
- [x] **Polling SSH** - Tentatives toutes les 10s pendant 5 min max
- [x] **WOL automatique** - Si connexion auto + WOL activé → réveil auto au lancement
- [x] **Bouton extinction** - ⏻ dans la barre session pour éteindre le PC
- [x] **Détection OS** - Auto-détection Linux/macOS/Windows pour shutdown

**Package** : `wake_on_lan: ^4.1.1+3`

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
- [x] 4 onglets : Connexion | Thème | Sécurité | WOL
- [x] Code PIN 6 chiffres et Empreinte séparés avec toggles indépendants
- [x] Temps de verrouillage auto : 5min / 10min / 15min / 30min

### ✅ Bouton CTRL universel (2 Fév 2026)

**Implémenté** : Nouveau système de raccourcis clavier universel.

- [x] **Bouton CTRL** - Remplace Send/Stop, supporte TOUS les raccourcis CTRL+A-Z
- [x] **Flèches historique** - ↑↓ empilées verticalement, taille réduite (28x28)
- [x] **Suppression Send/Stop** - Le clavier virtuel a déjà Enter

**Fonctionnement du bouton CTRL :**
1. Clic sur "CTRL" (vert) → devient "+" (jaune) = armé
2. Tape une lettre → envoie CTRL+lettre
3. Re-clic → désarme

**Raccourcis disponibles :**
| Raccourci | Action |
|-----------|--------|
| CTRL+C | Interrompre (SIGINT) |
| CTRL+D | EOF / quitter shell |
| CTRL+Z | Suspendre (SIGTSTP) |
| CTRL+L | Clear screen |
| CTRL+R | Recherche historique |
| CTRL+W | Chercher (nano) / Effacer mot (shell) |
| CTRL+O | Sauvegarder (nano) |
| CTRL+X | Quitter (nano) |

### ✅ Boutons overlay (2 Fév 2026 soir)

| Bouton | Type | Status | Description |
|--------|------|--------|-------------|
| **ESC** | Overlay terminal | ✅ Implémenté | Touche Escape (vim, menus) |
| **Saut de ligne ↵** | Overlay terminal | ✅ Implémenté | Nouvelle ligne dans le champ |
| **Scroll to bottom** | Tab bar intelligent | ✅ Implémenté | Apparaît si scrollé vers le haut |
| **Navigation dossiers** | Tab bar dropdown | ✅ Implémenté | cd rapide (style Warp) |

### ⏸️ Mode expanded (désactivé temporairement)

**Problème** : Le swipe vers le haut pour agrandir le champ de saisie à 40% de l'écran cause un overflow quand le clavier virtuel apparaît (conflit avec `Scaffold.resizeToAvoidBottomInset`).

**Workaround** : Le champ s'agrandit automatiquement avec `maxLines: null` quand on insère des sauts de ligne.

**À résoudre** : Restructurer le layout ou utiliser `LayoutBuilder` pour gérer dynamiquement l'espace disponible.

### ✅ Complétion intelligente (3 Fév 2026)

**Implémenté** : Système de suggestions intelligent et sécurisé.

- [x] **Historique intelligent** - Seules les commandes réussies sont enregistrées
- [x] **Détection d'erreurs** - Parsing de la sortie terminal pour détecter les erreurs
- [x] **Dictionnaire enrichi** - 400+ commandes (git, docker, npm, flutter, k8s, aws...)
- [x] **Suggestions dès la 1ère lettre** - Algorithme refactorisé pour suggestions immédiates
- [x] **Sécurité mots de passe** - Détection des prompts password, JAMAIS enregistrés
- [x] **Bouton effacer historique** - Dans Paramètres → Sécurité

**Remis à V1.3** : Analyse de chemin (ls silencieux pour `cd`/`cat`), TAB chaîné

### ✅ Copier/Coller Terminal (3 Fév 2026) — VALIDÉ

- [x] **Bouton Copier flottant** - Apparaît automatiquement quand texte sélectionné
- [x] **Copie vers presse-papiers** - Utilise notification native du mobile
- [x] **Menu contextuel desktop** - Clic droit → Copier/Coller
- [x] **Fix overflow champ de saisie** - maxHeight: 225px + scroll interne

✅ **Testé et validé** : Fonctionne correctement sur Android.

### ✅ Fix D-pad universel (3 Fév 2026)

- [x] **Support DECCKM** - Détection automatique du mode curseur du terminal
- [x] **Mode normal** - `\x1b[A` pour nmtui, htop, fzf, etc.
- [x] **Mode application** - `\x1bOA` pour alsamixer, pulsemixer, etc.
- [x] **Compatible toutes apps TUI** - Fonctionne avec TOUTES les applications Linux

### ✅ Mode édition (nano, vim) - 3 Fév 2026 soir

**Implémenté** : Édition directe dans le terminal quand un éditeur s'ouvre.

- [x] **Détection éditeur** - Séquences ANSI alternate screen (`\x1b[?1049h` / `\x1b[?1049l`)
- [x] **Terminal éditable** - `readOnly: false`, `autofocus: true` en mode édition
- [x] **Masquer champ saisie** - GhostTextInput invisible en mode édition
- [x] **Boutons overlay** - 3 boutons droite (D-pad toggle, CTRL menu, Enter)
- [x] **D-pad en croix** - Apparaît à gauche quand toggle activé
- [x] **Menu CTRL** - Popup avec raccourcis courants (CTRL+C/D/Z/X/O/W/S/L)
- [x] **Retour mode normal** - Automatique quand l'éditeur se ferme

**Apps supportées** : nano, vim, nvim, less, htop, btop, ranger, mc, et toutes apps TUI.

### UI actuelle V1.2

**Mode normal :**
```
┌─────────────────────────────────────────────────────────────┐
│ Header: [Logo] ChillShell  [Déconnect] [Tmux] [Settings]    │
├─────────────────────────────────────────────────────────────┤
│ Tabs: [●Terminal 1 ×]  [📁~] [↓] [+]                        │
├─────────────────────────────────────────────────────────────┤
│ Session info: ← tmux: vibe • 192.168...  Tailscale  ⏻      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    Terminal View (xterm)                    │
│                                                             │
│ [ESC]                                              [↵]      │
├─────────────────────────────────────────────────────────────┤
│ [↑]                                                         │
│ [↓] > [Input field...........] [↑] [↓] [CTRL]              │
└─────────────────────────────────────────────────────────────┘
```

**Mode édition (nano, vim, less, htop...) :**
```
┌─────────────────────────────────────────────────────────────┐
│ Header: [Logo] ChillShell  [Déconnect] [Tmux] [Settings]    │
├─────────────────────────────────────────────────────────────┤
│ Tabs: [●Terminal 1 ×]  [📁~] [↓] [+]                        │
├─────────────────────────────────────────────────────────────┤
│ Session info: ← tmux: vibe • 192.168...  Tailscale  ⏻      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    Terminal View (xterm)                    │
│           (clavier virtuel ouvert, saisie directe)          │
│                                              ┌───┐          │
│              ┌───┐                           │ ⊞ │          │
│              │ ↑ │                           ├───┤          │
│          ┌───┼───┼───┐                       │CTL│          │
│          │ ← │   │ → │                       ├───┤          │
│          └───┼───┼───┘                       │ ↵ │          │
│              │ ↓ │                           └───┘          │
│              └───┘                                          │
│ (D-pad si activé)           (3 boutons permanents à droite) │
├─────────────────────────────────────────────────────────────┤
│ (GhostTextInput masqué en mode édition)                     │
└─────────────────────────────────────────────────────────────┘
```

### Priorité basse (V1.2+)
- [x] **Mode terminal local** - Local Shell sur Android (message explicatif sur iOS)

---

## ✅ V1.3 - International & Apparence (Complété - 3 Fév 2026)

### ✅ Multi-langues
- [x] 🇬🇧 Anglais (défaut)
- [x] 🇫🇷 Français
- [x] 🇪🇸 Espagnol
- [x] 🇩🇪 Allemand
- [x] 🇨🇳 Chinois (amélioré par Kimi K2)

**~140 clés traduites** : interface complète, erreurs, WOL, sécurité, etc.

### ✅ Taille de police configurable
- [x] 5 tailles : XS (12px), S (14px), M (17px), L (20px), XL (24px)
- [x] Nouvel onglet "Général" dans Settings

### ✅ Réorganisation Settings
- [x] 5 onglets : Connexion | Général | Thème | Sécurité | WOL

---

## ✅ V1.4 - Upload Image pour Agents IA (Complété - 3-4 Fév 2026)

### ✅ Upload d'images pour agents IA CLI

Bouton permanent dans la barre d'onglets pour envoyer une image à un agent IA.

- [x] **Bouton upload image** - Icône 📷 dans la barre d'onglets
- [x] **Sélection galerie** - ImagePicker pour choisir l'image
- [x] **Transfert SFTP** - Upload automatique vers `/tmp/vibeterm_image_<timestamp>.<ext>`
- [x] **Shell local supporté** - Copie vers `/tmp` local
- [x] **Chemin auto-collé** - Le chemin est inséré dans le terminal pour l'agent IA
- [x] **Traduit 5 langues** - Messages d'upload en FR/EN/ES/DE/ZH

**Apps CLI agents IA supportées :**
| App | Commande |
|-----|----------|
| Claude Code | `claude` |
| Aider | `aider` |
| OpenCode | `opencode` |
| Gemini CLI | `gemini` |
| Cody | `cody` |
| Amazon Q | `amazon-q`, `aws-q` |
| Codex | `codex` |

---

## ✅ V1.5 - Sécurité PIN/Empreinte & Splash Screen (Complété - 5-6 Fév 2026)

### ✅ Refonte sécurité (5-6 Fév 2026)

**Face ID supprimé → Code PIN 6 chiffres**

- [x] **Code PIN 6 chiffres** - Création avec double saisie, stockage sécurisé (flutter_secure_storage)
- [x] **Désactivation sécurisée** - Demande le PIN actuel avant de désactiver
- [x] **Empreinte digitale activée** - Vérifie biométrie Android avant d'activer le toggle
- [x] **biometricOnly: true** - Empêche Android de proposer son propre PIN/pattern
- [x] **Lock Screen refait** - 6 cercles + clavier numérique + bouton empreinte
- [x] **PinService** - Nouveau service avec save/verify/delete/hasPin
- [x] **Section renommée** - "DÉVERROUILLAGE" (plus de mention Face ID)

**Fix Android requis pour empreinte :**
- [x] Permissions `USE_BIOMETRIC` + `USE_FINGERPRINT` dans AndroidManifest
- [x] `FlutterFragmentActivity` au lieu de `FlutterActivity` (requis par local_auth)

### ✅ Splash Screen custom (5-6 Fév 2026)

- [x] **Fond noir** - Remplace le fond blanc Flutter par défaut (#0F0F0F)
- [x] **Icône ChillShell** - ICONE_APPLICATION.png au lieu du logo Flutter
- [x] **Android 12+ splash** - `values-v31/styles.xml` pour le nouveau système splash
- [x] **Icône adaptative** - `mipmap-anydpi-v26/ic_launcher.xml` avec padding 66%
- [x] **5 densités** - mipmap hdpi/mdpi/xhdpi/xxhdpi/xxxhdpi régénérées

### ✅ Renommage & Polish (5-6 Fév 2026)

- [x] **VibeTerm → ChillShell** - `appName` dans toutes les localisations (5 ARB + 6 Dart)
- [x] **CTRL ouvre le clavier** - `SystemChannels.textInput.invokeMethod('TextInput.show')`
- [x] **Fix overflow paysage** - Page principale scrollable en mode landscape
- [x] **Fix race condition** - Chargement async settings + `addPostFrameCallback` pour lock check

---

## ✅ V1.5.1 - Audit Complet (6 Fév 2026)

### ✅ Audit Qualité
- [x] Suppression imports inutilisés et variables mortes
- [x] Fix lints (`use_null_aware_elements`, `const` manquants)
- [x] Nettoyage code mort dans providers

### ✅ Audit Sécurité
- [x] **PIN hashé SHA-256 + salt** - Plus jamais stocké en clair
- [x] **Migration PIN** - `migrateIfNeeded()` au démarrage pour les utilisateurs existants
- [x] **Filtrage commandes sensibles** - 10 patterns (password, token, API keys, .env, id_rsa...)
- [x] **Détection prompts** - sudo, SSH passphrase, GPG PIN → input jamais enregistré

### ✅ Audit Performance
- [x] **Riverpod `.select()`** - Rebuilds ciblés sur 4 widgets (au lieu de rebuild complet)
- [x] **Pause timer SSH** - Timer connexion pausé en arrière-plan (économie batterie)
- [x] **Fix fuite mémoire** - PTY subscription non nettoyée dans LocalShellService

### ✅ Audit Tests — 96 tests
- [x] 6 fichiers modèles testés (toJson/fromJson round-trip, defaults, copyWith)
- [x] GhostTextEngine testé (suggestions, history, edge cases)
- [x] TerminalNotifier testé (state, history, ghost text, commands)
- [x] Sécurité testée (10 patterns sensibles, détection prompts, erreurs)
- [x] Smoke test fixé (timeout pumpAndSettle → pump avec mock)

**Résultat** : 97/97 tests passent, 0 issues analyse, APK build OK.

---

## ✅ V1.5.2 - Migration SSH Isolate (11 Fév 2026)

### Problème résolu

**Saccades d'animation pendant le handshake SSH** : L'icône ChillShell flottante (loader) saccadait pendant les 2-3 premières secondes de connexion. Cause : les opérations cryptographiques SSH (Diffie-Hellman, Ed25519) s'exécutaient sur le thread principal Dart, bloquant la boucle d'événements et empêchant le rendu à 60fps.

### ✅ Architecture Isolate SSH

Toutes les opérations SSH déplacées dans un **Dart Isolate** séparé. Le thread principal reste libre pour l'UI.

```
MAIN ISOLATE (UI)                     BACKGROUND ISOLATE (SSH)
─────────────────                     ──────────────────────
SSHNotifier (Riverpod)                SSHIsolateWorker
  ↕                                     ├── Map<tabId, SSHService>
SSHIsolateClient                        ├── Multiplexage SSH
  ↕ SendPort / ReceivePort ↕            ├── Timer connexion (10s)
  (messages Map sérialisés)             ├── Reconnexion auto
                                        ├── SecureStorage (TOFU)
                                        └── Throttle resize (150ms)
```

**Fichiers créés :**
- [x] `lib/services/ssh_isolate_messages.dart` — Protocole de messages (commandes + événements)
- [x] `lib/services/ssh_isolate_worker.dart` — Worker dans le background isolate (toute la logique SSH)
- [x] `lib/services/ssh_isolate_client.dart` — Façade côté UI (pont vers l'isolate)

**Fichier réécrit :**
- [x] `lib/features/terminal/providers/ssh_provider.dart` — Délègue tout le SSH à l'isolate client

### ✅ Protocole de messages

**Main → Background (13 commandes)** : connect, createTab, closeTab, write, resize, disconnect, uploadFile, executeCommand, detectOS, shutdown, hostKeyResponse, reconnectTab, reconnectAll, pauseMonitor, resumeMonitor, dispose

**Background → Main (14 événements)** : connected, connectionFailed, tabCreated, tabCreateFailed, stdout, tabClosed, disconnected, allDisconnected, hostKeyVerify, commandResult, uploadResult, osDetected, reconnecting, reconnected, error, tabDead

Chaque requête-réponse utilise un `requestId` UUID unique avec timeout configurable.

### ✅ Nettoyage du loader

- [x] Suppression du hack fade-in 800ms dans `chillshell_loader.dart` (plus nécessaire, animation fluide)
- [x] `TickerProviderStateMixin` → `SingleTickerProviderStateMixin`

### ✅ Bug fix : timeout connexion

**Bug détecté au test** : "Connexion impossible" après 15s malgré connexion SSH réussie.

**Cause racine** : Timeout de 30s trop court pour `connect()` qui inclut la vérification TOFU (dialog utilisateur) + handshake SSH.

**Corrections appliquées :**
- [x] Timeout connect augmenté à 120s (au lieu de 30s)
- [x] Suppression fermeture prématurée des streams stdout sur `allDisconnected`
- [x] État `reconnecting` mis à jour avant envoi de `reconnectTab`
- [x] Ajout callback `onConnectionFailed` pour les échecs de reconnexion
- [x] Ajout `debugLabel` aux requêtes pendantes pour meilleur diagnostic

### Résultats

- ✅ Animation **fluide à 60fps** pendant toute la connexion SSH
- ✅ Nouvel onglet multiplexé : ouverture rapide (~50ms)
- ✅ Reconnexion automatique fonctionnelle
- ✅ TOFU (vérification clé d'hôte) fonctionnel
- ✅ Upload SFTP fonctionnel
- ✅ Shell local non impacté
- ✅ 0 issues analyse, 97/97 tests passent

---

## 🚀 V1.6 - Navigation & Productivité (Futur)

### Navigation & Productivité
- [ ] **Bouton Snippets** - Commandes favorites en accordéon (style Warp)
- [ ] **Complétion avancée** - Analyse de chemin (ls silencieux), TAB chaîné, suggestions multiples

### Priorité basse
- [ ] **Mosh support** - Connexions sur réseaux instables (notre foreground service suffit pour 90% des cas)

---

## 🔮 V2.0 - Premium & Sync (Futur lointain)

### Features avancées
- [ ] **Sync cross-device** - Synchronisation des connexions/snippets
- [ ] **Settings avancés** - Plus d'options de personnalisation

### Monétisation
*À définir - en cours de réflexion*

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
| flutter_riverpod | 2.6.1 | State management |
| dartssh2 | 2.13.0 | Connexions SSH |
| xterm | 4.0.0 | Rendu terminal |
| flutter_secure_storage | 10.0.0 | Stockage clés |
| local_auth | 3.0.0 | Biométrie |
| flutter_foreground_task | 9.2.0 | Connexions persistantes en arrière-plan |
| flutter_pty | 0.4.2 | Shell local Android |
| wake_on_lan | 4.1.1+3 | Réveil PC à distance (Magic Packet) |
| google_fonts | 8.0.1 | Police JetBrains Mono |
| file_picker | 10.3.10 | Import fichiers/clés SSH |

### À investiguer pour V1.6+
- `mosh` dart binding ou wrapper
- `sftp` via dartssh2

---

---

## 🐛 Bugs connus

### xterm.dart crash avec Codex/Claude Code

**Status** : ⏸️ Mis de côté — à résoudre plus tard

**Symptôme** : Apps TUI complexes (Codex CLI, Claude Code) crashent après 1-2 messages.

**Cause** : Race condition dans xterm.dart entre resize et écriture buffer.

**Voir** : `STATUS.md` pour les détails et pistes d'investigation.

---

*Dernière mise à jour: 11 Février 2026 (V1.5.2 - Migration SSH Isolate : animation fluide, 0 saccades)*
