# Implémentation Fonctionnelle - Plan

> **Pour Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rendre VibeTerm fonctionnel avec connexion SSH réelle, génération de clés, terminal xterm.dart et biométrie.

**Architecture:** Services + Providers Riverpod + Widgets connectés

**Tech Stack:** dartssh2, xterm.dart, flutter_secure_storage, local_auth

---

## Task 1: SSH Provider avec connexion réelle

**Files:**
- Create: `lib/features/terminal/providers/ssh_provider.dart`
- Modify: `lib/services/ssh_service.dart`

**Objectif:** Créer un provider qui gère l'état de connexion SSH et permet de se connecter/déconnecter.

**Code SSHProvider:**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/ssh_service.dart';
import '../../../models/models.dart';

enum SSHConnectionState { disconnected, connecting, connected, error }

class SSHState {
  final SSHConnectionState connectionState;
  final String? errorMessage;
  final Session? activeSession;

  const SSHState({
    this.connectionState = SSHConnectionState.disconnected,
    this.errorMessage,
    this.activeSession,
  });

  SSHState copyWith({...});
}

class SSHNotifier extends StateNotifier<SSHState> {
  final SSHService _sshService = SSHService();

  Future<bool> connect(Session session, String privateKey) async {...}
  Future<void> disconnect() async {...}
  void sendCommand(String command) {...}
}
```

---

## Task 2: Génération réelle de clés SSH

**Files:**
- Create: `lib/services/key_generation_service.dart`
- Modify: `lib/features/settings/widgets/add_ssh_key_sheet.dart`

**Objectif:** Générer de vraies paires de clés Ed25519/RSA avec dartssh2.

**Code KeyGenerationService:**
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';

class KeyGenerationService {
  /// Génère une paire de clés Ed25519
  static Future<Map<String, String>> generateEd25519(String comment) async {
    final keyPair = SSHKeyPair.ed25519();
    return {
      'privateKey': keyPair.toPem(),
      'publicKey': keyPair.toPublicKey().toOpenSSH(comment: comment),
    };
  }

  /// Génère une paire de clés RSA 4096 bits
  static Future<Map<String, String>> generateRSA4096(String comment) async {
    final keyPair = SSHKeyPair.rsa(4096);
    return {
      'privateKey': keyPair.toPem(),
      'publicKey': keyPair.toPublicKey().toOpenSSH(comment: comment),
    };
  }
}
```

---

## Task 3: Stockage sécurisé des clés

**Files:**
- Create: `lib/services/secure_storage_service.dart`
- Modify: `lib/features/settings/providers/settings_provider.dart`

**Objectif:** Sauvegarder/charger les clés SSH depuis flutter_secure_storage.

**Code SecureStorageService:**
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../models/models.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _keysKey = 'ssh_keys';

  static Future<void> saveKeys(List<SSHKey> keys) async {...}
  static Future<List<SSHKey>> loadKeys() async {...}
  static Future<void> deleteKey(String id) async {...}
  static Future<String?> getPrivateKey(String keyId) async {...}
}
```

---

## Task 4: Intégration xterm.dart

**Files:**
- Create: `lib/features/terminal/widgets/terminal_view.dart`
- Modify: `lib/features/terminal/screens/terminal_screen.dart`

**Objectif:** Remplacer les blocs de commandes par un vrai terminal xterm.dart connecté au SSH.

**Code TerminalView:**
```dart
import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TerminalView extends ConsumerStatefulWidget {
  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  late Terminal terminal;
  late TerminalController terminalController;

  @override
  void initState() {
    super.initState();
    terminal = Terminal(maxLines: 10000);
    terminalController = TerminalController();
    _connectToSSH();
  }

  void _connectToSSH() {
    // Connecter le terminal au flux SSH
  }

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      terminal: terminal,
      controller: terminalController,
      theme: TerminalTheme(...),
    );
  }
}
```

---

## Task 5: Connexion Terminal ↔ SSH Stream

**Files:**
- Modify: `lib/features/terminal/widgets/terminal_view.dart`
- Modify: `lib/services/ssh_service.dart`

**Objectif:** Connecter les flux stdin/stdout du SSH au terminal xterm.

**Code:**
```dart
// Dans SSHService
Stream<Uint8List> get outputStream => _session!.stdout;
StreamSink<Uint8List> get inputSink => _session!.stdin;

// Dans TerminalView
void _connectToSSH() {
  final sshService = ref.read(sshServiceProvider);

  // SSH output → Terminal
  sshService.outputStream.listen((data) {
    terminal.write(String.fromCharCodes(data));
  });

  // Terminal input → SSH
  terminal.onOutput = (data) {
    sshService.inputSink.add(Uint8List.fromList(data.codeUnits));
  };
}
```

---

## Task 6: Authentification biométrique

**Files:**
- Create: `lib/services/biometric_service.dart`
- Create: `lib/features/auth/screens/lock_screen.dart`
- Modify: `lib/main.dart`

**Objectif:** Ajouter un écran de verrouillage avec authentification biométrique.

**Code BiometricService:**
```dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
  }

  static Future<bool> authenticate() async {
    return await _auth.authenticate(
      localizedReason: 'Déverrouillez VibeTerm',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
  }
}
```

---

## Task 7: Écran de verrouillage

**Files:**
- Create: `lib/features/auth/screens/lock_screen.dart`

**Code:**
```dart
class LockScreen extends StatelessWidget {
  final VoidCallback onUnlocked;

  // Logo VibeTerm + bouton "Déverrouiller"
  // Appel BiometricService.authenticate()
  // Si succès → onUnlocked()
}
```

---

## Task 8: Intégration Lock Screen dans main.dart

**Objectif:** Afficher le lock screen au démarrage si biométrie activée.

**Modifications main.dart:**
- Vérifier si biométrie est activée (settings)
- Si oui → afficher LockScreen
- Sinon → afficher HomeScreen directement

---

## Task 9: UI Connexion SSH

**Files:**
- Create: `lib/features/terminal/widgets/connection_dialog.dart`

**Objectif:** Dialog pour saisir les infos de connexion (host, user, port, clé).

---

## Task 10: Tests et validation

**Étapes:**
1. Tester génération de clés
2. Tester connexion SSH à un serveur local
3. Tester terminal xterm.dart
4. Tester biométrie
5. Tester flux complet
