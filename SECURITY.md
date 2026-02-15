# Politique de Sécurité

## ⚠️ STATUT DU PROJET - LISEZ ATTENTIVEMENT

**Ce projet est en phase ALPHA et N'A PAS reçu d'audit de sécurité professionnel.**

### Processus de Développement

**Comment ce projet a été créé :**
- 🤖 Développé avec assistance de l'IA Claude Code (Anthropic)
- 👨‍💻 Par un non-développeur professionnel
- 🔍 Analyse de sécurité interne utilisant :
  - Modélisation des menaces STRIDE
  - Trail of Bits Security Skills (audit ligne par ligne)
  - **62 findings identifiés et corrigés** (4 Critical, 8 High, 21 Medium, 21 Low)
  - Scan automatique de vulnérabilités
  - Tests de sécurité automatisés

**Ce qui N'A PAS été fait :**
- ❌ Aucun test de pénétration (pentest) externe
- ❌ Aucune revue de code par des experts en sécurité professionnels
- ❌ Aucun audit de sécurité payant
- ❌ Aucune certification de sécurité
- ❌ Aucun fuzzing des parsers (SSH, terminal)
- ❌ Aucun test de charge / DoS

## 🎯 Surface d'Attaque et Risques

Cette application fournit un **accès SSH distant complet** à votre ordinateur via l'application mobile **ChillShell** qui se connecte à l'application desktop **Chill**.

### Architecture de Sécurité

```
┌──────────────────┐         SSH         ┌──────────────────┐
│  ChillShell      │ ◄──────────────────► │  Chill Desktop   │
│  (Mobile)        │   Chiffré via       │  (PC)            │
│                  │   Tailscale VPN      │                  │
│  Vecteurs:       │                      │  Vecteurs:       │
│  • App Android   │                      │  • SSH Server    │
│  • Stockage clés │                      │  • Tailscale     │
│  • Parser SSH    │                      │  • Wake-on-LAN   │
│  • Terminal UI   │                      │  • Config Files  │
└──────────────────┘                      └──────────────────┘
```

### Vecteurs d'Attaque Possibles

#### 1. Vulnérabilités dans ChillShell (App Android)
   - Bugs dans le code de l'application
   - Mauvaise gestion des clés SSH privées (stockage, mémoire)
   - Failles dans le parser SSH/terminal
   - Stockage non sécurisé de données sensibles
   - Injection de commandes shell
   - Path traversal lors de la navigation de dossiers
   - Root/Jailbreak detection bypassable

#### 2. Compromission du réseau Tailscale
   - Dépendance totale sur la sécurité de Tailscale
   - Si Tailscale est compromis, l'accès est ouvert
   - Configuration ACL incorrecte
   - Man-in-the-Middle sur le VPN (théorique)

#### 3. Vulnérabilités SSH
   - Mauvaise configuration SSH sur le PC
   - Clés faibles ou compromises
   - TOFU (Trust On First Use) bypass
   - Fingerprint spoofing

#### 4. Chaîne d'approvisionnement (Supply Chain)
   - Dépendances tierces avec vulnérabilités (dartssh2, xterm, etc.)
   - Bibliothèques Android compromises
   - Updates malveillants via pub.dev
   - Fork GitHub malveillant

#### 5. Configuration utilisateur
   - Permissions trop larges
   - Clés SSH partagées entre devices
   - Mots de passe faibles (si utilisés malgré les recommandations)
   - Pare-feu désactivé
   - Root SSH enabled

#### 6. Wake-on-LAN
   - Paquet magique intercepté/spoofé
   - Réveil non autorisé de la machine
   - DoS par réveil répétitif

#### 7. Application Desktop Chill
   - Vulnérabilités dans l'empaquetage Tailscale/SSH/WOL
   - Mauvaise isolation des services
   - Élévation de privilèges

### Impact Potentiel d'une Faille

Si une vulnérabilité est exploitée, un attaquant pourrait :

- 💀 **Accès système complet** : Contrôle total de votre ordinateur
- 📁 **Vol de fichiers** : Tous vos documents, photos, vidéos
- 🔑 **Vol de credentials** : Mots de passe, clés SSH, tokens, cookies de session
- 💳 **Données bancaires** : Si stockées sur le PC
- 🎥 **Surveillance** : Activer webcam, micro, keylogger
- 💾 **Ransomware** : Chiffrer vos données et demander une rançon
- 🗑️ **Destruction** : Supprimer tous vos fichiers
- 🌐 **Pivot** : Utiliser votre PC pour attaquer d'autres systèmes de votre réseau
- 🔓 **Backdoor persistant** : Installer un accès permanent

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
   - **Description** : Nature de la vulnérabilité
   - **Reproduction** : Étapes détaillées pour reproduire (PoC)
   - **Impact** : Gravité et conséquences possibles (CVSS score si possible)
   - **Preuve de concept** : Code ou démonstration (si applicable)
   - **Environnement** : Versions affectées (ChillShell version, Android version)
   - **Suggestions** : Correctif proposé (optionnel mais apprécié)
   - **Crédit** : Comment vous souhaitez être crédité (voir ci-dessous)

