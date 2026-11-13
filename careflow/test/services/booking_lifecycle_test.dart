import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:careflow/models/appointment.dart';
import 'package:careflow/services/database_service.dart';

/// Regression tests for the booking lifecycle and the public reviews
/// collection. Both areas caused real bugs:
///  - a cancelled/rejected appointment kept its slot lock forever, so the
///    slot could never be booked again;
///  - reviews lived on appointment docs, which patients cannot read, so the
///    doctor profile spinner never resolved.
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DatabaseService db;

  const doctorId = 'doctor_001';
  final slotTime = DateTime(2026, 9, 15, 10, 0);

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    db = DatabaseService(firestore: fakeFirestore);
  });

  AppointmentModel appointment({
    String patientId = 'p1',
    String patientName = 'Alice',
    DateTime? at,
  }) =>
      AppointmentModel(
        id: '',
        doctorId: doctorId,
        doctorName: 'Dr. Test',
        patientId: patientId,
        patientName: patientName,
        appointmentDateTime: at ?? slotTime,
        status: 'pending',
      );

  String slotKey(String doctor, DateTime at) =>
      '${doctor}_${at.millisecondsSinceEpoch}';

  Future<String> bookOne({String patientId = 'p1'}) async {
    final error = await db.bookAppointmentSafely(
      appointment(patientId: patientId, patientName: patientId),
    );
    expect(error, isNull);
    final snap = await fakeFirestore.collection('appointments').get();
    return snap.docs.single.id;
  }

  group('slot release when an appointment leaves the active states', () {
    test('cancelled appointment deletes its booked_slots lock', () async {
      final id = await bookOne();

      await db.updateAppointmentStatus(id, 'cancelled',
          cancelledBy: 'patient');

      final lock =
          await fakeFirestore.collection('booked_slots').doc(slotKey(doctorId, slotTime)).get();
      expect(lock.exists, isFalse,
          reason: 'A cancelled slot must become bookable again');

      final appt =
          await fakeFirestore.collection('appointments').doc(id).get();
      expect(appt.data()?['status'], equals('cancelled'));
      expect(appt.data()?['cancelledBy'], equals('patient'));
    });

    test('rejected appointment deletes its booked_slots lock', () async {
      final id = await bookOne();

      await db.updateAppointmentStatus(id, 'rejected');

      final lock =
          await fakeFirestore.collection('booked_slots').doc(slotKey(doctorId, slotTime)).get();
      expect(lock.exists, isFalse);
    });

    test('accepted appointment keeps its booked_slots lock', () async {
      final id = await bookOne();

      await db.updateAppointmentStatus(id, 'accepted');

      final lock =
          await fakeFirestore.collection('booked_slots').doc(slotKey(doctorId, slotTime)).get();
      expect(lock.exists, isTrue,
          reason: 'Accepting must not free the slot for someone else');
    });

    test('slot can be rebooked after cancellation', () async {
      final id = await bookOne(patientId: 'p1');
      await db.updateAppointmentStatus(id, 'cancelled');

      final second = await db.bookAppointmentSafely(
        appointment(patientId: 'p2', patientName: 'Bob'),
      );

      expect(second, isNull, reason: 'Released slot must be bookable again');
      final appointments =
          await fakeFirestore.collection('appointments').get();
      expect(appointments.docs, hasLength(2));
    });

    test('deleteAppointment removes both appointment and lock', () async {
      final id = await bookOne();

      await db.deleteAppointment(id);

      expect(
        (await fakeFirestore.collection('appointments').doc(id).get()).exists,
        isFalse,
      );
      final lock =
          await fakeFirestore.collection('booked_slots').doc(slotKey(doctorId, slotTime)).get();
      expect(lock.exists, isFalse,
          reason: 'Deleting a record must not leave the slot locked forever');
    });
  });

  group('public reviews collection', () {
    test('saveReviewForAppointment copies the appointment into reviews',
        () async {
      final id = await bookOne(patientId: 'p1');

      await db.saveReviewForAppointment(
        appointmentId: id,
        rating: 5,
        feedbackText: 'Great experience',
      );

      final review =
          await fakeFirestore.collection('reviews').doc(id).get();
      expect(review.exists, isTrue);
      final data = review.data()!;
      expect(data['appointment_id'], equals(id));
      expect(data['doctor_id'], equals(doctorId));
      expect(data['patient_id'], equals('p1'));
      expect(data['patient_name'], equals('p1'));
      expect(data['rating'], equals(5));
      expect(data['feedback_text'], equals('Great experience'));
    });

    test('saving twice updates the same review instead of duplicating',
        () async {
      final id = await bookOne();

      await db.saveReviewForAppointment(
          appointmentId: id, rating: 4, feedbackText: 'Good');
      await db.saveReviewForAppointment(
          appointmentId: id, rating: 2, feedbackText: 'Changed my mind');

      final reviews = await fakeFirestore.collection('reviews').get();
      expect(reviews.docs, hasLength(1));
      expect(reviews.docs.single.data()['rating'], equals(2));
    });

    test('streamReviewsForDoctor only emits that doctor\'s reviews',
        () async {
      final id = await bookOne();
      await db.saveReviewForAppointment(
          appointmentId: id, rating: 5, feedbackText: 'Excellent');

      final snap = await db.streamReviewsForDoctor(doctorId).first;
      expect(snap.docs, hasLength(1));
      expect(
        (snap.docs.single.data() as Map<String, dynamic>)['feedback_text'],
        equals('Excellent'),
      );

      final other = await db.streamReviewsForDoctor('doctor_999').first;
      expect(other.docs, isEmpty);
    });

    test('updateDoctorAggregateRating averages reviews into the user doc',
        () async {
      await fakeFirestore.collection('users').doc(doctorId).set({
        'name': 'Dr. Test',
        'role': 'doctor',
      });
      final id = await bookOne();
      await db.saveReviewForAppointment(
          appointmentId: id, rating: 5, feedbackText: 'Excellent');
      await fakeFirestore.collection('reviews').doc('second').set({
        'doctor_id': doctorId,
        'patient_id': 'p2',
        'rating': 4,
        'feedback_text': 'Good',
      });

      await db.updateDoctorAggregateRating(doctorId);

      final user = await fakeFirestore.collection('users').doc(doctorId).get();
      expect(user.data()?['rating'], equals(4.5));
      expect(user.data()?['reviewCount'], equals(2));
    });
  });
}
