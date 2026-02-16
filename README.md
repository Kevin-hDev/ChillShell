# ChillShell 🚀📱

> ⚠️ **AVERTISSEMENT IMPORTANT** : Ce projet est en phase **ALPHA**. Il a été entièrement développé avec l'assistance de l'IA Claude Code. **Aucun audit de sécurité externe par des professionnels n'a été réalisé**. L'utilisation de ce logiciel se fait entièrement à vos risques et périls.

## 📱 Qu'est-ce que ChillShell ?

**ChillShell** est une application mobile Android qui vous permet d'accéder au terminal SSH de votre ordinateur depuis n'importe où dans le monde, de manière sécurisée et sans ouvrir de ports sur votre réseau.

**Comment ça marche :**
- 🔐 Connexion sécurisée via réseau mesh Tailscale
- 🔑 Authentification SSH par clés cryptographiques (ED25519)
- ⚡ Réveil automatique de votre PC (Wake-on-LAN)
- 🚫 Aucun port forwarding nécessaire
- 🌐 Accès depuis n'importe où avec une connexion Internet
- 🖥️ Nécessite l'application desktop **Chill** sur votre PC

## 🏗️ Architecture du Projet

**ChillShell fait partie d'un écosystème en 2 parties :**

```
┌─────────────────────┐         SSH         ┌─────────────────────┐
│   ChillShell        │ ◄──────────────────► │   Chill Desktop     │
│   (Mobile Android)  │   via Tailscale      │   (Application PC)  │
│                     │                      │                     │
│   - Interface SSH   │                      │   Package intégré : │
│   - Gestion clés    │                      │   • Tailscale       │
│   - Wake-on-LAN     │                      │   • SSH Server      │
│   - Terminal xterm  │                      │   • Wake-on-LAN     │
└─────────────────────┘                      └─────────────────────┘
     Ce repository                           Repository séparé
```

**Ce repository contient :**
- 📱 L'application mobile Android **ChillShell** (Flutter/Dart)

**Ce repository NE contient PAS :**
- ❌ L'application desktop **Chill** (voir repository séparé)
- ❌ Un backend/API cloud
- ❌ Une base de données

## ✨ Fonctionnalités

- 🔐 **Sécurité renforcée** : Utilise Tailscale (VPN mesh) + SSH (clés ED25519)
- 📱 **Interface terminal mobile** : Terminal complet (xterm) sur votre téléphone
- ⚡ **Wake-on-LAN intégré** : Réveillez votre PC à distance
- 🗂️ **Navigateur de dossiers** : Parcourez les répertoires de votre PC
- 🚫 **Zéro port forwarding** : Pas besoin d'ouvrir votre routeur
- 🔓 **100% Open Source** : Code auditable et modifiable
- 💰 **Gratuit à vie** : Pas d'abonnement, pas de frais cachés
- 🌍 **Multilingue** : Français, Anglais, Espagnol, Allemand, Chinois

## ⚠️ AVERTISSEMENTS DE SÉCURITÉ - À LIRE ABSOLUMENT

**AVANT D'UTILISER CE LOGICIEL, VOUS DEVEZ COMPRENDRE :**

### État du Projet

- ❌ **Aucun audit de sécurité professionnel** n'a été effectué
- 🤖 **Développé avec assistance IA** (Claude Code) - Je ne suis pas un développeur professionnel
- 🔍 **Analyse de sécurité interne uniquement** :
  - Modélisation des menaces STRIDE
  - Analyse avec Trail of Bits Security Skills (62 findings corrigés)
  - Tests automatisés de vulnérabilités
  - Analyse statique du code
- 🐛 **Peut contenir des vulnérabilités** non découvertes
- 📢 **Logiciel ALPHA** : bugs, changements majeurs et instabilités possibles

### Risques Potentiels

Cette application donne un **accès SSH complet** à votre ordinateur. Une faille de sécurité pourrait permettre à un attaquant de :
- 💀 Accéder à tous vos fichiers
- 🔓 Voler vos mots de passe et données sensibles
- 💳 Accéder à vos informations bancaires
- 🎥 Activer votre webcam/micro
- 💾 Chiffrer vos données (ransomware)
- 🗑️ Supprimer vos fichiers

### Responsabilité

