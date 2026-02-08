import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';

class LocalShellService {
  Pty? _pty;
  StreamSubscription<Uint8List>? _ptySubscription;
  final _outputController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get outputStream => _outputController.stream;
  bool get isRunning => _pty != null;

  /// Démarre un shell local
  Future<void> startShell({int width = 80, int height = 24}) async {
    if (_pty != null) {
      if (kDebugMode) debugPrint('LocalShell: Shell already running');
      return;
    }

    // Déterminer le shell à utiliser
    final shell = Platform.isAndroid ? 'sh' : Platform.environment['SHELL'] ?? '/bin/sh';

    if (kDebugMode) debugPrint('LocalShell: Starting shell: $shell');

    _pty = Pty.start(
      shell,
      columns: width,
      rows: height,
    );

    // Écouter la sortie du PTY
    _ptySubscription = _pty!.output.listen(
      (data) {
        _outputController.add(data);
      },
      onError: (error) {
        if (kDebugMode) debugPrint('LocalShell: Error: $error');
        _outputController.addError(error);
      },
      onDone: () {
        if (kDebugMode) debugPrint('LocalShell: Shell exited');
        _pty = null;
      },
    );

    if (kDebugMode) debugPrint('LocalShell: Shell started successfully');
  }

  /// Écrit des données dans le shell
  void write(String data) {
    if (_pty != null) {
      _pty!.write(utf8.encode(data));
    } else {
      if (kDebugMode) debugPrint('LocalShell: PTY is NULL, data not sent');
    }
  }

  /// Redimensionne le terminal
  void resize(int width, int height) {
    if (_pty != null) {
      _pty!.resize(height, width);
    }
  }

  /// Ferme le shell
  Future<void> close() async {
    _ptySubscription?.cancel();
    _ptySubscription = null;
    if (_pty != null) {
      _pty!.kill();
      _pty = null;
    }
    if (kDebugMode) debugPrint('LocalShell: Closed');
  }

  /// Libère les ressources
  void dispose() {
    close();
    _outputController.close();
  }
}
