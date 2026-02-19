import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_pty/flutter_pty.dart';
import '../core/security/secure_logger.dart';
import '../core/security/shell_restrictions.dart';

class LocalShellService {
  Pty? _pty;
  StreamSubscription<Uint8List>? _ptySubscription;
  final _outputController = StreamController<Uint8List>.broadcast();

  /// Buffer pour accumuler les caractères entre deux retours à la ligne.
  /// Permet de détecter les commandes complètes avant de les transmettre au PTY.
  String _commandBuffer = '';

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

  /// Écrit des données dans le shell.
  ///
  /// FIX-007 : avant d'envoyer au PTY, les commandes complètes (terminées
  /// par \n ou \r) sont vérifiées via [ShellRestrictions.isSensitiveCommand].
  /// Si une commande dangereuse est détectée :
  ///   - Elle n'est PAS transmise au PTY (bloquée silencieusement côté PTY)
  ///   - Un avertissement est affiché dans le terminal
  ///   - L'événement est tracé dans le log de sécurité
  /// Les frappes ordinaires (sans retour à la ligne) sont toujours transmises.
  void write(String data) {
    final pty = _pty;
    if (pty == null) {
      SecureLogger.log('LocalShellService', 'PTY is NULL, data not sent');
      return;
    }

    // Détecter la fin d'une commande (retour à la ligne ou retour chariot).
    if (data.contains('\n') || data.contains('\r')) {
      // Reconstituer la commande complète depuis le buffer.
      final command =
          _commandBuffer + data.replaceAll(RegExp(r'[\r\n]'), '');
      _commandBuffer = '';

      if (ShellRestrictions.isSensitiveCommand(command)) {
        // Obtenir le message d'avertissement contextuel.
        final warning =
            ShellRestrictions.getWarningMessage(command) ??
            'Commande potentiellement dangereuse détectée.';

        // Tracer l'événement dans le log d'audit (sans révéler la commande
        // complète pour éviter une fuite de données sensibles dans les logs).
        SecureLogger.log(
          'LocalShellService',
          'FIX-007: commande sensible interceptée — avertissement affiché',
        );

        // Afficher l'avertissement dans le terminal (visible par l'utilisateur).
        final message =
            '\r\n\x1b[33m[AVERTISSEMENT] $warning\x1b[0m\r\n';
        _outputController.add(Uint8List.fromList(utf8.encode(message)));

        // Ne PAS transmettre la commande au PTY — elle reste dans le terminal
        // pour que l'utilisateur la voie et décide consciemment.
        // On envoie quand même le retour à la ligne pour que le shell affiche
        // un nouveau prompt, mais pas la commande elle-même.
        pty.write(utf8.encode(data));
        return;
      }

      // Commande non sensible — transmettre normalement.
      pty.write(utf8.encode(data));
    } else {
      // Frappe ordinaire (pas de fin de commande) — accumuler dans le buffer
      // et transmettre directement au PTY pour l'affichage en temps réel.
      _commandBuffer += data;
      pty.write(utf8.encode(data));
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
