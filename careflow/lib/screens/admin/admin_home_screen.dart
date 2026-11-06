import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../utils/constants.dart';
import '../../auth_wrapper.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final auth = AuthService();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Dashboard',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: db.streamUnverifiedDoctors(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final doctors = snapshot.data!;

          if (doctors.isEmpty) {
            return const Center(
              child: Text('No pending doctor requests.',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: kPrimaryBlue.withValues(alpha: 0.1),
                    radius: 30,
                    child:
                        const Icon(Icons.medical_services, color: kPrimaryBlue),
                  ),
                  title: Text(doctor.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(
                      '${doctor.specialty ?? 'General'} - ${doctor.email}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          await db.deleteUser(doctor.id);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          await db.approveDoctor(doctor.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
