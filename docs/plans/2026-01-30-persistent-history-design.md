# Design : Historique Persistant

> Date: 30 Janvier 2026

## Décisions

- **Scope** : Historique global (pas par hôte)
- **Taille max** : 200 commandes
- **Sauvegarde** : À chaque commande (pas de perte si crash)
- **Stockage** : flutter_secure_storage (clé: `command_history`)

## Fichiers modifiés

1. `lib/services/storage_service.dart` - Méthodes save/load
2. `lib/features/terminal/providers/terminal_provider.dart` - Intégration

## Flow

```
User tape commande
       │
       ▼
TerminalNotifier.addToHistory()
       │
       ├──> Ajoute à state.commandHistory
       │
       └──> StorageService.saveCommandHistory()
                    │
                    ▼
            flutter_secure_storage
```

## Chargement au démarrage

```
App démarre
    │
    ▼
TerminalNotifier.loadHistory()
    │
    ▼
StorageService.getCommandHistory()
    │
    ▼
state.commandHistory = données chargées
```
