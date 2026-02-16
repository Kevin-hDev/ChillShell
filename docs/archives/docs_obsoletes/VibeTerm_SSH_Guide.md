# 🔌 VibeTerm - Guide SSH & tmux

> Snippets pour l'implémentation de la connexion SSH avec dartssh2

---

## 1. Connexion SSH avec clé Ed25519

```dart
import 'package:dartssh2/dartssh2.dart';

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
      print('SSH Error: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _session?.close();
    _client?.close();
    _client = null;
  }

  bool get isConnected => _client != null;
}
```

---

## 2. Intégration tmux

```dart
class TmuxService {
  final SSHService _ssh;
  TmuxService(this._ssh);
  
  static const String attachCommand = 'tmux attach -t vibe || tmux new -s vibe';
  
  Future<SSHSession?> initTmuxSession() async {
    if (_ssh._client == null) return null;
    
    try {
      final session = await _ssh._client!.shell(
        pty: SSHPtyConfig(type: 'xterm-256color', width: 80, height: 24),
      );
      
      // Configurer la locale française
      session.write(utf8.encode('export LANG=fr_FR.UTF-8\n'));
      // Attacher à tmux
      session.write(utf8.encode('$attachCommand\n'));
      
      return session;
    } catch (e) {
      print('Tmux Error: $e');
      return null;
    }
  }
  
  Future<void> resize(SSHSession session, int width, int height) async {
    session.resizeTerminal(width, height);
  }
}

// Commandes tmux utiles
class TmuxCommands {
  static const String listSessions = 'tmux list-sessions';
  static String newSession(String name) => 'tmux new -s $name';
  static String attach(String name) => 'tmux attach -t $name';
  static const String detach = 'tmux detach';
  static String killSession(String name) => 'tmux kill-session -t $name';
}
```

---

## 3. Intégration xterm.dart

```dart
import 'package:xterm/xterm.dart';
import 'dart:convert';

class TerminalController {
  late Terminal terminal;
  SSHSession? _session;
  
  void init() {
    terminal = Terminal(maxLines: 10000);
  }
  
  void attachToSession(SSHSession session) {
    _session = session;
    
    session.stdout.listen((data) {
      terminal.write(utf8.decode(data));
    });
    
    session.stderr.listen((data) {
      terminal.write(utf8.decode(data));
    });
  }
  
  void sendCommand(String command) {
    _session?.write(utf8.encode('$command\n'));
  }
  
  void sendChar(String char) {
    _session?.write(utf8.encode(char));
  }
}
```

---

## 4. Ghost Text (Autocomplétion)

```dart
class CommandSuggestions {
  static const Map<String, String> suggestions = {
    'git': ' status',
    'git s': 'tatus',
    'git c': 'ommit -m ""',
    'git p': 'ush',
    'cd': ' ~/',
    'ls': ' -la',
    'npm': ' run dev',
    'npm i': 'nstall',
    'docker': ' compose up -d',
    'ssh': ' user@host',
    'tail': ' -f ',
  };
  
  static String? getSuggestion(String input) {
    if (input.isEmpty) return null;
    final lower = input.toLowerCase();
    for (final entry in suggestions.entries) {
      if (entry.key == lower) return entry.value;
    }
    return null;
  }
}
```

---

## 5. Stockage Sécurisé

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class StorageService {
  final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  
  Future<void> saveSSHKey(SSHKey key) async {
    final keys = await getSSHKeys();
    keys.add(key);
    await _storage.write(
      key: 'ssh_keys',
      value: jsonEncode(keys.map((k) => k.toJson()).toList()),
    );
  }
  
  Future<List<SSHKey>> getSSHKeys() async {
    final data = await _storage.read(key: 'ssh_keys');
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((json) => SSHKey.fromJson(json)).toList();
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
}
```

---

## 6. Authentification Biométrique

```dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final _auth = LocalAuthentication();
  
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authentifiez-vous pour accéder à VibeTerm',
        options: AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
    } catch (e) {
      return false;
    }
  }
}
```

---

## 7. Gestion des Erreurs

```dart
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
```
