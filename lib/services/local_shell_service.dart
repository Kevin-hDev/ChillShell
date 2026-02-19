import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';
import '../core/security/secure_logger.dart';

class LocalShellService {
  Pty? _pty;
  StreamSubscription<Uint8List>? _ptySubscription;
  final _outputController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get outputStream => _outputController.stream;
  bool get isRunning => _pty != null;

  /// Démarre un shell local
  Future<void> startShell({int width = 80, int height = 24}) async {
    if (_pty != null) {
      SecureLogger.log('LocalShellService', 'Shell already running');
      return;
    }

    // Déterminer le shell à utiliser
    final shell = Platform.isAndroid
        ? 'sh'
        : Platform.environment['SHELL'] ?? '/bin/sh';

    SecureLogger.log('LocalShellService', 'Starting shell');

    final pty = Pty.start(shell, columns: width, rows: height);
    _pty = pty;

    // Écouter la sortie du PTY
    _ptySubscription = pty.output.listen(
      (data) {
        _outputController.add(data);
      },
      onError: (error) {
        SecureLogger.logError('LocalShellService', error);
        _outputController.addError(error);
      },
      onDone: () {
        SecureLogger.log('LocalShellService', 'Shell exited');
        _pty = null;
      },
    );

    SecureLogger.log('LocalShellService', 'Shell started successfully');
  }

  /// Écrit des données dans le shell
  void write(String data) {
    final pty = _pty;
    if (pty != null) {
      pty.write(utf8.encode(data));
    } else {
      SecureLogger.log('LocalShellService', 'PTY is NULL, data not sent');
    }
  }

  /// Redimensionne le terminal
  void resize(int width, int height) {
    final pty = _pty;
    if (pty != null) {
      pty.resize(height, width);
    }
  }

  /// Ferme le shell
  Future<void> close() async {
    _ptySubscription?.cancel();
    _ptySubscription = null;
    final pty = _pty;
    if (pty != null) {
      pty.kill();
      _pty = null;
    }
    SecureLogger.log('LocalShellService', 'Closed');
  }

  /// Libère les ressources
  void dispose() {
    close();
    _outputController.close();
  }
}
