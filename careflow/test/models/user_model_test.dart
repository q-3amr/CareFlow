import 'package:flutter_test/flutter_test.dart';
import 'package:careflow/models/user.dart';

void main() {
  group('UserModel Tests', () {
    test('UserModel should create patient user correctly', () {
      final user = UserModel(
        id: 'test-id',
        email: 'patient@test.com',
        pushToken: "",
        name: 'Test Patient',
        role: 'patient',
        profileImage: '',
      );

      expect(user.id, 'test-id');
      expect(user.email, 'patient@test.com');
      expect(user.name, 'Test Patient');
      expect(user.role, 'patient');
      expect(user.specialty, isNull);
      expect(user.location, isNull);
    });

    test('UserModel should create doctor user correctly', () {
      final user = UserModel(
        id: 'doctor-id',
        email: 'doctor@test.com',
        name: 'Test Doctor',
        pushToken: "",
        role: 'doctor',
        profileImage: '',
        specialty: 'Cardiology',
        location: 'Amman',
        rating: 4.5,
        about: 'Experienced cardiologist',
        isVerified: true,
      );

      expect(user.role, 'doctor');
      expect(user.specialty, 'Cardiology');
      expect(user.location, 'Amman');
      expect(user.rating, 4.5);
      expect(user.isVerified, true);
    });

    test('UserModel should convert to map correctly', () {
      final user = UserModel(
        id: 'test-id',
        email: 'test@test.com',
        name: 'Test User',
        role: 'patient',
        profileImage: '',
        pushToken: "",
      );

      final map = user.toMap();

      expect(map.containsKey('id'), false);
      expect(map['email'], 'test@test.com');
      expect(map['name'], 'Test User');
      expect(map['role'], 'patient');
      expect(map['profileImage'], '');
    });

    test('UserModel should create from map correctly', () {
      final map = {
        'email': 'test@test.com',
        'name': 'Test User',
        'role': 'patient',
        'profileImage': '',
      };

      final user = UserModel.fromMap(map, 'test-id');

      expect(user.id, 'test-id');
      expect(user.email, 'test@test.com');
      expect(user.name, 'Test User');
      expect(user.role, 'patient');
    });
  });
}
