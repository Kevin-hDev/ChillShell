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

  /// Timestamps parallèles à commandHistory (pour le TTL à la sauvegarde)
  List<int> _historyTimestamps = [];

  /// Charge l'historique depuis le stockage persistant (avec filtre TTL 90 jours)
  Future<void> _loadHistory() async {
    final entries = await _storage.getCommandHistoryV2();
    if (entries.isEmpty) return;

    // Filtrer les entrées expirées (TTL 90 jours)
    final cutoff = DateTime.now()
        .subtract(Duration(days: _historyTtlDays))
        .millisecondsSinceEpoch;

    final validEntries = entries.where((e) {
      final t = e['t'] as int? ?? 0;
      return t >= cutoff;
    }).toList();

    final commands = validEntries.map((e) => e['c'] as String).toList();
    _historyTimestamps = validEntries.map((e) => e['t'] as int).toList();

    state = state.copyWith(commandHistory: commands);

    // Si des entrées ont expiré, re-sauvegarder sans elles
    if (validEntries.length < entries.length) {
      _saveHistoryV2(commands, _historyTimestamps);
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

  /// TTL de l'historique des commandes (90 jours)
  static const _historyTtlDays = 90;

  /// Regex de détection de secrets dans les commandes.
  /// Contrairement aux simples contains(), ces regex évitent les faux positifs
  /// (ex: "auth" ne matche plus "author") et détectent les vrais tokens inline.
  static final _sensitiveRegexes = [
    // Assignation inline de variables sensibles: SECRET=value, TOKEN=xyz, etc.
    RegExp(r'\b(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APIKEY|API[-_]KEY|PRIVATE_KEY|CREDENTIAL)\s*=\S+', caseSensitive: false),

    // Export de variables contenant des mots-clés sensibles (GITHUB_TOKEN, DB_PASSWORD, etc.)
    RegExp(r'\bexport\s+\w*(PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|APIKEY|PRIVATE_KEY|CREDENTIAL)\w*\s*=', caseSensitive: false),

    // Export de variables cloud/DB spécifiques
    RegExp(r'\bexport\s+(AWS_SECRET\w*|AZURE_\w+|GCP_\w+|GOOGLE_APPLICATION_CREDENTIALS|PGPASSWORD|MYSQL_PWD)\s*=', caseSensitive: false),

    // sshpass (outil qui passe un mot de passe en clair)
    RegExp(r'\bsshpass\b'),

    // Mots de passe base de données inline
    RegExp(r'PGPASSWORD=\S+'),
    RegExp(r'MYSQL_PWD=\S+'),
    RegExp(r'--password=\S+'),

    // Tokens GitHub (PAT classique, OAuth, fine-grained)
    RegExp(r'ghp_[a-zA-Z0-9]{36}'),
    RegExp(r'gho_[a-zA-Z0-9]{36}'),
    RegExp(r'github_pat_[a-zA-Z0-9_]{22,}'),

    // OpenAI API key
    RegExp(r'\bsk-[a-zA-Z0-9]{20,}'),

    // AWS Access Key ID
    RegExp(r'AKIA[A-Z0-9]{16}'),

    // Stripe keys
    RegExp(r'(sk_live|pk_live|sk_test|pk_test)_[a-zA-Z0-9]+'),

    // Slack tokens
    RegExp(r'xox[bpsar]-[a-zA-Z0-9-]+'),

    // JWT tokens (3 segments base64url séparés par des points)
    RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]+'),

    // Clés API dans les headers HTTP (curl -H "api_key: xxx")
    RegExp(r'\b(api[_-]?key|apikey)\s*[:=]\s*\S+', caseSensitive: false),

    // Lecture de fichiers sensibles (clés, .env, .pem)
    RegExp(r'\b(cat|less|more|head|tail|bat)\s+\S*\.(env|pem|key)\b'),
    RegExp(r'\b(cat|less|more|head|tail|bat)\s+\S*id_(rsa|ed25519|ecdsa|dsa)\b'),
  ];

  /// Vérifie si une commande contient des données sensibles (regex)
  bool _isSensitiveCommand(String command) {
    for (final regex in _sensitiveRegexes) {
      if (regex.hasMatch(command)) {
        return true;
      }
    }
    return false;
  }

  /// Ajoute une commande à l'historique et sauvegarde (avec timestamp pour TTL)
  /// Note: Utiliser addToHistoryIfSuccess() pour vérifier le code retour avant
  void addToHistory(String command) {
    if (command.trim().isEmpty) return;

    // NE JAMAIS enregistrer les commandes sensibles (mots de passe, tokens, etc.)
    if (_isSensitiveCommand(command)) {
      if (kDebugMode) debugPrint('SECURITY: Sensitive command NOT added to history');
      return;
    }

    // Éviter les doublons consécutifs
    if (state.commandHistory.isNotEmpty &&
        state.commandHistory.last == command) {
      return;
    }

    final newHistory = [...state.commandHistory, command];
    final newTimestamps = [..._historyTimestamps, DateTime.now().millisecondsSinceEpoch];

    // Limiter l'historique à 200 commandes
    if (newHistory.length > 200) {
      newHistory.removeAt(0);
      newTimestamps.removeAt(0);
    }

    _historyTimestamps = newTimestamps;
    state = state.copyWith(commandHistory: newHistory);

    // Sauvegarder l'historique avec timestamps (format V2)
    _saveHistoryV2(newHistory, newTimestamps);
  }

  /// Sauvegarde l'historique au format V2 (avec timestamps)
  void _saveHistoryV2(List<String> commands, List<int> timestamps) {
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < commands.length; i++) {
      entries.add({
        'c': commands[i],
        't': i < timestamps.length ? timestamps[i] : DateTime.now().millisecondsSinceEpoch,
      });
    }
    _storage.saveCommandHistoryV2(entries);
  }

  /// Efface complètement l'historique des commandes (utile pour reset après pollution)
  Future<void> clearCommandHistory() async {
    _historyTimestamps = [];
    state = state.copyWith(commandHistory: []);
    await _storage.saveCommandHistoryV2([]);
    if (kDebugMode) debugPrint('Command history cleared');
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
      if (kDebugMode) debugPrint('SECURITY: Sensitive input detected, NOT saving to history');
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
        if (kDebugMode) debugPrint('SECURITY: Password prompt detected, next input will NOT be saved');
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
        if (kDebugMode) debugPrint('ERROR DETECTED in output, command NOT added to history');
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
        if (kDebugMode) debugPrint('No error detected, adding command to history');
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
