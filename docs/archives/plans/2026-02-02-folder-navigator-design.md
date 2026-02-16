# Folder Navigator - Design & Implementation

> Date: 2 Février 2026
> Status: ✅ Implémenté

## Objectif

Navigation rapide dans les dossiers style Warp - dropdown qui liste les sous-dossiers du répertoire courant.

## Spécifications UI

### Position et taille
- **Bouton** : Dans la tab bar, affiche le nom du dossier courant (ou `~` pour home)
- **Dropdown** : Se déplie vers le BAS, aligné à droite du bouton
- **Dimensions** : Hauteur ~200px (5 items visibles), largeur 180px

### Contenu du dropdown
1. **Champ de recherche** - Filtre les dossiers en temps réel
2. **"Parent"** - Avec flèche ↑, remonte d'un niveau
3. **Liste des sous-dossiers** - Scrollable si > 5 items

### Comportement
- Clic sur dossier → `cd` + actualise la liste
- Clic en dehors → ferme le dropdown
- Recherche → filtre instantanément

## Architecture technique

### Fichiers créés
```
lib/features/terminal/widgets/folder_navigator.dart
lib/features/terminal/providers/folder_provider.dart
```

### Approche : SSH Exec (canal silencieux)

Les commandes de listing (`pwd`, `ls`) sont exécutées via le canal SSH **exec** (`.run()`) qui est séparé du shell interactif. Cela permet d'obtenir les données sans polluer le terminal.

```dart
// Dans ssh_service.dart
Future<String?> executeCommandSilently(String command) async {
  if (_client == null) return null;
  final result = await _client!.run(command);
  return String.fromCharCodes(result);
}
```

### Commande combinée

Chaque `.run()` crée un shell isolé, donc on combine `cd + pwd + ls` en une seule commande :

```bash
cd $HOME && pwd && echo "___SEP___" && ls -1 -d --color=never */ 2>/dev/null
```

**Notes importantes :**
- `~` ne fonctionne pas dans SSH exec → utiliser `$HOME`
- `--color=never` évite les codes ANSI dans les noms de dossiers

### Synchronisation avec le terminal

Après la navigation silencieuse, on envoie un `cd` au shell interactif pour synchroniser :

```dart
// Après loadFolders()
final newPath = ref.read(folderProvider).currentPath;
ref.read(sshProvider.notifier).write('cd "$newPath"\r');
```

> **Note V1** : Le `cd` est visible dans le terminal. Une amélioration future pourrait le rendre invisible.

## État (FolderProvider)

```dart
class FolderState {
  final String currentPath;      // "/home/user/projects"
  final String displayName;      // "projects" ou "~"
  final List<String> folders;    // ["src", "docs", "lib"]
  final bool isLoading;
  final String? error;
  final String searchQuery;      // Filtre de recherche
}
```

## Décisions techniques

| Choix | Décision |
|-------|----------|
| Obtention données | SSH exec (canal séparé, silencieux) |
| Isolation shells | Commandes combinées (cd + pwd + ls) |
| Expansion ~ | Utiliser `$HOME` |
| Sync terminal | `cd` envoyé au shell interactif |

## Améliorations futures

- [ ] Rendre le `cd` invisible dans le terminal
- [ ] Support des shells locaux (Android)
- [ ] Favoris / dossiers épinglés
