import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:careflow/screens/common/schedule_screen.dart';
import 'package:careflow/services/database_service.dart';
import 'package:careflow/models/appointment.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('ScheduleScreen pending visibility', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseService db;
    late MockFirebaseAuth mockAuth;

    const patientId = 'p1';
    const doctorId = 'doctor_001';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      db = DatabaseService(firestore: fakeFirestore);
      mockAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: patientId),
      );
    });

    testWidgets('patient sees pending and confirmed in Upcoming tab',
        (WidgetTester tester) async {
      // Seed: one confirmed, one pending, one completed
      await fakeFirestore.collection('appointments').doc('appt1').set({
        'id': 'appt1',
        'doctor_id': doctorId,
        'doctor_name': 'Dr. Smith',
        'patient_id': patientId,
        'patient_name': 'Alice',
        'appointmentDateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        'status': 'accepted',
        'hasFeedback': false,
        'isReviewSeen': false,
      });
      await fakeFirestore.collection('appointments').doc('appt2').set({
        'id': 'appt2',
        'doctor_id': doctorId,
        'doctor_name': 'Dr. Smith',
        'patient_id': patientId,
        'patient_name': 'Alice',
        'appointmentDateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
        'status': 'pending',
        'hasFeedback': false,
        'isReviewSeen': false,
      });
      await fakeFirestore.collection('appointments').doc('appt3').set({
        'id': 'appt3',
        'doctor_id': doctorId,
        'doctor_name': 'Dr. Smith',
        'patient_id': patientId,
        'patient_name': 'Alice',
        'appointmentDateTime': Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))),
        'status': 'completed',
        'hasFeedback': false,
        'isReviewSeen': false,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(
            isDoctor: false,
            testUser: mockAuth.currentUser,
            testDb: db,
          ),
        ),
      );

      // Wait for the stream to emit
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      debugPrint('After pumps - checking for Confirmed');

      // Upcoming tab (default) should show both confirmed and pending
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      // Switch to History tab
      await tester.tap(find.text('History & Past'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // History should show completed (and any cancelled/rejected)
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Confirmed'), findsNothing);
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('doctor sees pending and confirmed in Upcoming tab',
        (WidgetTester tester) async {
      await fakeFirestore.collection('appointments').doc('appt1').set({
        'id': 'appt1',
        'doctor_id': doctorId,
        'doctor_name': 'Dr. Smith',
        'patient_id': patientId,
        'patient_name': 'Alice',
        'appointmentDateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        'status': 'accepted',
        'hasFeedback': false,
        'isReviewSeen': false,
      });
      await fakeFirestore.collection('appointments').doc('appt2').set({
        'id': 'appt2',
        'doctor_id': doctorId,
        'doctor_name': 'Dr. Smith',
        'patient_id': 'p2',
        'patient_name': 'Bob',
        'appointmentDateTime': Timestamp.fromDate(DateTime.now().add(const Duration(days: 2))),
        'status': 'pending',
        'hasFeedback': false,
        'isReviewSeen': false,
      });

      final doctorAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: doctorId),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleScreen(
            isDoctor: true,
            testUser: doctorAuth.currentUser,
            testDb: db,
          ),
        ),
      );

      // Wait for the stream to emit
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();

      // Doctor's Upcoming shows both
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      // Doctor can mark completed on confirmed
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}