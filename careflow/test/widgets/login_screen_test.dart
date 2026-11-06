import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/screens/auth/login_screen.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('LoginScreen Widget Tests', () {
    testWidgets(
        'LoginScreen should display email and password field labels and buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(); // settle initial frame

      // Labels rendered by _buildLabeledField
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      // Page heading
      expect(find.text('Log in'), findsOneWidget);
      // Login button text
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets(
        'LoginScreen should show error snackbar when fields are empty and Login is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      final loginButton = find.text('Login');
      expect(loginButton, findsOneWidget);

      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton, warnIfMissed: false);
      await tester.pump(); // trigger setState / snackbar

      // A SnackBar should appear telling the user to fill in fields
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('LoginScreen should toggle password visibility icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      // Initial state: password is obscured → visibility_outlined icon shown
      final visibilityIcon = find.byIcon(Icons.visibility_outlined);
      expect(visibilityIcon, findsOneWidget);

      await tester.tap(visibilityIcon);
      await tester.pump();

      // After tap: password revealed → visibility_off_outlined icon shown
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('LoginScreen shows a Sign up link to navigate to SignupScreen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      final signUpLink = find.text('Sign up');
      expect(signUpLink, findsOneWidget);
    });
  });
}
