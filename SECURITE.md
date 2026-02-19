# Politique de Sécurité — ChillShell

**Dernière mise à jour :19 Février 2026
**Version :** 3.0

---

## 🔒 Travail de Sécurité Réalisé

ChillShell a fait l'objet d'une **validation de sécurité interne approfondie** avant publication.

### Audits de Sécurité Réalisés

**Quatre audits internes successifs :**

1. **Audit de Sécurité White-box** (Version 1.5.1)
   - Évaluation initiale de la sécurité de la codebase
   - 9 correctifs critiques appliqués
   - Score de sécurité (auto-évalué) : **6.5 → 8.5/10**

2. **Modélisation des Menaces STRIDE**
   - 22 menaces identifiées et analysées
   - 8 risques validés
   - **12 mitigations implémentées à 100%**

3. **Audit de Sécurité Ultra-Granulaire** (méthodologie Trail of Bits)
   - **4 agents IA spécialisés en parallèle** (Claude Opus 4.6, Gemini 3 PRO, Kimi K2.5)
   - 44 fichiers analysés (~7 500 lignes de code critique)
   - **62 findings :** 4 Critiques, 8 Élevés, 21 Moyens, 21 Faibles, 8 confirmations
   - **Verdict : 0 vulnérabilité exploitable à distance identifiée**

4. **Red Team + Blindage Défensif Complet** (Février 2026)
   - Simulation offensive : 25 vecteurs d'attaque identifiés et analysés
   - **26 modules de sécurité créés** (`lib/core/security/`)
   - **738 tests automatisés** — 0 régression
   - **30 fichiers existants renforcés**

### Ce Que Cela Signifie

- ✅ Méthodologie de sécurité professionnelle appliquée (protocole Trail of Bits)
- ✅ Aucune vulnérabilité exploitable à distance trouvée
- ✅ Tous les problèmes identifiés corrigés ou documentés
- ✅ Suite de tests automatisés : **738 tests passent**
- ✅ Score de sécurité interne (auto-évalué) : **8.5/10**

---

## 🛡️ Mesures de Sécurité Implémentées

### Stockage Sécurisé

Toutes les données sensibles sont stockées via **Flutter Secure Storage** :
- **Android :** Chiffrement AES-GCM via Android Keystore (puce matérielle)
- **iOS :** iOS Keychain avec protection matérielle

**Données protégées :**
- Clés SSH privées (chiffrées au repos)
- Code PIN (hashé avec PBKDF2-HMAC-SHA256, 100 000 itérations + salt aléatoire 32 octets)
- Empreintes des serveurs SSH (pour vérification TOFU)
- Journal d'audit (chiffré)
- Configurations Wake-on-LAN
- Historique des commandes (après filtrage des commandes sensibles)

**Zéro secret codé en dur** dans le code source (vérifié par scan complet de la codebase).

---

### Authentification Locale

**Code PIN :**
- Minimum 8 chiffres (100 millions de combinaisons)
- Hashé avec **PBKDF2-HMAC-SHA256** (100 000 itérations)
- **Comparaison en temps constant** (XOR bit à bit) — prévient les attaques par timing
- **Rate limiting :** 5 tentatives → verrouillage avec backoff exponentiel (30s → 300s max)
- La longueur du PIN n'est jamais stockée séparément (réduit la surface d'information)
- Jamais stocké en clair, jamais conservé en mémoire au-delà du traitement

**Authentification Biométrique :**
- API système native (empreinte digitale, Face ID)
- Données biométriques ne quittent jamais l'appareil
- Mode strict : biométrie uniquement (pas de fallback vers PIN système)
- Requise pour les actions critiques et irréversibles
- Auto-invalidée lorsque l'app passe en arrière-plan

**Verrouillage Automatique :**
- Timeout configurable : 5, 10, 15 ou 30 minutes
- Déclenché lorsque l'app reste en arrière-plan au-delà du délai choisi
- Re-authentification requise si l'app reste en arrière-plan plus de 2 minutes

