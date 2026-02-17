import 'package:flutter/foundation.dart';
import 'package:freerasp/freerasp.dart';

import '../models/audit_entry.dart';
import 'audit_log_service.dart';

/// Types of threats detected by freeRASP.
///
/// Maps to Talsec [Threat] enum but provides a ChillShell-specific
/// abstraction layer so the rest of the app never imports freerasp directly.
enum RaspThreatType {
  privilegedAccess, // root / jailbreak
  hook, // Frida, Xposed
  debugger, // debugger attached
  emulator, // simulator / emulator
  tampering, // app integrity compromised
  unofficialStore, // side-loaded
  deviceBinding, // cloned app
  obfuscation, // not obfuscated
  passcode, // no device lock
  secureHardware, // no secure hardware
  devMode, // developer mode on
  adbEnabled, // ADB active
}

/// Callback invoked when a threat is detected.
typedef OnThreatDetected = void Function(RaspThreatType threat);

/// freeRASP (Talsec) integration service for Runtime Application Self-Protection.
///
/// Detects: root/jailbreak, Frida/Xposed hooking, debugger attachment,
/// emulator/simulator, app tampering, unofficial store installation,
/// device binding changes, missing obfuscation, no device passcode,
/// missing secure hardware, developer mode, and ADB.
///
/// Skipped in debug mode because freeRASP detects debugger attachment
/// and would trigger false positives during development.
class RaspService {
  static bool _initialized = false;
  static OnThreatDetected? _onThreatDetected;

  /// Whether the service has been initialized.
  static bool get isInitialized => _initialized;

  /// Initialize freeRASP with threat detection callbacks.
  ///
  /// Does nothing if already initialized or in debug mode.
  /// In debug mode, freeRASP would detect the debugger and fire
  /// false-positive threats, so we skip entirely.
  static Future<void> initialize({OnThreatDetected? onThreatDetected}) async {
    if (_initialized) return;

    // Skip in debug mode (freeRASP detects the debugger)
    if (kDebugMode) {
      debugPrint('RaspService: skipped in debug mode');
      return;
    }

    _onThreatDetected = onThreatDetected;

    try {
      // Platform-specific configuration.
      // PLACEHOLDER hashes/IDs must be replaced before production release.
      final config = TalsecConfig(
        androidConfig: AndroidConfig(
          packageName: 'com.vibeterm.app',
          signingCertHashes: ['PLACEHOLDER_REPLACE_WITH_ACTUAL_HASH'],
        ),
        iosConfig: IOSConfig(
          bundleIds: ['com.vibeterm.app'],
          teamId: 'PLACEHOLDER_REPLACE_WITH_TEAM_ID',
        ),
        watcherMail: 'security@chillshell.app',
        isProd: true,
      );

      // Start the Talsec engine.
      await Talsec.instance.start(config);

      // Attach threat detection callbacks.
      final callback = ThreatCallback(
        onPrivilegedAccess: () =>
            _handleThreat(RaspThreatType.privilegedAccess),
        onHooks: () => _handleThreat(RaspThreatType.hook),
        onDebug: () => _handleThreat(RaspThreatType.debugger),
        onSimulator: () => _handleThreat(RaspThreatType.emulator),
        onAppIntegrity: () => _handleThreat(RaspThreatType.tampering),
        onUnofficialStore: () => _handleThreat(RaspThreatType.unofficialStore),
        onDeviceBinding: () => _handleThreat(RaspThreatType.deviceBinding),
        onObfuscationIssues: () => _handleThreat(RaspThreatType.obfuscation),
        onPasscode: () => _handleThreat(RaspThreatType.passcode),
        onSecureHardwareNotAvailable: () =>
            _handleThreat(RaspThreatType.secureHardware),
        onDevMode: () => _handleThreat(RaspThreatType.devMode),
        onADBEnabled: () => _handleThreat(RaspThreatType.adbEnabled),
      );
      Talsec.instance.attachListener(callback);

      _initialized = true;
      debugPrint('RaspService: initialized successfully');
    } catch (e) {
      // Do not crash the app if RASP fails to start — log and continue.
      debugPrint('RaspService: initialization failed: $e');
    }
  }

  /// Handle a detected threat: log to audit trail and notify the callback.
  static void _handleThreat(RaspThreatType threat) {
    debugPrint('RaspService: threat detected: ${threat.name}');

    // Log to encrypted audit trail for forensic review.
    AuditLogService.log(
      AuditEventType.raspThreatDetected,
      success: false,
      details: {'threat': threat.name},
    );

    // Notify the app-level callback (e.g. to show a warning or block).
    _onThreatDetected?.call(threat);
  }

  /// Reset service state (for testing purposes only).
  @visibleForTesting
  static void reset() {
    _initialized = false;
    _onThreatDetected = null;
  }
}
