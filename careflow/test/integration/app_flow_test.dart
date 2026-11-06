import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/screens/auth/login_screen.dart';
import 'package:careflow/screens/auth/signup_screen.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('App Integration Tests', () {
    testWidgets('LoginScreen should display correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      // Heading text
      expect(find.text('Log in'), findsOneWidget);
      // Field labels
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('SignupScreen should display correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
      // Heading – appears both as title Text and as button label
      expect(find.text('Sign up'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
    });

    testWidgets('User can navigate from login to signup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      // 'Sign up' is the GestureDetector link at the bottom of LoginScreen
      final signUpLink = find.text('Sign up');
      expect(signUpLink, findsOneWidget);

      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink, warnIfMissed: false);
      await tester.pumpAndSettle();

      // After navigation: SignupScreen heading + subtitle
      expect(find.text('Sign up'), findsWidgets);
      expect(find.text('Create your new account'), findsOneWidget);
    });

    testWidgets('User can navigate from signup to login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SignupScreen()));
      await tester.pumpAndSettle();

      // 'Login' is the GestureDetector link at the bottom of SignupScreen
      final loginLink = find.text('Login');
      expect(loginLink, findsOneWidget);

      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink, warnIfMissed: false);
      await tester.pumpAndSettle();

      // After navigation: LoginScreen heading
      expect(find.text('Log in'), findsOneWidget);
    });
  });
}
