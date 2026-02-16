# Wake-on-LAN (WOL) - Design Document

> Date: 2 Février 2026
> Status: Validé

---

## Vue d'ensemble

### Objectif
Permettre aux utilisateurs d'allumer leur PC à distance via Wake-on-LAN (WOL) avant de se connecter en SSH pour vibe coder.

### Principes clés
- **Optionnel** : Le WOL est une feature activable, pas obligatoire
- **Séparé du SSH** : Les connexions SSH classiques restent intactes
- **Deux modes** : Local (même réseau) et distant (port forwarding)
- **Automatisable** : WOL + connexion SSH en un seul flow si configuré

### Workflow utilisateur type

```
┌─────────────────────────────────────────────────────────────┐
│                    PREMIER LANCEMENT                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│     [WOL START]  ← Grisé (pas configuré)                    │
│                                                             │
│     [Nouvelle connexion SSH]                                │
│     [Connexions sauvegardées...]                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    APRÈS CONFIG WOL                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│     [WOL START]  ← Actif (vert)                             │
│                                                             │
│     [Nouvelle connexion SSH]                                │
│     [Connexions sauvegardées...]                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│               CLIC SUR "WOL START"                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Sélectionnez le PC à allumer :                             │
│                                                             │
│  [🖥️ PC Bureau - 192.168.1.50]                              │
│  [🖥️ PC Gaming - 192.168.1.100]                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Page Settings - Onglet WOL

### Structure de l'onglet (4ème onglet Settings)

```
┌─────────────────────────────────────────────────────────────┐
│  [Connexion] [Thème] [Sécurité] [WOL]                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Activer Wake-on-LAN ─────────────────────────────┐     │
│  │                                            [OFF]   │     │
│  │  Allumez votre PC à distance avant de vous        │     │
│  │  connecter en SSH.                                │     │
│  │                                                   │     │
│  │  📖 Guide complet sur chillshell.app/wol          │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ┌─ Configurations WOL ──────────────────────────────┐     │
│  │                                                   │     │
│  │  Aucune configuration. Ajoutez-en une pour       │     │
│  │  activer le WOL.                                  │     │
│  │                                                   │     │
│  │              [+ Ajouter un PC]                    │     │
│  │                                                   │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ┌─ Scan automatique (bientôt) ──────────────────────┐     │
│  │                                            [GRISÉ]│     │
│  │  Fonctionnalité en développement                  │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Logique du toggle "Activer WOL"

| Situation | Toggle | Bouton "WOL START" |
|-----------|--------|-------------------|
| Aucune config WOL | Grisé + désactivé | Grisé |
| Config WOL existe, toggle OFF | Actif mais OFF | Grisé |
| Config WOL existe, toggle ON | Actif et ON | Actif (vert) |

---

## Formulaire d'ajout WOL

### Écran "Ajouter un PC"

```
┌─────────────────────────────────────────────────────────────┐
│  ← Retour              Ajouter un PC                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Nom du PC                                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ PC Bureau                                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Adresse MAC *                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ AA:BB:CC:DD:EE:FF                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│  Comment trouver l'adresse MAC ? 📖                         │
│                                                             │
│  Connexion SSH associée *                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 🔑 kevin@192.168.1.50                          ▼   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ─── Options avancées (WOL distant) ───────────────────    │
│                                                             │
│  Adresse broadcast (optionnel)                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 255.255.255.255                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│  Par défaut: 255.255.255.255                                │
│                                                             │
│  Port UDP (optionnel)                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 9                                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│  Par défaut: 9                                              │
│                                                             │
│                    [Enregistrer]                            │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Champs

| Champ | Obligatoire | Description |
|-------|-------------|-------------|
| Nom du PC | Oui | Nom affiché dans la liste |
| Adresse MAC | Oui | Format XX:XX:XX:XX:XX:XX |
| Connexion SSH | Oui | Liste déroulante des connexions sauvegardées |
| Adresse broadcast | Non | Pour WOL distant (défaut: 255.255.255.255) |
| Port UDP | Non | Pour WOL distant (défaut: 9) |

---

## Flow WOL - Allumage du PC

### Étape 1 : Sélection du PC

```
┌─────────────────────────────────────────────────────────────┐
│                    Allumer un PC                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │  🖥️ PC Bureau                                      │     │
│  │  kevin@192.168.1.50                               │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
│  ┌───────────────────────────────────────────────────┐     │
│  │  🖥️ PC Gaming                                      │     │
│  │  kevin@192.168.1.100                              │     │
│  └───────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Étape 2 : Animation de démarrage (5 min max)

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                                                             │
│                    ⚡ WOL START ⚡                           │
│                                                             │
│                   [Animation stylée]                        │
│                                                             │
│              Réveil de PC Bureau en cours...                │
│                                                             │
│                   Tentative 3/30                            │
│                      01:24                                  │
│                                                             │
│                     [Annuler]                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Logique du polling

