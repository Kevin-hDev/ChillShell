import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/storage_service.dart';
import 'ghost_text_engine.dart';

class TerminalState {
  final List<Command> commands;
  final String currentInput;
  final String? ghostText;
  final List<String> commandHistory;
  final int historyIndex;
  final DateTime? lastCommandStart;
  final Duration? lastExecutionTime;
  final String? currentPath;

  const TerminalState({
    this.commands = const [],
    this.currentInput = '',
    this.ghostText,
    this.commandHistory = const [],
    this.historyIndex = -1,
    this.lastCommandStart,
    this.lastExecutionTime,
    this.currentPath,
  });

  TerminalState copyWith({
    List<Command>? commands,
    String? currentInput,
    String? ghostText,
    List<String>? commandHistory,
    int? historyIndex,
    DateTime? lastCommandStart,
    Duration? lastExecutionTime,
    String? currentPath,
  }) {
    return TerminalState(
      commands: commands ?? this.commands,
      currentInput: currentInput ?? this.currentInput,
      ghostText: ghostText,
      commandHistory: commandHistory ?? this.commandHistory,
      historyIndex: historyIndex ?? this.historyIndex,
      lastCommandStart: lastCommandStart ?? this.lastCommandStart,
      lastExecutionTime: lastExecutionTime ?? this.lastExecutionTime,
      currentPath: currentPath ?? this.currentPath,
    );
  }
}

class TerminalNotifier extends Notifier<TerminalState> {
  @override
  TerminalState build() {
    Future.microtask(_loadHistory);
    return const TerminalState();
  }

  final _uuid = const Uuid();
  final _storage = StorageService();

  /// Charge l'historique depuis le stockage persistant
  Future<void> _loadHistory() async {
    final history = await _storage.getCommandHistory();
    if (history.isNotEmpty) {
      state = state.copyWith(commandHistory: history);
    }
  }

  void setInput(String input, {bool resetHistory = true}) {
    final ghost = GhostTextEngine.getSuggestion(input, state.commandHistory);
    state = state.copyWith(
      currentInput: input,
      ghostText: ghost,
      historyIndex: resetHistory ? -1 : state.historyIndex,
    );
  }

  void acceptGhostText() {
    if (state.ghostText != null) {
      state = state.copyWith(
        currentInput: state.currentInput + state.ghostText!,
        ghostText: null,
      );
    }
  }

  /// Patterns de commandes sensibles à ne JAMAIS enregistrer
  static const _sensitivePatterns = [
    // Mots de passe et authentification
    'password',
    'passwd',
    'secret',
    'token',
    'api_key',
    'apikey',
    'api-key',
    'auth',
    'credential',
    'private',
    // Commandes d'export de variables sensibles
    'export ',
    // SSH avec mot de passe inline
    'sshpass',
    // MySQL/PostgreSQL avec mot de passe
    '-p=',
    '--password=',
    'PGPASSWORD=',
    'MYSQL_PWD=',
    // AWS/Cloud credentials
    'AWS_SECRET',
    'AZURE_',
    'GCP_',
    'GOOGLE_APPLICATION_CREDENTIALS',
    // Autres
    '.env',
    'id_rsa',
    'id_ed25519',
  ];

