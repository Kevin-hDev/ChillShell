import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/storage_service.dart';

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

class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalNotifier() : super(const TerminalState()) {
    _loadHistory();
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
    final ghost = _getSuggestion(input);
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

  /// Ajoute une commande à l'historique et sauvegarde
  void addToHistory(String command) {
    if (command.trim().isEmpty) return;

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


  String? _getSuggestion(String input) {
    if (input.isEmpty) return null;

    final lower = input.toLowerCase().trim();

    // 1. Chercher d'abord dans l'historique des commandes
    for (final cmd in state.commandHistory.reversed) {
      if (cmd.toLowerCase().startsWith(lower) && cmd.length > input.length) {
        return cmd.substring(input.length);
      }
    }

    // 2. Suggestions prédéfinies par catégorie
    const suggestions = <String, String>{
      // Git
      'git': ' status',
      'git s': 'tatus',
      'git st': 'atus',
      'git c': 'ommit -m ""',
      'git co': 'mmit -m ""',
      'git com': 'mit -m ""',
      'git p': 'ush',
      'git pu': 'sh',
      'git pul': 'l',
      'git pull': ' origin main',
      'git ch': 'eckout ',
      'git che': 'ckout ',
      'git b': 'ranch',
      'git br': 'anch',
      'git a': 'dd .',
      'git ad': 'd .',
      'git l': 'og --oneline',
      'git lo': 'g --oneline',
      'git d': 'iff',
      'git di': 'ff',
      'git m': 'erge ',
      'git r': 'ebase ',
      'git f': 'etch',
      'git fe': 'tch',
      'git cl': 'one ',

      // Navigation
      'cd': ' ~/',
      'cd .': './',
      'ls': ' -la',
      'ls -': 'la',
      'pwd': '',
      'll': '',
      'la': '',

      // Fichiers
      'cat': ' ',
      'less': ' ',
      'head': ' -n 20 ',
      'tail': ' -f ',
      'grep': ' -r "" .',
      'find': ' . -name ""',
      'mkdir': ' -p ',
      'rm': ' -rf ',
      'cp': ' -r ',
      'mv': ' ',
      'touch': ' ',
      'chmod': ' +x ',

      // NPM/Node
      'npm': ' run ',
      'npm r': 'un ',
      'npm ru': 'n ',
      'npm run': ' dev',
      'npm i': 'nstall',
      'npm in': 'stall',
      'npm ins': 'tall',
      'npm install': ' ',
      'npm start': '',
      'npm t': 'est',
      'npm te': 'st',
      'node': ' ',
      'npx': ' ',

      // Yarn
      'yarn': ' ',
      'yarn a': 'dd ',
      'yarn ad': 'd ',
      'yarn d': 'ev',
      'yarn de': 'v',
      'yarn i': 'nstall',
      'yarn in': 'stall',

      // Python
      'python': '3 ',
      'python3': ' ',
      'pip': ' install ',
      'pip i': 'nstall ',
      'pip in': 'stall ',
      'pip install': ' ',
      'venv': '',
      'source': ' venv/bin/activate',
      'pytest': ' -v',

      // Docker
      'docker': ' ',
      'docker p': 's',
      'docker ps': ' -a',
      'docker c': 'ompose ',
      'docker co': 'mpose ',
      'docker com': 'pose ',
      'docker comp': 'ose ',
      'docker compo': 'se ',
      'docker compos': 'e ',
      'docker compose': ' up -d',
      'docker compose u': 'p -d',
      'docker compose up': ' -d',
      'docker b': 'uild ',
      'docker bu': 'ild ',
      'docker r': 'un ',
      'docker ru': 'n ',
      'docker i': 'mages',
      'docker im': 'ages',
      'docker l': 'ogs ',
      'docker lo': 'gs ',
      'docker e': 'xec -it ',
      'docker ex': 'ec -it ',

      // Système
      'sudo': ' ',
      'apt': ' update',
      'apt u': 'pdate',
      'apt up': 'date',
      'apt upd': 'ate',
      'apt upda': 'te',
      'apt updat': 'e',
      'apt i': 'nstall ',
      'apt in': 'stall ',
      'apt ins': 'tall ',
      'apt inst': 'all ',
      'apt insta': 'll ',
      'apt instal': 'l ',
      'systemctl': ' status ',
      'systemctl s': 'tatus ',
      'systemctl st': 'atus ',
      'systemctl sta': 'tus ',
      'systemctl stat': 'us ',
      'systemctl statu': 's ',
      'journalctl': ' -xe',
      'htop': '',
      'top': '',
      'ps': ' aux',
      'ps a': 'ux',
      'ps au': 'x',
      'kill': ' -9 ',
      'killall': ' ',

      // Réseau
      'curl': ' -X GET ',
      'wget': ' ',
      'ping': ' ',
      'ssh': ' ',
      'scp': ' ',
      'netstat': ' -tulpn',
      'ss': ' -tulpn',

      // Tmux
      'tmux': ' ',
      'tmux n': 'ew-session -s ',
      'tmux ne': 'w-session -s ',
      'tmux new': '-session -s ',
      'tmux a': 'ttach -t ',
      'tmux at': 'tach -t ',
      'tmux att': 'ach -t ',
      'tmux atta': 'ch -t ',
      'tmux attac': 'h -t ',
      'tmux l': 'ist-sessions',
      'tmux li': 'st-sessions',
      'tmux lis': 't-sessions',
      'tmux k': 'ill-session -t ',
      'tmux ki': 'll-session -t ',

      // Éditeurs
      'vim': ' ',
      'vi': ' ',
      'nano': ' ',
      'code': ' .',
      'code .': '',

      // Flutter
      'flutter': ' ',
      'flutter r': 'un',
      'flutter ru': 'n',
      'flutter p': 'ub get',
      'flutter pu': 'b get',
      'flutter pub': ' get',
      'flutter pub g': 'et',
      'flutter pub ge': 't',
      'flutter b': 'uild ',
      'flutter bu': 'ild ',
      'flutter bui': 'ld ',
      'flutter buil': 'd ',
      'flutter t': 'est',
      'flutter te': 'st',
      'flutter tes': 't',
      'flutter c': 'lean',
      'flutter cl': 'ean',
      'flutter cle': 'an',
      'flutter clea': 'n',
      'flutter a': 'nalyze',
      'flutter an': 'alyze',
      'dart': ' ',
      'dart r': 'un ',
      'dart ru': 'n ',
      'dart f': 'ormat .',
      'dart fo': 'rmat .',
      'dart for': 'mat .',
      'dart form': 'at .',
      'dart forma': 't .',

      // Rust
      'cargo': ' ',
      'cargo b': 'uild',
      'cargo bu': 'ild',
      'cargo bui': 'ld',
      'cargo buil': 'd',
      'cargo r': 'un',
      'cargo ru': 'n',
      'cargo t': 'est',
      'cargo te': 'st',
      'cargo tes': 't',
      'cargo c': 'heck',
      'cargo ch': 'eck',
      'cargo che': 'ck',
      'cargo chec': 'k',
      'rustc': ' ',

      // Go
      'go': ' ',
      'go b': 'uild',
      'go bu': 'ild',
      'go bui': 'ld',
      'go buil': 'd',
      'go r': 'un .',
      'go ru': 'n .',
      'go t': 'est ./...',
      'go te': 'st ./...',
      'go tes': 't ./...',
      'go m': 'od ',
      'go mo': 'd ',
      'go mod': ' tidy',
      'go mod t': 'idy',
      'go mod ti': 'dy',
      'go mod tid': 'y',
    };

    for (final entry in suggestions.entries) {
      if (entry.key == lower) {
        return entry.value;
      }
    }

    return null;
  }
}

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) => TerminalNotifier(),
);
