# ChillShell - Status de développement

> Dernière mise à jour: 16 Février 2026

---

## 🐛 Bugs connus (à résoudre plus tard)

### xterm.dart crash avec apps TUI complexes (Codex, Claude Code)

**Symptôme** : Quand on utilise une app TUI comme Codex ou Claude Code, l'app crash après 1-2 messages envoyés.

**Erreur** : `Failed assertion: 'attached': is not true` dans `xterm/src/utils/circular_buffer.dart`

**Cause identifiée** : Race condition dans le package xterm.dart entre :
- Le resize du terminal (quand le clavier s'ouvre/ferme)
- L'écriture de données ANSI complexes dans le buffer

**Ce qu'on a essayé** :
- Throttle des événements resize (150ms) → insuffisant
- Try-catch autour de terminal.write() → n'empêche pas les données perdues
- Bloquer resize en alternate screen mode → pas assez, le crash arrive avant

**Prochaines pistes** :
- Mutex/lock pour synchroniser resize et write
- Utiliser isolate pour le parsing ANSI
- Ouvrir une issue sur le repo xterm.dart
- Envisager un fork du package avec fix

**Workaround temporaire** : Le try-catch évite le crash rouge, mais des données peuvent être perdues.

---

## 📖 Préparation Publication GitHub (16 Février 2026)

### Documentation Sécurité Complète

**Fichiers créés/mis à jour** :
- ✅ **SECURITY.md** (EN) - Mesures de sécurité, 3 audits + qualité, procédure de signalement
- ✅ **SECURITE.md** (FR) - Version française complète
- ✅ **⚠️\_READ\_THIS\_FIRST.md** (EN) - Avertissements, surface d'attaque, bonnes pratiques
- ✅ **⚠️\_LISEZ\_CECI\_AVANT\_INSTALLATION.md** (FR) - Version française
- ✅ **README.md** - Corrigé (contenait README Gitleaks par erreur)
- ✅ **CHANGELOG.md** - Historique complet v0.1.0-alpha → v1.5.2
- ✅ **ROADMAP.md** - Version actuelle corrigée (V1.5.2, pas V1.0)
- ✅ **CONTRIBUTING.md** - Ajout références documentation sécurité

**Travail de sécurité documenté** :
- 3 audits internes successifs (white-box, STRIDE, Trail of Bits méthodologie)
- 1 audit qualité (83 fichiers, 24 000 lignes)
- Score sécurité amélioré : 6.5 → 8.5/10 (auto-évalué)
- 62 findings corrigés (4 Critiques, 8 Élevés, 21 Moyens, 21 Faibles)
- 0 vulnérabilité exploitable à distance identifiée
- 97 tests unitaires passent

**Nettoyage docs** :
- 📁 `docs/archives/plans/` - 18 plans implémentation (260K)
- 📁 `docs/archives/docs_obsoletes/` - 4 documents obsolètes (32K)
  - VibeTerm_Architecture.md
  - VibeTerm_SSH_Guide.md
  - Vision Technique Ghost Text.md
  - VibeTerm_2026_Specifications_v2.md (document de conception initial)
- 📁 `docs/archives/TEST_HACK/` - Audit offensif à refaire plus tard (12K)

---

## État de la V1.5.2 — Stable (11 Février 2026)

**Build debug Android** : ✅ Fonctionnel et testé sur téléphone Android physique.

**iOS** : ⚠️ Non testé — aucun iPhone disponible pour le moment. À tester avant publication sur l'App Store.

| Fonctionnalité | Android | iOS (estimé) |
|----------------|---------|-------------|
| Interface / UI | ✅ Testé | ✅ Identique (Flutter) |
| Connexion SSH | ✅ Testé | ✅ Devrait fonctionner |
| Local Shell | ✅ Testé | ❌ Bloqué par Apple (message affiché) |
| Background SSH | ✅ Foreground Service | ⚠️ iOS plus restrictif, à adapter |
| Biométrie | ✅ Empreinte | ⚠️ Face ID (à tester) |
| Splash screen | ✅ Configuré | ⚠️ LaunchScreen.storyboard à configurer |

**Prochaines étapes avant déploiement** :
1. Ajustements visuels mineurs (terminé)
2. Site web ChillShell (en cours de brainstorming)
3. Signature APK release + configuration Play Store
4. Test iOS si appareil disponible

---

## Session 6 Février 2026 - Audit complet (Qualité, Sécurité, Performance, Tests)

### Audit 1 — Qualité du code

| Correction | Fichier |
|------------|---------|
| Suppression imports inutilisés | `ssh_service.dart`, `terminal_screen.dart`, `settings_screen.dart` |
| Suppression variables mortes | `settings_provider.dart` (`_secureStorage`, `_connectionKey`) |
| Remplacement `.toList()` par spread | `ghost_text_engine.dart` |
| Fix lint `use_null_aware_elements` | `connection_dialog.dart`, `add_ssh_key_sheet.dart` |
| Ajout const manquants | `settings_screen.dart`, `add_wol_sheet.dart` |

### Audit 2 — Sécurité

| Amélioration | Détail |
|-------------|--------|
| **PIN hashé SHA-256 + salt** | PinService utilise maintenant SHA-256 salé au lieu du stockage en clair |
| **Migration PIN** | `migrateIfNeeded()` au démarrage convertit l'ancien format vers le nouveau |
| **Commandes sensibles** | 10 patterns filtrés (password, token, API keys, .env, id_rsa...) |
| **Détection prompts** | sudo, SSH passphrase, GPG PIN → input suivant jamais enregistré |
| **Historique limité** | Max 200 commandes, doublons filtrés |

### Audit 3 — Performance

| Optimisation | Fichier |
|-------------|---------|
| `.select()` Riverpod (rebuilds ciblés) | `appearance_section.dart`, `ghost_text_input.dart`, `wol_section.dart`, `app_header.dart` |
| Pause/resume timer SSH en arrière-plan | `ssh_provider.dart` + `main.dart` (lifecycle) |
| Fix fuite mémoire PTY subscription | `local_shell_service.dart` |
| Suppression `!` inutile après `.select()` | `ghost_text_input.dart` |

### Audit 4 — Tests (96 tests)

| Fichier de test | Tests | Couverture |
|----------------|-------|------------|
| `test/models/app_settings_test.dart` | 11 | toJson/fromJson, defaults, copyWith, enums |
| `test/models/session_test.dart` | 5 | round-trip, missing optionals, copyWith |
| `test/models/ssh_key_test.dart` | 5 | round-trip, typeLabel, all key types |
| `test/models/saved_connection_test.dart` | 4 | round-trip, defaults, copyWith |
| `test/models/wol_config_test.dart` | 4 | round-trip, defaults, copyWith |
| `test/models/command_test.dart` | 6 | defaults, executionTimeLabel formats |
| `test/providers/ghost_text_engine_test.dart` | 12 | suggestions, history, case, edge cases |
| `test/providers/terminal_provider_test.dart` | 22 | state, history, ghost text, commands |
| `test/security/sensitive_command_test.dart` | 24 | 10 patterns, prompts, errors |
| `test/widget_test.dart` | 3 | smoke test (fixé timeout pumpAndSettle) |

**Résultat** : 96/96 tests passent, 0 issues `flutter analyze`, APK build OK.

---

## Session 5-6 Février 2026 - V1.5 Sécurité PIN/Empreinte, Splash Screen, UI Polish

### Refonte sécurité : Face ID → Code PIN 6 chiffres

**Changement majeur** : Le déverrouillage Face ID a été supprimé et remplacé par un code PIN à 6 chiffres personnalisé.

| Fonctionnalité | Description |
|----------------|-------------|
| **Code PIN 6 chiffres** | Toggle dans Settings → Sécurité, création avec double saisie |
| **Désactivation sécurisée** | Demande le PIN actuel avant de désactiver |
| **Empreinte digitale** | Activée et fonctionnelle (vérifie biométrie Android) |
| **PinService** | Stockage sécurisé via `flutter_secure_storage` |
| **Lock Screen refait** | 6 cercles + clavier numérique + bouton empreinte |
| **Section renommée** | "DÉVERROUILLAGE" (au lieu de "DÉVERROUILLAGE BIOMÉTRIQUE") |

### Activation empreinte digitale

**Problème résolu** : Le toggle empreinte ne fonctionnait pas du tout.

**Causes** (2 problèmes indépendants) :
1. Permissions Android manquantes (`USE_BIOMETRIC`, `USE_FINGERPRINT`)
2. `MainActivity` étendait `FlutterActivity` au lieu de `FlutterFragmentActivity` (requis par `local_auth`)

**Fix supplémentaire** : `biometricOnly: true` dans `AuthenticationOptions` pour empêcher Android de proposer son propre PIN/pattern (qui rendait notre UI PIN obsolète).

### Splash screen personnalisé

**Problème résolu** : Le logo Flutter par défaut (oiseau bleu sur rond blanc) s'affichait au lancement.

| Élément | Avant | Après |
|---------|-------|-------|
| **Fond** | Blanc | Noir (#0F0F0F) |
| **Icône** | Logo Flutter | ICONE_APPLICATION.png |
| **Android 12+** | Splash système | Splash custom via `values-v31/styles.xml` |
| **Icône adaptative** | Pas configuré | `mipmap-anydpi-v26/ic_launcher.xml` avec padding |

**Problème de crop résolu** : L'icône était tronquée dans le cercle Android 12+. Fix : redimensionné à 260x260 sur canvas 432x432 (zone de sécurité 66%).

### Renommage VibeTerm → ChillShell

- `appName` changé dans les 5 fichiers ARB + 6 fichiers Dart générés
- `localizedReason` dans BiometricService mis à jour

### Bouton CTRL ouvre le clavier

**Problème** : Le bouton CTRL n'ouvrait le clavier virtuel que la première fois.

**Investigation** : `FocusNode.hasFocus` reste `true` même quand le clavier est fermé sur Android → `requestFocus()` ne fait rien la 2ème fois.

**Solution** : `SystemChannels.textInput.invokeMethod('TextInput.show')` force l'affichage du clavier sans manipulation de focus.

### Fix overflow paysage

**Problème** : "BOTTOM OVERFLOWED BY 89 PIXELS" sur la page principale en mode paysage.

**Solution** : Remplacé `Padding` par `SingleChildScrollView` dans le contenu déconnecté de `terminal_screen.dart`.

### Vérification auto-lock

Vérifié que le verrouillage automatique (5/10/15/30 min) était déjà pleinement fonctionnel. Aucune modification nécessaire.

### Fichiers créés

| Fichier | Description |
|---------|-------------|
| `lib/services/pin_service.dart` | Service PIN (save, verify, delete, hasPin) |
| `android/app/src/main/res/values/colors.xml` | Couleur splash noir |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Icône adaptative |
| `android/app/src/main/res/values-v31/styles.xml` | Splash Android 12+ |
| `android/app/src/main/res/drawable/ic_launcher_foreground.png` | Foreground icône |
| `android/app/src/main/res/drawable/launch_image.png` | Image splash |

### Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `lib/models/app_settings.dart` | -`faceIdEnabled`, +`pinLockEnabled` |
| `lib/features/settings/providers/settings_provider.dart` | -`toggleFaceId()`, +`togglePinLock()`, +`setPinCode()` |
| `lib/features/settings/widgets/security_section.dart` | Toggle PIN + dialog création, vérification biométrie |
| `lib/features/auth/screens/lock_screen.dart` | UI PIN (6 cercles + clavier) + bouton empreinte |
| `lib/main.dart` | Logique lock avec PIN/empreinte, fix race condition async |
| `lib/services/biometric_service.dart` | `biometricOnly: true`, texte ChillShell |
| `android/app/src/main/AndroidManifest.xml` | +`USE_BIOMETRIC`, +`USE_FINGERPRINT` |
| `android/app/src/main/kotlin/.../MainActivity.kt` | `FlutterFragmentActivity` |
| `lib/features/terminal/widgets/ghost_text_input.dart` | CTRL + `SystemChannels.textInput.show` |
| `lib/features/terminal/screens/terminal_screen.dart` | `SingleChildScrollView` mode paysage |
| `android/app/src/main/res/drawable*/launch_background.xml` | Fond noir + icône |
| `android/app/src/main/res/mipmap-*/ic_launcher.png` | 5 tailles régénérées |
| `lib/l10n/app_*.arb` (5 fichiers) | `appName` → ChillShell, +`fingerprintUnavailable` |
| `lib/l10n/app_localizations*.dart` (6 fichiers) | Regénérés |

### Commits

- `9d944d3` - feat: V1.4 - Sécurité PIN/empreinte, splash screen, UI polish (63 fichiers)

---

## Session 3-4 Février 2026 - V1.4 Upload Image pour Agents IA

### Fonctionnalité complète : Transfert d'images vers agents IA CLI

Nouveau bouton permanent dans la barre d'onglets permettant d'envoyer une image à un agent IA (Claude Code, Aider, etc.).

### Fonctionnement

1. Clic sur l'icône 📷 dans la barre d'onglets
2. Sélection d'une image depuis la galerie
3. **SSH** : Transfert SFTP automatique vers `/tmp/vibeterm_image_<timestamp>.<ext>`
4. **Shell Local** : Copie vers `/tmp` local
5. Le chemin est automatiquement collé dans le terminal

### Détails techniques

| Élément | Description |
|---------|-------------|
| **Widget** | `_ImageImportButton` dans `session_tab_bar.dart` |
| **Icône** | `Icons.add_photo_alternate_outlined` (26x26) |
| **Position** | Barre d'onglets, à gauche du bouton dossier |
| **Logique** | `_handleImageImport()` dans `terminal_screen.dart` |
| **Transfer** | SFTP via `ssh_service.dart` → `uploadFile()` |
| **Destination** | `/tmp/vibeterm_image_<timestamp>.<extension>` |

### Agents IA CLI supportés

| Agent | Commande |
|-------|----------|
| Claude Code | `claude` |
| Aider | `aider` |
| OpenCode | `opencode` |
| Gemini CLI | `gemini` |
| Cody | `cody` |
| Amazon Q | `amazon-q`, `aws-q` |
| Codex | `codex` |

### Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `session_tab_bar.dart` | +`_ImageImportButton` widget |
| `terminal_screen.dart` | +`_handleImageImport()` logique upload |
| `ssh_provider.dart` | +`uploadFile()` méthode |
| `ssh_service.dart` | +`uploadFile()` SFTP |
| `app_*.arb` (5 langues) | +`uploadingImage`, +`uploadFailed` |

---

## Session 3 Février 2026 (nuit) - V1.3 Multi-langues

### Fonctionnalité complète : Internationalisation

L'application supporte maintenant 5 langues avec détection automatique de la langue système.

### Langues supportées

| Langue | Code | Fichier |
|--------|------|---------|
| 🇬🇧 Anglais | `en` | `app_en.arb` |
| 🇫🇷 Français | `fr` | `app_fr.arb` |
| 🇪🇸 Espagnol | `es` | `app_es.arb` |
| 🇩🇪 Allemand | `de` | `app_de.arb` |
| 🇨🇳 Chinois | `zh` | `app_zh.arb` |

### Textes traduits (~140 clés)

- Interface complète (Settings, Terminal, Connexion)
- Messages d'erreur et confirmations
- Wake-on-LAN (réveil PC, shutdown)
- Sécurité (biométrie, auto-lock)
- Copier/coller, historique

### Taille de police configurable

Nouvel onglet **Général** dans les paramètres avec :
- Sélecteur de langue
- Sélecteur de taille de police terminal (5 options)

| Taille | Pixels |
|--------|--------|
| XS | 12px |
| S | 14px |
| M | 17px (défaut) |
| L | 20px |
| XL | 24px |

### Fichiers créés/modifiés

| Fichier | Description |
|---------|-------------|
| `lib/l10n/app_*.arb` | 5 fichiers de traduction |
| `lib/l10n/app_localizations*.dart` | Classes générées Flutter |
| `lib/features/settings/widgets/appearance_section.dart` | Onglet Général (langue + font) |
| `lib/features/settings/screens/settings_screen.dart` | 5 onglets maintenant |
| `lib/models/app_settings.dart` | +`locale`, +`terminalFontSize` |

### Commits

- `c640da9` - feat: V1.3 Multi-langues - 5 languages + font size settings
- `ed83b6d` - fix(i18n): improve Chinese translation per Kimi K2 review

---

## Session 3 Février 2026 (soir) - Mode Édition (nano, vim)

### Fonctionnalité complète : Édition directe dans le terminal

Quand un éditeur (nano, vim, less, htop...) s'ouvre, le terminal passe automatiquement en mode édition avec des boutons overlay adaptés.

### Détection automatique

| Séquence ANSI | Signification | Action |
|---------------|---------------|--------|
| `\x1b[?1049h` | Entrée alternate screen | Activer mode édition |
| `\x1b[?1049l` | Sortie alternate screen | Désactiver mode édition |

**Apps supportées** : nano, vim, nvim, emacs, micro, helix, less, more, htop, btop, ranger, mc, nnn, et toutes les apps TUI utilisant l'alternate screen mode.

### Changements UI en mode édition

| Propriété | Mode normal | Mode édition |
|-----------|-------------|--------------|
| `readOnly` | `true` | `false` (saisie directe) |
| `autofocus` | `false` | `true` (clavier s'ouvre) |
| `GhostTextInput` | Visible | Masqué |
| Boutons overlay | ESC + ↵ | D-pad toggle + CTRL + Enter |

### Boutons overlay mode édition

```
              ┌───┐       ┌───┐
              │ ↑ │       │ ⊞ │  ← Toggle D-pad
          ┌───┼───┼───┐   ├───┤
          │ ← │   │ → │   │CTL│  ← Menu raccourcis
          └───┼───┼───┘   ├───┤
              │ ↓ │       │ ↵ │  ← Enter
              └───┘       └───┘
```

**Bouton CTRL** : Ouvre un menu popup avec les raccourcis courants :
- CTRL+C (Interrompre)
- CTRL+D (EOF/Quitter)
- CTRL+Z (Suspendre)
- CTRL+X (Quitter nano)
- CTRL+O (Sauver nano)
- CTRL+W (Chercher)
- CTRL+S (Sauvegarder)
- CTRL+L (Clear screen)

### Fichiers créés/modifiés

| Fichier | Modification |
|---------|--------------|
| `terminal_provider.dart` | +`isEditorModeProvider` |
| `terminal_view.dart` | Détection séquences ANSI + `readOnly` dynamique |
| `terminal_action_buttons.dart` | +`EditorModeButtons` widget |
| `terminal_screen.dart` | Affichage conditionnel overlay + masquage GhostTextInput |
| `widgets.dart` | Export `terminal_action_buttons.dart` |

### Flux complet

```
1. User tape "nano fichier.txt"
           ↓
2. nano envoie \x1b[?1049h (alternate screen)
           ↓
3. Détection → isEditorModeProvider = true
           ↓
4. Terminal: readOnly=false, clavier s'ouvre
   GhostTextInput: masqué
   Boutons overlay: affichés à droite
           ↓
5. User édite dans nano avec clavier + boutons
           ↓
6. User quitte nano (Ctrl+X via menu)
           ↓
7. nano envoie \x1b[?1049l (sortie alternate screen)
           ↓
8. Détection → isEditorModeProvider = false
           ↓
9. Retour mode normal (readOnly=true, GhostTextInput visible)
```

---

## Session 3 Février 2026 - Complétion, Sécurité, Copier/Coller & Fix Overflow

### Système de complétion refactorisé

| Fonctionnalité | Status | Description |
|----------------|--------|-------------|
| **Historique intelligent** | ✅ | Seules les commandes réussies sont enregistrées |
| **Détection d'erreurs** | ✅ | Parsing sortie terminal (command not found, etc.) |
| **Dictionnaire 400+ commandes** | ✅ | git, docker, npm, flutter, k8s, aws, terraform... |
| **Suggestions dès 1ère lettre** | ✅ | Algorithme refactorisé (était après mot complet) |
| **Sécurité mots de passe** | ✅ | Détection prompts, JAMAIS enregistrés |
| **Bouton effacer historique** | ✅ | Paramètres → Sécurité |

### Copier/Coller Terminal

| Fonctionnalité | Status | Description |
|----------------|--------|-------------|
| **Bouton Copier flottant** | ✅ | Apparaît en haut à droite quand texte sélectionné |
| **ListenableBuilder** | ✅ | Écoute les changements de sélection du TerminalController |
| **Menu contextuel desktop** | ✅ | Clic droit → Copier/Coller |
| **Pas de double notification** | ✅ | Utilise notification native du mobile uniquement |

**Note** : Le long press ne fonctionne pas car xterm l'utilise pour la sélection. Solution = bouton flottant automatique.

### Fix Overflow Champ de Saisie

**Problème résolu** : Le TextField avec `maxLines: null` grandissait vers le bas sans limite, passant derrière le clavier virtuel.

**Root cause** : Pas de contrainte de hauteur sur le TextField multiligne.

**Solution** :
- `ConstrainedBox` avec `maxHeight: 225` (~9 lignes)
- `SingleChildScrollView` avec `reverse: true` pour scroll automatique vers la dernière ligne
- Le champ scroll maintenant au lieu de déborder

**Fichier modifié** : `lib/features/terminal/widgets/ghost_text_input.dart`

### Fix D-pad pour toutes les apps TUI

**Problème** : Les flèches du D-pad ne fonctionnaient pas pour certaines apps (alsamixer fermait, pulsemixer ne répondait pas).

**Root cause** : Les terminaux ont 2 modes de curseur (standard DECCKM) :
- Mode normal : `\x1b[A` (nmtui, htop, fzf...)
- Mode application : `\x1bOA` (alsamixer, pulsemixer...)

On envoyait toujours le mode normal.

**Solution** :
- Ajouté `isApplicationCursorMode` dans `terminal_view.dart` qui lit `terminal.cursorKeysMode`
- Ajouté `_sendArrowKey()` dans `ghost_text_input.dart` qui envoie le bon code selon le mode
- Compatible avec TOUTES les apps TUI Linux maintenant

**Fichiers modifiés** :
- `lib/features/terminal/widgets/terminal_view.dart`
- `lib/features/terminal/widgets/ghost_text_input.dart`

### Sécurité des données sensibles

**Problème résolu** : Les mots de passe sudo étaient enregistrés dans l'historique.

**Solution multi-couche** :
1. **Patterns sensibles** : `password`, `token`, `secret`, `api_key`, etc. jamais enregistrés
2. **Détection prompts** : `[sudo] password`, `passphrase`, `enter password`...
3. **Flag sécurité** : Quand prompt détecté → input suivant ignoré

**Fichiers modifiés** :
- `lib/features/terminal/providers/terminal_provider.dart` - Logique sécurité + suggestions
- `lib/features/terminal/widgets/terminal_view.dart` - Interception output pour détection
- `lib/features/settings/widgets/security_section.dart` - Bouton effacer historique

### Remis à plus tard (V1.3)

- **Analyse de chemin (ls silencieux)** - Suggérer fichiers/dossiers pour `cd`, `cat`
- **Intelligence Git** - Suggérer branches locales
- **TAB chaîné** - Suggestions multiples

---

## Session 2 Février 2026 (soir) - Boutons overlay et améliorations

### Nouveaux boutons implémentés

| Bouton | Emplacement | Action |
|--------|-------------|--------|
| **ESC** | Overlay bas-gauche du terminal | Envoie `\x1b` (Escape) |
| **Saut de ligne ↵** | Overlay bas-droite du terminal | Insère `\n` dans le champ de saisie |
| **Scroll to bottom ↓** | Tab bar (intelligent) | Scroll vers le bas du terminal |
| **Bouton dossier 📁** | Tab bar (permanent) | Navigation rapide - À implémenter |

### Scroll to bottom intelligent

Le bouton apparaît **uniquement si** l'utilisateur a scrollé vers le haut dans le terminal (>50px du bas).
Utilise un `StateProvider<bool>` (`terminalScrolledUpProvider`) mis à jour par le `ScrollController`.

### Flèches historique empilées

Les boutons ↑↓ pour naviguer dans l'historique sont maintenant **empilés verticalement** à gauche du champ de saisie (style Warp).

### Bug connu : Mode expanded du champ de saisie

**Problème** : Le mode "expanded" (swipe vers le haut pour agrandir le champ à 40% de l'écran) cause un overflow de layout quand le clavier virtuel apparaît.

**Cause** : Conflit entre le `Scaffold.resizeToAvoidBottomInset` et la hauteur fixe du `AnimatedContainer`.

**Statut** : **Désactivé temporairement** - Le code est en place mais commenté. À résoudre dans une session future avec une approche différente (probablement avec un `LayoutBuilder` ou restructuration du layout).

**Workaround actuel** : Le champ s'agrandit automatiquement avec `maxLines: null` quand on ajoute des sauts de ligne.

### Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `lib/features/terminal/screens/terminal_screen.dart` | Boutons overlay ESC + Saut de ligne |
| `lib/features/terminal/widgets/ghost_text_input.dart` | Flèches empilées, `maxLines: null`, mode expanded désactivé |
| `lib/features/terminal/widgets/session_tab_bar.dart` | Bouton scroll to bottom + bouton dossier |
| `lib/features/terminal/widgets/terminal_view.dart` | ScrollController + détection scroll |
| `lib/features/terminal/widgets/terminal_action_buttons.dart` | +TerminalHistoryButton |
| `lib/features/terminal/providers/terminal_provider.dart` | +terminalScrolledUpProvider |

---

## Session 2 Février 2026 (après-midi) - Bouton CTRL universel

### Refonte de la barre de saisie

**Changement majeur** : Simplification de l'interface avec un bouton CTRL universel.

### Modifications

| Changement | Détail |
|------------|--------|
| **Bouton CTRL** | Remplace Send/Stop - supporte TOUS les raccourcis CTRL+A-Z |
| **Flèches historique** | Empilées verticalement (↑ au-dessus de ↓), taille 28x28 |
| **Suppression Send** | Le clavier virtuel a déjà Enter |
| **Suppression Stop** | Remplacé par CTRL+C |

### Fonctionnement du bouton CTRL

1. **Normal** : Bouton vert avec "CTRL"
2. **Armé** : Clic → devient jaune avec "+"
3. **Exécution** : Tape une lettre → envoie CTRL+lettre → redevient vert
4. **Annuler** : Re-clic sur le bouton → désarme

### Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `lib/features/terminal/widgets/terminal_action_buttons.dart` | +TerminalCtrlButton, -TerminalSendButton, -TerminalStopButton |
| `lib/features/terminal/widgets/ghost_text_input.dart` | Nouvelle logique CTRL, flèches empilées |

### Prochains boutons à implémenter

- **Navigation dossiers** - cd rapide style Warp
- **ESC** - Touche Escape (vim, menus)
- **Saut de ligne** - Nouvelle ligne sans envoyer

---

## Session 2 Février 2026 (nuit) - Wake-on-LAN

### Feature complète : Allumer son PC à distance

Nouvelle fonctionnalité permettant d'allumer un PC via Wake-on-LAN avant de se connecter en SSH.

### Fonctionnalités implémentées

| Feature | Description |
|---------|-------------|
| **Bouton WOL START** | Sur l'écran d'accueil, lance le réveil du PC |
| **Settings WOL** | 4ème onglet dans les paramètres |
| **Config WOL** | Nom, adresse MAC, connexion SSH associée |
| **Options avancées** | Broadcast address, port UDP (pour WOL distant) |
| **Animation** | Écran stylé pendant le réveil avec compteur |
| **Polling SSH** | Tentatives toutes les 10s pendant 5 min max |
| **WOL automatique** | Si connexion auto + WOL activé → réveil auto au lancement |
| **Bouton extinction** | ⏻ dans la barre session pour éteindre le PC |
| **Détection OS** | Auto-détection Linux/macOS/Windows pour commande shutdown |

### Fichiers créés

| Fichier | Description |
|---------|-------------|
| `lib/models/wol_config.dart` | Modèle de données |
| `lib/services/wol_service.dart` | Envoi Magic Packet + polling |
| `lib/features/settings/providers/wol_provider.dart` | État des configs |
| `lib/features/settings/widgets/wol_section.dart` | Onglet Settings |
| `lib/features/settings/widgets/add_wol_sheet.dart` | Formulaire ajout |
| `lib/features/terminal/widgets/wol_start_screen.dart` | Écran animation |

### Fichiers modifiés

| Fichier | Modification |
|---------|--------------|
| `pubspec.yaml` | +wake_on_lan ^4.1.1+3 |
| `lib/models/app_settings.dart` | +wolEnabled |
| `lib/features/settings/screens/settings_screen.dart` | 4ème onglet |
| `lib/features/terminal/screens/terminal_screen.dart` | Bouton + WOL auto |
| `lib/features/terminal/widgets/session_info_bar.dart` | Bouton extinction |
| `lib/services/ssh_service.dart` | detectOS(), shutdown() |

### Package utilisé

- `wake_on_lan: ^4.1.1+3` - Envoi de Magic Packets UDP

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

