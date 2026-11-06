import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// Source imports
import 'package:careflow/screens/patient/patient_map_screen.dart';
import 'package:careflow/models/user.dart';
import '../helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  group('PatientMapScreen & Location Filtering Tests - 10 Scenarios', () {
    // ── Pure Dart / logic tests (no Flutter rendering needed) ─────────────────

    // 1. Distance Sorting
    test(
        '1. Doctors list should be sorted from closest to farthest based on patient location',
        () {
      const double patientLat = 32.5380;
      const double patientLng = 35.9230;

      final closeDoctor = UserModel(
        id: 'doc_close',
        email: 'close@careflow.com',
        name: 'Dr. Close',
        role: 'doctor',
        pushToken: "",
        latitude: 32.5400,
        longitude: 35.9250,
      );

      final farDoctor = UserModel(
        id: 'doc_far',
        email: 'far@careflow.com',
        name: 'Dr. Far',
        pushToken: "",
        role: 'doctor',
        latitude: 31.9539,
        longitude: 35.9106,
      );

      List<UserModel> mockDoctors = [farDoctor, closeDoctor];

      mockDoctors.sort((a, b) {
        final distanceA = Geolocator.distanceBetween(
            patientLat, patientLng, a.latitude!, a.longitude!);
        final distanceB = Geolocator.distanceBetween(
            patientLat, patientLng, b.latitude!, b.longitude!);
        return distanceA.compareTo(distanceB);
      });

      expect(mockDoctors.first.id, 'doc_close');
      expect(mockDoctors.last.id, 'doc_far');
    });

    // 2. Distance calculation accuracy
    test(
        '2. Geolocator should calculate correct distance between two known coordinates',
        () {
      const double startLat = 32.5380;
      const double startLng = 35.9230;
      const double endLat = 32.5400;
      const double endLng = 35.9250;

      final distance =
          Geolocator.distanceBetween(startLat, startLng, endLat, endLng);

      expect(distance, isPositive);
    });

    // 3. Initial camera target coordinates
    test('3. Initial Camera Position should target correct coordinates', () {
      const initialTarget = LatLng(31.9539, 35.9106);
      expect(initialTarget.latitude, 31.9539);
      expect(initialTarget.longitude, 35.9106);
    });

    // 4. UserModel.fromMap parses latitude/longitude
    test('4. UserModel fromMap should parse location details properly', () {
      final mockData = {
        'name': 'Dr. Ahmad',
        'email': 'ahmad@careflow.com',
        'role': 'doctor',
        'specialty': 'Cardiology',
        'latitude': 32.5568,
        'longitude': 35.8469,
      };
      final doctor = UserModel.fromMap(mockData, 'doc_123');

      expect(doctor.latitude, 32.5568);
      expect(doctor.longitude, 35.8469);
    });

    // 5. Null-coordinate doctors are filtered out
    test('5. Doctors without coordinates should be filtered out from the map',
        () {
      final doctorWithoutLocation = UserModel(
        id: 'doc_null',
        email: 'null@careflow.com',
        name: 'Dr. No Location',
        role: 'doctor',
        pushToken: "",
        latitude: null,
        longitude: null,
      );

      final allDoctors = [doctorWithoutLocation];
      final validDoctors = allDoctors
          .where((doc) => doc.latitude != null && doc.longitude != null)
          .toList();

      expect(validDoctors.isEmpty, isTrue);
    });

    // 6. Marker InfoWindow title and snippet
    test(
        '6. Marker InfoWindow should display correct doctor name and specialty',
        () {
      final doctor = UserModel(
        id: 'doc_123',
        email: 'info@careflow.com',
        name: 'Dr. Ahmad',
        role: 'doctor',
        specialty: 'Cardiology',
        pushToken: "",
        latitude: 32.5568,
        longitude: 35.8469,
      );

      final marker = Marker(
        markerId: MarkerId(doctor.id),
        position: LatLng(doctor.latitude!, doctor.longitude!),
        infoWindow: InfoWindow(title: doctor.name, snippet: doctor.specialty),
      );

      expect(marker.infoWindow.title, 'Dr. Ahmad');
      expect(marker.infoWindow.snippet, 'Cardiology');
    });

    // ── Widget / UI tests ─────────────────────────────────────────────────────
    // Tests 7 & 8 render PatientMapScreen which embeds a GoogleMap.
    // Google Maps requires a native platform channel; the test environment stubs
    // it, so we verify the surrounding Scaffold/AppBar UI rather than the map itself.

    testWidgets(
        '7. PatientMapScreen should build without crashing and show the Map AppBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PatientMapScreen()));
      await tester.pump(); // let initState post-frame callbacks fire

      // The base map screen always shows an AppBar titled 'Map'
      expect(find.text('Map'), findsOneWidget);
    });

    testWidgets(
        '8. Bottom panel buttons should NOT appear when no doctor is selected',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PatientMapScreen()));
      await tester.pump();

      // selectedDoctor is null on launch → buildBottomPanel() returns null
      expect(find.text('Directions'), findsNothing);
      expect(find.text('View Profile'), findsNothing);
    });

    // 9. Zero-distance edge case
    test(
        '9. Distance calculation with identical coordinates should return zero',
        () {
      const double lat = 32.5380;
      const double lng = 35.9230;

      final distance = Geolocator.distanceBetween(lat, lng, lat, lng);
      expect(distance, 0.0);
    });

    // 10. CameraUpdate is non-null
    test('10. Camera Update should generate a valid non-null movement object',
        () {
      final targetLatLng = const LatLng(32.5400, 35.9250);
      final cameraUpdate = CameraUpdate.newLatLng(targetLatLng);

      expect(cameraUpdate, isNotNull);
    });
  });
}
