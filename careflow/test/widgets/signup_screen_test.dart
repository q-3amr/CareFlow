import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/screens/auth/signup_screen.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('SignupScreen Widget Tests', () {
    testWidgets('SignupScreen should display all required field labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      // Heading (appears at least once as text)
      expect(find.text('Sign up'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
    });

    testWidgets(
        'SignupScreen should show doctor fields when "Register as a Doctor" Switch is toggled on',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      // The toggle label is visible
      expect(find.text('Register as a Doctor'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Doctor-specific fields revealed
      expect(find.text('Specialty'), findsOneWidget);
      // The label in the source is 'Clinic Location', not 'Location'
      expect(find.text('Clinic Location'), findsOneWidget);
    });

    testWidgets(
        'SignupScreen should show error snackbar when passwords do not match',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      // TextField index: 0=Full Name, 1=Email, 2=Password, 3=Confirm Password
      final passwordField = find.byType(TextField).at(2);
      final confirmPasswordField = find.byType(TextField).at(3);

      await tester.enterText(passwordField, 'password123');
      await tester.enterText(confirmPasswordField, 'password456');
      await tester.pump();

      final signUpButton = find.text('Sign Up');
      expect(signUpButton, findsOneWidget);
      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton, warnIfMissed: false);
      await tester.pump();

      // A SnackBar error about mismatched passwords should appear
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
        'SignupScreen should show Specialty dropdown when doctor toggle is on',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Specialty label is visible
      expect(find.text('Specialty'), findsOneWidget);

      // The specialty dropdown (wrapped in DropdownButtonHideUnderline)
      final dropdown = find.byType(DropdownButton<String>);
      expect(dropdown, findsOneWidget);

      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown, warnIfMissed: false);
      await tester.pumpAndSettle();

      // 'General Medicine' must appear in the dropdown list
      expect(find.text('General Medicine'), findsWidgets);
    });
  });
}
