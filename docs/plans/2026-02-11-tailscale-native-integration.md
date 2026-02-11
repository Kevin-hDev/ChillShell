# Design : Integration native Tailscale dans ChillShell

> Date : 11 Fevrier 2026
> Statut : Valide par l'utilisateur

---

## Objectif

Remplacer completement l'application Tailscale officielle. L'utilisateur
cree son compte, s'authentifie et utilise le tunnel VPN Tailscale
directement depuis ChillShell, sans installer d'app externe.

## Plateforme cible

**Android uniquement** pour cette premiere iteration. iOS viendra plus tard.

---

## UI — Page settings/Acces (modifiee)

### Etat non connecte

La section "ACCES DISTANT" actuelle (3 boutons Play Store/App Store/Site web)
est remplacee par :

1. **Texte d'introduction** (discret) :
   "Creez votre compte Tailscale et authentifiez-vous directement depuis
   l'application"

2. **Deux boutons cote a cote** :
   - "Creer un compte" (icone `person_add`)
   - "Se connecter" (icone `login`)
   Les deux ouvrent une page OAuth Tailscale en webview.

3. **Accordeon** (ferme par defaut) :
   Titre : "Qu'est-ce que Tailscale ?"
   Contenu : explication courte — Tailscale cree un reseau prive securise
   entre vos appareils, accessible de partout (WiFi, 4G, 5G) sans
   configuration complexe.

### Etat connecte

Les deux boutons disparaissent. Remplaces par une card compacte :
- "Connecte — 100.x.y.z"
- Lien vers l'onglet dashboard Tailscale
- L'accordeon explicatif reste disponible

Le reste de la page (Cles SSH, Card securite) ne change pas.

---

## UI — Nouvel onglet settings/Tailscale (dashboard)

Un nouvel onglet "Tailscale" apparait dans la barre des settings, entre
"Acces" et "General". **Visible uniquement quand l'utilisateur est connecte.**

### Card de statut (en haut)

- Indicateur vert "Connecte" ou rouge "Deconnecte"
- "Mon IP : 100.x.y.z" + bouton copier
- Nom de l'appareil (ex: "samsung-galaxy-s24")
- Bouton "Se deconnecter" discret a droite

### Liste des machines

Titre : "Mes appareils (N)"

Chaque machine = une card contenant :
- Nom de la machine (ex: "pc-bureau")
- IP Tailscale (ex: "100.64.0.2")
- Pastille de statut : verte = en ligne, rouge = hors ligne
- Bouton "Copier l'IP" (icone copier)
- Bouton "Connexion SSH" (icone terminal) — ouvre le formulaire de
  nouvelle connexion SSH avec l'IP pre-remplie dans le champ host

Tri : machines en ligne en premier, hors ligne en dessous (legerement grisees).

---

## Architecture technique

### Flux d'authentification

```
Bouton "Se connecter"
  -> TailscaleProvider.login()
    -> TailscaleService (Dart)
      -> MethodChannel
        -> TailscalePlugin (Kotlin)
          -> OAuth webview -> token
          -> Demarre VpnService -> tunnel actif
          -> IP 100.x.y.z obtenue
        <- retour au Dart
      <- met a jour TailscaleState
    -> UI se rafraichit (dashboard visible)
```

### Cote Android (Kotlin)

- `TailscalePlugin.kt` : plugin Flutter exposant les methodes via MethodChannel
  - `login()` : demarre le flux OAuth
  - `logout()` : coupe le tunnel et deconnecte
  - `getStatus()` : retourne etat connexion + IP locale
  - `getMyIP()` : retourne l'IP Tailscale du telephone
- `TailscaleVpnService.kt` : service VPN Android (extends VpnService)
  - Gere le tunnel WireGuard/Tailscale en arriere-plan
  - Utilise `libtailscale.aar` (Go compile via gomobile)
- `AndroidManifest.xml` : permission `BIND_VPN_SERVICE` + declaration du service

### Cote Dart

- `TailscaleService` : communication avec le plugin natif via MethodChannel
  + appels API REST Tailscale pour la liste des machines
- `TailscaleProvider` (Riverpod StateNotifier) : gere `TailscaleState`
- `TailscaleState` : modele immutable — isConnected, myIP, deviceName, devices list
- `TailscaleDevice` : modele immutable — name, ip, isOnline

### API REST Tailscale

Pour la liste des machines, appel direct en Dart :
`GET https://api.tailscale.com/api/v2/tailnet/-/devices`
Avec le token OAuth obtenu lors de l'authentification.
Pas besoin de passer par le natif pour ca.

---

## Fichiers

### Nouveaux (Dart)

| Fichier | Role |
|---------|------|
| `lib/services/tailscale_service.dart` | Communication plugin natif + API REST |
| `lib/features/settings/providers/tailscale_provider.dart` | Etat Riverpod |
| `lib/models/tailscale_device.dart` | Modele immutable TailscaleDevice |
| `lib/features/settings/widgets/tailscale_section.dart` | Section auth dans onglet Acces |
| `lib/features/settings/widgets/tailscale_dashboard.dart` | Dashboard (onglet Tailscale) |

### Nouveaux (Android natif)

| Fichier | Role |
|---------|------|
| `android/app/src/main/kotlin/.../TailscalePlugin.kt` | Plugin Flutter <-> natif |
| `android/app/src/main/kotlin/.../TailscaleVpnService.kt` | Service VPN |
| `android/app/libs/libtailscale.aar` | Bibliotheque Tailscale compilee |

### Modifies

| Fichier | Changement |
|---------|------------|
| `lib/features/settings/widgets/access_section.dart` | Remplacer 3 boutons par TailscaleSection |
| `lib/features/settings/screens/settings_screen.dart` | Ajouter onglet Tailscale conditionnel |
| `lib/models/app_settings.dart` | Champs Tailscale (token, statut) |
| `lib/l10n/app_*.arb` (x5) | Nouvelles cles i18n |
| `lib/services/services.dart` | Export nouveau service |
| `android/app/src/main/AndroidManifest.xml` | Permission VPN + service |
| `pubspec.yaml` | Aucune nouvelle dependance Dart |

---

## Deploiement en equipe (3 agents)

### Agent 1 : Fondations Dart
- Modeles (`tailscale_device.dart`)
- Mise a jour `app_settings.dart`
- i18n (5 fichiers ARB + gen-l10n)
- Service (`tailscale_service.dart`)
- Provider (`tailscale_provider.dart`)
- Export dans `services.dart`

### Agent 2 : Android natif
- Recherche et build de `libtailscale.aar`
- `TailscalePlugin.kt` (MethodChannel)
- `TailscaleVpnService.kt`
- `AndroidManifest.xml` modifie

### Agent 3 : UI Flutter
- `tailscale_section.dart` (auth dans Acces)
- `tailscale_dashboard.dart` (nouvel onglet)
- Modification `access_section.dart`
- Modification `settings_screen.dart`
- Depend de Agent 1 (modeles + providers + i18n)
