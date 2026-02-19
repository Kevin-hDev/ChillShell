import 'dart:async';
import 'package:flutter/services.dart';
import 'screenshot_protection_service.dart';
import '../core/security/secure_logger.dart';

/// Centralized secure clipboard management service.
///
/// Replaces scattered clipboard cleanup code with:
/// - Native silent clear (no Android 13+ "Copied" notification)
/// - Configurable delay (3s, 5s, 10s, 15s)
/// - Single active timer (cancels previous)
class ClipboardSecurityService {
  static Timer? _clearTimer;

  /// Available delay options for the UI selector.
  static const List<int> availableDelays = [3, 5, 10, 15];

  /// Copy text to clipboard and schedule automatic cleanup.
  ///
  /// [text] - text to copy
  /// [autoClearEnabled] - whether auto-clear is active
  /// [clearAfterSeconds] - delay before clearing (default 5s)
  static Future<void> copyWithAutoClear({
    required String text,
    required bool autoClearEnabled,
    int clearAfterSeconds = 5,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (autoClearEnabled) {
      scheduleClear(clearAfterSeconds);
    }
  }

  /// Schedule a clipboard clear after [seconds].
  /// Cancels any previous timer to avoid conflicts.
  static void scheduleClear(int seconds) {
    _clearTimer?.cancel();
    _clearTimer = Timer(Duration(seconds: seconds), () {
      _clearNative();
    });
  }

  /// Clear clipboard immediately via native API.
  static Future<void> clearNow() async {
    _clearTimer?.cancel();
    await _clearNative();
  }

  /// Cancel any scheduled clear (e.g. when user disables the feature).
  static void cancelScheduledClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }

  /// Use native API for silent clear (no toast on Android 13+).
  static Future<void> _clearNative() async {
    try {
      await ScreenshotProtectionService.clearClipboard();
    } catch (e) {
      // Fallback to Flutter standard API
      SecureLogger.logError('ClipboardSecurityService', e);
      try {
        await Clipboard.setData(const ClipboardData(text: ''));
      } catch (_) {}
    }
  }
}
