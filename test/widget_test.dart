import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unbounddrive/main.dart';

void main() {
  testWidgets('UnboundDriveApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: UnboundDriveApp(),
      ),
    );

    // Verify that the login branding text is rendered
    expect(find.text('UnboundDrive'), findsOneWidget);
  });
}
