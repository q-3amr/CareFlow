import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:careflow/services/database_service.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('AI Booking Path - transactional lock', () {
    late FakeFirebaseFirestore fakeFirestore;
    late DatabaseService db;

    const doctorId = 'doc_ai_test';
    const patientId = 'patient_ai_test';
    const doctorName = 'Dr. AI Test';
    const patientName = 'Patient AI Test';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      db = DatabaseService(firestore: fakeFirestore);
    });

    test('bookAppointmentForAi uses _bookSlotTransaction and prevents double booking', () async {
      final appointmentDateTime = DateTime.now().add(const Duration(days: 1));
      final dateStr = '${appointmentDateTime.year}-${appointmentDateTime.month}-${appointmentDateTime.day}';
      final timeStr = '${appointmentDateTime.hour > 12 ? appointmentDateTime.hour - 12 : appointmentDateTime.hour}:${appointmentDateTime.minute.toString().padLeft(2, '0')} ${appointmentDateTime.hour >= 12 ? 'PM' : 'AM'}';

      // First booking - should succeed
      final result1 = await db.bookAppointmentForAi(
        doctorId,
        dateStr,
        timeStr,
        db: db,
        patientId: patientId,
      );

      final parsed1 = jsonDecode(result1);
      expect(parsed1['success'], isTrue);

      // Verify appointment was created
      final appointments = await fakeFirestore.collection('appointments').get();
      expect(appointments.docs.length, 1);
      expect(appointments.docs.first.data()['status'], 'pending');
      expect(appointments.docs.first.data()['patient_id'], patientId);
      expect(appointments.docs.first.data()['doctor_id'], doctorId);

      // Verify booked_slots lock was created
      final locks = await fakeFirestore.collection('booked_slots').get();
      expect(locks.docs.length, 1);
      expect(locks.docs.first.data()['bookedBy'], patientId);
      expect(locks.docs.first.data()['doctorId'], doctorId);

      // Second booking for same slot - should fail with double-booking error
      final result2 = await db.bookAppointmentForAi(
        doctorId,
        dateStr,
        timeStr,
        db: db,
        patientId: 'another_patient',
      );

      final parsed2 = jsonDecode(result2);
      expect(parsed2['success'], isFalse);
      expect(parsed2['error'], contains('CRITICAL: This exact time slot'));

      // Verify no additional appointment was created
      final appointments2 = await fakeFirestore.collection('appointments').get();
      expect(appointments2.docs.length, 1);

      // Verify lock count unchanged
      final locks2 = await fakeFirestore.collection('booked_slots').get();
      expect(locks2.docs.length, 1);
    });

    test('bookAppointmentForAi releases lock on cancellation path', () async {
      final appointmentDateTime = DateTime.now().add(const Duration(days: 2));
      final dateStr = '${appointmentDateTime.year}-${appointmentDateTime.month}-${appointmentDateTime.day}';
      final timeStr = '${appointmentDateTime.hour > 12 ? appointmentDateTime.hour - 12 : appointmentDateTime.hour}:${appointmentDateTime.minute.toString().padLeft(2, '0')} ${appointmentDateTime.hour >= 12 ? 'PM' : 'AM'}';

      // Book via AI
      final result1 = await db.bookAppointmentForAi(
        doctorId,
        dateStr,
        timeStr,
        db: db,
        patientId: patientId,
      );
      final parsed1 = jsonDecode(result1);
      expect(parsed1['success'], isTrue);

      // Find the appointment ID
      final appointments = await fakeFirestore.collection('appointments').get();
      final apptId = appointments.docs.first.id;

      // Cancel the appointment (simulating patient cancellation)
      await db.updateAppointmentStatus(apptId, 'cancelled', cancelledBy: 'patient');

      // Verify lock was released
      final locks = await fakeFirestore.collection('booked_slots').get();
      expect(locks.docs.length, 0);

      // Rebook same slot - should succeed now
      final result2 = await db.bookAppointmentForAi(
        doctorId,
        dateStr,
        timeStr,
        db: db,
        patientId: patientId,
      );
      final parsed2 = jsonDecode(result2);
      expect(parsed2['success'], isTrue);
    });

    // test('bookAppointmentForAi rejects when not logged in and no patientId provided', () async {
    //   // This test requires FirebaseAuth mock which conflicts with fake_cloud_firestore
    //   // The core functionality is tested by the first two tests which explicitly pass patientId
    // });
  });
}