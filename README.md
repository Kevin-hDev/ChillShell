# ⌘ VibeTerm

> Terminal mobile moderne style Warp pour piloter un PC à distance via SSH

![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart)

---

## 📱 Aperçu

**VibeTerm** est une application mobile Flutter qui agit comme un miroir de terminal pour contrôler votre PC à distance via SSH. Inspirée du design de Warp Terminal.

### Fonctionnalités

- 🎨 Interface sombre style Warp avec blocs de commandes
- 📑 Multi-sessions via onglets
- 👻 Ghost text completion (autocomplétion intelligente)
- 🔐 Gestion sécurisée des clés SSH
- 🔄 Synchronisation bidirectionnelle via tmux
- 🌐 Connexion via Tailscale (mesh VPN)

---

## 📚 Documentation

| Fichier | Description |
|---------|-------------|
| [docs/VibeTerm_2026_Specifications_v2.md](docs/VibeTerm_2026_Specifications_v2.md) | Spécifications fonctionnelles |
| [docs/VibeTerm_Design_System.md](docs/VibeTerm_Design_System.md) | Design system complet |
| [docs/VibeTerm_Architecture.md](docs/VibeTerm_Architecture.md) | Architecture technique |
| [docs/VibeTerm_SSH_Guide.md](docs/VibeTerm_SSH_Guide.md) | Guide SSH/tmux |

---

## 🚀 Quick Start

```bash
# Installer les dépendances
flutter pub get

# Lancer en développement
flutter run
```

### Prérequis PC hôte

```bash
# tmux
sudo apt install tmux

# Clé SSH Ed25519
ssh-keygen -t ed25519 -C "vibeterm"

# Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

---

## 🏗️ Stack

| Composant | Technologie |
|-----------|-------------|
| Framework | Flutter 3.38 |
| State | Riverpod |
| Terminal | xterm.dart |
| SSH | dartssh2 |
| Storage | flutter_secure_storage |
| Auth | local_auth |

---

## 🎨 Design

Palette Warp Dark :

| Couleur | Hex | Usage |
|---------|-----|-------|
| Background | `#0F0F0F` | Fond |
| Block | `#1A1A1A` | Cartes |
| Border | `#333333` | Bordures |
| Text | `#FFFFFF` | Texte |
| Accent | `#10B981` | Vert |

---

## 📋 Roadmap

- [x] Design validé (mockups)
- [x] Documentation complète
- [ ] Phase 1 : Setup + theme
- [ ] Phase 2 : UI Terminal + Settings
- [ ] Phase 3 : State management
- [ ] Phase 4 : SSH/tmux
- [ ] Phase 5 : Sécurité
- [ ] Phase 6 : Tests

---

## 📄 License

MIT
