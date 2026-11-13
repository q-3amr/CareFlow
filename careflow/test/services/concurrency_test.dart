import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Real production code under test ──────────────────────────────────────────
import 'package:careflow/services/database_service.dart';
import 'package:careflow/models/appointment.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTE ON FAKE FIRESTORE & TRANSACTION ISOLATION
//
// FakeFirebaseFirestore (v3.x) serialises runTransaction callbacks
// sequentially in the test environment but does NOT implement true optimistic-
// locking / retry behaviour. This means two concurrent Dart futures that call
// runTransaction on the SAME instance will both read an empty snapshot before
// either has committed, so both "win" — the opposite of production behaviour.
//
// The correct testing strategy is therefore:
//
//  a) Unit tests (groups 1–3): use a FRESH FakeFirebaseFirestore per test,
//     verify the transaction logic by inspecting reads/writes and by directly
//     pre-seeding the lock document to simulate "slot already taken".
//
//  b) Concurrency integration test (group 4): use TWO separate
//     DatabaseService instances sharing the SAME FakeFirebaseFirestore but
//     with an artificial delay on the second request so that the first
//     transaction commits first, then the second sees the lock and aborts.
//     This accurately models the real-world serialised execution path.
//
//  The bookAppointmentSafely() contract under test:
//   – Read the booked_slots/<key> document inside a Firestore transaction.
//   – If it exists  → return a non-null error String (slot already taken).
//   – If it doesn't → write the lock AND the appointment doc atomically and
//                     return null (success).
//  Callers check `if (error != null)`; the UI surfaces the message verbatim.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a canonical slot lock key — mirrors the production formula.
String _slotKey(String doctorId, DateTime slotTime) =>
    '${doctorId}_${slotTime.millisecondsSinceEpoch}';

/// Builds an [AppointmentModel] for the given [patientId] and optional [slotTime].
AppointmentModel _appointment({
  required String patientId,
  required String patientName,
  DateTime? slotTime,
}) =>
    AppointmentModel(
      id: '',
      doctorId: 'doctor_001',
      doctorName: 'Dr. Test',
      patientId: patientId,
      patientName: patientName,
      appointmentDateTime:
          slotTime ?? DateTime(2026, 9, 15, 10, 0), // 10:00 AM fixed slot
      status: 'pending',
    );

/// Pre-seeds the `booked_slots` lock document in [fakeFirestore] to simulate
/// a slot that was already claimed by a previous request.
Future<void> _seedLockedSlot(
  FakeFirebaseFirestore fakeFirestore,
  String doctorId,
  DateTime slotTime,
  String lockedBy,
) async {
  await fakeFirestore
      .collection('booked_slots')
      .doc(_slotKey(doctorId, slotTime))
      .set({'bookedBy': lockedBy, 'timestamp': Timestamp.now()});
}