**CE LOGICIEL EST FOURNI "TEL QUEL", SANS AUCUNE GARANTIE.**

- 🛡️ **VOUS êtes responsable** de la sécurité de vos systèmes
- ⚖️ Les auteurs ne peuvent être tenus responsables des dommages
- 🚨 Utilisation entièrement à vos propres risques

## 🔒 Recommandations de Sécurité ESSENTIELLES

Si vous décidez malgré tout d'utiliser ce logiciel :

### Avant d'installer

1. ✅ **Examinez le code source** vous-même ou faites-le examiner par quelqu'un de compétent
2. ✅ **Comprenez les risques** - lisez TOUTE cette documentation
3. ✅ **Testez d'abord sur un système non-critique** (pas votre PC principal)

### Configuration sécurisée

4. ✅ **Utilisez des clés SSH ED25519** (jamais de mots de passe !)
5. ✅ **Activez les ACL Tailscale** pour restreindre l'accès
6. ✅ **Gardez tout à jour** : Tailscale, SSH, Android, ChillShell, Chill Desktop
7. ✅ **Configurez un utilisateur dédié** (non-root) pour SSH
8. ✅ **Désactivez l'accès root SSH** (`PermitRootLogin no`)

### Surveillance

9. ✅ **Surveillez vos logs** régulièrement (`/var/log/auth.log`)
10. ✅ **Vérifiez les connexions actives** (`who`, `last`)
11. ✅ **Mettez en place des alertes** pour connexions inhabituelles

### Sauvegarde

12. ✅ **SAUVEGARDEZ TOUT** avant d'installer
13. ✅ **Testez vos sauvegardes** régulièrement

### Ce qu'il ne faut JAMAIS faire

- ❌ **JAMAIS exposer SSH directement** sur Internet (port forwarding)
- ❌ **JAMAIS utiliser des mots de passe** SSH (uniquement clés)
- ❌ **JAMAIS donner accès root** via SSH
- ❌ **JAMAIS utiliser sur un système de production** (entreprise, serveur important)

## 📋 Prérequis

### Sur votre téléphone Android
- **Android 12 (API 31) ou supérieur**
- ~50 MB d'espace libre
- Connexion Internet (WiFi ou données mobiles)

### Sur votre PC
- Système d'exploitation : Linux, macOS, ou Windows
- **Application desktop Chill** installée (voir repository séparé)
- Réseau supportant Wake-on-LAN (optionnel)

## 🛠️ Installation

### 📱 Étape 1 : Installer ChillShell (Application Mobile)

#### Option 1 : APK pré-compilé (Recommandé - Plus simple)

1. **Téléchargez l'APK** depuis [Releases GitHub](https://github.com/Kevin-hdev/ChillShell/releases)
2. **Vérifiez le checksum SHA256** (sécurité) :
   ```bash
   # Sur PC
   sha256sum ChillShell-vX.X.X.apk
   # Comparez avec le checksum affiché sur la page Release
   ```
3. **Activez "Sources inconnues"** dans les paramètres Android :
   - Paramètres → Sécurité → Sources inconnues (ou Applications inconnues)
4. **Transférez l'APK** sur votre téléphone (USB, email, ou cloud)
5. **Installez l'APK** en cliquant dessus
6. ⚠️ **Vous installez à vos risques et périls**

#### Option 2 : Compiler vous-même (Plus sûr - Avancé)