  /// Vérifie si une commande contient des données sensibles
  bool _isSensitiveCommand(String command) {
    final lower = command.toLowerCase();
    for (final pattern in _sensitivePatterns) {
      if (lower.contains(pattern.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Ajoute une commande à l'historique et sauvegarde
  /// Note: Utiliser addToHistoryIfSuccess() pour vérifier le code retour avant
  void addToHistory(String command) {
    if (command.trim().isEmpty) return;

    // NE JAMAIS enregistrer les commandes sensibles (mots de passe, tokens, etc.)
    if (_isSensitiveCommand(command)) {
      debugPrint('SECURITY: Sensitive command NOT added to history');
      return;
    }

    // Éviter les doublons consécutifs
    if (state.commandHistory.isNotEmpty &&
        state.commandHistory.last == command) {
      return;
    }

    final newHistory = [...state.commandHistory, command];
    // Limiter l'historique à 200 commandes
    if (newHistory.length > 200) {
      newHistory.removeAt(0);
    }

    state = state.copyWith(commandHistory: newHistory);

    // Sauvegarder l'historique de manière persistante
    _storage.saveCommandHistory(newHistory);
  }

  /// Efface complètement l'historique des commandes (utile pour reset après pollution)
  Future<void> clearCommandHistory() async {
    state = state.copyWith(commandHistory: []);
    await _storage.saveCommandHistory([]);
    debugPrint('Command history cleared');
  }

  /// Commande en attente de validation (avant vérification via output)
  String? _pendingCommand;
  DateTime? _pendingCommandTime;
  bool _pendingCommandValidated = false;

  /// SÉCURITÉ: Indique si le shell attend une saisie sensible (mot de passe, passphrase, etc.)
  /// Quand true, l'input suivant NE SERA PAS enregistré dans l'historique
  bool _isWaitingForSensitiveInput = false;

  /// Patterns qui indiquent que le shell attend un mot de passe ou autre donnée sensible
  static const _passwordPromptPatterns = [
    // Sudo
    '[sudo] password',
    'password for',
    'mot de passe',
    // SSH
    'passphrase',
    'enter passphrase',
    'ssh password',
    // GPG
    'enter pin',
    'gpg: ',
    // Generic
    'password:',
    'password :',
    'secret:',
    'token:',
    'api key:',
    // MySQL/PostgreSQL
    'enter password',
    // Docker
    'login password',
    // Git credentials
    'password for \'',
    'username for',
    // Confirmation dangereuse
    'are you sure',
    'y/n',
    '(yes/no)',
  ];

  /// Patterns d'erreur courants dans les shells
  static const _errorPatterns = [
    // English - Basic errors
    'command not found',
    'No such file or directory',
    'Permission denied',
    'is not recognized',
    'cannot access',
    'does not exist',
    'not a directory',
    'is a directory',
    'syntax error',
    'invalid option',
    'unknown option',
    'missing argument',
    'too few arguments',
    'bad substitution',
    'unbound variable',
    ': not found',
    'No command',
    'unable to',
    'Operation not permitted',
    'segmentation fault',
    'Killed',
    'error:',
    'Error:',
    'failed',
    'cannot find',
    'cannot execute',
    'not permitted',

    // French - Ubuntu/Debian suggestion messages
    "n'a pas été trouvée",  // "La commande « htopi » n'a pas été trouvée"
    'pas été trouvé',       // Variante masculine
    'Aucun fichier ou dossier de ce nom',
    'commande introuvable',
    "n'existe pas",
    'Erreur',
    'Permission non accordée',
    'opération non permise',

    // Zsh specific
    'zsh: command not found',
    'zsh: no such file or directory',

    // Bash specific
    'bash: ',  // Préfixe d'erreur bash (ex: "bash: htopi: command not found")
  ];

  /// Stocke une commande en attente de validation
  /// SÉCURITÉ: Si on attend une saisie sensible (mot de passe), on n'enregistre RIEN
  void setPendingCommand(String command) {
    // SÉCURITÉ CRITIQUE: Si le shell attend un mot de passe, on n'enregistre PAS l'input
    if (_isWaitingForSensitiveInput) {
      debugPrint('SECURITY: Sensitive input detected, NOT saving to history');
      _isWaitingForSensitiveInput = false; // Reset pour le prochain input
      _pendingCommand = null;
      _pendingCommandTime = null;
      _pendingCommandValidated = false;
      return; // NE PAS enregistrer cette commande
    }

    _pendingCommand = command;
    _pendingCommandTime = DateTime.now();
    _pendingCommandValidated = false;
  }

  /// Appelé quand on reçoit de la sortie du terminal
  /// 1. Détecte si le shell demande un mot de passe (pour ne pas enregistrer l'input suivant)
  /// 2. Vérifie si la sortie contient une erreur pour la commande en attente
  void onTerminalOutput(String output) {
    final lowerOutput = output.toLowerCase();

    // SÉCURITÉ: Détecter si le shell demande un mot de passe ou autre donnée sensible
    for (final pattern in _passwordPromptPatterns) {
      if (lowerOutput.contains(pattern.toLowerCase())) {
        _isWaitingForSensitiveInput = true;
        debugPrint('SECURITY: Password prompt detected ("$pattern"), next input will NOT be saved');
        // Annuler aussi la commande en attente si c'était une commande qui demande un password
        _pendingCommand = null;
        _pendingCommandTime = null;
        return;
      }
    }

    // Si pas de commande en attente, rien d'autre à faire
    if (_pendingCommand == null || _pendingCommandValidated) return;

    // Vérifier si la sortie contient un pattern d'erreur
    for (final pattern in _errorPatterns) {
      if (lowerOutput.contains(pattern.toLowerCase())) {
        // Erreur détectée → ne pas ajouter à l'historique
        debugPrint('ERROR DETECTED: "$pattern" in output, command "$_pendingCommand" NOT added to history');
        _pendingCommand = null;
        _pendingCommandTime = null;
        return;
      }
    }
  }

  /// Valide la commande en attente après le délai (si pas d'erreur détectée)
  void validatePendingCommandAfterDelay() {
    if (_pendingCommand == null || _pendingCommandValidated) return;

    // Vérifier que le délai est passé (500ms)
    if (_pendingCommandTime != null) {
      final elapsed = DateTime.now().difference(_pendingCommandTime!);
      if (elapsed.inMilliseconds >= 500) {
        // Pas d'erreur détectée après le délai → ajouter à l'historique
        debugPrint('No error detected for "$_pendingCommand", adding to history');
        addToHistory(_pendingCommand!);
        _pendingCommandValidated = true;
        _pendingCommand = null;
        _pendingCommandTime = null;
      }
    }
  }

  /// Annule la commande en attente
  void cancelPendingCommand() {
    _pendingCommand = null;
    _pendingCommandTime = null;
    _pendingCommandValidated = false;
  }

  /// Navigue vers la commande précédente dans l'historique
  String? previousCommand() {
    if (state.commandHistory.isEmpty) return null;

    int newIndex = state.historyIndex;
    if (newIndex == -1) {
      newIndex = state.commandHistory.length - 1;
    } else if (newIndex > 0) {
      newIndex--;
    }

    state = state.copyWith(historyIndex: newIndex);
    return state.commandHistory[newIndex];
  }

  /// Navigue vers la commande suivante dans l'historique
  String? nextCommand() {
    if (state.commandHistory.isEmpty || state.historyIndex == -1) return null;

    int newIndex = state.historyIndex + 1;
    if (newIndex >= state.commandHistory.length) {
      state = state.copyWith(historyIndex: -1);
      return '';
    }

    state = state.copyWith(historyIndex: newIndex);
    return state.commandHistory[newIndex];
  }

  void executeCommand(String command) {
    if (command.trim().isEmpty) return;

    final cmd = Command(
      id: _uuid.v4(),
      command: command,
      timestamp: DateTime.now(),
      isRunning: true,
    );

    // Ajouter à l'historique
    addToHistory(command);

    state = state.copyWith(
      commands: [...state.commands, cmd],
      currentInput: '',
      ghostText: null,
      historyIndex: -1,
    );
  }

  void updateCommandOutput(String commandId, String output, {bool isComplete = false, Duration? executionTime}) {
    state = state.copyWith(
      commands: state.commands.map((cmd) {
        if (cmd.id == commandId) {
          return cmd.copyWith(
            output: output,
            isRunning: !isComplete,
            executionTime: executionTime ?? cmd.executionTime,
          );
        }
        return cmd;
      }).toList(),
    );
  }

  void clearHistory() {
    state = const TerminalState();
  }

  /// Marque le début d'une commande (pour calculer le temps d'exécution)
  void startCommand() {
    // Capturer le temps d'exécution de la commande précédente
    Duration? previousExecutionTime;
    if (state.lastCommandStart != null) {
      previousExecutionTime = DateTime.now().difference(state.lastCommandStart!);
    }

    state = state.copyWith(
      lastCommandStart: DateTime.now(),
      lastExecutionTime: previousExecutionTime,
    );
  }

  /// Met à jour le chemin courant
  void updatePath(String path) {
    state = state.copyWith(currentPath: path);
  }
}

final terminalProvider = NotifierProvider<TerminalNotifier, TerminalState>(
  TerminalNotifier.new,
);

/// Provider pour tracker si le terminal a été scrollé vers le haut
/// (pour afficher le bouton "scroll to bottom")
class _TerminalScrolledUp extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final terminalScrolledUpProvider = NotifierProvider<_TerminalScrolledUp, bool>(
  _TerminalScrolledUp.new,
);

/// Provider pour le mode édition (nano, vim, less, htop, etc.)
/// True quand une app utilise l'alternate screen mode
class _IsEditorMode extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final isEditorModeProvider = NotifierProvider<_IsEditorMode, bool>(
  _IsEditorMode.new,
);
