# Design : Refonte Settings (Tailscale + WOL + Clés SSH)

> Date : 5 Février 2026
> Status : Validé

---

## Résumé des changements

- Nouvel onglet **"Accès"** avec Tailscale + Clés SSH
- Page **WOL simplifiée** (suppression options avancées) + instructions intégrées
- **Clés SSH** : suppression RSA, renommage boutons, fix import
- **Suppression multiple** pour clés SSH et configs WOL

---

## 1. Réorganisation des onglets Settings

### Avant (4 onglets)
```
| Connexion | Général | Sécurité | WOL |
```

### Après (5 onglets)
```
| Connexion | Accès | Général | Sécurité | WOL |
```

### Contenu par onglet

| Onglet | Contenu |
|--------|---------|
| **Connexion** | Connexions rapides + Connexions sauvegardées |
| **Accès** | Tailscale (card) + Clés SSH (liste) |
| **Général** | Langue + Taille police |
| **Sécurité** | Biométrie + Auto-lock |
| **WOL** | Activer WOL + Configs PC + Instructions (cards dépliables) |

### Fichier impacté
- `settings_screen.dart` (TabController passe de 4 à 5)

---

## 2. Nouvel onglet "Accès"

### Structure de la page

```
┌─────────────────────────────────────────┐
│ 🌐 ACCÈS DISTANT                        │
├─────────────────────────────────────────┤
│ Tailscale                               │
│ Connectez-vous à votre PC de            │
│ n'importe où dans le monde              │
│                                         │
│ ┌────────────────┬────────────────┐     │
│ │ 📱 Play Store  │ 🍎 App Store   │     │
│ ├────────────────┴────────────────┤     │
│ │   🌐 Site web (tailscale.com)   │     │
│ └─────────────────────────────────┘     │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ 🔑 CLÉS SSH                             │
├─────────────────────────────────────────┤
│ 🔑 Ma clé Ed25519              [🗑️]    │
├─────────────────────────────────────────┤
│              [+ Ajouter]                │
└─────────────────────────────────────────┘
```

### Boutons Tailscale
- 📱 Play Store → ouvre lien Play Store
- 🍎 App Store → ouvre lien App Store
- 🌐 Site web → ouvre tailscale.com

### Fichiers impactés
- Créer `access_section.dart` (nouveau fichier)
- `connection_section.dart` → retirer la section Clés SSH

---

## 3. Page WOL simplifiée

### Formulaire "Ajouter une configuration"

```
┌─────────────────────────────────────────┐
│ ← Retour          Ajouter un PC         │
├─────────────────────────────────────────┤
│ Nom du PC                               │
│ [PC Bureau___________________________]  │
│                                         │
│ Adresse MAC *                           │
│ [AA:BB:CC:DD:EE:FF___________________]  │
│ 📖 Comment trouver l'adresse MAC ?      │
│                                         │
│ Connexion SSH associée                  │
│ [▼ Sélectionner une connexion_______]   │
│                                         │
│ [        💾 Enregistrer              ]  │
└─────────────────────────────────────────┘
```

### Supprimé
- ❌ Section "Options avancées" (broadcast address, port UDP)

### Fichier impacté
- `add_wol_sheet.dart`

---

## 4. Instructions WoL (cards dépliables)

### Emplacement
En bas de la page WOL, après la liste des configs

### Structure

```
┌─────────────────────────────────────────┐
│ ℹ️ CONFIGURATION REQUISE                │
├─────────────────────────────────────────┤
│ Le Wake-on-LAN permet d'allumer votre   │
│ PC depuis l'app.                        │
│                                         │
│ ⚡ Allumer : câble Ethernet requis      │
│ ⏻ Éteindre : WiFi ou câble             │
│                                         │
│ ▼ Windows ──────────────────────────    │
│ ▼ Mac ──────────────────────────────    │
│                                         │
│ 📖 Guide complet : chillshell.app/wol   │
└─────────────────────────────────────────┘
```

### Card Windows (dépliée)

```
▲ Windows ────────────────────────────

  1. BIOS (au démarrage, touche F2/Del)
     • Activer "Power On By PCI-E"
     • Désactiver "ErP Ready"

  2. Désactiver "Démarrage rapide"
     • Options d'alimentation → Paramètre système
     • Cliquer sur "Modifier des paramètres
       actuellement non disponibles"
     • Décocher "Activer le démarrage rapide"

  3. Gestionnaire de périphériques
     • Carte réseau → Gestion alimentation
     • Cocher "Autoriser uniquement un paquet
       magique à sortir l'ordinateur du mode veille"
     • Carte réseau → Avancé
     • Activer "Wake on Magic Packet"
```

