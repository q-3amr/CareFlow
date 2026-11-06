import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../services/message.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';

class DoctorRequestsScreen extends StatefulWidget {
  const DoctorRequestsScreen({super.key});

  @override
  State<DoctorRequestsScreen> createState() => _DoctorRequestsScreenState();
}

class _DoctorRequestsScreenState extends State<DoctorRequestsScreen> {
  final _db = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  final MessageServices _messageServices = MessageServices();

  String _formatDateTime(DateTime date) {
    final datePart = formatDateDisplay(date);
    final timePart = formatTimeFromDateTime(date);
    return '$datePart | $timePart';
  }

  Future<void> _acceptRequest(String docId, String patientId) async {
    await _db.updateAppointmentStatus(docId, 'accepted');

    final token = await _db.getToken(
        patientId); //جلب توكن المريض //هذا السطر هو الذي يبحث في قاعدة البيانات عن "العنوان الرقمي" (FCM Token) الخاص بجهاز المريض
    if (token.isNotEmpty) {
      //ارسال القبول
      await _messageServices.sendNotificationToUser(
          fcmToken: token,
          title: 'Appointment Accepted',
          body: 'Your appointment request has been accepted by the doctor.',
          type: 'appointment');
    }
  }

  Future<void> _declineRequest(String docId, String patientId) async {
    await _db.updateAppointmentStatus(
      docId,
      'rejected',
      cancelledBy: 'doctor',
    );

    final token = await _db.getToken(patientId); //جلب توكن المريض
    if (token.isNotEmpty) {
      //ارسال الرفض
      await _messageServices.sendNotificationToUser(
          fcmToken: token,
          title: 'Appointment Rejected',
          body: 'Your appointment request has been rejected by the doctor.',
          type: 'appointment');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pending Requests',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: StreamBuilder<dynamic>(
          stream: user?.uid != null
              ? _db.streamPendingAppointments(user!.uid)
              : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'No pending requests',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }

            final requests = snapshot.data!.docs;

            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final data = req.data() as Map<String, dynamic>;
                final dateObj = parseDate(data['appointmentDateTime']);

                return _buildRequestCard(
                  name: data['patient_name'] ?? 'Unknown',
                  date: _formatDateTime(dateObj),
                  docId: req.id,
                  patientId:
                      data['patient_id'] ?? '', // ← معرف المريض لإرسال الإشعار
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required String name,
    required String date,
    required String docId,
    required String patientId, // ← معرف المريض لإرسال إشعار القبول/الرفض
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.shade100, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_filled_rounded,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            date,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _declineRequest(docId, patientId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(docId, patientId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: kPrimaryBlue.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
