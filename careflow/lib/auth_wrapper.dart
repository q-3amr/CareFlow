import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/user.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'utils/app_colors.dart';
import 'widgets/app_empty_state.dart';
import 'screens/guest/guest_home_screen.dart';
import 'screens/patient/patient_home_screen.dart';
import 'screens/doctors/doctor_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

class AuthWrapper extends StatefulWidget {
  final AuthService? authService;
  final DatabaseService? databaseService;

  const AuthWrapper({
    super.key,
    this.authService,
    this.databaseService,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _roleUid;
  Future<UserModel?>? _roleFuture;
  String? _tokenUid;

  AuthService get _auth => widget.authService ?? AuthService();
  DatabaseService get _db => widget.databaseService ?? DatabaseService();

  Future<UserModel?> _roleFor(String uid) {
    if (_roleUid != uid || _roleFuture == null) {
      _roleUid = uid;
      _roleFuture = _db.getUserById(uid);
    }
    return _roleFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges,
      builder: (context, snapshot) {
        final User? user = snapshot.data;

        // A cold start can emit null before the persisted session is restored.
        // Showing the guest home there makes the app look like it opened twice.
        if (user == null) {
          final stillRestoring =
              snapshot.connectionState == ConnectionState.waiting ||
                  FirebaseAuth.instance.currentUser != null;
          if (stillRestoring) return const _AuthLoadingScreen();
          return const GuestHomeScreen();
        }

        if (_tokenUid != user.uid) {
          _tokenUid = user.uid;
          _db.updateNotificationToken(user.uid);
        }

        return FutureBuilder<UserModel?>(
          future: _roleFor(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                body: SafeArea(
                  child: AppEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Unable to load profile',
                    message: roleSnapshot.error.toString(),
                    iconColor: AppColors.destructive,
                    iconBackgroundColor: AppColors.destructiveLight,
                    action: ElevatedButton(
                      onPressed: () => _auth.signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ),
                ),
              );
            }

            final userModel = roleSnapshot.data;
            debugPrint(
              'AuthWrapper: uid=${user.uid} role=${userModel?.role ?? 'missing'}',
            );
            if (userModel != null &&
                userModel.role.trim().toLowerCase() == 'admin') {
              return AdminHomeScreen(
                databaseService: _db,
                authService: _auth,
              );
            }
            if (userModel != null && userModel.isDoctor) {
              if (userModel.isVerified != true) {
                final isDark =
                    Theme.of(context).brightness == Brightness.dark;
                return Scaffold(
                  body: SafeArea(
                    child: AppEmptyState(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Account Under Review',
                      message:
                          'Your doctor credentials are being verified by the '
                          'CareFlow administration. You will gain access once '
                          'approved.',
                      iconColor: isDark
                          ? const Color(0xFFFCD34D)
                          : AppColors.warningText,
                      iconBackgroundColor: isDark
                          ? AppColors.warningSoftDark
                          : AppColors.warningLight,
                      action: OutlinedButton(
                        onPressed: () => _auth.signOut(),
                        child: const Text('Sign Out'),
                      ),
                    ),
                  ),
                );
              }
              return const DoctorHomeScreen();
            }

            if (userModel != null && userModel.isPatient) {
              return const PatientHomeScreen();
            }

            // Signed in but the profile is missing or has an unknown role.
            // Never fall through to the patient dashboard: that hid admin
            // routing bugs behind a patient session.
            return _UnknownProfileScreen(
              uid: user.uid,
              role: userModel?.role ?? 'missing',
              onSignOut: _auth.signOut,
            );
          },
        );
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _UnknownProfileScreen extends StatelessWidget {
  final String uid;
  final String role;
  final VoidCallback onSignOut;

  const _UnknownProfileScreen({
    required this.uid,
    required this.role,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: AppEmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile unavailable',
          message: 'Signed in as $uid\nRole: $role\n\n'
              'This account has no valid CareFlow profile. '
              'Contact the administrator.',
          iconColor: isDark ? const Color(0xFFFCD34D) : AppColors.warningText,
          iconBackgroundColor:
              isDark ? AppColors.warningSoftDark : AppColors.warningLight,
          action: ElevatedButton(
            onPressed: onSignOut,
            child: const Text('Sign Out'),
          ),
        ),
      ),
    );
  }
}
