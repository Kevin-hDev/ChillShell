# Politique de Sécurité

## 🔒 Travail de Sécurité Réalisé

ChillShell a fait l'objet d'une **validation de sécurité interne approfondie** avant publication.

### Audits de Sécurité Réalisés

**Trois audits internes successifs + audit qualité :**

1. **Audit de Sécurité White-box** (Version 1.5.1)
   - Évaluation initiale de la sécurité
   - 9 correctifs critiques appliqués
   - Score de sécurité amélioré (auto-évalué) : **6.5 → 8.5/10**

2. **Modélisation des Menaces STRIDE**
   - 22 menaces identifiées
   - 8 risques validés
   - **12 mitigations implémentées à 100%**

3. **Audit de Sécurité Ultra-Granulaire** (méthodologie Trail of Bits)
   - **4 agents IA spécialisés en parallèle** (Claude Opus 4.6, Gemini 3 PRO, Kimi K2.5)
   - 44 fichiers analysés (~7 500 lignes de code critique)
   - **62 findings :** 4 Critiques, 8 Élevés, 21 Moyens, 21 Faibles, 8 confirmations
   - **Verdict : 0 vulnérabilité exploitable à distance identifiée**

4. **Audit Qualité de la Codebase**
   - 83 fichiers (~24 000 lignes de code)
   - 4 bugs critiques corrigés
   - Code mort supprimé
   - Refactoring appliqué
   - **92 tests unitaires qui passent**

### Ce Que Cela Signifie

- ✅ Méthodologie de sécurité professionnelle appliquée (protocole Trail of Bits)
- ✅ Aucune vulnérabilité exploitable à distance trouvée
- ✅ Tous les problèmes identifiés corrigés ou documentés
- ✅ Score de sécurité interne (auto-évalué) : **8.5/10**

---

## 🛡️ Mesures de Sécurité Implémentées

### Stockage Sécurisé

Toutes les données sensibles sont stockées via **Flutter Secure Storage** :
- **Android :** Chiffrement AES-CBC via Android Keystore
- **iOS :** iOS Keychain avec protection matérielle

**Données protégées :**
- Clés SSH privées (chiffrées au repos)
- Code PIN (hashé avec PBKDF2-HMAC-SHA256, 100 000 itérations + salt aléatoire 32 octets)
- Empreintes des serveurs SSH (pour vérification TOFU)
- Journal d'audit (chiffré)
- Configurations Wake-on-LAN
- Historique des commandes (après filtrage des commandes sensibles)

**Zéro secret hardcodé** dans le code source (vérifié par scan complet de la codebase).

---

### Authentification Locale

**Code PIN :**
- Minimum 8 chiffres (100 millions de combinaisons)
- Hashé avec **PBKDF2-HMAC-SHA256** (100 000 itérations)
- **Comparaison en temps constant** (XOR bit à bit) prévient les attaques par timing
- **Rate limiting :** 5 tentatives → 30s de verrouillage, backoff exponentiel (max 300s)
- Jamais stocké en clair, jamais conservé en mémoire au-delà du temps de traitement

**Authentification Biométrique :**
- API système native (empreinte digitale, Face ID)
- Données biométriques ne quittent jamais l'appareil
- Mode strict : biométrie uniquement (pas de fallback vers PIN système)
- Auto-invalidée lorsque l'app passe en arrière-plan

**Verrouillage Automatique :**
- Timeout configurable : 5, 10, 15 ou 30 minutes
- Déclenché lorsque l'app reste en arrière-plan au-delà du délai choisi
- Écran de chargement au démarrage empêche le contournement temporaire

---

### Sécurité des Connexions SSH

**TOFU (Trust On First Use) - Durci :**
- Empreinte SHA-256 du serveur affichée à la première connexion
- Confirmation manuelle de l'utilisateur requise
- Empreinte stockée dans le stockage sécurisé
- **Comparaison en temps constant** lors des connexions suivantes
- **Alerte rouge** si l'empreinte change (avertissement MITM)

**Protocole & Chiffrement :**
- Protocole SSH2 (bibliothèque dartssh2)
- Algorithme de clé préféré : **Ed25519**
- Communications chiffrées de bout en bout

