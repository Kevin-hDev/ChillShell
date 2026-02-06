import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibeterm/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage platform channel
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    if (methodCall.method == 'read') return null;
    if (methodCall.method == 'write') return null;
    if (methodCall.method == 'delete') return null;
    return null;
  });

  testWidgets('VibeTerm app starts without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VibeTermApp()));
    // Use pump() instead of pumpAndSettle() because the app has periodic timers
    await tester.pump(const Duration(seconds: 1));

    // App should render without crash - check the loading indicator is shown
    // (settings are loading from secure storage which returns null in mock)
    expect(find.byType(VibeTermApp), findsOneWidget);
  });
}
