# VibeTerm Phase 1 - Core Setup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Mettre en place les fondations de VibeTerm : models, services SSH, et écran Terminal fonctionnel avec données mockées.

**Architecture:** Feature-First + Riverpod. Les models définissent les structures de données partagées. Les services encapsulent la logique métier (SSH, stockage). L'UI consomme les providers Riverpod.

**Tech Stack:** Flutter 3.38+, Riverpod 2.4.9, dartssh2 3.0.0, xterm 5.1.0, flutter_secure_storage 9.0.0

---

## Tâches Parallélisables

Les tâches sont organisées en groupes. Les tâches d'un même groupe peuvent être exécutées en parallèle par des subagents.

---

## GROUPE A : Models & Providers (Agent 1)

### Task A1: Créer le model Session

**Files:**
- Create: `lib/models/session.dart`

**Step 1: Créer le fichier session.dart**

```dart
import 'package:flutter/foundation.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

@immutable
class Session {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final ConnectionStatus status;
  final String? tmuxSession;
  final DateTime? lastConnected;

  const Session({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.status = ConnectionStatus.disconnected,
    this.tmuxSession,
    this.lastConnected,
  });

  Session copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    ConnectionStatus? status,
    String? tmuxSession,
    DateTime? lastConnected,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      status: status ?? this.status,
      tmuxSession: tmuxSession ?? this.tmuxSession,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'tmuxSession': tmuxSession,
    'lastConnected': lastConnected?.toIso8601String(),
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    port: json['port'] as int? ?? 22,
    username: json['username'] as String,
    tmuxSession: json['tmuxSession'] as String?,
    lastConnected: json['lastConnected'] != null
        ? DateTime.parse(json['lastConnected'] as String)
        : null,
  );
}
```

**Step 2: Commit**

```bash
git add lib/models/session.dart
git commit -m "feat(models): add Session model with connection status"
```

---

### Task A2: Créer le model SSHKey

**Files:**
- Create: `lib/models/ssh_key.dart`

**Step 1: Créer le fichier ssh_key.dart**

```dart
import 'package:flutter/foundation.dart';

enum SSHKeyType { ed25519, rsa }

@immutable
class SSHKey {
  final String id;
  final String name;
  final String host;
  final SSHKeyType type;
  final String privateKey;
  final DateTime createdAt;
  final DateTime? lastUsed;

  const SSHKey({
    required this.id,
    required this.name,
    required this.host,
    required this.type,
    required this.privateKey,
    required this.createdAt,
    this.lastUsed,
  });

  SSHKey copyWith({
    String? id,
    String? name,
    String? host,
    SSHKeyType? type,
    String? privateKey,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return SSHKey(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      type: type ?? this.type,
      privateKey: privateKey ?? this.privateKey,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'host': host,
    'type': type.name,
    'privateKey': privateKey,
    'createdAt': createdAt.toIso8601String(),
    'lastUsed': lastUsed?.toIso8601String(),
  };

  factory SSHKey.fromJson(Map<String, dynamic> json) => SSHKey(
    id: json['id'] as String,
    name: json['name'] as String,
    host: json['host'] as String,
    type: SSHKeyType.values.byName(json['type'] as String),
    privateKey: json['privateKey'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastUsed: json['lastUsed'] != null
        ? DateTime.parse(json['lastUsed'] as String)
        : null,
  );

  String get typeLabel => type == SSHKeyType.ed25519 ? 'ED25519' : 'RSA';

  String get lastUsedLabel {
    if (lastUsed == null) return 'Jamais utilisée';
    final diff = DateTime.now().difference(lastUsed!);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays} jours';
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/ssh_key.dart
git commit -m "feat(models): add SSHKey model with Ed25519/RSA support"
```

---

### Task A3: Créer le model Command

**Files:**
- Create: `lib/models/command.dart`

**Step 1: Créer le fichier command.dart**

