import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';

class ScheduleScreen extends StatefulWidget {
  final bool isDoctor;

  const ScheduleScreen({super.key, required this.isDoctor});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _db = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;

  int _selectedTab = 0;

  bool _isExpired(DateTime appointmentDate) => isExpiredAppointment(appointmentDate);

  void _cancelAppointment(String docId) async {
    final confirm = await _confirmDialog(
          title: 'Cancel Appointment?',
          message: 'Are you sure you want to cancel this scheduled consultation?',
          confirmLabel: 'Cancel Appointment',
          confirmColor: AppColors.destructive,
        ) ??
        false;

    if (confirm) {
      await _db.updateAppointmentStatus(
        docId,
        'cancelled',
        cancelledBy: 'patient',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Appointment has been cancelled'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _completeAppointment(String docId) async {
    final confirm = await _confirmDialog(
          title: 'Complete Appointment?',
          message: 'Confirm that this clinical consultation has been completed?',
          confirmLabel: 'Mark Completed',
          confirmColor: AppColors.success,
        ) ??
        false;

    if (confirm) {
      await _db.updateAppointmentStatus(docId, 'completed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Consultation marked as completed'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _deleteAppointment(String docId) async {
    final confirm = await _confirmDialog(
          title: 'Remove from History?',
          message: 'Permanently remove this appointment record from history?',
          confirmLabel: 'Remove Record',
          confirmColor: AppColors.destructive,
        ) ??
        false;

    if (confirm) {
      await _db.deleteAppointment(docId);
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        title: Text(title, style: AppTypography.title.copyWith(color: textPrimary)),
        content: Text(message, style: AppTypography.body.copyWith(color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Back', style: AppTypography.label.copyWith(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, AppMetrics.controlHeight),
            ),
            child: Text(confirmLabel, style: AppTypography.label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Schedule'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Segmented Tabs Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            color: Theme.of(context).cardColor,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.backgroundDark
                    : AppColors.surfaceSunken,
                borderRadius: AppRadius.medium,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  _buildTab('Upcoming Sessions', 0, isDark),
                  const SizedBox(width: AppSpacing.xs),
                  _buildTab('History & Past', 1, isDark),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Appointments List Stream
          Expanded(
            child: StreamBuilder<dynamic>(
              stream: user?.uid != null
                  ? _db.streamUserAppointments(user!.uid, isDoctor: widget.isDoctor)
                  : null,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(textPrimary, textSecondary);
                }

                final docs = snapshot.data!.docs;

                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String;
                  final date = parseDate(data['appointmentDateTime']);
                  final expired = _isExpired(date);

                  if (_selectedTab == 0) {
                    return status == 'accepted' && !expired;
                  } else {
                    return status == 'completed' ||
                        status == 'cancelled' ||
                        status == 'rejected' ||
                        (status == 'accepted' && expired);
                  }
                }).toList();

                filtered.sort((a, b) {
                  final dateA = parseDate((a.data() as Map)['appointmentDateTime']);
                  final dateB = parseDate((b.data() as Map)['appointmentDateTime']);
                  return _selectedTab == 0 ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
                });

                if (filtered.isEmpty) {
                  return _buildEmptyState(textPrimary, textSecondary);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildAppointmentCard(
                    filtered[index],
                    isDark,
                    textPrimary,
                    textSecondary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, bool isDark) {
    final active = _selectedTab == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        child: InkWell(
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: AppRadius.small,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: AppMetrics.minTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? (isDark ? AppColors.cardTintDark : AppColors.cardLight)
                  : Colors.transparent,
              borderRadius: AppRadius.small,
              boxShadow: active && !isDark ? AppShadows.soft : null,
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: active
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
    dynamic doc,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final String name = widget.isDoctor
        ? (data['patient_name'] ?? 'Patient')
        : (data['doctor_name'] ?? 'Doctor');
    final DateTime dateObj = parseDate(data['appointmentDateTime']);
    final String dateStr = formatDateDisplay(dateObj);
    final String timeStr = formatTimeFromDateTime(dateObj);
    final bool expired = _isExpired(dateObj);
    final String status = data['status'];

    String displayStatus;
    AppBadgeVariant badgeVariant;

    if (status == 'accepted' && !expired) {
      displayStatus = 'Confirmed';
      badgeVariant = AppBadgeVariant.primary;
    } else if (status == 'accepted' && expired) {
      displayStatus = 'Passed';
      badgeVariant = AppBadgeVariant.warning;
    } else if (status == 'cancelled') {
      displayStatus = 'Cancelled';
      badgeVariant = AppBadgeVariant.warning;
    } else if (status == 'rejected') {
      displayStatus = 'Declined';
      badgeVariant = AppBadgeVariant.destructive;
    } else if (status == 'completed') {
      displayStatus = 'Completed';
      badgeVariant = AppBadgeVariant.success;
    } else {
      displayStatus = status;
      badgeVariant = AppBadgeVariant.neutral;
    }

    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join()
        : 'US';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                AppAvatar(initials: initials, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isDoctor ? name : 'Dr. $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.section.copyWith(
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppBadge(
                        label: displayStatus,
                        variant: badgeVariant,
                      ),
                    ],
                  ),
                ),

                // Doctor action: complete
                if (widget.isDoctor && displayStatus == 'Confirmed')
                  IconButton(
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                    tooltip: 'Mark completed',
                    onPressed: () => _completeAppointment(doc.id),
                  ),

                // Patient action: cancel
                if (!widget.isDoctor && displayStatus == 'Confirmed')
                  IconButton(
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.destructive,
                    ),
                    tooltip: 'Cancel appointment',
                    onPressed: () => _cancelAppointment(doc.id),
                  ),

                // History action: remove
                if (_selectedTab == 1)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: textSecondary,
                    ),
                    tooltip: 'Remove',
                    onPressed: () => _deleteAppointment(doc.id),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            const SizedBox(height: AppSpacing.md),

            // Date & Time Footer
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: AppIconSize.sm,
                  color: textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    dateStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(
                  Icons.access_time_rounded,
                  size: AppIconSize.sm,
                  color: textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  timeStr,
                  style: AppTypography.caption.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return AppEmptyState(
      icon: Icons.event_available_rounded,
      title: _selectedTab == 0
          ? 'No Upcoming Consultations'
          : 'No History Found',
      message: _selectedTab == 0
          ? 'Your scheduled appointments will appear here.'
          : 'Completed or past consultations will be recorded here.',
    );
  }
}
