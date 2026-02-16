# ⚠️ AVERTISSEMENT DE SÉCURITÉ - LISEZ CECI AVANT D'INSTALLER

## 🔒 Sécurité : Un Travail Sérieux A Été Fait

**AVANT de vous alarmer**, sachez que ChillShell a fait l'objet d'un **travail de sécurité approfondi** :

- ✅ 3 audits internes successifs + audit qualité
- ✅ Score sécurité selon nous **8.5/10** (amélioré depuis 6.5)
- ✅ **62 findings corrigés** (4 Critiques, 8 Élevés, 21 Moyens, 21 Faibles)
- ✅ **0 vulnérabilité exploitable à distance identifiée**
- ✅ 92 tests unitaires qui passent

**📖 Consultez [SECURITE.md](SECURITE.md) pour voir TOUTES les mesures de sécurité implémentées.**

---

## ⚠️ MAIS Ce Projet Reste en Phase ALPHA

### Ce qui N'A PAS été fait

Malgré le travail réalisé, ce projet **N'A PAS reçu** :

- ❌ Audit de sécurité professionnel externe payant
- ❌ Test de pénétration (pentest) par des experts
- ❌ Revue de code par des professionnels en sécurité
- ❌ Certification de sécurité
- ❌ Fuzzing des parsers (SSH, terminal)
- ❌ Tests de charge / DoS

### Comment ce projet a été créé

- 🤖 Développé avec assistance de l'IA Claude Code Opus 4.6, et Gemini 3 PRO & Kimi K2.5 en support
- 👨‍💻 Par un **non-développeur professionnel** (ancien manager)
- 🔍 Audit de sécurité **interne** (pas externe)

---

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

### Scénarios de Menace (Si Nos Protections Étaient Contournées)

Ces scénarios représentent ce qui POURRAIT arriver **SI** un attaquant découvrait une vulnérabilité **ET** parvenait à contourner nos protections. Chacun nécessite de franchir plusieurs couches de sécurité :

#### 🔐 Vol de Clé SSH Privée
**Ce qui serait nécessaire :**
- Contourner le chiffrement AES-CBC du Android Keystore
- Extraire la mémoire d'un appareil rooté
- Surmonter le zeroing SecureBuffer et l'isolation mémoire (Dart isolate)

**Nos protections :** Flutter Secure Storage (AES/Keychain), zeroing explicite de la mémoire, clés jamais mises en cache entre les connexions

#### 📦 Injection de Commandes
**Ce qui serait nécessaire :**
- Contourner la validation des entrées et la sanitization des chemins
- Exploiter le parser SSH/terminal
- Contourner le filtrage des commandes sensibles (clés AWS, tokens, mots de passe)

**Nos protections :** Validation des entrées, détection path traversal, filtrage historique commandes avec regex

#### 🔓 Brute Force du PIN
**Ce qui serait nécessaire :**
- Contourner le rate limiting (5 tentatives → 30s de verrouillage, backoff exponentiel max 300s)
- Casser PBKDF2 offline (100 000 itérations)
- Surmonter la comparaison en temps constant

**Nos protections :** PBKDF2-HMAC-SHA256 (100k itérations) + salt unique 32 octets, rate limiting, comparaison XOR en temps constant

#### 🎭 Attaque Man-in-the-Middle SSH
**Ce qui serait nécessaire :**
- L'utilisateur doit ignorer l'alerte rouge de changement d'empreinte
- Contourner la comparaison en temps constant de l'empreinte
- Compromettre le mécanisme TOFU (Trust On First Use)

**Nos protections :** TOFU durci avec confirmation manuelle, alerte rouge MITM, comparaison temps constant, empreintes stockées dans stockage sécurisé

#### 🗂️ Path Traversal (Navigation Dossiers)
**Ce qui serait nécessaire :**
- Contourner la validation des chemins distants
- Exploiter le navigateur de dossiers pour accéder à `../../etc/passwd`

**Nos protections :** Validation des chemins, détection `..` dans uploads SFTP

#### 🔍 Exploitation Root/Jailbreak
**Ce qui serait nécessaire :**
- Contourner la détection (possible avec Magisk Hide)
- L'utilisateur doit ignorer la bannière d'avertissement
- Exploiter l'appareil compromis pour extraire des données

**Nos protections :** Détection au démarrage (su, Superuser.apk, Cydia.app), bannière d'avertissement (informatif, non bloquant)

#### 🌐 Compromission Tailscale/Supply Chain
**Ce qui serait nécessaire :**
- Compromettre l'infrastructure Tailscale OU
- Mise à jour malveillante de dépendance (dartssh2, xterm) via pub.dev OU
- Configuration ACL incorrecte par l'utilisateur

**Nos protections :** Filtrage URLs OAuth Tailscale, pinning des versions de dépendances, documentation ACL dans README

---

**À retenir :** Chaque scénario nécessite de contourner plusieurs couches. Notre architecture implémente la défense en profondeur, mais aucun système n'est sécurisé à 100%. Suivez toujours les bonnes pratiques de sécurité ci-dessous.

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

---

## 🛡️ Bonnes Pratiques de Sécurité OBLIGATOIRES

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

## 📖 Vous Voulez Savoir Ce Qui A ÉTÉ Fait en Termes de Sécurité ?

👉 **Lisez [SECURITE.md](SECURITE.md)** pour tous les détails sur :
- Les 3 audits de sécurité réalisés
- Toutes les mesures de sécurité implémentées
- Les limitations connues (documentées)
- Comment signaler une vulnérabilité de manière responsable

---

**Dernière mise à jour :** Février 2026  
**Version :** 1.0
