# Design : Bouton Send → Stop (v2)

> Date: 30 Janvier 2026

## Décisions

- **Un seul bouton** : Send ou Stop (jamais les deux)
- **État par onglet** : chaque tab a son propre isRunning
- **Commandes filtrées** : Stop uniquement pour les commandes "long-running"
- **Champ intelligent** : Si texte dans le champ → toujours Send (pour répondre aux prompts)
- **Ctrl+C** : caractère ASCII 3 (`\x03`)

## Logique du bouton

```
Stop affiché si:
  - Process en cours (commande long-running lancée)
  - ET champ de saisie VIDE

Send affiché sinon:
  - Pas de process en cours
  - OU champ de saisie contient du texte (pour répondre aux prompts y/n, sudo, etc.)
```

## Commandes "long-running" (nécessitent Stop)

- **Serveurs** : npm, yarn, node, python, flask, cargo, go, flutter...
- **Docker** : docker-compose, docker build
- **Réseau** : curl, wget, ssh, scp, rsync
- **Installations** : apt, pip, brew, npm install...
- **Monitoring** : top, htop, watch, tail -f
- **Éditeurs** : vim, nano, emacs
- **Scripts** : ./script.sh, *.py, *.sh

## Commandes exclues (instantanées)

cd, ls, pwd, echo, cat, mkdir, touch, rm, cp, mv, clear, history, exit...

## Swipe gestures (dans le champ de saisie)

- Swipe droite → TAB (accepter ghost text)
- Swipe haut → Flèche ↑ (navigation menus interactifs)
- Swipe bas → Flèche ↓ (navigation menus interactifs)

## Fichiers modifiés

1. `ssh_provider.dart` - Liste commandes + isLongRunningCommand() + tabRunningState
2. `ghost_text_input.dart` - Logique bouton + swipe vertical
