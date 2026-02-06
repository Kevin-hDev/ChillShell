# Audit complet ChillShell — Design

> **Périmètre :** Tout `lib/` (72 fichiers, 18 829 LOC) + config Android/iOS pour la sécurité
> **Approche :** Analyse + correction directe (pas de rapport sans action)
> **Règle de sécurité :** Après chaque refactoring → `flutter analyze` + `flutter build apk --debug`

---

## Vue d'ensemble

| # | Audit | Focus | Périmètre |
|---|-------|-------|-----------|
| 1 | Qualité du code | Nettoyage, refactoring, cohérence | Tout `lib/` |
| 2 | Sécurité | Failles, stockage, logs, permissions | `lib/` + `android/` + `ios/` |
| 3 | Performance | Fluidité, mémoire, batterie, FPS | `lib/` |
| 4 | Tests | Couverture des fonctions critiques | `lib/` + `test/` |

**Ordre :** 1 → 2 → 3 → 4 (on nettoie avant de sécuriser, on sécurise avant d'optimiser, on teste le code final)

**Chaque audit = une session dédiée** pour garder le focus et ne rien louper.

---

## Audit 1 — Qualité du code

**Objectif :** Un code propre, sans duplication, sans code mort, avec des fichiers de taille raisonnable.

### 1.1 — Code mort
- Imports inutilisés dans chaque fichier
- Variables, méthodes et classes jamais appelées
- Clés de traduction définies mais jamais utilisées dans l'UI
- Constantes du theme (couleurs, spacing) jamais référencées
- Fichiers entiers potentiellement inutilisés

### 1.2 — Textes en dur
- Chercher les strings affichées à l'utilisateur qui ne passent pas par le système de traduction (`l10n`)
- Les remplacer par des clés de traduction

### 1.3 — Duplication
- Patterns de code copié-collé entre widgets
- Logique dupliquée entre providers
- Widgets qui font la même chose avec des noms différents

### 1.4 — Fichiers trop gros (refactoring)
- `terminal_provider.dart` (1 436 lignes) — découper en sous-providers ou extraire les listes de commandes
- `terminal_screen.dart` (990 lignes) — extraire des widgets
- `ssh_provider.dart` (990 lignes) — séparer la logique onglets/connexion/reconnexion
- Tout fichier > 400 lignes sera examiné

### 1.5 — Cohérence des patterns
- Est-ce que tous les providers suivent le même pattern Riverpod 3 ?
- Est-ce que la gestion d'erreurs est uniforme (try/catch vs silencieux) ?
- Est-ce que les couleurs utilisent toujours les constantes du theme ?

### 1.6 — Vérification finale
- `flutter analyze` — 0 erreurs, 0 warnings
- `flutter build apk --debug` — BUILD SUCCESS

---

## Audit 2 — Sécurité

**Objectif :** Aucune faille exploitable, données sensibles protégées, bonnes pratiques respectées.

### 2.1 — Stockage des secrets
- Vérifier que les clés SSH privées sont bien dans `flutter_secure_storage` et jamais en clair
- Vérifier le stockage du code PIN (hashé ou en clair ?)
- Vérifier que les mots de passe ne sont jamais stockés nulle part

### 2.2 — Fuites de données dans les logs
- Chercher tous les `debugPrint` et `print` qui pourraient afficher des clés, mots de passe, tokens
- Vérifier que les logs sensibles sont désactivés en mode release

### 2.3 — Historique des commandes
- Vérifier que le filtre de commandes sensibles fonctionne (passwords, tokens, export)
- Vérifier que les prompts de mot de passe sont bien détectés pour ne pas enregistrer la saisie suivante

### 2.4 — Config Android/iOS
- Permissions déclarées — est-ce qu'on demande plus que nécessaire ?
- `android:allowBackup` — est-ce que les données sensibles pourraient être extraites via un backup ?
- Config réseau — est-ce qu'on autorise le trafic en clair (HTTP) ?
- Clé de signature et config ProGuard/R8

### 2.5 — Validation des entrées
- Injection dans les champs host/username/port
- Vérification des inputs avant envoi SSH

### 2.6 — Vérification finale
- Aucun secret en clair dans le code source
- `flutter analyze` + `flutter build apk --debug`

---

## Audit 3 — Performance

**Objectif :** Une app fluide à 60/120 FPS, pas de freeze, consommation batterie minimale en arrière-plan.

### 3.1 — Rebuilds UI inutiles
- Analyser chaque `ref.watch()` — est-ce qu'on écoute tout l'état alors qu'on a besoin d'un seul champ ? (utiliser `.select()` quand possible)
- Vérifier les `setState()` — est-ce qu'ils reconstruisent trop de widgets ?
- Chercher les widgets lourds qui pourraient être `const`

### 3.2 — Rendu terminal (le plus critique)
- Le terminal xterm est le widget le plus sollicité — vérifier que le flux SSH ne provoque pas de rebuilds excessifs
- Vérifier le throttle du resize PTY (déjà 150ms, peut-être ajustable)
- Optimiser le parsing des séquences ANSI si possible

### 3.3 — Fuites mémoire et streams
- Vérifier que tous les `StreamSubscription` sont annulés au dispose
- Vérifier que les `Timer` sont tous annulés (reconnexion, auto-lock, resize)
- Vérifier que les services SSH sont bien nettoyés à la fermeture d'onglets

### 3.4 — Consommation batterie
- Analyser le `flutter_foreground_task` — fréquence des checks en arrière-plan
- Le timer de vérification de connexion (toutes les 10s) est-il trop fréquent ?
- Peut-on réduire l'activité quand l'app est en arrière-plan ?

### 3.5 — Configuration FPS
- Flutter tourne à 60 FPS par défaut, 120 FPS sur les écrans compatibles
- On peut forcer le mode haute fréquence avec `FlutterView.render()` pour les appareils 90/120 Hz
- Ajouter un réglage utilisateur dans les settings si pertinent

### 3.6 — Vérification finale
- `flutter analyze` + `flutter build apk --debug`
- Pas de jank visible dans les animations

---

## Audit 4 — Tests

**Objectif :** Couvrir les fonctions critiques pour attraper les régressions automatiquement. On ne vise pas 100% de couverture — on cible les zones à risque.

### 4.1 — Tests unitaires des models
- `AppSettings` — `toJson()` / `fromJson()` round-trip
- `Session`, `SSHKey`, `SavedConnection`, `WolConfig` — sérialisation/désérialisation
- `Command` — mêmes vérifications

### 4.2 — Tests unitaires des services
- `StorageService` — save puis load retourne les mêmes données
- `PinService` — save PIN, verify correct, verify incorrect
- `SecureStorageService` — stockage et récupération des clés

### 4.3 — Tests des providers (logique métier)
- `SettingsNotifier` — toggle un réglage → l'état change correctement
- `TerminalNotifier` — filtre de commandes sensibles (passwords, tokens)
- `TerminalNotifier` — détection d'erreurs dans l'output
- `SessionsNotifier` — add/remove/update sessions
- `SSHNotifier` — logique des onglets (créer, fermer, sélectionner)

### 4.4 — Tests de sécurité
- L'historique ne contient jamais de mots de passe
- Les prompts de password sont bien détectés
- Le ghost text ne suggère pas de commandes sensibles

### 4.5 — Tests d'intégration légers
- Le flow de démarrage : settings chargés → lock screen affiché si PIN activé
- Le flow de connexion : créer une session → état mis à jour

### 4.6 — Vérification finale
- `flutter test` — tous les tests passent
- `flutter analyze` + `flutter build apk --debug`