1. Envoi du Magic Packet WOL
2. Attente 10 secondes
3. Tentative de connexion SSH
4. Si échec → retour à l'étape 3 (max 30 tentatives = 5 min)
5. Si succès → connexion établie, affichage du terminal

### Étape 3 : Succès

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                       ✅ Connecté !                         │
│                                                             │
│                    PC Bureau allumé                         │
│                   Connexion SSH établie                     │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         ↓ (auto après 1.5s)
      [Terminal]
```

---

## Extinction du PC

### Emplacement du bouton

Le bouton d'extinction apparaît dans la **barre de session info** quand on est connecté à un PC qui a une config WOL associée.

```
┌─────────────────────────────────────────────────────────────┐
│ Session info: ← PC Bureau • 192.168.1.50  ⏱ 2m  [⏻]       │
└─────────────────────────────────────────────────────────────┘
                                                   ↑
                                         Bouton extinction
```

### Flow d'extinction

**Clic sur le bouton ⏻ :**

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│              ⚠️ Éteindre le PC ?                            │
│                                                             │
│         Voulez-vous vraiment éteindre PC Bureau ?           │
│                                                             │
│         La connexion SSH sera fermée.                       │
│                                                             │
│              [Annuler]    [Éteindre]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Détection automatique de l'OS

À la première connexion SSH, l'app exécute `uname -s` en arrière-plan et stocke le résultat.

| Résultat `uname` | OS détecté | Commande shutdown |
|------------------|------------|-------------------|
| `Linux` | Linux | `sudo shutdown -h now` |
| `Darwin` | macOS | `sudo shutdown -h now` |
| Erreur/timeout | Windows | `shutdown /s /t 0` |

**Note** : Si `sudo` demande un mot de passe, l'utilisateur le verra dans le terminal avant l'extinction.

---

## WOL Automatique

### Quand le WOL auto se déclenche

Si **toutes** ces conditions sont remplies au lancement de l'app :

1. ✅ Connexion auto SSH activée dans les settings
2. ✅ La dernière connexion SSH a une config WOL associée
3. ✅ WOL activé dans les settings

### Flow automatique

```
┌─────────────────────────────────────────────────────────────┐
│                  LANCEMENT DE L'APP                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ⚡ WOL START ⚡                           │
│                                                             │
│                   [Animation stylée]                        │
│                                                             │
│           Réveil automatique de PC Bureau...                │
│                                                             │
│                   Tentative 1/30                            │
│                      00:00                                  │
│                                                             │
│                     [Annuler]                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Si l'utilisateur clique "Annuler"** → Retour à l'écran d'accueil normal

### Cas où le PC est déjà allumé

Le polling détecte immédiatement que le PC répond → connexion SSH directe sans attente.

```
Tentative 1 → SSH OK → Connecté en ~2 secondes
```

Pas de requête WOL inutile envoyée après la première.

### Résumé des combinaisons

| Connexion auto | WOL activé | Config WOL existe | Comportement |
|----------------|------------|-------------------|--------------|
| ❌ | - | - | Écran d'accueil normal |
| ✅ | ❌ | - | Tentative SSH directe (erreur si PC éteint) |
| ✅ | ✅ | ❌ | Tentative SSH directe |
| ✅ | ✅ | ✅ | **WOL auto + polling SSH** |

---

## Implémentation technique

### Package Flutter pour WOL

```yaml
# pubspec.yaml
dependencies:
  wake_on_lan: ^1.1.0  # Envoi de Magic Packets
```

### Modèle de données

```dart
class WolConfig {
  String id;
  String name;           // "PC Bureau"
  String macAddress;     // "AA:BB:CC:DD:EE:FF"
  String sshConnectionId; // Référence vers la connexion SSH
  String? broadcastAddress; // Optionnel (défaut: 255.255.255.255)
  int port;              // Défaut: 9
  String? detectedOS;    // "linux", "macos", "windows" (auto-détecté)
}
```

