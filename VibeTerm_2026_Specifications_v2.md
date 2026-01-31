# 📜 Spécifications Projet : VibeTerm 2026 (v2.0)

> **Version** : 2.0  
> **Dernière mise à jour** : 29 janvier 2026  
> **Statut** : Design validé, prêt pour implémentation

---

## 1. Vision du Projet

Développer une application mobile (iOS/Android) agissant comme un **miroir de terminal ultra-moderne** pour piloter un PC à distance via SSH. 

- **Esthétique** : Inspirée de Warp Terminal (blocs, design sombre, épuré)
- **Ergonomie** : Pensée pour le Vibe Coding et l'usage mobile
- **Architecture** : Multi-sessions avec onglets

---

## 2. Architecture Technique (Stack 2026)

| Composant | Technologie | Version / Détails |
|-----------|-------------|-------------------|
| Framework Mobile | Flutter | v3.38.8 (Optimisé Impeller) |
| Rendu Terminal | xterm.dart | v5.1.0 (Support Nerd Fonts & GPU) |
| Protocole SSH | dartssh2 | v3.0.0+ (Ed25519 & Persistence) |
| Tunnel Réseau | Tailscale | Mesh VPN (Accès IP stable sans NAT) |
| Multiplexeur | tmux | Pour le mirroring PC ↔ Mobile |
| Langage | Dart | v3.10.7 |
| Stockage sécurisé | flutter_secure_storage | Pour clés SSH et credentials |

---

## 3. Structure des Écrans

### 3.1 Écran Terminal (Principal)

L'écran principal de l'application, composé de :

```
┌─────────────────────────────────────┐
│ [Header] Logo + Titre + Boutons Nav │
├─────────────────────────────────────┤
│ [Onglets] Session1 | Session2 | +   │
├─────────────────────────────────────┤
│ [Info] tmux: vibe • host • Tailscale│
├─────────────────────────────────────┤
│                                     │
│ [Bloc Commande 1]                   │
│   ❯ commande                  0.02s │
│   output...                         │
│                                     │
│ [Bloc Commande 2]                   │
│   ❯ commande                  1.20s │
│   output...                         │
│                                     │
├─────────────────────────────────────┤
│ [Input] ❯ Run commands        [↑]   │
└─────────────────────────────────────┘
```

**Fonctionnalités :**
- Système d'onglets pour multi-sessions (scroll tactile horizontal)
- Bouton "+" pour nouvelle session
- Indicateur de statut par onglet (connecté/déconnecté)
- Blocs de commandes avec header (commande + temps) et body (output)
- Zone d'input fixe en bas avec ghost text completion
- Swipe → ou bouton pour accepter l'autocomplétion
- Bouton d'envoi (flèche vers le haut)

### 3.2 Écran Paramètres (Settings)

```
┌─────────────────────────────────────┐
│ [Header] Logo + "Paramètres" + Nav  │
├─────────────────────────────────────┤
│                                     │
│ Paramètres                          │
│ Gérer vos clés SSH et connexions    │
│                                     │
│ 🔑 Clés SSH              [+Ajouter] │
│ ┌─────────────────────────────────┐ │
│ │ Workstation Key    ED25519  ✏🗑 │ │
│ │ workstation.local • Aujourd'hui│ │
│ ├─────────────────────────────────┤ │
│ │ Server Prod        ED25519  ✏🗑 │ │
│ │ 192.168.1.50 • Hier            │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ⚡ Connexions rapides               │
│ ┌─────────────────────────────────┐ │
│ │ Connexion auto démarrage   [ON] │ │
│ │ Reconnecter si déconnecté  [ON] │ │
│ │ Notification déconnexion  [OFF] │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 🎨 Apparence                        │
│ ┌─────────────────────────────────┐ │
│ │ [Warp Dark] [Dracula] [Nord]    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 🔒 Sécurité                         │
│ ┌─────────────────────────────────┐ │
│ │ Auth biométrique           [ON] │ │
│ │ [Effacer toutes les clés]       │ │
│ └─────────────────────────────────┘ │
│                                     │
└─────────────────────────────────────┘
```

**Sections :**
1. **Clés SSH** : Liste, ajout, édition, suppression
2. **Connexions rapides** : Auto-connect, reconnexion, notifications
3. **Apparence** : Sélecteur de thème
4. **Sécurité** : Biométrie, suppression des données

