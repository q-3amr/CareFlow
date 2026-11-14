import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/screens/auth/login_screen.dart';
import '../helpers/firebase_mock_helper.dart';

Widget buildTestApp(Widget child) {
  return MaterialApp(
    home: child,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('LoginScreen Widget Tests', () {
    testWidgets(
        'LoginScreen should display email and password field labels and buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Labels rendered by _buildLabeledField
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      // Page heading
      expect(find.text('Welcome Back'), findsOneWidget);
      // Sign-in button text
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets(
        'LoginScreen should show inline error when fields are empty and Sign In is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      final loginButton = find.text('Sign In');
      expect(loginButton, findsOneWidget);

      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton, warnIfMissed: false);
      await tester.pumpAndSettle(); // trigger validation

      // Inline error messages should appear for empty fields
      expect(find.text('Required'), findsNWidgets(2));
    });

    testWidgets('LoginScreen should toggle password visibility icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Initial state: password is obscured → visibility_outlined icon shown
      final visibilityIcon = find.byIcon(Icons.visibility_outlined);
      expect(visibilityIcon, findsOneWidget);

      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();

      // After tap: password revealed → visibility_off_outlined icon shown
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('LoginScreen shows a Register link to navigate to SignupScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      final signUpLink = find.text('Register');
      expect(signUpLink, findsOneWidget);
    });
  });
}
