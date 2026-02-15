# Changelog

Toutes les modifications notables de ChillShell seront documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère à [Semantic Versioning](https://semver.org/lang/fr/).

## [Non publié]

### En cours
- Préparation de la première release publique

---

## [0.1.0-alpha] - [Date à définir]

### 🎉 Première Release Alpha

#### Ajouté
- 📱 Application mobile Android (Flutter)
- 🔐 Connexion SSH via clés ED25519
- 🖥️ Terminal xterm complet
- 🗂️ Navigateur de dossiers
- ⚡ Wake-on-LAN intégré
- 🔒 Verrouillage PIN/biométrique
- 🌍 Support multilingue (FR, EN, ES, DE, ZH)
- 🎨 Thèmes : Warp Dark, Dracula, Nord
- 🔑 Génération de clés ED25519 intégrée
- 📋 Gestion des connexions SSH sauvegardées

#### Sécurité
- 🛡️ Audit Trail of Bits (62 findings corrigés)
- 🔒 FlutterSecureStorage pour clés privées
- 🔐 EncryptedSharedPreferences (Android)
- 🚫 Protection screenshot/screen recording
- 🔍 Détection root/jailbreak
- 📝 Journal d'audit de sécurité
- ⏱️ Comparaisons constant-time (crypto)
- 🔐 TOFU durci avec timeout

#### Connu
- ⚠️ Logiciel ALPHA - Bugs attendus
- ⚠️ Pas d'audit externe professionnel
- ⚠️ Reconnexion automatique instable
- ⚠️ Wake-on-LAN peut échouer sur certains réseaux

---

## Notes de Version

### Semantic Versioning

- **MAJOR** (X.0.0) : Changements incompatibles de l'API
- **MINOR** (0.X.0) : Ajout de fonctionnalités compatibles
- **PATCH** (0.0.X) : Corrections de bugs compatibles

### Types de Changements

- **Ajouté** : Nouvelles fonctionnalités
- **Modifié** : Changements dans fonctionnalités existantes
- **Déprécié** : Fonctionnalités bientôt retirées
- **Retiré** : Fonctionnalités retirées
- **Corrigé** : Corrections de bugs
- **Sécurité** : Correctifs de vulnérabilités