```dart
import 'package:flutter/foundation.dart';

@immutable
class Command {
  final String id;
  final String command;
  final String output;
  final Duration executionTime;
  final DateTime timestamp;
  final bool isRunning;

  const Command({
    required this.id,
    required this.command,
    this.output = '',
    this.executionTime = Duration.zero,
    required this.timestamp,
    this.isRunning = false,
  });

  Command copyWith({
    String? id,
    String? command,
    String? output,
    Duration? executionTime,
    DateTime? timestamp,
    bool? isRunning,
  }) {
    return Command(
      id: id ?? this.id,
      command: command ?? this.command,
      output: output ?? this.output,
      executionTime: executionTime ?? this.executionTime,
      timestamp: timestamp ?? this.timestamp,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  String get executionTimeLabel {
    if (executionTime.inMilliseconds < 1000) {
      return '${(executionTime.inMilliseconds / 1000).toStringAsFixed(3)}s';
    }
    return '${executionTime.inSeconds}.${(executionTime.inMilliseconds % 1000 ~/ 100)}s';
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/command.dart
git commit -m "feat(models): add Command model for terminal history"
```

---

### Task A4: Créer le model AppSettings

**Files:**
- Create: `lib/models/app_settings.dart`

**Step 1: Créer le fichier app_settings.dart**

```dart
import 'package:flutter/foundation.dart';

enum AppTheme { warpDark, dracula, nord }

@immutable
class AppSettings {
  final AppTheme theme;
  final bool autoConnectOnStart;
  final bool reconnectOnDisconnect;
  final bool notifyOnDisconnect;
  final bool biometricEnabled;

  const AppSettings({
    this.theme = AppTheme.warpDark,
    this.autoConnectOnStart = true,
    this.reconnectOnDisconnect = true,
    this.notifyOnDisconnect = false,
    this.biometricEnabled = false,
  });

  AppSettings copyWith({
    AppTheme? theme,
    bool? autoConnectOnStart,
    bool? reconnectOnDisconnect,
    bool? notifyOnDisconnect,
    bool? biometricEnabled,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      autoConnectOnStart: autoConnectOnStart ?? this.autoConnectOnStart,
      reconnectOnDisconnect: reconnectOnDisconnect ?? this.reconnectOnDisconnect,
      notifyOnDisconnect: notifyOnDisconnect ?? this.notifyOnDisconnect,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'autoConnectOnStart': autoConnectOnStart,
    'reconnectOnDisconnect': reconnectOnDisconnect,
    'notifyOnDisconnect': notifyOnDisconnect,
    'biometricEnabled': biometricEnabled,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme: AppTheme.values.byName(json['theme'] as String? ?? 'warpDark'),
    autoConnectOnStart: json['autoConnectOnStart'] as bool? ?? true,
    reconnectOnDisconnect: json['reconnectOnDisconnect'] as bool? ?? true,
    notifyOnDisconnect: json['notifyOnDisconnect'] as bool? ?? false,
    biometricEnabled: json['biometricEnabled'] as bool? ?? false,
  );
}
```

**Step 2: Commit**

```bash
git add lib/models/app_settings.dart
git commit -m "feat(models): add AppSettings model for user preferences"
```

---

### Task A5: Créer le barrel file models

**Files:**
- Create: `lib/models/models.dart`

**Step 1: Créer le barrel file**

```dart
export 'session.dart';
export 'ssh_key.dart';
export 'command.dart';
export 'app_settings.dart';
```

**Step 2: Commit**

```bash
git add lib/models/models.dart
git commit -m "feat(models): add barrel file for models"
```

---

### Task A6: Créer le SessionsProvider

**Files:**
- Create: `lib/features/terminal/providers/sessions_provider.dart`

**Step 1: Créer le provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';

class SessionsNotifier extends StateNotifier<List<Session>> {
  SessionsNotifier() : super([]);

  final _uuid = const Uuid();

