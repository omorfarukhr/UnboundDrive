import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unbounddrive/app/theme/app_theme.dart';
import 'package:unbounddrive/features/drive/presentation/screens/home_drive_screen.dart';
import 'package:unbounddrive/main.dart';

void main() {
  testWidgets('UnboundDriveApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: UnboundDriveApp(),
      ),
    );
    expect(find.text('UnboundDrive'), findsOneWidget);
  });

  testWidgets('HomeDriveScreen renders properly without crashing', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const HomeDriveScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('UnboundDrive'), findsOneWidget);
    expect(find.text('Cloud Capacity'), findsOneWidget);
  });
}
