# Site Chill — Document de Design Complet

> Document de reference pour le developpement du site web Chill
> Date : 9 fevrier 2026
> Statut : Valide

---

## 1. VUE D'ENSEMBLE

### Identite
- **Nom du site** : Chill
- **Marque** : Chill (marque parapluie pour plusieurs apps futures)
- **Produit actuel** : ChillShell (terminal SSH mobile)
- **Produit futurs** : ChillDesk, ChillScrappe (pas presentes pour le moment)
- **URL cible** : chill.app (ou similaire)
- **Langues** : Anglais (defaut) + Francais (toggle discret)
- **Theme** : Dark/Light avec detection automatique (`prefers-color-scheme`) + toggle manuel

### Vision long terme
Chill proposera des services accessibles/peu chers qui permettent de faire la meme chose que des services bien plus chers, en restant au maximum sur du local niveau donnees pour la securite. Pour le moment, seul ChillShell est presente. Le site evoluera naturellement avec les nouveaux produits (ajout d'un onglet "Produits" avec menu deroulant).

### Stack technique
- **Framework** : Astro (statique, i18n natif, SEO, zero JS par defaut)
- **Style** : Tailwind CSS (dark mode via `dark:`)
- **Animations** : Motion (ex Framer Motion) — scroll reveal style Linear
- **Hebergement** : Vercel
- **Analytics** : Plausible ou Umami (RGPD-friendly)

### Principes d'architecture code
- Fichier de design tokens centralise (couleurs, typo, spacing) — jamais de valeurs en dur
- Architecture modulaire : composants reutilisables, fichiers courts
- Composants partages : CodeBlock, Accordion, Carousel, TabsOS, etc.
- Utiliser le skill `frontend-design` pour un design de qualite, pas generique "fait par IA"
- SEO a travailler avec les skills/MCP dedies

---

## 2. DESIGN & DIRECTION ARTISTIQUE

### Inspirations
- **Linear** (https://linear.app/homepage) : animation scroll streaming mot par mot, palette sombre, typographie Inter
- **OpenClaw** : logo centre flottant en header, blocs de code style terminal avec tabs + bouton copier
- Les palettes de couleurs de Linear sont reprises et adaptees a l'identite Chill

### Palette de couleurs

**Dark mode (defaut)** :
| Token | Valeur | Usage |
|-------|--------|-------|
| `bg-primary` | `#08090a` | Fond principal (style Linear) |
| `bg-elevated` | `#111214` | Cards, accordeons, blocs de code |
| `border` | `#1e2025` | Bordures subtiles |
| `text-primary` | `#f7f8f8` | Texte principal |
| `text-secondary` | `#8a8f98` | Sous-titres, descriptions |
| `accent` | `#10B981` | Vert emeraude ChillShell |
| `color-blue` | `#4ea7fc` | Liens |
| `color-red` | `#eb5757` | Erreurs, incompatible |
| `color-green` | `#4cb782` | Succes, compatible |
| `color-orange` | `#fc7840` | Avertissements, en cours de test |

**Light mode** : A definir avec le skill `frontend-design` (pas juste un "inverse" du dark)

### Typographie
| Element | Police | Taille | Weight | Spacing |
|---------|--------|--------|--------|---------|
| H1 Hero | Inter Variable | ~64px | 510 | -1.4px |
| H2 Sections | Inter Variable | ~40px | 510 | -1px |
| H3 Cards | Inter Variable | ~24px | 500 | -0.5px |
| Body | Inter Variable | 17px | 400 | 0 |
| Body small | Inter Variable | 15px | 400 | -0.011em |
| Code/Terminal | JetBrains Mono | 14px | 400 | 0 |

### Animations
- **Scroll reveal (toute la page d'accueil)** : Chaque element apparait progressivement au scroll (Motion `whileInView`), animation mot par mot sur les titres, fade-in sur les paragraphes — exactement comme Linear
- **Logo Chill** : Animation flottante (bob up/down, style OpenClaw)
- **Carrousels** : Auto-defilement + swipe manuel
- **Transitions de page** : Fluides entre les sections

### Composants de reference
- **Blocs de code** : Style OpenClaw — dots macOS en haut, tabs (Install/Run/Upgrade), fond `bg-elevated`, bouton copier
- **Accordeons** : Utilises partout (tutos, FAQ, securite, updates)
- **Tabs OS** : Windows / Mac / Linux avec icones
- **Carrousels** : Auto-scroll + swipe, indicateurs de pagination

---

## 3. STRUCTURE DU SITE & NAVIGATION

### Header
```
+-----------------------------------------------+
|     [Icone Chill + animation flottante]        |
|                  "Chill"                        |
|                                                 |
|  Tutos v  |  Securite  |  Updates  |  FAQ  [FR/EN]
+-----------------------------------------------+
```
- Logo + nom "Chill" centre AU-DESSUS des onglets (style OpenClaw, pas a gauche)
- Navbar en dessous avec 4 onglets + toggle langue discret
- Le logo ramene a l'accueil
- Evolution future : ajout d'un onglet "Produits v" quand les nouvelles apps arrivent

### Dropdown Tutos (ordre logique d'utilisation)
```
Tutos v
  +-- Config OS        (prerequis systeme)
  +-- SSH              (connexion de base)
  +-- Tailscale        (connexion distante)
  +-- BIOS             (prerequis hardware WoL)
  +-- Wake-on-LAN      (allumer son PC)
  +-- Agents CLI       (installer les outils)
```

### Arborescence des pages
```
/
+-- index                    (Accueil)
+-- tutos/
|   +-- config-os            (tabs Windows/Mac/Linux + accordeons)
|   +-- ssh                  (tabs Windows/Mac/Linux + accordeons)
|   +-- tailscale            (tabs Windows/Mac/Linux + accordeons)
|   +-- bios                 (accordeons par marque, ASUS d'abord)
|   +-- wol                  (tabs Windows/Mac/Linux + accordeons)
|   +-- agents-cli           (tableau compatibilite + cards accordeons)
+-- securite                 (version simple + details en accordeons/code)
+-- updates                  (cards par version, accordeons, telechargement)
+-- faq                      (accordeons questions/reponses)
+-- mentions-legales
+-- cgu
+-- politique-confidentialite
```

### Footer
```
Logo Chill  |  (c) 2026 Chill  |  Mentions legales  |  CGU  |  Confidentialite
```
Minimaliste, pas de doublons avec le contenu de la page.

---

## 4. PAGE D'ACCUEIL — DETAIL DES SECTIONS

### 4.1 Hero Chill (marque)
- Icone ICONE_APPLICATION.png centre avec animation flottante (bob up/down)
- "Chill" en grand en dessous
- Pas de slogan (arrivera avec les futurs produits)
- Fond sombre avec halo vert subtil derriere le logo (style OpenClaw mais en vert emeraude)

### 4.2 Section ChillShell (hero produit)
- Nom "ChillShell" + slogan oriente code/terminal
- Tagline : "Ton terminal desktop. Dans ta poche."
- Sous-titre : "L'app SSH pensee pour le vibe coding"
- Boutons : Play Store (gauche) + App Store (droite)
- Animation streaming : texte qui apparait mot par mot style Linear

### 4.3 Section 1 — Terminal & Agents CLI (perspective gauche)
- **Layout** : Screenshot incline en perspective 3D a gauche + texte en trapeze a droite
- **Images** : Carrousel 5 images (auto-defilement + swipe manuel)
  - Terminal simple
  - 2 screenshots avec agents CLI differents ouverts
- **Texte** : "Un vrai terminal. Pas une imitation. Lance Claude Code, Cursor, Gemini CLI directement."

### 4.4 Section 2 — Connexions (perspective droite, miroir)
- **Layout** : Screenshot incline a droite + texte en trapeze a gauche (effet miroir de la section 1)
- **Images** : Carrousel 3 images (auto-defilement + swipe manuel)
  - SSH
  - Tailscale
  - Wake-on-LAN
- **Texte** : "Connecte-toi en local ou a distance. Allume ton PC depuis ton canape."

### 4.5 Section 3 — Personnalisation (image droite + fade)
- **Layout** : Screenshots droits avec fondu transparent sur les bords + texte normal a cote
- **Images** : Carrousel 5 images (auto-defilement + swipe manuel)
  - 5 themes de couleurs differents
  - 5 langues differentes visibles
- **Texte** : "Personnalise ton experience. Themes, langues, ton app a ta facon."

### 4.6 Section Differenciation — "Pourquoi ChillShell ?"
- Agnostique — ton terminal, tes outils, ton choix
- Wake-on-LAN integre
- Pense pour les agents CLI, pas juste un client SSH generique
- Tes donnees restent sur ton telephone

### 4.7 Section Pricing
- "Essai gratuit 4 jours"
- "Puis 1.99 euros — Une seule fois, pour toujours"
- Boutons stores repetes ici
- Ordre : differenciation PUIS prix (convaincre avant de donner le prix)

### 4.8 Footer

---

## 5. PAGES TUTOS

### Structure commune
- **Tabs OS** en haut : Windows / Mac / Linux (sauf page BIOS)
- **Accordeons** pour chaque etape, fermes par defaut
- Le contenu des accordeons change selon le tab OS selectionne
- **Blocs de code** style OpenClaw : dots macOS, fond sureleve, bouton copier
- **Ton** : tutoiement, direct, structure etape par etape (meme style que les docs existants)
- **Windows** : screenshots de l'interface + commandes PowerShell
- **Linux** : commandes terminal uniquement (public avise)
- **macOS** : commandes simples, pas de screenshots (pas de Mac disponible)

### 5.1 Page Config OS
- Prerequis systeme avant tout le reste
- Windows : activer OpenSSH, firewall, verifier les services
- Linux : installer openssh-server (Debian/Fedora/Arch)
- macOS : activer Remote Login

### 5.2 Page SSH
- Verifier / Installer / Demarrer / Trouver son IP / Tester la connexion
- Section cles SSH : ajouter sa cle publique (difference admin/standard pour Windows)

### 5.3 Page Tailscale
- Installation PC + mobile
- Creation de compte
- Utilisation avec ChillShell (IP 100.x.x.x)
- Explication simple : "Ca marche partout : WiFi, 5G, etranger"

### 5.4 Page BIOS (pas de tabs OS)
- Guide generique : quoi chercher, noms alternatifs des options selon les marques
- Accordeon ASUS ROG (detaille, pret)
- Accordeons autres marques : ajoutes plus tard quand documentes
- Parametres cles : ErP Ready (Disabled), Power On By PCI-E (Enabled), ASPM (Disabled si probleme)
- Important : rendre les choses simples pour ne pas faire fuir, le BIOS est intimidant

### 5.5 Page Wake-on-LAN
- Tabs OS avec accordeons
- Avertissement clair en haut : "WoL local uniquement, Ethernet requis"
- Tableau de compatibilite (Windows = OK, Linux = experimental avec Intel I226-V)
- Checklist de debug en bas de page

### 5.6 Page Agents CLI
**Tableau de compatibilite en haut de page** :

| Agent | Windows | Linux | iOS |
|-------|---------|-------|-----|
| Claude Code | OK | OK | ? |
| Codex CLI | OK | BUG | ? |
| Cursor CLI | OK | OK | ? |
| Kimi Code | OK | OK | ? |
| Gemini CLI | OK | OK | ? |
| Droid CLI | OK | OK | ? |
| Mistral Vibe | OK | OK | ? |
| Crush | ? | ? | ? |
| Grok CLI | OK | OK | ? |
| OpenCode | BUG | BUG | ? |

Indicateurs : vert = OK, rouge = ne fonctionne pas, orange = en cours de test

**Cards par agent** avec accordeons :
- Nom + logo + description courte (visible ferme)
- Accordeon depliable : bloc de code style OpenClaw avec tabs Install / Run / Upgrade + bouton copier
- Prerequis indiques (Node.js 18+, Python 3.10+, etc.)

---

## 6. PAGE SECURITE

### Partie haute — Version simple (rassurante)
Icones + phrases courtes, lisible en 10 secondes :
- "Tes cles SSH restent sur ton telephone. Jamais envoyees nulle part."
- "Chiffrement AES-CBC (Android) / Keychain (iOS)"
- "Code PIN hashe, jamais stocke en clair"
- "Aucune donnee transmise a nos serveurs"

### Partie basse — Details techniques en cards + accordeons
Chaque card contient des accordeons avec des blocs de code montrant l'implementation :
- **Card Stockage des donnees** : tableau detaille des methodes de stockage/chiffrement
- **Card Connexion SSH** : TOFU, Ed25519, gestion des cles en memoire (SecureBuffer, dispose)
- **Card Authentification locale** : PIN PBKDF2-HMAC-SHA256 100k iterations, biometrie, verrouillage auto
- **Card Protection contre les fuites** : filtrage regex historique, clipboard cleanup, FLAG_SECURE
- **Card Detection root/jailbreak** : chemins verifies, banniere d'avertissement
- **Card Journal d'audit** : evenements enregistres, rotation FIFO 500 entrees
- **Card Limitations connues** : transparence totale (SecureBuffer/GC, detection root contournable)
- **Card Audits realises** : scores et resultats (white-box 8.5/10, STRIDE 100% mitige)

---

## 7. PAGE UPDATES

- Cards par version, la plus recente depliee par defaut
- Anciennes versions en accordeons fermes
- Chaque card contient :
  - Numero de version + date
  - Liste des changements (nouveautes, corrections, ameliorations)
  - Lien de telechargement APK (version actuelle + anciennes)
- Permet aux utilisateurs de revenir a une ancienne version en cas de bug

---

## 8. PAGE FAQ

- Accordeons questions/reponses, simple et direct
- Pas de formulaire de contact pour le lancement (Discord viendra plus tard)
- Questions :
  - "ChillShell fonctionne avec quel OS cote serveur ?"
  - "Ca marche avec Claude Code / Cursor CLI / Codex ?"
  - "Le Wake-on-LAN marche en WiFi ?"
  - "Je peux utiliser ChillShell sans Wake-on-LAN ?"
  - "Mes donnees sont-elles envoyees quelque part ?"
  - "Le paiement est-il unique ou recurrent ?"
  - "Il y a un remboursement possible ?"

---

## 9. PAGES LEGAL

### Mentions legales
- Editeur : [A completer]
- Hebergeur : Vercel Inc.
- Contact : [A completer]

### CGU
- Licence d'utilisation personnelle
- Pas de revente/redistribution
- Pas de reverse engineering
- Limitation de responsabilite

### Politique de confidentialite
- Donnees collectees : Aucune (ou analytics anonymes si Plausible)
- Donnees stockees localement : Cles SSH (chiffrees), configurations serveurs
- Pas de transmission a des tiers
- Conformite RGPD

---

## 10. SEO

### Meta tags (chaque page)
```html
<title>Chill — ChillShell | App SSH Mobile pour Vibe Coding</title>
<meta name="description" content="...adapte par page...">
<meta name="keywords" content="ssh app, mobile ssh, claude code, vibe coding, wake on lan...">
```

### Open Graph (partages sociaux)
```html
<meta property="og:title" content="Chill — Ton terminal dans ta poche">
<meta property="og:image" content="/og-image.png">
<meta property="og:url" content="https://chill.app">
```

### Mots-cles a cibler (pages tutos = SEO fort)
- "claude code installation windows/mac/linux"
- "cursor cli setup tutorial"
- "gemini cli install"
- "codex cli install"
- "ssh app for coding"
- "mobile terminal app"
- "wake on lan ssh"
- "vibe coding mobile"
- A travailler en profondeur avec les skills/MCP SEO dedies apres le build

### Assets necessaires
- [ ] Logo Chill (version web)
- [ ] Icone app ICONE_APPLICATION.png (deja disponible)
- [ ] Screenshots app 9:16 — minimum 13 (5 terminal + 3 connexions + 5 themes)
- [ ] og-image.png (1200x630)
- [ ] Favicon
- [ ] Logos/icones des agents CLI

---

## 11. ARCHITECTURE CODE ASTRO

```
src/
+-- config/
|   +-- design-tokens.ts       <- COULEURS, TYPO, SPACING (source unique)
+-- i18n/
|   +-- en.json                <- traductions anglais
|   +-- fr.json                <- traductions francais
+-- layouts/
|   +-- BaseLayout.astro       <- layout commun (head, nav, footer)
+-- components/
|   +-- ui/
|   |   +-- Accordion.tsx      <- reutilisable partout
|   |   +-- Carousel.tsx       <- auto-scroll + swipe
|   |   +-- CodeBlock.tsx      <- style OpenClaw (dots, tabs, copier)
|   |   +-- TabsOS.tsx         <- Windows/Mac/Linux
|   |   +-- LanguageToggle.tsx
|   |   +-- ThemeToggle.tsx
|   +-- home/
|   |   +-- HeroChill.astro    <- logo flottant
|   |   +-- HeroChillShell.astro
|   |   +-- SectionPerspective.tsx  <- sections 1&2 (image inclinee + texte trapeze)
|   |   +-- SectionFade.tsx    <- section 3+ (image droite + fade)
|   |   +-- Differentiator.astro
|   |   +-- Pricing.astro
|   +-- tutos/
|   |   +-- TutoLayout.astro   <- layout tabs OS + accordeons
|   |   +-- AgentCard.tsx      <- card agent CLI
|   |   +-- CompatTable.tsx    <- tableau compatibilite agents
|   +-- security/
|       +-- SecuritySimple.astro
|       +-- SecurityDetail.tsx
+-- pages/
|   +-- index.astro
|   +-- securite.astro
|   +-- updates.astro
|   +-- faq.astro
|   +-- tutos/
|   |   +-- config-os.astro
|   |   +-- ssh.astro
|   |   +-- tailscale.astro
|   |   +-- bios.astro
|   |   +-- wol.astro
|   |   +-- agents-cli.astro
|   +-- mentions-legales.astro
|   +-- cgu.astro
|   +-- politique-confidentialite.astro
+-- styles/
|   +-- global.css             <- Tailwind + variables CSS depuis tokens
+-- assets/
    +-- images/
    +-- icons/
```

**Principe cle** : `design-tokens.ts` est la seule source de verite. Toutes les couleurs, tailles, spacing sont importes depuis ce fichier. Jamais de valeur en dur dans un composant.

---

## 12. DECISIONS PRISES

| Decision | Choix | Raison |
|----------|-------|--------|
| Nom du site | Chill (pas ChillShell) | Marque parapluie pour futurs produits |
| Slogan Chill | Aucun pour le moment | Arrive avec les futurs produits |
| Navigation | 4 onglets + dropdown Tutos | Simple, evolutif |
| Theme | Dark + Light + detection auto | Accessibilite |
| Logo position | Centre au-dessus de la navbar | Style OpenClaw |
| Sections accueil | 3 sections screenshots + diff + pricing | Parcours complet |
| Section 1-2 | Perspective 3D + texte trapeze | Dynamique, remplit la page |
| Section 3+ | Image droite + fade transparent | Plus calme, lisible |
| Carrousels | Auto-defilement + swipe manuel | Partout, jamais toutes les images visibles |
| Tutos | Tabs OS + accordeons combines | Un clic pour l'OS, un clic pour l'etape |
| Page BIOS | Separee des tutos OS | Hardware independant de l'OS |
| Page BIOS contenu | ASUS ROG d'abord, autres plus tard | Seul BIOS documente |
| Agents CLI | Tableau compat en haut + cards accordeons | Vue d'ensemble rapide |
| Securite | Simple en haut + details techniques en cards | Double public |
| Updates | Cards par version + telechargement anciennes | Transparence, choix utilisateur |
| FAQ | Accordeons simples | Pas de Discord pour le moment |
| Framework | Astro | Statique, i18n natif, SEO, leger |
| Style | Tailwind CSS | Dark mode integre, tokens |
| Animations | Motion (ex Framer Motion) | Scroll reveal style Linear |
| Architecture | Modulaire, design tokens centralises | Pas de valeurs en dur, fichiers courts |
| Ton des tutos | Tutoiement, direct, etape par etape | Meme style que les docs existants |

---

*Document cree le 9 fevrier 2026*
*Valide par brainstorming collaboratif*
