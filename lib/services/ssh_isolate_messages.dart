import 'dart:typed_data';
import 'package:uuid/uuid.dart';

/// Protocole de messages entre le main isolate (UI) et le background isolate (SSH).
///
/// Tous les messages sont des `Map<String, dynamic>` sérialisables via SendPort.
/// Le champ `type` identifie le message, `requestId` permet les requêtes-réponse.

const _uuid = Uuid();

/// Génère un requestId unique pour les messages requête-réponse.
String generateRequestId() => _uuid.v4();

// ============================================================
// Types de messages : Main → Background (commandes)
// ============================================================

/// Commande de connexion initiale.
abstract final class IsolateCommand {
  static const connect = 'connect';
  static const createTab = 'createTab';
  static const closeTab = 'closeTab';
  static const write = 'write';
  static const resize = 'resize';
  static const disconnect = 'disconnect';
  static const uploadFile = 'uploadFile';
  static const executeCommand = 'executeCommand';
  static const detectOS = 'detectOS';
  static const shutdown = 'shutdown';
  static const pauseMonitor = 'pauseMonitor';
  static const resumeMonitor = 'resumeMonitor';
  static const hostKeyResponse = 'hostKeyResponse';
  static const reconnectTab = 'reconnectTab';
  static const reconnectAll = 'reconnectAll';
  static const testConnect = 'testConnect';
  static const dispose = 'dispose';
}

// ============================================================
// Types de messages : Background → Main (événements)
// ============================================================

abstract final class IsolateEvent {
  static const connected = 'connected';
  static const connectionFailed = 'connectionFailed';
  static const tabCreated = 'tabCreated';
  static const tabCreateFailed = 'tabCreateFailed';
  static const stdout = 'stdout';
  static const tabClosed = 'tabClosed';
  static const disconnected = 'disconnected';
  static const allDisconnected = 'allDisconnected';
  static const hostKeyVerify = 'hostKeyVerify';
  static const commandResult = 'commandResult';
  static const uploadResult = 'uploadResult';
  static const osDetected = 'osDetected';
  static const reconnecting = 'reconnecting';
  static const reconnected = 'reconnected';
  static const error = 'error';
  static const tabDead = 'tabDead';
  static const testConnectResult = 'testConnectResult';
}

// ============================================================
// Helpers de construction de messages Main → Background
// ============================================================

Map<String, dynamic> buildConnectMessage({
  required String host,
  required String username,
  required String keyId,
  required String sessionId,
  required int port,
  required String tabId,
}) {
  return {
    'type': IsolateCommand.connect,
    'requestId': generateRequestId(),
    'host': host,
    'username': username,
    'keyId': keyId,
    'sessionId': sessionId,
    'port': port,
    'tabId': tabId,
  };
}

Map<String, dynamic> buildCreateTabMessage({
  required String keyId,
  required String tabId,
}) {
  return {
    'type': IsolateCommand.createTab,
    'requestId': generateRequestId(),
    'keyId': keyId,
    'tabId': tabId,
  };
}

Map<String, dynamic> buildCloseTabMessage({required String tabId}) {
  return {'type': IsolateCommand.closeTab, 'tabId': tabId};
}

Map<String, dynamic> buildWriteMessage({
  required String tabId,
  required Uint8List data,
}) {
  return {'type': IsolateCommand.write, 'tabId': tabId, 'data': data};
}

Map<String, dynamic> buildResizeMessage({
  required String tabId,
  required int width,
  required int height,
}) {
  return {
    'type': IsolateCommand.resize,
    'tabId': tabId,
    'width': width,
    'height': height,
  };
}

Map<String, dynamic> buildDisconnectMessage() {
  return {'type': IsolateCommand.disconnect};
}

Map<String, dynamic> buildUploadFileMessage({
  required String localPath,
  required String remotePath,
}) {
  return {
    'type': IsolateCommand.uploadFile,
    'requestId': generateRequestId(),
    'localPath': localPath,
    'remotePath': remotePath,
  };
}

Map<String, dynamic> buildExecuteCommandMessage({
  required String tabId,
  required String command,
}) {
  return {
    'type': IsolateCommand.executeCommand,
    'requestId': generateRequestId(),
    'tabId': tabId,
    'command': command,
  };
}

Map<String, dynamic> buildDetectOSMessage({required String tabId}) {
  return {
    'type': IsolateCommand.detectOS,
    'requestId': generateRequestId(),
    'tabId': tabId,
  };
}

Map<String, dynamic> buildShutdownMessage({
  required String tabId,
  required String os,
}) {
  return {'type': IsolateCommand.shutdown, 'tabId': tabId, 'os': os};
}

Map<String, dynamic> buildHostKeyResponseMessage({
  required String requestId,
  required bool accepted,
}) {
  return {
    'type': IsolateCommand.hostKeyResponse,
    'requestId': requestId,
    'accepted': accepted,
  };
}

Map<String, dynamic> buildReconnectTabMessage({required String tabId}) {
  return {'type': IsolateCommand.reconnectTab, 'tabId': tabId};
}

Map<String, dynamic> buildReconnectAllMessage() {
  return {
    'type': IsolateCommand.reconnectAll,
    'requestId': generateRequestId(),
  };
}

Map<String, dynamic> buildPauseMonitorMessage() {
  return {'type': IsolateCommand.pauseMonitor};
}

Map<String, dynamic> buildResumeMonitorMessage() {
  return {'type': IsolateCommand.resumeMonitor};
}

Map<String, dynamic> buildTestConnectMessage({
  required String host,
  required String username,
  required String keyId,
  required int port,
}) {
  return {
    'type': IsolateCommand.testConnect,
    'requestId': generateRequestId(),
    'host': host,
    'username': username,
    'keyId': keyId,
    'port': port,
  };
}

Map<String, dynamic> buildDisposeMessage() {
  return {'type': IsolateCommand.dispose};
}
