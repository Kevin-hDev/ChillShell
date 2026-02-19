import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibeterm/core/security/secure_logger.dart';

/// État de la navigation dans les dossiers
class FolderState {
  final String currentPath;
  final String displayName;
  final List<String> folders;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  /// OS distant détecté ('linux', 'macos', 'windows') — mis en cache après le 1er appel
  final String? remoteOS;

  const FolderState({
    this.currentPath = '~',
    this.displayName = '~',
    this.folders = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.remoteOS,
  });

  FolderState copyWith({
    String? currentPath,
    String? displayName,
    List<String>? folders,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? remoteOS,
  }) {
    return FolderState(
      currentPath: currentPath ?? this.currentPath,
      displayName: displayName ?? this.displayName,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      remoteOS: remoteOS ?? this.remoteOS,
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
  /// Détecte automatiquement l'OS distant (Linux/macOS/Windows) au premier appel
  Future<void> loadFolders(
    SilentCommandExecutor execute, {
    String? basePath,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final os = await _ensureOSDetected(execute);

      final command = os == 'windows'
          ? _buildWindowsCommand(basePath)
          : _buildUnixCommand(basePath);

      final result = await execute(command);
      if (result == null) {
        state = state.copyWith(isLoading: false, error: 'Erreur connexion');
        return;
      }

      final parsed = _parseFolderListResult(result);
      if (parsed == null) {
        state = state.copyWith(isLoading: false, error: 'Erreur parsing');
        return;
      }

      final (currentPath, folders) = parsed;
      final displayName = _calculateDisplayName(currentPath, os);

      state = state.copyWith(
        currentPath: currentPath,
        displayName: displayName,
        folders: folders,
        isLoading: false,
        error: null,
      );

      SecureLogger.log('FolderProvider', 'Folders loaded successfully');
    } catch (e) {
      SecureLogger.logError('FolderProvider', e);
      state = state.copyWith(isLoading: false, error: 'Erreur: $e');
    }
  }

  Future<String> _ensureOSDetected(SilentCommandExecutor execute) async {
    String os = state.remoteOS ?? '';
    if (os.isEmpty) {
      os = await _detectRemoteOS(execute);
      state = state.copyWith(remoteOS: os);
    }
    return os;
  }

  (String, List<String>)? _parseFolderListResult(String result) {
    final sepIndex = result.indexOf('___SEP___');
    if (sepIndex == -1) return null;

    final currentPath = result.substring(0, sepIndex).trim();
    final listPart = result.substring(sepIndex + '___SEP___'.length).trim();

    final folders = listPart
        .split('\n')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .map((f) => f.endsWith('/') ? f.substring(0, f.length - 1) : f)
        .toList();

    return (currentPath, folders);
  }

  String _calculateDisplayName(String currentPath, String os) {
    final sep = os == 'windows' ? r'\' : '/';
    if (currentPath == '~' || currentPath == '/') return '~';
    if (os == 'windows' && RegExp(r'^[A-Za-z]:\\?$').hasMatch(currentPath)) {
      return currentPath;
    }
    final segments = currentPath.split(sep);
    String displayName = segments.isNotEmpty ? segments.last : '~';
    if (displayName.isEmpty) {
      displayName = os == 'windows' ? currentPath : '/';
    }
    return displayName;
  }

  String _computeParentPath(String currentPath, String os) {
    final sep = os == 'windows' ? r'\' : '/';
    if (currentPath == '/' || currentPath == '~') return currentPath;
    if (os == 'windows' && RegExp(r'^[A-Za-z]:\\?$').hasMatch(currentPath)) {
      return currentPath;
    }
    final segments = currentPath.split(sep);
    segments.removeLast();
    if (os == 'windows') {
      return segments.length <= 1
          ? '${segments.first}$sep'
          : segments.join(sep);
    }
    return segments.isEmpty ? '/' : segments.join(sep);
  }

  String _computeChildPath(String currentPath, String folderName, String os) {
    final sep = os == 'windows' ? r'\' : '/';
    return '$currentPath$sep$folderName';
  }

  /// Détecte l'OS distant via uname -s (cache le résultat dans l'état)
  Future<String> _detectRemoteOS(SilentCommandExecutor execute) async {
    try {
      final result = await execute('uname -s');
      final output = (result ?? '').trim().toLowerCase();
      if (output.contains('linux')) return 'linux';
      if (output.contains('darwin')) return 'macos';
    } catch (_) {}
    // Si uname échoue ou donne autre chose → probablement Windows
    return 'windows';
  }

  /// Commande pour lister les dossiers sur Linux/macOS
  String _buildUnixCommand(String? basePath) {
    if (basePath == null) {
      return 'cd \$HOME && pwd && echo "___SEP___" && ls -1 -d */ 2>/dev/null';
    }
    // En single quotes bash, seul ' nécessite un échappement via '\''
    // Tous les autres caractères ($, `, !, \) sont déjà littéraux
    final safePath = basePath.replaceAll("'", r"'\''");
    return "cd '$safePath' && pwd && echo '___SEP___' && ls -1 -d */ 2>/dev/null";
  }

  /// Commande pour lister les dossiers sur Windows (cmd.exe)
  String _buildWindowsCommand(String? basePath) {
    if (basePath == null) {
      return 'cd %USERPROFILE% && cd && echo ___SEP___ && dir /b /ad 2>NUL';
    }
    // cd /d permet de changer de lecteur (ex: de C: à D:)
    final safePath = basePath.replaceAll('"', '');
    return 'cd /d "$safePath" && cd && echo ___SEP___ && dir /b /ad 2>NUL';
  }

  /// Navigue vers un dossier et actualise la liste
  Future<void> navigateToFolder(
    String folderName,
    SilentCommandExecutor execute,
  ) async {
    state = state.copyWith(isLoading: true);

    try {
      final os = state.remoteOS ?? 'linux';

      final targetPath = folderName == '..'
          ? _computeParentPath(state.currentPath, os)
          : _computeChildPath(state.currentPath, folderName, os);

      // Charger les dossiers du nouveau chemin
      await loadFolders(execute, basePath: targetPath);
    } catch (e) {
      SecureLogger.logError('FolderProvider', e);
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
