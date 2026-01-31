import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibeterm/main.dart';

void main() {
  testWidgets('VibeTerm app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VibeTermApp()));
    await tester.pumpAndSettle();

    // Verify app title is displayed
    expect(find.text('VibeTerm'), findsOneWidget);
  });
}
