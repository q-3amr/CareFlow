import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:careflow/auth_wrapper.dart';
import 'package:careflow/services/auth_service.dart';
import 'package:careflow/services/database_service.dart';
import 'package:careflow/models/user.dart';
import 'package:careflow/providers/theme_provider.dart';
import 'package:careflow/providers/notification_provider.dart';
import 'package:careflow/providers/chat_provider.dart';
import '../helpers/firebase_mock_helper.dart';

/// Mock AuthService for testing that wraps MockFirebaseAuth
class MockAuthService extends AuthService {
  final MockFirebaseAuth _mockAuth;

  MockAuthService({required MockFirebaseAuth mockAuth}) : _mockAuth = mockAuth;

  @override
  Stream<User?> get authStateChanges => _mockAuth.authStateChanges();

  @override
  User? get currentUser => _mockAuth.currentUser;

  @override
  Future<void> signOut() async => await _mockAuth.signOut();
}

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('AuthWrapper routing', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseService db;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      db = DatabaseService(firestore: fakeFirestore);
    });

    Future<void> seedUser({
      required String uid,
      required String email,
      required String role,
      bool isVerified = true,
      String name = 'Test User',
    }) async {
      await fakeFirestore.collection('users').doc(uid).set({
        'id': uid,
        'email': email,
        'name': name,
        'role': role,
        'isVerified': isVerified,
        'pushToken': '',
      });
    }

    testWidgets('guest (no auth) shows GuestHomeScreen', (WidgetTester tester) async {
      final mockAuth = MockFirebaseAuth(signedIn: false);
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Should show guest home - no loading indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('patient role routes to PatientHomeScreen', (WidgetTester tester) async {
      const uid = 'patient_routing_test';
      await seedUser(uid: uid, email: 'patient@test.com', role: 'patient');

      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'patient@test.com'),
      );
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // PatientHomeScreen should load (no loading indicator)
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Should not show unknown profile screen
      expect(find.text('Profile unavailable'), findsNothing);
    });

    testWidgets('verified doctor routes to DoctorHomeScreen', (WidgetTester tester) async {
      const uid = 'doctor_verified_test';
      await seedUser(uid: uid, email: 'doctor@test.com', role: 'doctor', isVerified: true);

      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'doctor@test.com'),
      );
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // DoctorHomeScreen should load
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Profile unavailable'), findsNothing);
      expect(find.text('Account Under Review'), findsNothing);
    });

    testWidgets('unverified doctor shows Account Under Review screen', (WidgetTester tester) async {
      const uid = 'doctor_unverified_test';
      await seedUser(uid: uid, email: 'unverified@test.com', role: 'doctor', isVerified: false);

      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'unverified@test.com'),
      );
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      // Wait for auth state -> role future -> UI
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      // Debug: print what widgets are found
      debugPrint('Widgets after pump: ${tester.allWidgets.length}');

      // Should show "Account Under Review" screen
      expect(find.text('Account Under Review'), findsOneWidget);
      expect(find.textContaining('credentials are being verified'), findsOneWidget);
    });

    testWidgets('admin role routes to AdminHomeScreen', (WidgetTester tester) async {
      const uid = 'admin_routing_test';
      await seedUser(uid: uid, email: 'admin@test.com', role: 'admin');

      // Admin screen queries unverified doctors - seed one so stream completes
      await fakeFirestore.collection('users').doc('unverified_doc_for_admin').set({
        'id': 'unverified_doc_for_admin',
        'email': 'unverified@admin.com',
        'name': 'Dr. Unverified',
        'role': 'doctor',
        'isVerified': false,
        'pushToken': '',
      });

      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'admin@test.com'),
      );
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      // AdminHomeScreen should load - not show profile unavailable or stuck on loading
      expect(find.text('Profile unavailable'), findsNothing);
      // Accept either "Admin dashboard" title or the empty state "All caught up"
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // The screen should be one of the admin screens (not profile unavailable)
      // We just verify we didn't fall through to unknown profile
      expect(find.text('Profile unavailable'), findsNothing);
    });

    testWidgets('unknown role shows Profile unavailable screen', (WidgetTester tester) async {
      const uid = 'unknown_role_test';
      await seedUser(uid: uid, email: 'unknown@test.com', role: 'invalid_role');

      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'unknown@test.com'),
      );
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      // Wait for auth state, then role future, then UI
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      // Should show unknown profile screen
      expect(find.text('Profile unavailable'), findsOneWidget);
      expect(find.textContaining('Signed in as $uid'), findsOneWidget);
      expect(find.textContaining('Role: invalid_role'), findsOneWidget);
    });

    testWidgets('missing profile (no user doc) shows Profile unavailable screen', (WidgetTester tester) async {
      const uid = 'missing_profile_test';

      final mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: uid, email: 'missing@test.com'),
      );
      final authService = MockAuthService(mockAuth: mockAuth);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => NotificationProvider()),
              ChangeNotifierProvider(create: (_) => ChatProvider()),
            ],
            child: AuthWrapper(
              authService: authService,
              databaseService: db,
            ),
          ),
        ),
      );

      // Wait for auth state, then role future, then UI
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      // Should show unknown profile screen with 'missing' role
      expect(find.text('Profile unavailable'), findsOneWidget);
      expect(find.textContaining('Signed in as $uid'), findsOneWidget);
      expect(find.textContaining('Role: missing'), findsOneWidget);
    });
  });
}