import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Stream<User?> get authStateChanges => auth.authStateChanges();

  User? get currentUser => auth.currentUser;

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code, _loginErrors);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? specialty,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      UserCredential result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user == null) return;

      UserModel newUser = UserModel(
        id: user.uid,
        email: email,
        name: name,
        role: role,
        profileImage: '',
        specialty: role == 'doctor' ? (specialty ?? 'General') : null,
        location: role == 'doctor' ? (location ?? 'Amman') : null,
        latitude: role == 'doctor' ? latitude : null,
        longitude: role == 'doctor' ? longitude : null,
        rating: role == 'doctor' ? 0.0 : null,
        about: role == 'doctor' ? 'New Doctor' : null,
        pushToken: await _fcm.getToken(),
        isVerified: role == 'doctor' ? false : null,
      );

      final userMap = newUser.toMap();

      userMap['createdAt'] = FieldValue.serverTimestamp();

      await firestore.collection('users').doc(user.uid).set(userMap);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code, _signupErrors);
    } catch (e) {
      throw 'Error saving user data: $e';
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code, _resetErrors);
    }
  }

  Future<void> signOut() async => await auth.signOut();

  static String _mapAuthError(String code, Map<String, String> map) {
    return map[code] ?? map['default']!;
  }

  static const Map<String, String> _loginErrors = {
    'user-not-found': 'Incorrect email or password.',
    'wrong-password': 'Incorrect email or password.',
    'invalid-credential': 'Incorrect email or password.',
    'invalid-email': 'Invalid email format.',
    'network-request-failed': 'No internet connection.',
    'user-disabled': 'This user has been disabled.',
    'default': 'Login failed. Please try again.',
  };

  static const Map<String, String> _signupErrors = {
    'email-already-in-use': 'The email is already in use.',
    'weak-password': 'The password is too weak.',
    'invalid-email': 'Invalid email format.',
    'default': 'An error occurred during registration.',
  };

  static const Map<String, String> _resetErrors = {
    'invalid-email': 'Invalid email format.',
    'network-request-failed': 'No internet connection.',
    'user-not-found': 'No account found with this email.',
    'default': 'Failed to send reset email.',
  };
}