**Prérequis :**
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installé (version 3.x)
- [Android SDK](https://developer.android.com/studio) installé
- Git installé

**Étapes :**
```bash
# 1. Cloner le repository
git clone https://github.com/Kevin-hdev/ChillShell.git
cd ChillShell

# 2. Installer les dépendances Flutter
flutter pub get

# 3. Compiler l'APK en mode release
flutter build apk --release

# 4. L'APK se trouve dans :
# build/app/outputs/flutter-apk/app-release.apk

# 5. Transférer sur votre téléphone et installer
```

---

### 🖥️ Étape 2 : Installer Chill Desktop (Application PC)

**⚠️ ChillShell nécessite l'application desktop Chill pour fonctionner.**

**Chill Desktop package tout ce dont vous avez besoin :**
- ✅ Tailscale (réseau mesh sécurisé)
- ✅ Serveur SSH (OpenSSH)
- ✅ Support Wake-on-LAN

**Configuration en 3 clics - Aucune connaissance technique requise !**

**Pour installer Chill Desktop :**
1. Rendez-vous sur le repository [Chill Desktop](https://github.com/Kevin-hdev/Chill)
2. Suivez les instructions d'installation pour votre OS
3. Lancez Chill Desktop et suivez le setup initial (3 clics)
4. Notez l'IP Tailscale de votre PC (affichée dans l'interface Chill)

> **Note :** Si vous préférez configurer manuellement Tailscale + SSH + WOL sans Chill Desktop, c'est possible mais plus complexe. Voir la section "Installation manuelle" ci-dessous.

---

### 🔧 Étape 3 : Configurer ChillShell

1. **Ouvrez ChillShell** sur votre téléphone
2. **Appuyez sur "Nouvelle connexion"**
3. **Entrez les informations** :
   - Nom de la connexion : `Mon PC` (ou ce que vous voulez)
   - Hôte : `100.x.x.x` (IP Tailscale de votre PC, fournie par Chill Desktop)
   - Port : `22`
   - Nom d'utilisateur : `votre-username` (fourni par Chill Desktop)
4. **Générez ou importez une clé SSH ED25519** :
   - ChillShell peut générer une paire de clés pour vous
   - Ou importez une clé existante
5. **Ajoutez la clé publique** dans Chill Desktop (copier-coller)
6. **Connectez-vous !**

### ⚡ Wake-on-LAN (Optionnel)

Si vous voulez réveiller votre PC à distance :

**Dans Chill Desktop :**
1. Activez Wake-on-LAN dans les paramètres
2. Notez l'adresse MAC de votre carte réseau

**Dans ChillShell :**
1. Ajoutez la configuration WOL à votre connexion :
   - Adresse MAC : `XX:XX:XX:XX:XX:XX`
   - Adresse de broadcast : `255.255.255.255` (par défaut)

**Dans le BIOS de votre PC :**
- Activez "Wake on LAN"
- Activez "EuP 2013" ou options similaires

---

## 📖 Installation Manuelle (Sans Chill Desktop)

**⚠️ Réservé aux utilisateurs avancés**

Si vous ne voulez pas utiliser Chill Desktop et préférez tout configurer manuellement :

### 1. Installer et configurer Tailscale

```bash
# Sur votre PC (Linux/macOS)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Notez votre IP Tailscale
tailscale ip -4
# Exemple : 100.64.1.2
```

### 2. Installer et sécuriser SSH

```bash
# Ubuntu/Debian
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
```

**Éditez `/etc/ssh/sshd_config` pour durcir la sécurité :**
```bash
# Configuration sécurisée recommandée
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
```

**Redémarrez SSH :**
```bash
sudo systemctl restart ssh
```

### 3. Générer des clés SSH ED25519

```bash
# Sur votre PC ou depuis ChillShell
ssh-keygen -t ed25519 -C "ChillShell"

# Ajoutez la clé publique à authorized_keys
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 4. Configurer Wake-on-LAN (Optionnel)

```bash
# Vérifier si WOL est supporté
sudo ethtool [interface-réseau] | grep Wake-on
# Devrait afficher "Wake-on: g"

# Activer WOL si désactivé
sudo ethtool -s [interface-réseau] wol g
```

---

## 🐛 Problèmes Connus

- [ ] Wake-on-LAN peut ne pas fonctionner sur certains réseaux
- [ ] Première connexion SSH peut être lente (chargement shell)
- [ ] Terminal peut avoir des problèmes d'affichage avec certains prompts complexes
- [ ] Reconnexion automatique parfois instable

Consultez les [Issues GitHub](https://github.com/Kevin-hdev/ChillShell/issues) pour la liste complète et les solutions.

## 🤝 Contribuer

**Les contributions sont les bienvenues, SURTOUT pour la sécurité !**

### Vous pouvez contribuer en :

- 🔍 Auditant le code pour trouver des vulnérabilités (voir [SECURITY.md](SECURITY.md))
- 🐛 Signalant des bugs
- 💡 Proposant des améliorations
- 📝 Améliorant la documentation
- 🧪 Ajoutant des tests
- 🌍 Traduisant l'interface (5 langues supportées)

### Comment contribuer

1. Forkez le projet
2. Créez une branche (`git checkout -b feature/amelioration`)
3. Committez vos changements (`git commit -m 'Ajout amélioration'`)
4. Pushez (`git push origin feature/amelioration`)
5. Ouvrez une Pull Request

**Voir [CONTRIBUTING.md](CONTRIBUTING.md) pour les détails complets.**

## 🔒 Sécurité

**Vous avez trouvé une vulnérabilité ?**

🚨 **N'OUVREZ PAS d'issue publique** - cela mettrait les utilisateurs en danger.

**Procédure de divulgation responsable :**
1. Envoyez un email à : **Chill_app@outlook.fr**
2. Incluez les détails de la vulnérabilité (reproduction, impact, PoC)
3. Réponse sous 48-72h (meilleur effort)
4. Nous coordonnerons la divulgation et le correctif

**Crédit :** Votre nom sera mentionné publiquement dans le Hall of Fame (si vous le souhaitez).

**Voir [SECURITY.md](SECURITY.md) pour tous les détails.**

## 📄 Licence

Ce projet est sous licence **GPL v3** (GNU General Public License v3.0).

**Ce que cela signifie :**
- ✅ Vous pouvez utiliser ce code gratuitement
- ✅ Vous pouvez le modifier
- ✅ Vous pouvez le redistribuer
- ⚠️ **MAIS vous DEVEZ garder le code open source**
- ⚠️ **Toute modification DOIT être partagée sous GPL v3**
- ❌ **Vous ne pouvez PAS le rendre propriétaire/fermé**

Voir le fichier [LICENSE](LICENSE) pour le texte complet.

## 🙏 Remerciements

- 🤖 Développé avec [Claude Code](https://code.claude.com) (Anthropic)
- 🔒 Analyse de sécurité : Trail of Bits Skills + STRIDE (62 findings corrigés)
- 🌐 Utilise [Tailscale](https://tailscale.com) pour le réseau mesh sécurisé
- 🔑 Utilise OpenSSH pour les connexions sécurisées
- 🖥️ Utilise [xterm.js](https://xtermjs.org/) pour le rendu terminal
- 📦 Construit avec [Flutter](https://flutter.dev)

## 🏆 Hall of Fame - Chercheurs en Sécurité

Ces personnes ont contribué à améliorer la sécurité du projet :

*(Aucune contribution pour le moment - soyez le premier !)*

**Format :** Nom/Pseudo - Description de la vulnérabilité - Gravité - Date

## 📞 Contact & Support

- 🐛 **Bugs et problèmes** : [GitHub Issues](https://github.com/Kevin-hdev/ChillShell/issues)
- 💬 **Discussions générales** : [GitHub Discussions](https://github.com/Kevin-hdev/ChillShell/discussions)
- 🔒 **Sécurité** : Chill_app@outlook.fr
- 📧 **Autre** : Chill_app@outlook.fr

## 🔗 Liens Utiles

- 📱 [ChillShell (Application Mobile)](https://github.com/Kevin-hdev/ChillShell) - Ce repository
- 🖥️ [Chill Desktop (Application PC)](https://github.com/Kevin-hdev/Chill) - Repository séparé
- 🌐 [Site Web](https://chillshell.app) - En construction
- 📖 [Documentation complète](https://github.com/Kevin-hdev/ChillShell/wiki)

## ⚠️ Clause de Non-Responsabilité Finale

**EN UTILISANT CE LOGICIEL, VOUS RECONNAISSEZ ET ACCEPTEZ QUE :**

1. Ce logiciel est fourni "TEL QUEL" sans aucune garantie
2. Les auteurs ne sont PAS responsables des dommages, pertes de données, failles de sécurité ou tout autre problème
3. Vous utilisez ce logiciel entièrement à vos propres risques
4. Vous êtes seul responsable de la sécurité de vos systèmes
5. Ce logiciel n'a PAS été audité par des professionnels de la sécurité
6. Il peut contenir des vulnérabilités critiques non découvertes

**SI VOUS N'ACCEPTEZ PAS CES CONDITIONS, N'UTILISEZ PAS CE LOGICIEL.**

---

⭐ **Si ce projet vous est utile, mettez une étoile sur GitHub !**

🚨 **Rappel : Logiciel ALPHA non audité - Utilisation à vos risques**

💬 **Questions ? Ouvrez une Discussion sur GitHub !**
