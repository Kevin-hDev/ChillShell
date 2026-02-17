import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibeterm/features/terminal/providers/terminal_provider.dart';

/// Mock du channel flutter_secure_storage pour les tests
void setupSecureStorageMock() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'read') return null;
        if (methodCall.method == 'write') return null;
        if (methodCall.method == 'delete') return null;
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupSecureStorageMock();

  late ProviderContainer container;
  late TerminalNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(terminalProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('TerminalNotifier - Input and Ghost Text', () {
    test('initial state is empty', () {
      final state = container.read(terminalProvider);
      expect(state.currentInput, '');
      expect(state.ghostText, null);
      expect(state.commandHistory, isEmpty);
      expect(state.historyIndex, -1);
    });

    test('setInput updates current input', () {
      notifier.setInput('git');
      expect(container.read(terminalProvider).currentInput, 'git');
    });

    test('setInput generates ghost text for known commands', () {
      notifier.setInput('git st');
      final state = container.read(terminalProvider);
      expect(state.ghostText, isNotNull);
      expect(state.ghostText, 'atus');
    });

    test('setInput clears ghost text when no match', () {
      notifier.setInput('xyznocommand');
      expect(container.read(terminalProvider).ghostText, null);
    });

    test('acceptGhostText appends ghost text to input', () {
      notifier.setInput('git st');
      final ghost = container.read(terminalProvider).ghostText;
      expect(ghost, isNotNull);

      notifier.acceptGhostText();
      final state = container.read(terminalProvider);
      expect(state.currentInput, 'git status');
      expect(state.ghostText, null);
    });

    test('acceptGhostText does nothing when no ghost text', () {
      notifier.setInput('xyz');
      notifier.acceptGhostText();
      expect(container.read(terminalProvider).currentInput, 'xyz');
    });
  });

  group('TerminalNotifier - History Navigation', () {
    test('previousCommand returns null with empty history', () {
      expect(notifier.previousCommand(), null);
    });

    test('previousCommand navigates to last command', () {
      notifier.addToHistory('ls');
      notifier.addToHistory('pwd');
      notifier.addToHistory('whoami');

      expect(notifier.previousCommand(), 'whoami');
      expect(notifier.previousCommand(), 'pwd');
      expect(notifier.previousCommand(), 'ls');
      // At beginning, stays at first
      expect(notifier.previousCommand(), 'ls');
    });

    test('nextCommand navigates forward', () {
      notifier.addToHistory('ls');
      notifier.addToHistory('pwd');

      notifier.previousCommand(); // pwd
      notifier.previousCommand(); // ls
      expect(notifier.nextCommand(), 'pwd');
    });

    test('nextCommand past end returns empty string', () {
      notifier.addToHistory('ls');
      notifier.previousCommand(); // ls
      expect(notifier.nextCommand(), '');
    });

    test('nextCommand with no navigation returns null', () {
      expect(notifier.nextCommand(), null);
    });

    test('setInput resets history index by default', () {
      notifier.addToHistory('ls');
      notifier.addToHistory('pwd');
      notifier.previousCommand(); // navigates to 'pwd'

      notifier.setInput('new input');
      // After setInput with resetHistory=true, index resets to -1
      expect(container.read(terminalProvider).historyIndex, -1);
    });

    test('setInput preserves history index when resetHistory=false', () {
      notifier.addToHistory('ls');
      notifier.addToHistory('pwd');
      notifier.previousCommand(); // index = 1

      notifier.setInput('pwd', resetHistory: false);
      expect(container.read(terminalProvider).historyIndex, isNot(-1));
    });
  });

  group('TerminalScrolledUp provider', () {
    test('initial value is false', () {
      expect(container.read(terminalScrolledUpProvider), false);
    });

    test('set changes value', () {
      container.read(terminalScrolledUpProvider.notifier).set(true);
      expect(container.read(terminalScrolledUpProvider), true);
    });
  });

  group('IsEditorMode provider', () {
    test('initial value is false', () {
      expect(container.read(isEditorModeProvider), false);
    });

    test('set changes value', () {
      container.read(isEditorModeProvider.notifier).set(true);
      expect(container.read(isEditorModeProvider), true);
    });
  });
}