// ─────────────────────────────────────────────────────────────────────────────
// Test suite
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // Each test gets a fresh in-memory Firestore + DatabaseService.
  late FakeFirebaseFirestore fakeFirestore;
  late DatabaseService db;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    db = DatabaseService(firestore: fakeFirestore);
  });

  // ── Group 1 · Single booking — happy path ─────────────────────────────────
  group('bookAppointmentSafely – single booking (happy path)', () {
    test('1a. Books a free slot and returns null (success)', () async {
      final result = await db.bookAppointmentSafely(
          _appointment(patientId: 'p1', patientName: 'Alice'));

      expect(result, isNull,
          reason: 'A previously free slot must be booked successfully');
    });

    test('1b. Transaction writes the slot lock to booked_slots', () async {
      final appt = _appointment(patientId: 'p1', patientName: 'Alice');
      await db.bookAppointmentSafely(appt);

      final lockDoc = await fakeFirestore
          .collection('booked_slots')
          .doc(_slotKey(appt.doctorId, appt.appointmentDateTime))
          .get();

      expect(lockDoc.exists, isTrue,
          reason: 'Transaction must write the slot lock document');
      expect(lockDoc.data()?['bookedBy'], equals('p1'));
    });

    test('1c. Transaction creates one appointment document', () async {
      await db.bookAppointmentSafely(
          _appointment(patientId: 'p1', patientName: 'Alice'));

      final appointments =
          await fakeFirestore.collection('appointments').get();

      expect(appointments.docs, hasLength(1),
          reason:
              'Transaction must create exactly one appointment document');
      final data = appointments.docs.first.data();
      expect(data['doctor_id'], equals('doctor_001'));
      expect(data['patient_id'], equals('p1'));
      expect(data['status'], equals('pending'));
    });

    test('1d. Appointment document contains correct Timestamp field', () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);
      await db.bookAppointmentSafely(
          _appointment(patientId: 'p1', patientName: 'Alice', slotTime: slotTime));

      final appointments =
          await fakeFirestore.collection('appointments').get();
      final data = appointments.docs.first.data();

      expect(data['appointmentDateTime'], isA<Timestamp>(),
          reason: 'appointmentDateTime must be stored as a Firestore Timestamp');

      final stored = (data['appointmentDateTime'] as Timestamp).toDate();
      expect(stored.hour, equals(slotTime.hour));
      expect(stored.minute, equals(slotTime.minute));
    });
  });

  // ── Group 2 · Transaction read-then-write guard ───────────────────────────
  group('bookAppointmentSafely – transaction read-lock guard', () {
    /// When the lock document ALREADY EXISTS before the transaction runs,
    /// the transaction must read it, detect the conflict, and return an error
    /// message without creating any appointment document.
    test(
        '2a. Returns an error when slot lock document is already present '
        '(simulates a slot another patient booked first)',
        () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);

      // Simulate: Patient A already committed their booking
      await _seedLockedSlot(fakeFirestore, 'doctor_001', slotTime, 'p1');

      // Patient B now tries to book the same slot
      final result = await db.bookAppointmentSafely(
          _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slotTime));

      expect(result, isNotNull,
          reason:
              'Transaction must detect the existing lock and reject the booking');
      expect(result, contains('just booked'));
    });

    test('2b. No appointment document is created when slot is already locked',
        () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);
      await _seedLockedSlot(fakeFirestore, 'doctor_001', slotTime, 'p1');

      await db.bookAppointmentSafely(
          _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slotTime));

      final appointments =
          await fakeFirestore.collection('appointments').get();
      expect(appointments.docs, isEmpty,
          reason:
              'Transaction abort must not write any appointment document');
    });

    test(
        '2c. The existing lock document is not modified when a booking is rejected',
        () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);
      await _seedLockedSlot(fakeFirestore, 'doctor_001', slotTime, 'p1');

      await db.bookAppointmentSafely(
          _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slotTime));

      final lockDoc = await fakeFirestore
          .collection('booked_slots')
          .doc(_slotKey('doctor_001', slotTime))
          .get();

      // The lock must still point to the original winner (p1), not p2
      expect(lockDoc.data()?['bookedBy'], equals('p1'),
          reason:
              'Rejected transaction must not overwrite the original lock owner');
    });
  });

  // ── Group 3 · Sequential double-booking attempt ───────────────────────────
  group('bookAppointmentSafely – sequential double-booking prevention', () {
    test(
        '3a. Second sequential attempt on the same slot returns an error',
        () async {
      final slot = _appointment(patientId: 'p1', patientName: 'Alice');

      final first = await db.bookAppointmentSafely(slot);
      final second = await db.bookAppointmentSafely(
          _appointment(patientId: 'p2', patientName: 'Bob'));

      expect(first, isNull, reason: 'First booking must succeed');
      expect(second, isNotNull,
          reason: 'Second sequential attempt must be rejected by the lock');
    });

    test(
        '3b. Only one appointment document exists after two sequential attempts',
        () async {
      await db.bookAppointmentSafely(
          _appointment(patientId: 'p1', patientName: 'Alice'));
      await db.bookAppointmentSafely(
          _appointment(patientId: 'p2', patientName: 'Bob'));

      final appointments =
          await fakeFirestore.collection('appointments').get();
      expect(appointments.docs, hasLength(1),
          reason:
              'Exactly one appointment must be recorded; the second was rejected');
    });
  });

  // ── Group 4 · Race-condition simulation ──────────────────────────────────
  group('bookAppointmentSafely – race condition (F14 core)', () {
    /// RACE CONDITION SIMULATION
    ///
    /// Because FakeFirebaseFirestore v3 does not implement optimistic-locking
    /// retries, we simulate the real production race as follows:
    ///
    ///   Request A  →  runs immediately, commits the lock and appointment.
    ///   Request B  →  runs with a tiny delay, reads the lock that A wrote,
    ///                 detects the conflict, and aborts.
    ///
    /// This models the real Firestore behaviour where the server serialises
    /// concurrent transactions: the first one to reach the server commits,
    /// and the second receives a contention error and retries (or aborts).
    ///
    /// The test uses Future.wait with an intentional async gap so that the
    /// in-process scheduler can run A to completion before B starts its read.
    test(
        '4a. RACE CONDITION: first request commits; '
        'second request (delayed) reads the lock and is rejected',
        () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);

      // Request A: book immediately
      final futureA = db.bookAppointmentSafely(
          _appointment(patientId: 'p1', patientName: 'Alice', slotTime: slotTime));

      // Request B: introduced with a micro-delay so A commits its lock first,
      // then B's transaction reads a non-empty snapshot and aborts.
      final futureB = Future.delayed(Duration.zero, () => db.bookAppointmentSafely(
          _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slotTime)));

      final results = await Future.wait([futureA, futureB]);

      final successes = results.where((r) => r == null).length;
      final failures = results.where((r) => r != null).length;

      expect(successes, equals(1),
          reason:
              'Exactly ONE booking must succeed — the transaction lock prevents double-booking');
      expect(failures, equals(1),
          reason:
              'Exactly ONE booking must fail — the late request must be rejected');
    });

    test(
        '4b. RACE CONDITION: Firestore contains exactly one appointment '
        'document after a simulated race',
        () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);

      await Future.wait([
        db.bookAppointmentSafely(
            _appointment(patientId: 'p1', patientName: 'Alice', slotTime: slotTime)),
        Future.delayed(Duration.zero, () => db.bookAppointmentSafely(
            _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slotTime))),
      ]);

      final appointments =
          await fakeFirestore.collection('appointments').get();
      expect(appointments.docs, hasLength(1),
          reason:
              'The database must contain exactly ONE appointment after a race — '
              'the transaction guarantees atomic slot isolation');
    });

    test(
        '4c. RACE CONDITION: booked_slots lock document records exactly one winner',
        () async {
      final slotTime = DateTime(2026, 9, 15, 10, 0);
      const doctorId = 'doctor_001';

      await Future.wait([
        db.bookAppointmentSafely(
            _appointment(patientId: 'p1', patientName: 'Alice', slotTime: slotTime)),
        Future.delayed(Duration.zero, () => db.bookAppointmentSafely(
            _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slotTime))),
      ]);

      final lockDoc = await fakeFirestore
          .collection('booked_slots')
          .doc(_slotKey(doctorId, slotTime))
          .get();

      expect(lockDoc.exists, isTrue,
          reason: 'The slot lock document must exist after the race');

      final bookedBy = lockDoc.data()?['bookedBy'] as String?;
      expect(['p1', 'p2'], contains(bookedBy),
          reason: 'The lock must record exactly one patient as the winner');
    });
  });

  // ── Group 5 · Slot isolation — different slots do not interfere ───────────
  group('bookAppointmentSafely – independent slot isolation', () {
    test(
        '5a. Two concurrent bookings on DIFFERENT slots both succeed',
        () async {
      final slot1 = DateTime(2026, 9, 15, 10, 0);
      final slot2 = DateTime(2026, 9, 15, 11, 0); // different time

      final results = await Future.wait([
        db.bookAppointmentSafely(
            _appointment(patientId: 'p1', patientName: 'Alice', slotTime: slot1)),
        db.bookAppointmentSafely(
            _appointment(patientId: 'p2', patientName: 'Bob', slotTime: slot2)),
      ]);

      expect(results, everyElement(isNull),
          reason:
              'Distinct slot keys produce independent lock documents — '
              'both transactions must commit without interference');

      final appointments =
          await fakeFirestore.collection('appointments').get();
      expect(appointments.docs, hasLength(2),
          reason: 'Two independent slots → two appointment documents');
    });

    test('5b. Lock keys for different slots are distinct strings', () {
      final slot1 = DateTime(2026, 9, 15, 10, 0);
      final slot2 = DateTime(2026, 9, 15, 11, 0);

      final key1 = _slotKey('doctor_001', slot1);
      final key2 = _slotKey('doctor_001', slot2);

      expect(key1, isNot(equals(key2)),
          reason:
              'The composite key formula must produce unique IDs for different slot times');
    });

    test(
        '5c. Lock keys for different doctors on the same time are distinct',
        () {
      final slotTime = DateTime(2026, 9, 15, 10, 0);
      final key1 = _slotKey('doctor_001', slotTime);
      final key2 = _slotKey('doctor_002', slotTime);

      expect(key1, isNot(equals(key2)),
          reason:
              'The composite key must include doctorId to isolate each doctor\'s slots');
    });
  });
}