**Gestion des Clés en Mémoire :**
- Clés privées chargées dans un **SecureBuffer** dédié
- **Zeroing explicite** après utilisation (limite la fenêtre d'exposition)
- Le worker SSH ne conserve pas les clés entre les connexions
- Opérations cryptographiques exécutées dans un **isolate Dart séparé** (isolation thread d'arrière-plan)

**Génération de Clés :**
- Clés Ed25519 générées localement sur l'appareil
- Octets de la clé privée **effacés de la mémoire** après stockage
- Clé publique séparée de la clé privée dans le modèle de données
- Sérialisation JSON **exclut explicitement la clé privée**

---

### Protection Contre les Fuites de Données

**Filtrage de l'Historique des Commandes :**
- Filtrage automatique par regex exclut les secrets de l'historique :
  - Clés AWS, tokens JWT/Bearer, clés API
  - Mots de passe en ligne de commande
  - Variables contenant des mots-clés sensibles (SECRET, TOKEN, KEY, PASSWORD)
- Expiration automatique : entrées de plus de 90 jours supprimées
- L'utilisateur peut effacer manuellement l'historique complet

**Logs de Production :**
- Tous les appels debug conditionnés par le mode debug Flutter
- **En production (APK release) : zéro log émis**
- Aucun hostname, adresse IP ou identifiant dans les logs de production
- Audit confirmé que les 188 occurrences de logs sont toutes protégées
- Logs du moteur Go Tailscale également filtrés (tokens OAuth, URLs d'auth)

**Presse-papiers :**
- **Auto-vidé 30 secondes** après copie de données sensibles
- **Vidé silencieusement** lorsque l'app passe en arrière-plan (empêche les apps malveillantes de lire)

---

### Protection d'Écran

**Android :**
- **FLAG_SECURE** activé par défaut
- Bloque les captures d'écran et l'enregistrement d'écran
- L'app n'apparaît pas dans le sélecteur d'apps récentes (écran noir affiché)
- Désactivable par l'utilisateur dans les réglages

**iOS :**
- Écran de masquage affiché automatiquement lorsque l'app passe en arrière-plan
- Empêche la capture du contenu dans le sélecteur d'apps
- Désactivable par l'utilisateur dans les réglages

---

### Détection d'Appareil Compromis

- Vérification au démarrage des appareils rootés (Android) ou jailbreakés (iOS)
- Recherche de chemins/fichiers caractéristiques (su, Superuser.apk, Cydia.app, etc.)
- **Bannière d'avertissement** si détecté (informatif, non bloquant)
- L'utilisateur peut choisir de continuer en toute connaissance de cause

---

### Journal d'Audit

**Événements de sécurité enregistrés automatiquement :**
- Connexion SSH (succès ou échec)
- Déconnexion/reconnexion SSH
- Échec d'authentification
- Import/suppression de clé SSH
- Création/suppression de PIN
- Changement d'empreinte de serveur

**Stockage :**
- Chiffré dans le stockage sécurisé
- Format JSON compact avec horodatages
- Limité à 500 entrées avec rotation automatique

---

### Transferts de Fichiers SFTP

- **30 Mo maximum par fichier**
- Transfert par streaming (morceaux, pas de chargement complet en mémoire) prévient les attaques par saturation mémoire
- Validation des chemins distants détecte les tentatives de traversée de répertoire

---

### Import de Clés SSH

- Validation du format avant import
- **Limite de 16 Ko** (une clé SSH normale < 5 Ko)
- Fichiers anormalement gros bloqués (prévient les injections)
- Clé importée immédiatement transférée dans le stockage sécurisé

---

### Intégration Tailscale

Mesures spécifiques à la sécurité :
- **URLs OAuth :** jamais loguées en clair (seule la longueur loguée en debug)
- **Clés publiques :** tronquées dans les logs (16 premiers caractères seulement)
- **Messages d'erreur :** génériques, ne divulguent pas de détails techniques
- **Validation d'URL :** seul le schéma HTTPS accepté
- **Code mort supprimé :** tout le code de stockage de tokens Tailscale côté Dart supprimé

---

### Permissions

**Android :**
- Permissions minimales demandées (réseau, capteur biométrique, stockage local)
- **Sauvegarde ADB désactivée** (allowBackup=false) empêche l'extraction de données
- Services marqués comme non exportés
- Service VPN Tailscale protégé par permissions système

**iOS :**
- Données sensibles dans le Keychain iOS (protection matérielle)
- Écran de confidentialité auto-activé en arrière-plan

---

### Architecture Isolate

- Opérations cryptographiques SSH exécutées dans un **isolate Dart séparé**
- Avantages : UI reste réactive, traitement des clés isolé du reste de l'app
- IDs de requête utilisent des **UUID v4 cryptographiquement aléatoires** (imprévisibles)

---

### Internationalisation

- Tous les messages d'erreur et UI traduits en 5 langues (FR, EN, ES, DE, ZH)
- Aucune chaîne sensible hardcodée dans le code source
- Messages d'erreur SSH utilisent des codes traduits dans l'UI

---

## ⚠️ Limitations Connues (Documentées et Acceptées)

| Limitation | Explication | Impact |
|------------|-------------|--------|
| **Clé privée en String Dart** | Le type String Dart est immutable. La clé privée peut rester temporairement en mémoire jusqu'au passage du ramasse-miettes. | **Faible.** Nécessite un appareil rooté avec accès mémoire. Mitigé par la lecture depuis le stockage sécurisé à chaque connexion. |
| **SecureBuffer et GC** | Le ramasse-miettes Dart peut créer des copies temporaires des données en mémoire. | **Faible.** Même prérequis que ci-dessus. |
| **Détection root contournable** | Des outils comme Magisk Hide peuvent masquer le root de l'appareil. | **Faible.** La mesure est informative, pas préventive. |
| **Clé Ed25519 non chiffrée au repos** | Les clés générées utilisent cipher=none dans leur format. | **Acceptable** tant que la clé reste dans le stockage sécurisé (chiffré par AES/Keychain). Si l'export est prévu à l'avenir, un chiffrement AES-256-CTR sera ajouté. |
| **SharedPreferences pour le PIN** | Le hash et le salt du PIN sont dans SharedPreferences (accessible sans root mais protégés par PBKDF2). | **Mitigé.** Le brute force offline est rendu impraticable par les 100 000 itérations PBKDF2. |

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
   - **Environnement :** Versions affectées (version ChillShell, version Android)
   - **Suggestions :** Correctif proposé (optionnel mais apprécié)
   - **Crédit :** Comment vous souhaitez être crédité (voir ci-dessous)

### Délais et Attentes

**Ce que vous pouvez attendre :**
- ⏱️ **Accusé de réception :** 48-72 heures (meilleur effort)
- 🔍 **Analyse initiale :** 2-6 jours
- 🛠️ **Correctif :** Selon gravité et complexité
  - **Critique :** 1-2 jours
  - **Élevé :** 3-4 jours
  - **Moyen/Faible :** 1 semaine
- 📢 **Divulgation publique :** Coordonnée avec vous après le correctif

**Ce que vous NE pouvez PAS attendre :**
- 💰 **Bug bounty :** Nous n'avons pas de budget (projet gratuit open source)
- ⚡ **SLA garantis :** Projet bénévole, pas de délais contractuels
- 👔 **Support professionnel :** Équipe de sécurité limitée (1 personne)

### Crédit et Reconnaissance Publique

**Qu'est-ce que le "crédit" ?**

Si vous trouvez une vulnérabilité et nous la signalez de manière responsable, nous vous remercierons publiquement (si vous le souhaitez).

**Options :**

**Option 1 : Reconnaissance Publique** (par défaut)
- ✅ Votre nom/pseudo mentionné dans :
  - SECURITE.md (Hall of Fame)
  - CHANGELOG.md
  - Release notes du correctif
  - Potentiellement sur les réseaux sociaux
- ✅ Bon pour votre réputation professionnelle
- ✅ Peut être ajouté sur votre CV/LinkedIn

**Option 2 : Anonyme**
- ✅ Vulnérabilité corrigée sans mention publique de qui l'a trouvée
- ✅ Votre identité reste privée

**Choisissez l'option que vous préférez dans votre email.**

### Divulgation Coordonnée

Nous suivons la **divulgation coordonnée** :

1. Vous nous signalez la vulnérabilité en privé
2. Nous travaillons sur un correctif
3. Nous vous tenons au courant de l'avancement
4. Une fois le correctif déployé et les utilisateurs notifiés
5. Nous publions les détails de la vulnérabilité (CVE si applicable)
6. Vous êtes crédité publiquement (si souhaité)

**Délai standard :** 90 jours maximum entre la découverte et la divulgation publique (suivant les pratiques de Google Project Zero).

---

## 🏆 Hall of Fame - Chercheurs en Sécurité

Ces personnes ont aidé à sécuriser ChillShell en signalant des vulnérabilités de manière responsable :

*(Aucune contribution pour le moment - soyez le premier !)*

**Format :**
- **Nom/Pseudo** - Description de la vulnérabilité - Gravité (Critique/Élevée/Moyenne/Faible) - Date - CVE (si applicable)

**Exemple :**
- **John Doe** - Injection SQL dans le gestionnaire de connexions - Élevée - 2026-03-15 - CVE-2026-12345

---

## 📚 Ressources de Sécurité

### Sécurité SSH :
- [Guide officiel OpenSSH](https://www.openssh.com/security.html)
- [Guide de Durcissement SSH](https://www.ssh.com/academy/ssh/security)
- [Guide NIST SSH](https://nvlpubs.nist.gov/nistpubs/ir/2015/NIST.IR.7966.pdf)

### Sécurité Tailscale :
- [Modèle de Sécurité Tailscale](https://tailscale.com/security)
- [Guide ACL Tailscale](https://tailscale.com/kb/1018/acls/)
- [Chiffrement Tailscale](https://tailscale.com/blog/how-tailscale-works/)

### Sécurité Android :
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Meilleures Pratiques Sécurité Android](https://developer.android.com/topic/security/best-practices)
- [Système Android Keystore](https://developer.android.com/training/articles/keystore)

### Sécurité Flutter/Dart :
- [Meilleures Pratiques Sécurité Flutter](https://flutter.dev/docs/deployment/security)
- [Sécurité Dart](https://dart.dev/guides/security)

---

**Dernière mise à jour :** Février 2026  
**Version de cette politique :** 2.0
