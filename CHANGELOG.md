# Changelog

Toutes les modifications notables de ChillShell seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [Non publié]

### En cours
- Préparation publication GitHub open source
- Documentation sécurité complète (SECURITY.md + avertissements)
- Nettoyage documentation obsolète

---

## [1.5.2] - 2026-02-11

### Corrigé
- 🎯 **Animation fluide pendant connexion SSH** - Migration complète SSH vers Dart Isolate
  - Toutes les opérations SSH (handshake, crypto) déplacées dans isolate séparé
  - Thread principal UI reste libre → animation loader à 60fps sans saccades
  - Nouveau multiplexage onglets ultra-rapide (~50ms par nouvel onglet)
- 🔧 Timeout connexion augmenté à 120s (inclut dialog TOFU utilisateur)
- 🔧 Gestion améliorée des échecs de reconnexion
- 🔧 Suppression fermeture prématurée streams stdout

### Technique
- Nouveau protocole de messages Main ↔ Background Isolate
- `ssh_isolate_messages.dart` - 13 commandes + 14 événements
- `ssh_isolate_worker.dart` - Worker SSH dans background isolate
- `ssh_isolate_client.dart` - Façade UI pour communication isolate
- `ssh_provider.dart` - Réécrit pour déléguer tout le SSH à l'isolate

---

## [1.5.1] - 2026-02-06

### Sécurité
- 🔐 **PIN hashé SHA-256 + salt** - Plus jamais stocké en clair
- 🔄 Migration automatique PIN existants vers nouveau format sécurisé
- 🚫 **Filtrage commandes sensibles** - 10 patterns (password, token, API keys, .env, id_rsa...)
- 🔍 **Détection prompts** - sudo, SSH passphrase, GPG PIN → input suivant jamais enregistré
- 📊 Historique limité à 200 commandes, doublons supprimés

### Performance
- ⚡ **Riverpod `.select()`** - Rebuilds ciblés sur 4 widgets critiques
- 🔋 **Pause timer SSH** - Timer connexion pausé en arrière-plan (économie batterie)
- 🔧 Fix fuite mémoire PTY subscription dans LocalShellService

### Tests
- ✅ **97 tests unitaires** - 100% de réussite
- 🧪 6 fichiers modèles testés (toJson/fromJson, copyWith, defaults)
- 🧪 GhostTextEngine testé (suggestions, history, edge cases)
- 🧪 TerminalNotifier testé (state, commands, ghost text)
- 🧪 Sécurité testée (10 patterns sensibles, détection prompts)

### Qualité
- 🧹 Suppression imports inutilisés et variables mortes
- 🧹 Fix lints (`use_null_aware_elements`, `const` manquants)
- 📊 0 issues `flutter analyze`

---

## [1.5.0] - 2026-02-05

### Sécurité
- 🔐 **Code PIN 6 chiffres** - Remplace Face ID, double saisie à la création
- 👆 **Empreinte digitale activée** - Vérifie biométrie Android avant activation
- 🔒 **Désactivation sécurisée** - Demande PIN actuel avant désactivation
- 🛡️ **biometricOnly: true** - Empêche Android de proposer son propre PIN/pattern
- 🔑 **PinService** - Nouveau service (save/verify/delete/hasPin)
- 🔧 Permissions Android ajoutées : `USE_BIOMETRIC`, `USE_FINGERPRINT`
- 🔧 `FlutterFragmentActivity` requis pour `local_auth`

