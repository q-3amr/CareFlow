import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/screens/auth/login_screen.dart';
import 'package:careflow/screens/auth/signup_screen.dart';
import 'package:careflow/screens/guest/guest_home_screen.dart';
import 'package:careflow/utils/app_theme.dart';
import '../helpers/firebase_mock_helper.dart';

/// Presentation-only regression tests: mount the screens that do not need
/// backend data and confirm they never overflow at the smallest supported
/// widths, with normal and 1.5x text scaling.
void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  const sizes = <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(412, 915),
  ];

  Widget buildTestApp(Widget child, double textScale) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: child,
    );
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen,
    Size size,
    double textScale,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(screen, textScale));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await tester.drag(scrollable.first, const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  }

  for (final size in sizes) {
    for (final textScale in <double>[1.0, 1.5]) {
      testWidgets(
        'guest home fits ${size.width.toInt()}x${size.height.toInt()} '
        'at ${textScale}x text',
        (tester) =>
            pumpScreen(tester, const GuestHomeScreen(), size, textScale),
      );

      testWidgets(
        'login fits ${size.width.toInt()}x${size.height.toInt()} '
        'at ${textScale}x text',
        (tester) => pumpScreen(tester, const LoginScreen(), size, textScale),
      );

      testWidgets(
        'signup fits ${size.width.toInt()}x${size.height.toInt()} '
        'at ${textScale}x text',
        (tester) => pumpScreen(tester, const SignupScreen(), size, textScale),
      );
    }
  }

  testWidgets('signup doctor form fits 320x568 at 1.5x text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.5),
          ),
          child: child!,
        ),
        home: const SignupScreen(),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Doctor').first, warnIfMissed: false);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1600));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
