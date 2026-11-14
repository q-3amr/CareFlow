import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/screens/auth/login_screen.dart';
import 'package:careflow/screens/auth/signup_screen.dart';
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

  group('App Integration Tests', () {
    testWidgets('LoginScreen should display correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      // Heading text
      expect(find.text('Welcome Back'), findsOneWidget);
      // Field labels
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('SignupScreen should display correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const SignupScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      // Heading
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
    });

    testWidgets('User can navigate from login to signup', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // 'Register' is the TextButton link at the bottom of LoginScreen
      final signUpLink = find.text('Register');
      expect(signUpLink, findsOneWidget);

      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink, warnIfMissed: false);
      await tester.pumpAndSettle();

      // After navigation: SignupScreen heading + subtitle
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Select your role and enter credentials'), findsOneWidget);
    });

    testWidgets('User can navigate from signup to login', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const SignupScreen()));
      await tester.pumpAndSettle();

      // 'Sign In' is the TextButton link at the bottom of SignupScreen
      final loginLink = find.text('Sign In');
      expect(loginLink, findsOneWidget);

      await tester.ensureVisible(loginLink);
      await tester.tap(loginLink, warnIfMissed: false);
      await tester.pumpAndSettle();

      // After navigation: LoginScreen heading
      expect(find.text('Welcome Back'), findsOneWidget);
    });
  });
}