---

### Sécurité des Connexions SSH

**TOFU (Trust On First Use) — Durci :**
- Empreinte SHA-256 du serveur affichée à la première connexion
- Confirmation manuelle de l'utilisateur requise
- Empreinte stockée dans le stockage sécurisé
- **Comparaison en temps constant** lors des connexions suivantes
- **Alerte rouge** si l'empreinte change (avertissement Man-in-the-Middle)

**Protocole & Algorithmes :**
- Protocole SSH2 uniquement (bibliothèque dartssh2, version verrouillée)
- Algorithme de clé préféré : **Ed25519**
- **16 algorithmes SSH faibles bloqués** au niveau logiciel (SHA-1, CBC, arcfour, 3DES, etc.)
- Communications chiffrées de bout en bout via WireGuard (Tailscale)

**Gestion des Clés en Mémoire :**
- Clés privées chargées dans un **SecureKeyHolder** dédié (tableau d'octets, non String)
- **Zeroing explicite** après utilisation (limite la fenêtre d'exposition mémoire)
- Le worker SSH ne conserve pas les clés entre les connexions
- Opérations cryptographiques exécutées dans un **isolate Dart séparé** (isolation thread)

**Génération de Clés :**
- Clés Ed25519 générées localement sur l'appareil
- Octets de la clé privée **effacés de la mémoire** après stockage
- Clé publique séparée de la clé privée dans le modèle de données
- Sérialisation JSON **exclut explicitement la clé privée**

**Timeout de Session :**
- Sessions SSH inactives déconnectées automatiquement (15 minutes, configurable)

---

### Protection Contre les Fuites de Données

**Filtrage de l'Historique des Commandes :**
- Filtrage automatique par regex exclut les secrets de l'historique :
  - Clés AWS, tokens JWT/Bearer, clés API
  - Mots de passe en ligne de commande
  - Variables contenant des mots-clés sensibles (SECRET, TOKEN, KEY, PASSWORD)
- **Limite :** 500 entrées maximum avec rotation automatique
- **Expiration :** entrées de plus de 30 jours supprimées automatiquement
- L'utilisateur peut effacer manuellement l'historique complet

**Avertissements sur Commandes Sensibles :**
- L'app détecte les commandes shell potentiellement dangereuses
- Un avertissement est affiché avant exécution (l'utilisateur reste maître)

**Logs de Production :**
- Tous les appels de debug conditionnés par le mode debug Flutter
- **En production (APK release) : zéro log émis**
- Aucun hostname, adresse IP ou identifiant dans les logs de production
- Logs du moteur Go Tailscale également filtrés (tokens OAuth, URLs d'auth)

**Presse-papiers :**
- **Auto-vidé** après copie de données sensibles (délai configurable : 3s, 5s, 10s, 15s)
- **Vidé silencieusement** lorsque l'app passe en arrière-plan
- API native utilisée (pas de notification système "Clipboard cleared")

---

### Protection d'Écran

**Android :**
- **FLAG_SECURE** activé par défaut
- Bloque les captures d'écran et l'enregistrement d'écran
- L'app n'apparaît pas dans le sélecteur d'apps récentes (écran noir)
- Désactivable par l'utilisateur dans les réglages

**iOS :**
- Écran de masquage affiché automatiquement en arrière-plan
- Empêche la capture du contenu dans le sélecteur d'apps
- Désactivable par l'utilisateur dans les réglages

---

### Anti-Tampering (freeRASP / Talsec)

Intégration de **freeRASP 6.12.0** (Talsec Security) — détection de 12 types de menaces :

| Menace | Détection |
|--------|-----------|
| Root Android / Jailbreak iOS | ✅ |
| Debugger attaché | ✅ |
| Hooks (Frida, Xposed) | ✅ |
| Émulateur | ✅ |
| Tampering de l'APK | ✅ |
| Installation hors store officiel | ✅ |
| Obfuscation manquante | ✅ |
| Pas de verrouillage d'écran appareil | ✅ |
| Mode développeur actif | ✅ |
| ADB connecté | ✅ |

**Comportement :**
- Mode **Avertir** : enregistrement dans le journal d'audit chiffré
- Mode **Bloquer** : écran d'alerte bloquant l'app
- Désactivé automatiquement en mode debug (évite les faux positifs)
- Configurable par l'utilisateur dans les réglages (section Sécurité)

---

### Sécurité de la Supply Chain

- **6 packages critiques verrouillés** en version exacte (sans le `^` qui permettrait des mises à jour automatiques) :

| Package | Version verrouillée | Rôle |
|---------|--------------------|----|
| dartssh2 | 2.13.0 | Bibliothèque SSH |
| cryptography | 2.9.0 | Primitives cryptographiques |
| pointycastle | 3.9.1 | Primitives cryptographiques |
| flutter_secure_storage | 10.0.0 | Stockage sécurisé |
| local_auth | 3.0.0 | Biométrie |
| freerasp | 6.12.0 | Anti-tampering |

- Signature APK obligatoire en release (le build échoue sans keystore de production)
- Obfuscation du code activée à chaque build release (`--obfuscate --split-debug-info`)

---

### Journal d'Audit Anti-Falsification

**Événements de sécurité enregistrés automatiquement :**
- Connexion SSH (succès ou échec)
- Déconnexion / reconnexion SSH
- Échec d'authentification
- Import / suppression de clé SSH
- Création / suppression de PIN
- Changement d'empreinte de serveur
- Tentatives de connexion répétées (rate limiting)

**Intégrité du journal :**
- Chaque entrée est chaînée avec un hash SHA-256 de l'entrée précédente
- Toute falsification d'une entrée rend invalides toutes les entrées suivantes
- Méthode `verifyIntegrity()` disponible pour contrôler l'intégrité de la chaîne

**Stockage :**
- Chiffré dans le stockage sécurisé
- Limité à 500 entrées avec rotation automatique

---

### Wake-on-LAN

- WOL acheminé en priorité via **Tailscale (WireGuard chiffré)**
- Évite l'exposition des paquets magiques UDP en clair sur le réseau local
- Fallback sur broadcast UDP uniquement si Tailscale n'est pas configuré

---

### Transferts de Fichiers SFTP

- **30 Mo maximum par fichier**
- Transfert par streaming (morceaux) — prévient les attaques par saturation mémoire
- Validation des chemins distants — détecte les tentatives de traversée de répertoire (`../`)

---

### Import de Clés SSH

- Validation du format avant import
- **Limite de 16 Ko** (une clé SSH normale fait moins de 5 Ko)
- Fichiers anormalement gros bloqués (prévient les injections)
- Clé importée immédiatement transférée dans le stockage sécurisé

---

### Intégration Tailscale

- **URLs OAuth :** jamais loguées en clair
- **Clés publiques :** tronquées dans les logs (16 premiers caractères seulement)
- **Messages d'erreur :** génériques, ne divulguent pas de détails techniques
- **Validation d'URL :** schéma HTTPS uniquement
- **Code mort supprimé :** tout le code de stockage de tokens Tailscale côté Dart supprimé

---

### Permissions

**Android :**
- Permissions minimales demandées (réseau, capteur biométrique, stockage local)
- **Sauvegarde ADB désactivée** (`allowBackup=false`) — empêche l'extraction de données
- Services marqués comme non exportés
- Service VPN Tailscale protégé par permissions système

**iOS :**
- Données sensibles dans le Keychain iOS (protection matérielle)
- Écran de confidentialité auto-activé en arrière-plan

---

### Architecture Sécurisée

- Toutes les opérations SSH exécutées dans un **isolate Dart séparé** (isolation thread)
- IDs de requête : **UUID v4 cryptographiquement aléatoires** (imprévisibles)
- Zéro `debugPrint` en production — tous les logs passent par le **SecureLogger** qui filtre automatiquement les secrets et ne produit rien en release
- Roadmap **post-quantique** documentée (migration X25519-Kyber768 prévue quand dartssh2 le supporte)

---

## ⚠️ Limitations Connues (Documentées et Acceptées)

| Limitation | Explication | Impact |
|------------|-------------|--------|
| **GC Dart et mémoire** | Le ramasse-miettes Dart peut conserver des copies temporaires de données en mémoire. | **Faible.** Nécessite un appareil rooté avec accès mémoire direct. Mitigé par SecureKeyHolder (Uint8List + zeroing). |
| **Détection root contournable** | Des outils comme Magisk Hide peuvent masquer le root à freeRASP. | **Faible.** La mesure est informative. freeRASP détecte les vecteurs les plus courants. |
| **Clé Ed25519 non chiffrée au repos** | Les clés générées utilisent `cipher=none` dans leur format PEM. | **Acceptable** tant que la clé reste dans le stockage sécurisé chiffré. |

---

## 🚨 Signaler une Vulnérabilité

**Nous prenons la sécurité au sérieux, mais comprenez nos limites en tant que projet bénévole.**

### Procédure de Divulgation Responsable

**Si vous découvrez une vulnérabilité de sécurité :**

1. **🚫 N'OUVREZ PAS d'issue publique sur GitHub**
   - Cela mettrait immédiatement tous les utilisateurs en danger
   - Les attaquants pourraient exploiter la faille avant le correctif

2. **📧 Envoyez un email privé à :**
   - **Chill_app@outlook.fr**
   - Sujet : `[SECURITY] Vulnérabilité dans ChillShell`

3. **📋 Incluez dans votre email :**
   - **Description :** Nature de la vulnérabilité
   - **Reproduction :** Étapes détaillées pour reproduire (PoC)
   - **Impact :** Gravité et conséquences possibles (score CVSS si possible)
   - **Preuve de concept :** Code ou démonstration (si applicable)
   - **Environnement :** Versions affectées (version ChillShell, version Android/iOS)
   - **Suggestions :** Correctif proposé (optionnel mais apprécié)
   - **Crédit :** Comment vous souhaitez être crédité

### Délais et Attentes

| Étape | Délai estimé |
|-------|-------------|
| Accusé de réception | 48–72 heures |
| Analyse initiale | 2–6 jours |
| Correctif Critique | 1–2 jours |
| Correctif Élevé | 3–4 jours |
| Correctif Moyen/Faible | 1 semaine |
| Divulgation publique | Coordonnée après le correctif (max 90 jours) |

**Ce que vous NE pouvez PAS attendre :**
- 💰 **Bug bounty :** Projet gratuit open source, pas de budget
- ⚡ **SLA garantis :** Équipe bénévole
- 👔 **Support professionnel :** 1 développeur

### Crédit et Reconnaissance Publique

Si vous signalez une vulnérabilité de manière responsable, vous serez remercié publiquement (si vous le souhaitez) dans :
- Ce fichier (Hall of Fame ci-dessous)
- Le CHANGELOG
- Les release notes du correctif

---

## 🏆 Hall of Fame — Chercheurs en Sécurité

Ces personnes ont aidé à sécuriser ChillShell en signalant des vulnérabilités de manière responsable :

*(Aucune contribution pour le moment — soyez le premier !)*

**Format :**
- **Nom/Pseudo** — Description — Gravité — Date — CVE (si applicable)

---

## 📚 Ressources de Sécurité

### Sécurité SSH :
- [Guide officiel OpenSSH](https://www.openssh.com/security.html)
- [Guide de Durcissement SSH](https://www.ssh.com/academy/ssh/security)

### Sécurité Tailscale :
- [Modèle de Sécurité Tailscale](https://tailscale.com/security)
- [Chiffrement Tailscale (WireGuard)](https://tailscale.com/blog/how-tailscale-works/)

### Sécurité Mobile :
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Meilleures Pratiques Sécurité Android](https://developer.android.com/topic/security/best-practices)
- [Android Keystore](https://developer.android.com/training/articles/keystore)