---

## 4. Fonctionnalités Détaillées

### 4.1 Miroir de Session (PC ↔ Mobile)

- Utilisation de `tmux` sur le PC hôte
- Connexion automatique à la session existante ou création :
  ```bash
  tmux attach -t vibe || tmux new -s vibe
  ```
- Synchronisation bidirectionnelle en temps réel
- Au lancement, envoi de `export LANG=fr_FR.UTF-8`

### 4.2 Système d'Onglets Multi-Sessions

- Chaque onglet = une connexion SSH distincte
- Possibilité de se connecter à plusieurs machines
- Indicateur visuel de l'état de connexion (point vert/gris)
- Scroll horizontal tactile (sans scrollbar visible)
- Bouton "+" toujours accessible pour nouvelle session

### 4.3 Interface "Warp-Mobile"

- **Design** : Dark Mode (Fond : `#0f0f0f`)
- **Polices** : JetBrains Mono / FiraCode Nerd Font
- **Input intelligent** : Champ de saisie séparé du flux (en bas)
- **Ghost Text Completion** :
  - Suggestions de commandes en gris (`#555555`) derrière le curseur
  - Validation par swipe → ou bouton de complétion
  - Envoi par bouton vert (flèche ↑)

### 4.4 Gestion des Clés SSH

- Stockage sécurisé via `flutter_secure_storage`
- Support Ed25519 et RSA
- Association clé ↔ host
- Métadonnées : nom, type, dernière utilisation
- Import/Export (optionnel)

### 4.5 Sécurité

- Authentification biométrique (Face ID / Touch ID / Empreinte)
- Aucune clé API ou mot de passe en dur
- Option de suppression complète des données sensibles

---

## 5. Guide d'Implémentation (Phases)

### Phase 1 : Core SSH
- Setup du tunnel SSH avec `dartssh2`
- Authentification par clé (Ed25519)
- Connexion via Tailscale

### Phase 2 : Rendu Terminal
- Intégration `xterm.dart`
- Gestion du redimensionnement dynamique
- Rendu des blocs de commandes style Warp

### Phase 3 : Multi-Sessions
- Système d'onglets
- Gestion des connexions multiples
- Persistance des sessions

### Phase 4 : Ghost Text & Input
- Widget `GhostTextInput` pour la complétion
- Détection des commandes courantes
- Geste swipe → pour validation

### Phase 5 : Settings & Sécurité
- Écran de paramètres complet
- Gestion des clés SSH (CRUD)
- Authentification biométrique
- Stockage sécurisé

### Phase 6 : Thèmes & Polish
- Implémentation des thèmes (Warp Dark, Dracula, Nord)
- Animations et transitions
- Tests et optimisations

---

## 6. Points Critiques & Configuration IA

> [!IMPORTANT]
> **Consignes impératives pour Claude (via Claude Code ou API) :**

1. **Langue** : Claude doit impérativement communiquer et répondre en **Français**.

2. **Design System** : Se référer au fichier `VibeTerm_Design_System.md` pour reproduire exactement le design validé.

3. **Recherche Web** : Pour toute analyse ou recherche de documentation, utiliser le MCP Brave Search pour obtenir les données les plus fraîches.

4. **Sécurité** : 
   - Aucune clé API ou mot de passe en dur
   - Utiliser `flutter_secure_storage` pour tout stockage sensible
   - Implémenter l'auth biométrique avec `local_auth`

5. **Architecture** : Respecter une architecture propre (Provider/Riverpod pour le state management)

---

## 7. Livrables Attendus

- [ ] Application Flutter fonctionnelle (iOS + Android)
- [ ] Connexion SSH stable via Tailscale
- [ ] Multi-sessions avec onglets
- [ ] Ghost text completion
- [ ] Écran Settings complet
- [ ] Gestion sécurisée des clés SSH
- [ ] Auth biométrique
- [ ] 3 thèmes disponibles (Warp Dark, Dracula, Nord)

---

## 8. Fichiers de Référence

| Fichier | Description |
|---------|-------------|
| `VibeTerm_2026_Specifications_v2.md` | Ce document (specs fonctionnelles) |
| `VibeTerm_Design_System.md` | Design system complet (couleurs, composants, spacing) |
| `vibeterm-mockup-v5.jsx` | Mockup React de référence |

