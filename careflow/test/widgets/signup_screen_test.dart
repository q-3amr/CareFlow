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

      // Heading
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      // Default role is Patient, so the patient CTA is shown.
      expect(find.text('Create Patient Account'), findsOneWidget);
    });

    testWidgets(
        'SignupScreen should show doctor fields when the Doctor role is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      // Role selector exposes Patient and Doctor options.
      expect(find.text('Patient'), findsOneWidget);
      final doctorOption = find.text('Doctor');
      expect(doctorOption, findsOneWidget);

      await tester.ensureVisible(doctorOption);
      await tester.tap(doctorOption, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Doctor-specific fields revealed
      expect(find.text('Medical Specialty'), findsOneWidget);
      expect(find.text('Clinic Location'), findsOneWidget);
      // Submit button switches to the doctor CTA.
      expect(find.text('Register as Doctor'), findsOneWidget);
    });

    testWidgets(
        'SignupScreen should show error snackbar when passwords do not match',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      // TextField index: 0=Full Name, 1=Email, 2=Password, 3=Confirm Password
      final nameField = find.byType(TextField).at(0);
      final emailField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);
      final confirmPasswordField = find.byType(TextField).at(3);

      await tester.enterText(nameField, 'Alex Morgan');
      await tester.enterText(emailField, 'alex@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.enterText(confirmPasswordField, 'password456');
      await tester.pump();

      final signUpButton = find.text('Create Patient Account');
      expect(signUpButton, findsOneWidget);
      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton, warnIfMissed: false);
      await tester.pump();

      // A SnackBar error about mismatched passwords should appear
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets(
        'SignupScreen should show Medical Specialty dropdown when Doctor is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      final doctorOption = find.text('Doctor');
      expect(doctorOption, findsOneWidget);

      await tester.ensureVisible(doctorOption);
      await tester.tap(doctorOption, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Specialty label is visible
      expect(find.text('Medical Specialty'), findsOneWidget);

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