### Card Mac (dépliée)

```
▲ Mac ────────────────────────────────

  1. Menu Apple → Préférences Système
  2. Économiseur d'énergie
  3. Cocher "Réactiver pour l'accès
     au réseau"
```

### Fichier impacté
- `wol_section.dart`

---

## 5. Clés SSH (simplification + fix)

### Changements boutons

| Avant | Après |
|-------|-------|
| "Clé privée" | "Importer une clé" |
| "Générer une clé" | "Créer une clé SSH" |
| Choix RSA / Ed25519 | Ed25519 uniquement (pas de choix) |
| Texte ".pem / .pub" | Retirer ".pub" (erreur) |
| Import ne fonctionne pas | 🐛 Fix à implémenter |

### Menu "+" après changements

```
┌─────────────────────────────────────┐
│ + Créer une clé SSH                 │
│ + Importer une clé                  │
└─────────────────────────────────────┘
```

### Fichier impacté
- `add_ssh_key_sheet.dart`

---

## 6. Suppression multiple (Clés SSH + WOL)

### Comportement identique pour les deux listes

#### Mode normal
```
┌─────────────────────────────────────────┐
│ 🔑 Ma clé Ed25519              [🗑️]    │
│ 🔑 Clé serveur prod            [🗑️]    │
├─────────────────────────────────────────┤
│              [+ Ajouter]                │
└─────────────────────────────────────────┘
```
- Tap sur 🗑️ = popup confirmation → supprime 1 item

#### Mode sélection (long press sur un item)
```
┌─────────────────────────────────────────┐
│ ☑️ Ma clé Ed25519                       │
│ ⬜ Clé serveur prod                     │
├─────────────────────────────────────────┤
│       [+ Ajouter]  [🗑️ Supprimer]      │
└─────────────────────────────────────────┘
```
- Tap sur items = toggle sélection
- Tap sur "🗑️ Supprimer" = popup "Supprimer X éléments ?" → confirmer

#### Sortie du mode sélection
- Tap ailleurs / bouton retour
- Après suppression confirmée

### Fichiers impactés
- `wol_section.dart` (liste configs WOL)
- `access_section.dart` (liste clés SSH)

---

## Fichiers à modifier (récapitulatif)

| Fichier | Action |
|---------|--------|
| `settings_screen.dart` | TabController 4→5, nouvel onglet "Accès" |
| `access_section.dart` | **CRÉER** - Tailscale + Clés SSH |
| `connection_section.dart` | Retirer section Clés SSH |
| `add_wol_sheet.dart` | Supprimer options avancées |
| `wol_section.dart` | Ajouter cards instructions + suppression multiple |
| `add_ssh_key_sheet.dart` | Renommer boutons, supprimer RSA, fix import |
| Fichiers l10n (5 langues) | Nouvelles clés de traduction |

---

## Traductions à ajouter

| Clé | FR | EN |
|-----|----|----|
| `accessTab` | Accès | Access |
| `remoteAccess` | Accès distant | Remote Access |
| `tailscaleDescription` | Connectez-vous à votre PC de n'importe où | Connect to your PC from anywhere |
| `downloadTailscale` | Télécharger Tailscale | Download Tailscale |
| `playStore` | Play Store | Play Store |
| `appStore` | App Store | App Store |
| `website` | Site web | Website |
| `createSshKey` | Créer une clé SSH | Create SSH Key |
| `importKey` | Importer une clé | Import Key |
| `configRequired` | Configuration requise | Configuration Required |
| `wolDescription` | Le Wake-on-LAN permet d'allumer votre PC depuis l'app. | Wake-on-LAN lets you turn on your PC from the app. |
| `turnOnCableRequired` | Allumer : câble Ethernet requis | Turn on: Ethernet cable required |
| `turnOffWifiOrCable` | Éteindre : WiFi ou câble | Turn off: WiFi or cable |
| `fullGuide` | Guide complet | Full guide |
| `deleteItems` | Supprimer {count} éléments ? | Delete {count} items? |

---

*Document validé le 5 Février 2026*
