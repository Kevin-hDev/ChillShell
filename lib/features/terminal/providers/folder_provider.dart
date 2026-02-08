import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// État de la navigation dans les dossiers
class FolderState {
  final String currentPath;
  final String displayName;
  final List<String> folders;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  const FolderState({
    this.currentPath = '~',
    this.displayName = '~',
    this.folders = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  FolderState copyWith({
    String? currentPath,
    String? displayName,
    List<String>? folders,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return FolderState(
      currentPath: currentPath ?? this.currentPath,
      displayName: displayName ?? this.displayName,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Dossiers filtrés par la recherche
  List<String> get filteredFolders {
    if (searchQuery.isEmpty) return folders;
    final query = searchQuery.toLowerCase();
    return folders.where((f) => f.toLowerCase().contains(query)).toList();
  }
}

/// Callback type pour exécuter des commandes SSH silencieuses
typedef SilentCommandExecutor = Future<String?> Function(String command);

/// Notifier pour la navigation dossiers
class FolderNotifier extends Notifier<FolderState> {
  @override
  FolderState build() => const FolderState();

  /// Récupère le chemin courant et la liste des dossiers via SSH exec (silencieux)
  /// Si basePath est fourni, on liste ce dossier, sinon on liste le home
  Future<void> loadFolders(SilentCommandExecutor execute, {String? basePath}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Construire la commande combinée (tout en une seule exécution car chaque .run() est isolé)
      // Note: ~ ne fonctionne pas dans SSH exec, utiliser $HOME pour le home
      // SÉCURITÉ: Utiliser des guillemets simples pour empêcher l'injection de commandes
      // ($(...), `...`, $var ne sont PAS interprétés dans les guillemets simples)
      String command;
      if (basePath == null) {
        // Pas de chemin spécifié → utiliser $HOME (sans guillemets pour expansion)
        command = 'cd \$HOME && pwd && echo "___SEP___" && ls -1 -d --color=never */ 2>/dev/null';
      } else {
        // Chemin spécifié → guillemets simples + échappement des ' dans le chemin
        final safePath = basePath.replaceAll("'", r"'\''");
        command = "cd '$safePath' && pwd && echo '___SEP___' && ls -1 -d --color=never */ 2>/dev/null";
      }

      final result = await execute(command);
      if (result == null) {
        state = state.copyWith(isLoading: false, error: 'Erreur connexion');
        return;
      }

      // Parser le résultat
      final sepIndex = result.indexOf('___SEP___');
      if (sepIndex == -1) {
        state = state.copyWith(isLoading: false, error: 'Erreur parsing');
        return;
      }

      final currentPath = result.substring(0, sepIndex).trim();
      final lsPart = result.substring(sepIndex + '___SEP___'.length).trim();

      final folders = lsPart
          .split('\n')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .map((f) => f.endsWith('/') ? f.substring(0, f.length - 1) : f)
          .toList();

      // Calculer le nom d'affichage (dernier segment du chemin)
      String displayName;
      if (currentPath == '~' || currentPath.endsWith('/home') || currentPath == '/') {
        displayName = '~';
      } else {
        final segments = currentPath.split('/');
        displayName = segments.isNotEmpty ? segments.last : '~';
        if (displayName.isEmpty) displayName = '/';
      }

      state = state.copyWith(
        currentPath: currentPath,
        displayName: displayName,
        folders: folders,
        isLoading: false,
        error: null,
      );

      if (kDebugMode) debugPrint('FolderProvider: path=$currentPath, folders=${folders.length}');
    } catch (e) {
      if (kDebugMode) debugPrint('FolderProvider: Error: $e');
      state = state.copyWith(isLoading: false, error: 'Erreur: $e');
    }
  }

  /// Navigue vers un dossier et actualise la liste
  Future<void> navigateToFolder(String folderName, SilentCommandExecutor execute) async {
    state = state.copyWith(isLoading: true);

    try {
      // Construire le chemin absolu
      String targetPath;
      if (folderName == '..') {
        // Remonter d'un niveau
        final currentPath = state.currentPath;
        if (currentPath == '/' || currentPath == '~') {
          targetPath = currentPath;
        } else {
          final segments = currentPath.split('/');
          segments.removeLast();
          targetPath = segments.isEmpty ? '/' : segments.join('/');
        }
      } else {
        // Descendre dans le sous-dossier (chemin absolu)
        targetPath = '${state.currentPath}/$folderName';
      }

      // Charger les dossiers du nouveau chemin
      await loadFolders(execute, basePath: targetPath);
    } catch (e) {
      if (kDebugMode) debugPrint('FolderProvider: Navigate error: $e');
      state = state.copyWith(isLoading: false, error: 'Erreur: $e');
    }
  }

  /// Met à jour la recherche
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Réinitialise l'état
  void reset() {
    state = const FolderState();
  }
}

final folderProvider = NotifierProvider<FolderNotifier, FolderState>(
  FolderNotifier.new,
);