  void addSession({
    required String name,
    required String host,
    required String username,
    int port = 22,
  }) {
    final session = Session(
      id: _uuid.v4(),
      name: name,
      host: host,
      port: port,
      username: username,
    );
    state = [...state, session];
  }

  void removeSession(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  void updateSessionStatus(String id, ConnectionStatus status) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(
          status: status,
          lastConnected: status == ConnectionStatus.connected
              ? DateTime.now()
              : s.lastConnected,
        );
      }
      return s;
    }).toList();
  }

  void updateTmuxSession(String id, String tmuxSession) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(tmuxSession: tmuxSession);
      }
      return s;
    }).toList();
  }
}

final sessionsProvider = StateNotifierProvider<SessionsNotifier, List<Session>>(
  (ref) => SessionsNotifier(),
);

final activeSessionIndexProvider = StateProvider<int>((ref) => 0);

final activeSessionProvider = Provider<Session?>((ref) {
  final sessions = ref.watch(sessionsProvider);
  final index = ref.watch(activeSessionIndexProvider);
  if (sessions.isEmpty || index >= sessions.length) return null;
  return sessions[index];
});
```

**Step 2: Commit**

```bash
git add lib/features/terminal/providers/sessions_provider.dart
git commit -m "feat(providers): add SessionsNotifier with Riverpod"
```

---

### Task A7: Créer le TerminalProvider

**Files:**
- Create: `lib/features/terminal/providers/terminal_provider.dart`

**Step 1: Créer le provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';

class TerminalState {
  final List<Command> commands;
  final String currentInput;
  final String? ghostText;

  const TerminalState({
    this.commands = const [],
    this.currentInput = '',
    this.ghostText,
  });

  TerminalState copyWith({
    List<Command>? commands,
    String? currentInput,
    String? ghostText,
  }) {
    return TerminalState(
      commands: commands ?? this.commands,
      currentInput: currentInput ?? this.currentInput,
      ghostText: ghostText,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalNotifier() : super(const TerminalState());

  final _uuid = const Uuid();

  void setInput(String input) {
    final ghost = _getSuggestion(input);
    state = state.copyWith(currentInput: input, ghostText: ghost);
  }

  void acceptGhostText() {
    if (state.ghostText != null) {
      state = state.copyWith(
        currentInput: state.currentInput + state.ghostText!,
        ghostText: null,
      );
    }
  }

  void executeCommand(String command) {
    if (command.trim().isEmpty) return;

    final cmd = Command(
      id: _uuid.v4(),
      command: command,
      timestamp: DateTime.now(),
      isRunning: true,
    );

    state = state.copyWith(
      commands: [...state.commands, cmd],
      currentInput: '',
      ghostText: null,
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

  String? _getSuggestion(String input) {
    if (input.isEmpty) return null;

    const suggestions = {
      'git': ' status',
      'git s': 'tatus',
      'git c': 'ommit -m ""',
      'git p': 'ush',
      'git pull': ' origin main',
      'cd': ' ~/',
      'ls': ' -la',
      'npm': ' run dev',
      'npm i': 'nstall',
      'docker': ' compose up -d',
    };

    final lower = input.toLowerCase();
    for (final entry in suggestions.entries) {
      if (entry.key == lower) return entry.value;
    }
    return null;
  }
}

final terminalProvider = StateNotifierProvider<TerminalNotifier, TerminalState>(
  (ref) => TerminalNotifier(),
);
```

**Step 2: Commit**

```bash
git add lib/features/terminal/providers/terminal_provider.dart
git commit -m "feat(providers): add TerminalNotifier with ghost text support"
```

---

### Task A8: Créer le barrel file providers

**Files:**
- Create: `lib/features/terminal/providers/providers.dart`

**Step 1: Créer le barrel file**

```dart
export 'sessions_provider.dart';
export 'terminal_provider.dart';
```

**Step 2: Commit**

```bash
git add lib/features/terminal/providers/providers.dart
git commit -m "feat(providers): add barrel file for terminal providers"
```