### Interface
- 🎨 **Splash screen custom** - Fond noir (#0F0F0F) + icône ChillShell
- 🎨 **Icône adaptative** - Android 12+ avec padding 66%
- 🎨 **5 densités d'icônes** - hdpi/mdpi/xhdpi/xxhdpi/xxxhdpi régénérées
- 🔧 Lock screen refait - 6 cercles + clavier numérique + bouton empreinte
- 🔧 Section renommée "DÉVERROUILLAGE" (plus de mention Face ID)

### Corrections
- 🔧 CTRL ouvre le clavier - `SystemChannels.textInput.show`
- 🔧 Fix overflow paysage - Page principale scrollable en landscape
- 🔧 Fix race condition - Loading async settings + `addPostFrameCallback`

### Renommage
- 🏷️ **VibeTerm → ChillShell** - `appName` dans 5 localisations + 6 fichiers Dart générés

---

## [1.4.0] - 2026-02-03

### Ajouté
- 📷 **Upload image pour agents IA CLI** - Bouton permanent dans barre d'onglets
  - Sélection galerie via ImagePicker
  - Transfert SFTP automatique vers `/tmp/vibeterm_image_<timestamp>.<ext>`
  - Support shell local (copie vers `/tmp`)
  - Chemin auto-collé dans terminal pour l'agent IA
  - Traduit en 5 langues (FR/EN/ES/DE/ZH)
- 🤖 Apps CLI supportées : Claude Code, Aider, OpenCode, Gemini CLI, Cody, Amazon Q, Codex

---

## [1.3.0] - 2026-02-03

### Internationalisation
- 🌍 **5 langues** : Anglais, Français, Espagnol, Allemand, Chinois
- 📝 ~140 clés traduites : interface, erreurs, WOL, sécurité
- 🇨🇳 Traduction chinoise améliorée par Kimi K2

### Apparence
- 🔤 **Taille de police configurable** - 5 tailles : XS (12px), S (14px), M (17px), L (20px), XL (24px)
- ⚙️ Nouvel onglet "Général" dans Settings (langue + font)
- 📱 Settings réorganisés : 5 onglets (Connexion | Général | Thème | Sécurité | WOL)

---

## [1.2.0] - 2026-02-03

### Mode Édition
- ✏️ **Édition directe dans terminal** - Détection auto éditeurs (nano, vim, less, htop...)
- 📡 Séquences ANSI alternate screen (`\x1b[?1049h` / `\x1b[?1049l`)
- ⌨️ Terminal éditable (`readOnly: false`, `autofocus: true`)
- 🎮 **Boutons overlay** - D-pad croix (toggle) + menu CTRL + Enter
- 🔧 Menu CTRL : popup raccourcis (CTRL+C/D/Z/X/O/W/S/L)
- 🔄 Retour mode normal automatique à la fermeture éditeur

### Complétion Intelligente
- 🧠 **Historique intelligent** - Seules commandes réussies enregistrées
- 🔍 **Détection d'erreurs** - Parsing sortie terminal
- 📚 **Dictionnaire 400+ commandes** - git, docker, npm, flutter, k8s, aws, terraform...
- ⚡ **Suggestions dès 1ère lettre** - Algorithme refactorisé
- 🔐 **Sécurité mots de passe** - Détection prompts, JAMAIS enregistrés
- 🗑️ Bouton effacer historique dans Settings → Sécurité

### Copier/Coller
- 📋 **Bouton Copier flottant** - Apparaît auto quand texte sélectionné
- 📲 Copie vers presse-papiers - Notification native mobile
- 🖱️ Menu contextuel desktop - Clic droit → Copier/Coller
- 📏 Fix overflow champ saisie - maxHeight: 225px + scroll interne

### D-pad Universel
- 🕹️ **Support DECCKM** - Détection auto mode curseur terminal
- ⬆️ Mode normal : `\x1b[A` (nmtui, htop, fzf...)
- ⬆️ Mode application : `\x1bOA` (alsamixer, pulsemixer...)
- ✅ Compatible TOUTES apps TUI Linux

---

## [1.1.0] - 2026-02-02

### Boutons & Raccourcis
- 🎛️ **Bouton CTRL universel** - Supporte TOUS raccourcis CTRL+A-Z
  - Clic → mode armé (jaune "+")
  - Tape lettre → envoie CTRL+lettre
  - Re-clic → désarme
- 🔼 **Flèches historique empilées** - ↑↓ verticalement (28x28)
- 🆕 **Boutons overlay** - ESC + Saut de ligne (↵)
- 📂 **Navigation dossiers** - cd rapide style Warp
- ⬇️ **Scroll to bottom** - Intelligent (apparaît si scrollé >50px)

### Connexions Persistantes
- 🔌 **Foreground Service SSH** - Maintient connexions actives en arrière-plan
- 🔋 Suppression `wakelock_plus` - Remplacé par foreground service
- 💾 **Persistance session** - Onglet/session actifs après fermeture app
- ✅ Tests validés : téléphone verrouillé 3min, navigation app, fermeture complète

### Wake-on-LAN
- ⚡ **Réveil PC à distance** - Bouton WOL START sur écran accueil
- ⚙️ **Settings WOL** - 4ème onglet paramètres
- 🎬 **Animation réveil** - Écran stylé avec compteur
- 🔄 **Polling SSH** - Tentatives 10s pendant 5min max
- 🚀 **WOL automatique** - Si connexion auto + WOL activé
- ⏻ **Bouton extinction** - Dans barre session (détection OS auto)
- 🖥️ Détection OS : Linux/macOS/Windows pour commande shutdown

### Shell Local
- 💻 **Terminal local Android** - Sans connexion SSH
- 🛠️ Package `flutter_pty` v0.4.2
- 🍎 Message explicatif iOS (non disponible)

### Corrections
- 🔧 Fix affichage ncurses - Synchronisation taille PTY (htop, fzf, radeontop)
- 🔧 Double Enter Claude Code - `\n` → `\r` avec délai 50ms
- 🔧 Numérotation onglets - Réutilisation après fermeture corrigée
- 🔧 Message erreur fantôme - Sur clics rapides "+" corrigé

### UI/UX
- 📏 **Header réduit** - Logo 36x36, boutons 33x33
- 📑 **Onglets réduits** - Hauteur 32px, font 12px
- 🏷️ **Nommage onglets** - "Terminal 1, 2..." au lieu de l'IP
- 📊 **Barre session info** - Font 11px, fond opaque
- 🎨 **Design System** - Nouveaux fichiers : buttons.dart, icons.dart, animations.dart

### Settings Réorganisés
- ⚙️ **3 onglets** - Connexion | Thème | Sécurité
- 🔐 Toggles séparés - Face ID + Empreinte indépendants
- ⏱️ Temps verrouillage - 4 cases : 5min/10min/15min/30min

---

## [1.0.0] - 2026-01-31

### 🎉 Première Version Stable

#### Fonctionnalités Core
- 📱 Application mobile Flutter (Android + iOS)
- 🔐 Connexion SSH avec dartssh2 (Ed25519/RSA)
- 🖥️ Terminal xterm.dart fonctionnel
- 📑 Multi-onglets avec connexions SSH indépendantes
- 🔑 Génération de clés SSH intégrée (Ed25519/RSA)
- 💾 Stockage sécurisé des clés (flutter_secure_storage)
- 👆 Authentification biométrique (Code PIN / Empreinte digitale)
- 🔒 Auto-lock après 10 minutes d'inactivité
- 🎨 Thème Warp Dark
- 💬 Ghost text / suggestions de commandes
- ⬆️ Navigation historique commandes (session)
- 📋 Connexions sauvegardées
- 🔄 Auto-connexion au démarrage (optionnel)
- 🔄 Reconnexion automatique (optionnel)

#### Sécurité
- 🛡️ Audit Trail of Bits (62 findings corrigés)
- 🔒 FlutterSecureStorage pour clés privées
- 🔐 EncryptedSharedPreferences (Android)
- 🚫 Protection screenshot/screen recording
- 🔍 Détection root/jailbreak
- 📝 Journal d'audit de sécurité
- ⏱️ Comparaisons constant-time (crypto)
- 🔐 TOFU durci avec timeout

#### Corrections
- 🔧 Fix: Contenu onglets qui se mélangeait à la fermeture
- 🔧 Fix: Numérotation onglets réutilisée (Terminal 3, 4 → 3 au lieu de 5)
- 🔧 Fix: Message erreur fantôme sur clics rapides "+"
- 🔧 Fix: Nouvel onglet affiche vide jusqu'à navigation
- 🔧 Fix: Commande PS1 visible dans terminal (supprimée)

#### Optimisations
- ⚡ Sécurité: Clés privées jamais en mémoire (keyId reference)
- ⚡ Performance: Cache thème terminal
- ⚡ Performance: Riverpod selectors (rebuilds ciblés)
- ⚡ Robustesse: Guard anti-double création onglet
- ⚡ Robustesse: Retry mechanism streams async

---

## [0.1.0-alpha] - 2026-01-29

### 🎉 Première Release Alpha

#### Ajouté
- 📱 Application mobile Android (Flutter)
- 🔐 Connexion SSH via clés ED25519
- 🖥️ Terminal xterm complet
- 🗂️ Navigateur de dossiers
- 🌍 Support multilingue (FR, EN, ES, DE, ZH)
- 🎨 Thèmes : Warp Dark, Dracula, Nord
- 🔑 Génération de clés ED25519 intégrée
- 📋 Gestion des connexions SSH sauvegardées

#### Connu
- ⚠️ Logiciel ALPHA - Bugs attendus
- ⚠️ Pas d'audit externe professionnel
- ⚠️ Reconnexion automatique instable

---

## Notes de Version

### Semantic Versioning

- **MAJOR** (X.0.0) : Changements incompatibles de l'API
- **MINOR** (0.X.0) : Ajout de fonctionnalités compatibles
- **PATCH** (0.0.X) : Corrections de bugs compatibles

### Types de Changements

- **Ajouté** : Nouvelles fonctionnalités
- **Modifié** : Changements dans fonctionnalités existantes
- **Déprécié** : Fonctionnalités bientôt retirées
- **Retiré** : Fonctionnalités retirées
- **Corrigé** : Corrections de bugs
- **Sécurité** : Correctifs de vulnérabilités
