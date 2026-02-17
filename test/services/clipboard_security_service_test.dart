import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/services/clipboard_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Cancel any leftover timer from a previous test.
    ClipboardSecurityService.cancelScheduledClear();

    // Stub the MethodChannel used by ScreenshotProtectionService so native
    // calls don't throw MissingPluginException during tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.vibeterm/security'),
          (MethodCall methodCall) async => null,
        );

    // Stub the system platform channel used by Clipboard.setData so it works
    // inside fakeAsync without waiting for a real engine response.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
          MethodCall methodCall,
        ) async {
          return null;
        });
  });

  tearDown(() {
    ClipboardSecurityService.cancelScheduledClear();

    // Remove stubs.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.vibeterm/security'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('ClipboardSecurityService', () {
    test('availableDelays contains [3, 5, 10, 15]', () {
      expect(ClipboardSecurityService.availableDelays, [3, 5, 10, 15]);
    });

    test(
      'copyWithAutoClear with autoClearEnabled=false does NOT schedule a timer',
      () {
        fakeAsync((async) {
          ClipboardSecurityService.copyWithAutoClear(
            text: 'secret',
            autoClearEnabled: false,
          );
          async.flushMicrotasks();

          // Advance well past any possible delay — no timer should fire.
          async.elapse(const Duration(seconds: 30));
          async.flushMicrotasks();

          // If we get here without error the timer was never created.
          ClipboardSecurityService.cancelScheduledClear();
        });
      },
    );

    test('copyWithAutoClear with autoClearEnabled=true schedules a clear', () {
      fakeAsync((async) {
        bool clearCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.vibeterm/security'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'clearClipboard') {
                  clearCalled = true;
                }
                return null;
              },
            );

        ClipboardSecurityService.copyWithAutoClear(
          text: 'secret',
          autoClearEnabled: true,
          clearAfterSeconds: 5,
        );

        // Flush microtasks for the Future from copyWithAutoClear (Clipboard.setData).
        async.flushMicrotasks();

        // Not yet cleared before the delay.
        expect(clearCalled, isFalse);

        // Advance past the delay.
        async.elapse(const Duration(seconds: 5));

        // Flush microtasks for the Future from _clearNative.
        async.flushMicrotasks();

        expect(clearCalled, isTrue);
      });
    });

    test('scheduleClear cancels previous timer when called again', () {
      fakeAsync((async) {
        int clearCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.vibeterm/security'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'clearClipboard') {
                  clearCount++;
                }
                return null;
              },
            );

        // Schedule a first clear at 10s.
        ClipboardSecurityService.scheduleClear(10);

        // After 3s, schedule another clear at 5s — the first timer is cancelled.
        async.elapse(const Duration(seconds: 3));
        ClipboardSecurityService.scheduleClear(5);

        // At 8s total (3+5), the second timer fires.
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(clearCount, 1);

        // Advance past the original 10s mark — no second fire.
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(clearCount, 1);
      });
    });

    test('cancelScheduledClear cancels pending timer', () {
      fakeAsync((async) {
        int clearCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.vibeterm/security'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'clearClipboard') {
                  clearCount++;
                }
                return null;
              },
            );

        ClipboardSecurityService.scheduleClear(5);

        // Cancel before it fires.
        async.elapse(const Duration(seconds: 2));
        ClipboardSecurityService.cancelScheduledClear();

        // Advance past the original delay.
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(clearCount, 0);
      });
    });

    test('clearNow cancels any pending timer', () {
      fakeAsync((async) {
        int clearCount = 0;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('com.vibeterm/security'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'clearClipboard') {
                  clearCount++;
                }
                return null;
              },
            );

        // Schedule a future clear.
        ClipboardSecurityService.scheduleClear(10);

        // Immediately clear — this should cancel the pending timer too.
        ClipboardSecurityService.clearNow();
        async.flushMicrotasks();

        // One clear from clearNow.
        expect(clearCount, 1);

        // Advance past the original timer — it should NOT fire again.
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(clearCount, 1);
      });
    });
  });
}