---

## GROUPE B : UI Terminal (Agent 2)

### Task B1: Créer le widget SessionTabBar

**Files:**
- Create: `lib/features/terminal/widgets/session_tab_bar.dart`

**Dépend de:** Task A1 (Session model), Task A6 (SessionsProvider)

**Step 1: Créer le widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../models/models.dart';
import '../providers/providers.dart';

class SessionTabBar extends ConsumerWidget {
  const SessionTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final activeIndex = ref.watch(activeSessionIndexProvider);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(width: VibeTermSpacing.xs),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = index == activeIndex;
                return _SessionTab(
                  session: session,
                  isActive: isActive,
                  onTap: () => ref.read(activeSessionIndexProvider.notifier).state = index,
                );
              },
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          _AddSessionButton(
            onTap: () {
              // TODO: Ouvrir dialog pour nouvelle session
              ref.read(sessionsProvider.notifier).addSession(
                name: 'Session ${sessions.length + 1}',
                host: 'localhost',
                username: 'user',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  final Session session;
  final bool isActive;
  final VoidCallback onTap;

  const _SessionTab({
    required this.session,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.sm,
          vertical: VibeTermSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? VibeTermColors.accent : VibeTermColors.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(
            color: isActive ? VibeTermColors.accent : VibeTermColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusDot(status: session.status),
            const SizedBox(width: VibeTermSpacing.xs),
            Text(
              session.name,
              style: VibeTermTypography.tabText.copyWith(
                color: isActive ? VibeTermColors.bg : VibeTermColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ConnectionStatus status;

  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ConnectionStatus.connected:
        color = VibeTermColors.success;
        break;
      case ConnectionStatus.connecting:
        color = VibeTermColors.warning;
        break;
      case ConnectionStatus.error:
        color = VibeTermColors.danger;
        break;
      case ConnectionStatus.disconnected:
        color = VibeTermColors.textMuted;
        break;
    }

    return Container(
      width: VibeTermSizes.statusDotSmall,
      height: VibeTermSizes.statusDotSmall,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AddSessionButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSessionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: VibeTermColors.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(color: VibeTermColors.border),
        ),
        child: const Icon(
          Icons.add,
          color: VibeTermColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/terminal/widgets/session_tab_bar.dart
git commit -m "feat(ui): add SessionTabBar widget with status indicators"
```

---

### Task B2: Créer le widget SessionInfoBar

**Files:**
- Create: `lib/features/terminal/widgets/session_info_bar.dart`

**Step 1: Créer le widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../providers/providers.dart';

class SessionInfoBar extends ConsumerWidget {
  const SessionInfoBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.xs,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VibeTermColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '←',
            style: TextStyle(color: VibeTermColors.textMuted, fontSize: 12),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Text(
            'tmux: ',
            style: VibeTermTypography.caption.copyWith(
              color: VibeTermColors.textMuted,
            ),
          ),
          Text(
            session.tmuxSession ?? 'vibe',
            style: VibeTermTypography.caption.copyWith(
              color: VibeTermColors.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Text(
            '•',
            style: VibeTermTypography.caption.copyWith(
              color: VibeTermColors.textMuted,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Text(
            session.host,
            style: VibeTermTypography.caption.copyWith(
              color: VibeTermColors.text,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: VibeTermSpacing.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: VibeTermColors.accentDim,
              borderRadius: BorderRadius.circular(VibeTermRadius.xs),
            ),
            child: Text(
              'Tailscale',
              style: VibeTermTypography.caption.copyWith(
                color: VibeTermColors.accent,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/terminal/widgets/session_info_bar.dart
git commit -m "feat(ui): add SessionInfoBar widget with tmux info"
```

---

### Task B3: Créer le widget CommandBlock

**Files:**
- Create: `lib/features/terminal/widgets/command_block.dart`

**Step 1: Créer le widget**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../models/models.dart';

class CommandBlock extends StatelessWidget {
  final Command command;

  const CommandBlock({super.key, required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: VibeTermSpacing.sm),
      decoration: BoxDecoration(
        color: VibeTermColors.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: VibeTermColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommandHeader(command: command),
          if (command.output.isNotEmpty || command.isRunning)
            _CommandOutput(command: command),
        ],
      ),
    );
  }
}

class _CommandHeader extends StatelessWidget {
  final Command command;

  const _CommandHeader({required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeTermSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VibeTermColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Text(
            '❯',
            style: VibeTermTypography.prompt.copyWith(
              color: VibeTermColors.accent,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Expanded(
            child: Text(
              command.command,
              style: VibeTermTypography.commandHeader,
            ),
          ),
          if (command.isRunning)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VibeTermColors.accent,
              ),
            )
          else
            Text(
              command.executionTimeLabel,
              style: VibeTermTypography.caption.copyWith(
                color: VibeTermColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandOutput extends StatelessWidget {
  final Command command;

  const _CommandOutput({required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VibeTermSpacing.sm),
      child: command.isRunning && command.output.isEmpty
          ? Text(
              '...',
              style: VibeTermTypography.terminalOutput.copyWith(
                color: VibeTermColors.textMuted,
              ),
            )
          : Text(
              command.output,
              style: VibeTermTypography.terminalOutput,
            ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/terminal/widgets/command_block.dart
git commit -m "feat(ui): add CommandBlock widget with header and output"
```

---

### Task B4: Créer le widget GhostTextInput

**Files:**
- Create: `lib/features/terminal/widgets/ghost_text_input.dart`

**Step 1: Créer le widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../providers/providers.dart';

class GhostTextInput extends ConsumerStatefulWidget {
  const GhostTextInput({super.key});

  @override
  ConsumerState<GhostTextInput> createState() => _GhostTextInputState();
}

class _GhostTextInputState extends ConsumerState<GhostTextInput> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final terminalNotifier = ref.read(terminalProvider.notifier);
    final input = _controller.text.trim();

    if (input.isNotEmpty) {
      terminalNotifier.executeCommand(input);
      _controller.clear();
    }
  }

  void _acceptGhost() {
    final state = ref.read(terminalProvider);
    if (state.ghostText != null) {
      ref.read(terminalProvider.notifier).acceptGhostText();
      _controller.text = state.currentInput + state.ghostText!;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);

    return Container(
      padding: const EdgeInsets.all(VibeTermSpacing.sm),
      decoration: const BoxDecoration(
        color: VibeTermColors.bgBlock,
        border: Border(
          top: BorderSide(color: VibeTermColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              '❯',
              style: VibeTermTypography.prompt.copyWith(
                color: VibeTermColors.accent,
              ),
            ),
            const SizedBox(width: VibeTermSpacing.xs),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 100) {
                    _acceptGhost();
                  }
                },
                child: Stack(
                  children: [
                    // Ghost text layer
                    if (terminalState.ghostText != null)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            terminalState.currentInput + terminalState.ghostText!,
                            style: VibeTermTypography.input.copyWith(
                              color: VibeTermColors.ghost,
                            ),
                          ),
                        ),
                      ),
                    // Input field
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: VibeTermTypography.input,
                      decoration: InputDecoration(
                        hintText: 'Run commands',
                        hintStyle: VibeTermTypography.input.copyWith(
                          color: VibeTermColors.textMuted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        ref.read(terminalProvider.notifier).setInput(value);
                      },
                      onSubmitted: (_) => _onSubmit(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: VibeTermSpacing.xs),
            _SendButton(onTap: _onSubmit),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: VibeTermSizes.sendButton,
        height: VibeTermSizes.sendButton,
        decoration: BoxDecoration(
          color: VibeTermColors.accent,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        ),
        child: const Icon(
          Icons.arrow_upward,
          color: VibeTermColors.bg,
          size: 24,
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/terminal/widgets/ghost_text_input.dart
git commit -m "feat(ui): add GhostTextInput widget with swipe completion"
```

---

### Task B5: Créer le widget AppHeader

**Files:**
- Create: `lib/shared/widgets/app_header.dart`

**Step 1: Créer le widget**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../../features/terminal/providers/providers.dart';

class AppHeader extends ConsumerWidget {
  final VoidCallback? onTerminalTap;
  final VoidCallback? onSettingsTap;
  final bool isTerminalActive;

  const AppHeader({
    super.key,
    this.onTerminalTap,
    this.onSettingsTap,
    this.isTerminalActive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: VibeTermColors.bg,
        border: Border(
          bottom: BorderSide(color: VibeTermColors.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Logo
            Container(
              width: VibeTermSizes.logo,
              height: VibeTermSizes.logo,
              decoration: BoxDecoration(
                color: VibeTermColors.accent,
                borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              ),
              child: const Center(
                child: Text(
                  '⌘',
                  style: TextStyle(
                    color: VibeTermColors.bg,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            // Title & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VibeTerm',
                    style: VibeTermTypography.appTitle,
                  ),
                  if (session != null)
                    Row(
                      children: [
                        Container(
                          width: VibeTermSizes.statusDotSmall,
                          height: VibeTermSizes.statusDotSmall,
                          decoration: BoxDecoration(
                            color: session.status == ConnectionStatus.connected
                                ? VibeTermColors.success
                                : VibeTermColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.host,
                          style: VibeTermTypography.caption.copyWith(
                            color: VibeTermColors.accent,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Nav buttons
            _NavButton(
              icon: Icons.terminal,
              isActive: isTerminalActive,
              onTap: onTerminalTap,
            ),
            const SizedBox(width: VibeTermSpacing.xs),
            _NavButton(
              icon: Icons.settings,
              isActive: !isTerminalActive,
              onTap: onSettingsTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: VibeTermSizes.navButton,
        height: VibeTermSizes.navButton,
        decoration: BoxDecoration(
          color: isActive ? VibeTermColors.bgElevated : VibeTermColors.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(
            color: isActive ? VibeTermColors.accent : VibeTermColors.border,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? VibeTermColors.accent : VibeTermColors.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
```

**Step 2: Ajouter import ConnectionStatus**

Ajouter en haut du fichier :
```dart
import '../../models/models.dart';
```

**Step 3: Commit**

```bash
git add lib/shared/widgets/app_header.dart
git commit -m "feat(ui): add AppHeader widget with logo and nav buttons"
```

---

### Task B6: Créer le barrel file widgets terminal

**Files:**
- Create: `lib/features/terminal/widgets/widgets.dart`

**Step 1: Créer le barrel file**

```dart
export 'session_tab_bar.dart';
export 'session_info_bar.dart';
export 'command_block.dart';
export 'ghost_text_input.dart';
```

**Step 2: Commit**

```bash
git add lib/features/terminal/widgets/widgets.dart
git commit -m "feat(ui): add barrel file for terminal widgets"
```

---

### Task B7: Créer le TerminalScreen

**Files:**
- Create: `lib/features/terminal/screens/terminal_screen.dart`

**Step 1: Créer l'écran**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/app_header.dart';
import '../providers/providers.dart';
import '../widgets/widgets.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  @override
  void initState() {
    super.initState();
    // Ajouter une session de démo au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessions = ref.read(sessionsProvider);
      if (sessions.isEmpty) {
        ref.read(sessionsProvider.notifier).addSession(
          name: 'workstation',
          host: 'workstation.local',
          username: 'vibe',
        );
        ref.read(sessionsProvider.notifier).updateSessionStatus(
          ref.read(sessionsProvider).first.id,
          ConnectionStatus.connected,
        );

        // Ajouter des commandes de démo
        _addDemoCommands();
      }
    });
  }

  void _addDemoCommands() {
    final notifier = ref.read(terminalProvider.notifier);

    // Simuler des commandes exécutées
    notifier.executeCommand('ssh vibe@workstation.local');
    Future.delayed(const Duration(milliseconds: 100), () {
      final commands = ref.read(terminalProvider).commands;
      if (commands.isNotEmpty) {
        notifier.updateCommandOutput(
          commands.first.id,
          '🔐 Connected to workstation.local via Tailscale\n   Session: tmux attach -t vibe',
          isComplete: true,
          executionTime: const Duration(milliseconds: 24),
        );
      }
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      notifier.executeCommand('git pull origin main');
      Future.delayed(const Duration(milliseconds: 100), () {
        final commands = ref.read(terminalProvider).commands;
        if (commands.length > 1) {
          notifier.updateCommandOutput(
            commands[1].id,
            'remote: Enumerating objects: 47, done.\nremote: Counting objects: 100% (47/47)\nFrom github.com:team/vibeterm\n   a3f2c1d..b7e9f4a  main → origin/main',
            isComplete: true,
            executionTime: const Duration(milliseconds: 1283),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final terminalState = ref.watch(terminalProvider);

    return Scaffold(
      backgroundColor: VibeTermColors.bg,
      body: Column(
        children: [
          AppHeader(
            isTerminalActive: true,
            onSettingsTap: () {
              // TODO: Navigation vers Settings
            },
          ),
          const SessionTabBar(),
          const SessionInfoBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(VibeTermSpacing.sm),
              itemCount: terminalState.commands.length,
              itemBuilder: (context, index) {
                return CommandBlock(command: terminalState.commands[index]);
              },
            ),
          ),
          const GhostTextInput(),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/features/terminal/screens/terminal_screen.dart
git commit -m "feat(ui): add TerminalScreen with demo data"
```

---

### Task B8: Mettre à jour main.dart

**Files:**
- Modify: `lib/main.dart`

**Step 1: Mettre à jour main.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/terminal/screens/terminal_screen.dart';

void main() {
  runApp(const ProviderScope(child: VibeTermApp()));
}

class VibeTermApp extends StatelessWidget {
  const VibeTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeTerm',
      debugShowCheckedModeBanner: false,
      theme: VibeTermTheme.dark,
      home: const TerminalScreen(),
    );
  }
}
```

**Step 2: Commit**

```bash
git add lib/main.dart
git commit -m "feat: update main.dart to use TerminalScreen"
```

---

## GROUPE C : Services (Agent 3 - Optionnel, peut être fait après)

### Task C1: Créer le SSHService

**Files:**
- Create: `lib/services/ssh_service.dart`

**Step 1: Créer le service**

```dart
import 'package:dartssh2/dartssh2.dart';

enum SSHError {
  connectionFailed,
  authenticationFailed,
  keyNotFound,
  timeout,
  hostUnreachable,
  tmuxError,
}

class SSHException implements Exception {
  final SSHError error;
  final String message;

  SSHException(this.error, this.message);

  String get userMessage {
    switch (error) {
      case SSHError.connectionFailed:
        return 'Connexion impossible. Vérifiez l\'adresse du serveur.';
      case SSHError.authenticationFailed:
        return 'Authentification échouée. Vérifiez votre clé SSH.';
      case SSHError.keyNotFound:
        return 'Aucune clé SSH configurée pour cet hôte.';
      case SSHError.timeout:
        return 'Délai d\'attente dépassé.';
      case SSHError.hostUnreachable:
        return 'Serveur injoignable. Vérifiez Tailscale.';
      case SSHError.tmuxError:
        return 'Erreur tmux. La session n\'a pas pu être créée.';
    }
  }
}

class SSHService {
  SSHClient? _client;
  SSHSession? _session;

  Future<bool> connect({
    required String host,
    required String username,
    required String privateKey,
    int port = 22,
  }) async {
    try {
      final key = SSHKeyPair.fromPem(privateKey);
      _client = SSHClient(
        await SSHSocket.connect(host, port),
        username: username,
        identities: [key],
      );
      await _client!.authenticated;
      return true;
    } catch (e) {
      throw SSHException(
        SSHError.connectionFailed,
        'SSH Error: $e',
      );
    }
  }

  Future<SSHSession?> startShell() async {
    if (_client == null) return null;

    try {
      _session = await _client!.shell(
        pty: SSHPtyConfig(type: 'xterm-256color', width: 80, height: 24),
      );
      return _session;
    } catch (e) {
      throw SSHException(SSHError.connectionFailed, 'Shell Error: $e');
    }
  }

  Future<void> disconnect() async {
    await _session?.close();
    _client?.close();
    _client = null;
    _session = null;
  }

  bool get isConnected => _client != null;

  SSHSession? get session => _session;
}
```

**Step 2: Commit**

```bash
git add lib/services/ssh_service.dart
git commit -m "feat(services): add SSHService with dartssh2"
```

---

### Task C2: Créer le StorageService

**Files:**
- Create: `lib/services/storage_service.dart`

**Step 1: Créer le service**

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class StorageService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // SSH Keys
  Future<void> saveSSHKey(SSHKey key) async {
    final keys = await getSSHKeys();
    final existingIndex = keys.indexWhere((k) => k.id == key.id);

    if (existingIndex >= 0) {
      keys[existingIndex] = key;
    } else {
      keys.add(key);
    }

    await _storage.write(
      key: 'ssh_keys',
      value: jsonEncode(keys.map((k) => k.toJson()).toList()),
    );
  }

  Future<List<SSHKey>> getSSHKeys() async {
    final data = await _storage.read(key: 'ssh_keys');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((json) => SSHKey.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<SSHKey?> getSSHKeyForHost(String host) async {
    final keys = await getSSHKeys();
    try {
      return keys.firstWhere((k) => k.host == host);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSSHKey(String id) async {
    final keys = await getSSHKeys();
    keys.removeWhere((k) => k.id == id);
    await _storage.write(
      key: 'ssh_keys',
      value: jsonEncode(keys.map((k) => k.toJson()).toList()),
    );
  }

  Future<void> deleteAllKeys() async {
    await _storage.delete(key: 'ssh_keys');
  }

  // App Settings
  Future<void> saveSettings(AppSettings settings) async {
    await _storage.write(
      key: 'app_settings',
      value: jsonEncode(settings.toJson()),
    );
  }

  Future<AppSettings> getSettings() async {
    final data = await _storage.read(key: 'app_settings');
    if (data == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/storage_service.dart
git commit -m "feat(services): add StorageService with flutter_secure_storage"
```

---

### Task C3: Créer le barrel file services

**Files:**
- Create: `lib/services/services.dart`

**Step 1: Créer le barrel file**

```dart
export 'ssh_service.dart';
export 'storage_service.dart';
```

**Step 2: Commit**

```bash
git add lib/services/services.dart
git commit -m "feat(services): add barrel file for services"
```

---

## Résumé de l'Exécution

| Groupe | Agent | Tâches | Dépendances |
|--------|-------|--------|-------------|
| A | Agent 1 | A1-A8 (Models & Providers) | Aucune |
| B | Agent 2 | B1-B8 (UI Terminal) | Dépend de A |
| C | Agent 3 | C1-C3 (Services) | Dépend de A |

**Ordre recommandé :**
1. Lancer Agent 1 (Groupe A) - Models & Providers
2. Une fois A terminé, lancer Agent 2 (Groupe B) et Agent 3 (Groupe C) en parallèle
3. Commit final et test de l'app

---

## Vérification Finale

Après toutes les tâches :

```bash
flutter analyze
flutter run
```

L'app devrait afficher :
- Header avec logo VibeTerm
- Tab bar avec un onglet "workstation"
- Info bar avec tmux info
- 2 command blocks de démo
- Input field avec ghost text fonctionnel