### Délais et Attentes

**Ce que vous pouvez attendre :**
- ⏱️ **Accusé de réception** : 48-72 heures (meilleur effort)
- 🔍 **Analyse initiale** : 3-7 jours
- 🛠️ **Correctif** : Selon gravité et complexité
  - **Critique** : 1-2 semaines
  - **Haute** : 2-4 semaines
  - **Moyenne/Basse** : 4-8 semaines
- 📢 **Divulgation publique** : Coordonnée avec vous après le correctif

**Ce que vous NE pouvez PAS attendre :**
- 💰 **Bug bounty** : Nous n'avons pas de budget (projet gratuit open source)
- ⚡ **SLA garantis** : Projet bénévole, pas de délais contractuels
- 👔 **Support professionnel** : Équipe de sécurité limitée (1 personne)

### Crédit et Reconnaissance Publique

**Qu'est-ce que le "crédit" ?**

Si vous trouvez une vulnérabilité et nous la signalez de manière responsable, nous vous remercierons publiquement (si vous le souhaitez).

**Options :**

**Option 1 : Reconnaissance Publique** (par défaut)
- ✅ Votre nom/pseudo mentionné dans :
  - SECURITY.md (Hall of Fame)
  - CHANGELOG.md
  - Release notes du correctif
  - Potentiellement sur les réseaux sociaux
- ✅ Bon pour votre réputation professionnelle
- ✅ Peut être ajouté sur votre CV/LinkedIn

**Option 2 : Anonyme**
- ✅ Vulnérabilité corrigée sans mention publique de qui l'a trouvée
- ✅ Votre identité reste privée

**Choisissez l'option que vous préférez dans votre email.**

### Coordinated Disclosure

Nous suivons la **divulgation coordonnée** :

1. Vous nous signalez la vulnérabilité en privé
2. Nous travaillons sur un correctif
3. Nous vous tenons au courant de l'avancement
4. Une fois le correctif déployé et les utilisateurs notifiés
5. Nous publions les détails de la vulnérabilité (CVE si applicable)
6. Vous êtes crédité publiquement (si souhaité)

**Délai standard :** 90 jours maximum entre la découverte et la divulgation publique (suivant les pratiques de Google Project Zero).

## 🛡️ Bonnes Pratiques de Sécurité

### Pour les Utilisateurs

**AVANT d'installer :**

1. ✅ **Comprenez les risques** - Relisez tous les avertissements dans le README
2. ✅ **Examinez le code** - Ou faites-le examiner par quelqu'un de compétent
3. ✅ **Sauvegardez tout** - Système complet et données importantes
4. ✅ **Préparez un plan B** - Comment récupérer si ça tourne mal

**Configuration SÉCURISÉE :**

5. ✅ **Utilisez Chill Desktop** - Package sécurisé Tailscale + SSH + WOL
6. ✅ **Clés ED25519 uniquement** - JAMAIS de mots de passe SSH
   ```bash
   # Générez une clé depuis ChillShell ou votre PC
   ssh-keygen -t ed25519 -C "ChillShell"
   ```
7. ✅ **Configuration SSH durcie** :
   ```bash
   # /etc/ssh/sshd_config
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   MaxAuthTries 3
   LoginGraceTime 30
   X11Forwarding no
   ```
8. ✅ **ACL Tailscale restrictives** - Limitez qui peut se connecter :
   ```json
   {
     "acls": [
       {
         "action": "accept",
         "src": ["tag:mobile"],
         "dst": ["tag:desktop:22"]
       }
     ]
   }
   ```
9. ✅ **Pare-feu actif** - Même avec Tailscale (defense in depth)
10. ✅ **Utilisateur dédié** - Pas votre compte principal
    ```bash
    sudo useradd -m -s /bin/bash chillshell
    # Ne pas ajouter à sudo sauf si strictement nécessaire
    ```

**Surveillance ACTIVE :**

11. ✅ **Surveillez les logs SSH** régulièrement
    ```bash
    sudo tail -f /var/log/auth.log  # Linux
    log show --predicate 'process == "sshd"' --info  # macOS
    ```
12. ✅ **Vérifiez les connexions** actives
    ```bash
    who       # Utilisateurs connectés
    last      # Historique connexions
    ss -tnp   # Connexions TCP actives
    ```
13. ✅ **Alertes automatiques** - Configurez des notifications pour :
    - Connexions SSH réussies
    - Tentatives échouées répétées (> 3 en 5 min)
    - Modifications de fichiers système (auditd)
14. ✅ **Audits réguliers** :
    ```bash
    sudo aureport -au  # Événements d'authentification (Linux)
    sudo fail2ban-client status sshd  # Bannissements actifs
    ```

**Mises à jour OBLIGATOIRES :**

15. ✅ **Maintenez à jour** :
    - ChillShell (vérifiez GitHub régulièrement)
    - Chill Desktop
    - Tailscale
    - OpenSSH
    - Système d'exploitation Android
    - Système d'exploitation PC
