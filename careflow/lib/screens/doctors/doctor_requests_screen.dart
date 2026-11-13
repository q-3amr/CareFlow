import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../services/message.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';

class DoctorRequestsScreen extends StatefulWidget {
  final bool isTab;

  const DoctorRequestsScreen({super.key, this.isTab = false});

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
    return '$datePart · $timePart';
  }

  Future<void> _acceptRequest(String docId, String patientId) async {
    await _db.updateAppointmentStatus(docId, 'accepted');

    final token = await _db.getToken(patientId);
    if (token.isNotEmpty) {
      await _messageServices.sendNotificationToUser(
        fcmToken: token,
        title: 'Appointment Accepted',
        body: 'Your appointment request has been accepted by the doctor.',
        type: 'appointment',
      );
    }
  }

  Future<void> _declineRequest(String docId, String patientId) async {
    await _db.updateAppointmentStatus(
      docId,
      'rejected',
      cancelledBy: 'doctor',
    );

    final token = await _db.getToken(patientId);
    if (token.isNotEmpty) {
      await _messageServices.sendNotificationToUser(
        fcmToken: token,
        title: 'Appointment Rejected',
        body: 'Your appointment request has been rejected by the doctor.',
        type: 'appointment',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab,
        title: const Text('Pending requests'),
      ),
      body: StreamBuilder<dynamic>(
        stream:
            user?.uid != null ? _db.streamPendingAppointments(user!.uid) : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.inbox_rounded,
              title: 'No pending requests',
              message: 'New patient requests will appear here.',
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            padding: AppSpacing.screen,
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final data = req.data() as Map<String, dynamic>;
              final dateObj = parseDate(data['appointmentDateTime']);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildRequestCard(
                  name: data['patient_name'] ?? 'Unknown',
                  date: _formatDateTime(dateObj),
                  docId: req.id,
                  patientId: data['patient_id'] ?? '',
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard({
    required String name,
    required String date,
    required String docId,
    required String patientId,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = AppColors.textSecondary(isDark);
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(initials: initial, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.section.copyWith(
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: AppIconSize.sm,
                          color: textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            date,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AppBadge(
                label: 'Pending',
                variant: AppBadgeVariant.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineRequest(docId, patientId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.destructive,
                    side: const BorderSide(color: AppColors.destructive),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(docId, patientId),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
