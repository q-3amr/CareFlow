import 'package:flutter/material.dart';
import 'package:careflow/models/user.dart';
import 'package:careflow/services/database_service.dart';

class DoctorsListScreen extends StatelessWidget {
  const DoctorsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();

    return Scaffold(
      appBar: AppBar(title: const Text('Available Doctors')),
      body: StreamBuilder<List<UserModel>>(
        stream: db.streamDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final doctors = snapshot.data ?? [];

          if (doctors.isEmpty) {
            return const Center(child: Text('No doctors found.'));
          }

          return ListView.builder(
            itemCount: doctors.length,
            itemBuilder: (context, index) {
              final doctor = doctors[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        (doctor.profileImage != null &&
                            doctor.profileImage!.isNotEmpty)
                        ? NetworkImage(doctor.profileImage!)
                        : null,
                    child:
                        (doctor.profileImage == null ||
                            doctor.profileImage!.isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    doctor.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Text(
                    '${doctor.specialty ?? 'General'} • ${doctor.location ?? 'Unknown'}\nRating: ${doctor.rating?.toStringAsFixed(1) ?? '0.0'}',
                  ),

                  isThreeLine: true,
                  trailing: (doctor.isVerified == true)
                      ? const Icon(Icons.verified, color: Colors.green)
                      : null,
                  onTap: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