### Fichiers à créer

| Fichier | Description |
|---------|-------------|
| `lib/models/wol_config.dart` | Modèle WolConfig |
| `lib/services/wol_service.dart` | Envoi Magic Packet + polling SSH |
| `lib/features/settings/widgets/wol_section.dart` | Onglet Settings WOL |
| `lib/features/settings/widgets/add_wol_sheet.dart` | Formulaire ajout WOL |
| `lib/features/settings/providers/wol_provider.dart` | État des configs WOL |
| `lib/features/terminal/widgets/wol_start_screen.dart` | Écran animation WOL |

### Fichiers à modifier

| Fichier | Modification |
|---------|--------------|
| `lib/models/app_settings.dart` | Ajouter `wolEnabled: bool` |
| `lib/features/settings/screens/settings_screen.dart` | 4ème onglet WOL |
| `lib/features/terminal/screens/terminal_screen.dart` | Bouton "WOL START" + flow auto |
| `lib/features/terminal/widgets/session_info_bar.dart` | Bouton extinction ⏻ |
| `lib/services/ssh_service.dart` | Détection OS via `uname -s` |

### Stockage

Les configs WOL sont stockées dans `flutter_secure_storage` (comme les clés SSH) car elles contiennent des infos réseau sensibles.

---

## Prérequis côté PC

**Important** : Le WOL nécessite une configuration sur le PC cible. Voir le guide complet sur `chillshell.app/tutos/wol-setup.html`.

### 1. BIOS/UEFI (tous OS)

Activer l'option WOL dans le BIOS :
- Chercher : "Wake on LAN", "Wake on PCI-E", "Power On by PME", "Resume by LAN"
- Activer l'option → Save & Exit

### 2. Configuration OS

| OS | Commande vérification | Commande activation |
|----|----------------------|---------------------|
| **Linux** | `sudo ethtool <interface> \| grep Wake` | `sudo ethtool -s <interface> wol g` |
| **Windows** | `Get-NetAdapterPowerManagement` | `Set-NetAdapterPowerManagement -Name "Ethernet" -WakeOnMagicPacket Enabled` |
| **macOS** | `pmset -g \| grep womp` | `sudo pmset -a womp 1` |

### 3. Extinction : sudo sans mot de passe (optionnel)

Pour éviter de taper le mot de passe sudo à chaque extinction :
```bash
sudo visudo
# Ajouter à la fin :
# username ALL=(ALL) NOPASSWD: /sbin/shutdown
```

**Note** : La confirmation dans l'app protège déjà contre les clics accidentels.

---

## Notes techniques

### WOL Local vs Distant

| Mode | Configuration requise | Complexité |
|------|----------------------|------------|
| **Local** (même WiFi) | Connexion Ethernet + config BIOS/OS | Simple |
| **Distant** (Internet) | + Port forwarding UDP 9 sur la box | Avancé |

**Important** : Le WiFi ne supporte pas le WOL dans 95% des cas. Connexion Ethernet requise.

Le guide complet pour le WOL distant sera disponible sur `chillshell.app/tutos/wol-setup.html`.

### Gestion d'erreurs

| Erreur | Message affiché |
|--------|-----------------|
| Timeout 5 min | "ERREUR: PC ÉTEINT - Le PC n'a pas répondu" |
| MAC invalide | "Adresse MAC invalide" |
| Réseau indisponible | "Pas de connexion réseau" |

---

## Tests de validation

### Tests effectués (2 Fév 2026)

| Test | Résultat |
|------|----------|
| Ajout d'un PC (formulaire) | ✅ Validé |
| Bouton WOL START (PC allumé) | ✅ Validé - Connexion rapide (~2s) |
| Bouton extinction ⏻ visible | ✅ Validé |
| Popup confirmation extinction | ✅ Validé |
| Commande shutdown envoyée | ✅ Validé (demande mot de passe sudo) |
| PC s'éteint | ✅ Validé |

### Tests à faire plus tard

| Test | Status |
|------|--------|
| WOL START avec PC éteint (câblé Ethernet) | ⏳ À tester |
| WOL distant (broadcast + port UDP forwarding) | ⏳ À tester |
| WOL automatique au lancement | ⏳ À tester |
| Détection OS automatique | ⏳ À tester