16. ✅ **Surveillez les security advisories** :
    - [ChillShell Releases](https://github.com/Kevin-hdev/ChillShell/releases)
    - [GitHub Security Advisories](https://github.com/Kevin-hdev/ChillShell/security/advisories)

**TESTEZ en environnement SAFE :**

17. ✅ **Commencez sur un système de test** :
    - Pas votre PC principal
    - Pas de données sensibles
    - Environnement isolé (VM recommandée)
18. ✅ **Ne passez en production QUE si** :
    - Aucun problème après 2+ semaines de tests
    - Vous comprenez totalement comment ça fonctionne
    - Vous avez un plan de réponse aux incidents

### Pour les Contributeurs

**Si vous contribuez au code :**

1. ✅ **Security-first mindset** - Pensez sécurité avant fonctionnalités
2. ✅ **Validez toutes les entrées** - Ne faites jamais confiance aux données utilisateur
3. ✅ **Principe du moindre privilège** - Demandez le minimum de permissions
4. ✅ **Gestion sécurisée des secrets** :
   - Jamais de clés en dur dans le code
   - Utilisez FlutterSecureStorage (EncryptedSharedPreferences)
   - Chiffrez les données sensibles au repos
   - Effacez les secrets de la mémoire après usage (SecureBuffer)
5. ✅ **Dépendances à jour** - Scannez les CVE connues :
   ```bash
   flutter pub outdated
   dart pub global activate pana && pana .
   ```
6. ✅ **Revue de code** - Faites relire votre code par d'autres
7. ✅ **Tests de sécurité** - Ajoutez des tests pour les cas limites :
   - Path traversal (`../../etc/passwd`)
   - Shell injection (`` `rm -rf /` ``)
   - Constant-time comparison
8. ✅ **Documentation** - Documentez les implications sécurité de vos changements

## 🔍 Limitations Connues

### Risques Acceptés (Non Corrigés)

Ces limitations sont connues mais acceptées pour des raisons de complexité/performance :

- **M7** : Longueur du PIN stockée en clair (impact mineur)
- **M10** : Pas d'HMAC sur audit log (complexité vs. bénéfice)
- **M12** : SecureBuffer limité par GC Dart (limitation inhérente du langage)
- **M18** : `security-crypto:1.1.0-alpha06` non stable (version stable trop ancienne)

### Ce Que ChillShell NE Protège PAS

- ❌ **Malware sur votre PC** : Si votre PC est déjà compromis, ChillShell ne peut rien faire
- ❌ **Phishing** : Si vous donnez vos clés à un attaquant, il peut se connecter
- ❌ **Device volé déverrouillé** : Si votre téléphone est volé et déverrouillé, l'attaquant a accès
- ❌ **Forensics avancée** : Un attaquant avec accès physique à votre device peut extraire des clés de la RAM
- ❌ **Backdoor Tailscale/SSH** : Si Tailscale ou OpenSSH ont une backdoor, ChillShell est compromis

## 📚 Ressources de Sécurité

### Pour en savoir plus sur la sécurité SSH :

- [Guide officiel OpenSSH](https://www.openssh.com/security.html)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/security)
- [NIST Guide to SSH](https://nvlpubs.nist.gov/nistpubs/ir/2015/NIST.IR.7966.pdf)

### Sécurité Tailscale :

- [Tailscale Security Model](https://tailscale.com/security)
- [Tailscale ACL Guide](https://tailscale.com/kb/1018/acls/)
- [Tailscale Encryption](https://tailscale.com/blog/how-tailscale-works/)

### Sécurité Android :

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)

### Sécurité Flutter/Dart :

- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)
- [Dart Security](https://dart.dev/guides/security)

## 🏆 Hall of Fame - Chercheurs en Sécurité

Ces personnes ont aidé à sécuriser ChillShell en signalant des vulnérabilités :

*(Aucune contribution pour le moment - soyez le premier !)*

**Format :**
- **Nom/Pseudo** - Description de la vulnérabilité - Gravité (Critical/High/Medium/Low) - Date - CVE (si applicable)

**Exemple :**
- **John Doe** - SQL Injection dans le gestionnaire de connexions - High - 2026-03-15 - CVE-2026-12345

---

## ⚖️ Clause de Non-Responsabilité Légale

**CE LOGICIEL EST FOURNI "TEL QUEL", SANS GARANTIE D'AUCUNE SORTE, EXPRESSE OU IMPLICITE.**

Les auteurs et contributeurs :
- ❌ Ne garantissent PAS que le logiciel est exempt de bugs ou de vulnérabilités
- ❌ Ne sont PAS responsables des dommages, pertes de données, violations de sécurité
- ❌ N'offrent AUCUNE garantie de support ou de correctifs
- ❌ Ne peuvent être tenus responsables en cas de compromission de votre système

**EN UTILISANT CE LOGICIEL, VOUS ACCEPTEZ D'ASSUMER TOUS LES RISQUES.**

Si vous n'êtes pas à l'aise avec ce niveau de risque, **N'UTILISEZ PAS ce logiciel.**

---

**Dernière mise à jour : [Sera complété lors de la publication]**

**Version de cette politique : 1.0**
