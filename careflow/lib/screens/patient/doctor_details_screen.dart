import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../services/message.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/star_rating_widget.dart';
import '../common/chat_screen.dart';
import '../auth/login_screen.dart';
import '../../models/appointment.dart';
import '../../models/user.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final String doctorName;
  final String specialty;
  final String? doctorId;
  final double? latitude;
  final double? longitude;
  final double? distance;

  const DoctorDetailsScreen({
    super.key,
    required this.doctorName,
    required this.specialty,
    this.doctorId,
    this.latitude,
    this.longitude,
    this.distance,
  });

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  final _db = DatabaseService();
  final MessageServices _messageServices = MessageServices();

  User? get _user => FirebaseAuth.instance.currentUser;

  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  List<String> _availableSlots = [];
  bool _isLoadingSlots = false;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _generateSlotsForDate(_selectedDate);
  }

  Future<void> _openDirections() async {
    if (widget.latitude != null && widget.longitude != null) {
      final Uri googleMapsUrl = Uri.parse(
        'google.navigation:q=${widget.latitude},${widget.longitude}&mode=d',
      );

      try {
        if (await canLaunchUrl(googleMapsUrl)) {
          await launchUrl(googleMapsUrl);
        } else {
          final Uri webUrl = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${widget.latitude},${widget.longitude}',
          );
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open map navigation'),
              backgroundColor: AppColors.destructive,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _generateSlotsForDate(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _selectedTimeSlot = null;
    });

    final dateKey = formatDateKey(date);
    final availabilityDoc =
        await _db.getAvailability(widget.doctorId ?? '', dateKey);

    if (!availabilityDoc.exists || availabilityDoc['slots'] == null) {
      if (mounted) {
        setState(() {
          _availableSlots = [];
          _isLoadingSlots = false;
        });
      }
      return;
    }

    final List<String> doctorSlots =
        List<String>.from(availabilityDoc['slots']);

    final appointmentsSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('doctor_id', isEqualTo: widget.doctorId ?? '')
        .where('status', whereIn: ['pending', 'accepted']).get();

    final Set<String> takenTimes = {};
    for (var doc in appointmentsSnap.docs) {
      final data = doc.data();
      final rawDate = data['appointmentDateTime'];
      if (rawDate == null) continue;
      final DateTime apptDate = (rawDate as Timestamp).toDate();

      if (apptDate.year == date.year &&
          apptDate.month == date.month &&
          apptDate.day == date.day) {
        takenTimes.add(formatTimeFromDateTime(apptDate));
      }
    }

    final now = DateTime.now();
    final bool isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final available = doctorSlots.where((s) {
      if (takenTimes.contains(s)) return false;

      if (isToday) {
        try {
          final parts = s.split(' ');
          final timeParts = parts[0].split(':');
          int hour = int.parse(timeParts[0]);
          int minute = int.parse(timeParts[1]);
          if (parts[1] == 'PM' && hour != 12) hour += 12;
          if (parts[1] == 'AM' && hour == 12) hour = 0;

          final slotTime =
              DateTime(date.year, date.month, date.day, hour, minute);
          if (slotTime.isBefore(now)) return false;
        } catch (_) {}
      }
      return true;
    }).toList();

    if (mounted) {
      setState(() {
        _availableSlots = available;
        _isLoadingSlots = false;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm on ${dt.day}/${dt.month}/${dt.year}';
  }

  void _bookAppointment() async {
    if (_user == null) {
      _showLoginDialog();
      return;
    }
    if (_selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an available time slot'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isBooking = true);

    final parts = _selectedTimeSlot!.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    if (parts[1] == 'PM' && hour != 12) hour += 12;
    if (parts[1] == 'AM' && hour == 12) hour = 0;

    final finalDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );

    try {
      final patient = await _db.getUserById(_user!.uid);
      final patientName = patient?.name ?? 'Patient';

      final newAppointment = AppointmentModel(
        id: '',
        doctorId: widget.doctorId ?? '',
        doctorName: widget.doctorName,
        patientId: _user!.uid,
        patientName: patientName,
        appointmentDateTime: finalDate,
        status: 'pending',
      );

      final error = await _db.bookAppointmentSafely(newAppointment);

      if (mounted) {
        setState(() => _isBooking = false);
        if (error == null) {
          _db.getToken(widget.doctorId ?? '').then((token) {
            if (token.isNotEmpty) {
              _messageServices.sendNotificationToUser(
                fcmToken: token,
                title: 'New Appointment Request',
                body:
                    '$patientName requested an appointment on ${_formatDateTime(finalDate)}',
                type: 'appointment',
              );
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Appointment requested. Awaiting doctor confirmation.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.destructive,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _generateSlotsForDate(_selectedDate);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showLoginDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        title: Text('Authentication Required', style: AppTypography.title.copyWith(color: textPrimary)),
        content: Text(
          'Please sign in with your CareFlow account to schedule a consultation.',
          style: AppTypography.body.copyWith(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.label.copyWith(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const LoginScreen(returnToPrevious: true)),
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final initials = widget.doctorName.isNotEmpty
        ? widget.doctorName
            .trim()
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
        : 'DR';
    final hasLocation = widget.latitude != null && widget.longitude != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [
          if (hasLocation)
            IconButton(
              icon: const Icon(Icons.directions_rounded),
              tooltip: 'Get directions',
              onPressed: _openDirections,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Doctor Hero Card
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    AppAvatar(initials: initials, size: 64),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Dr. ${widget.doctorName}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.title.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: AppIconSize.sm,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              AppBadge(
                                label: widget.specialty,
                                variant: AppBadgeVariant.primary,
                              ),
                              if (widget.distance != null)
                                AppBadge(
                                  label:
                                      '${widget.distance!.toStringAsFixed(1)} km away',
                                  variant: AppBadgeVariant.neutral,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(height: 1, color: Theme.of(context).dividerColor),
                const SizedBox(height: AppSpacing.md),

                // Rating & Reviews
                StreamBuilder<UserModel?>(
                  stream: widget.doctorId != null
                      ? _db.streamUser(widget.doctorId!)
                      : null,
                  builder: (context, snap) {
                    final userModel = snap.data;
                    double avg = userModel?.rating ?? 5.0;
                    int count = userModel?.reviewCount ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StarRatingWidget(
                              initialRating: avg,
                              starSize: 15,
                              isReadOnly: true,
                            ),
                            Text(
                              avg.toStringAsFixed(1),
                              style: AppTypography.label.copyWith(
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              '($count reviews)',
                              style: AppTypography.caption.copyWith(
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                if (_user == null) {
                                  _showLoginDialog();
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => ChatScreen(
                                      receiverId: widget.doctorId!,
                                      receiverName: widget.doctorName,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: AppIconSize.sm,
                              ),
                              label: const Text('Message'),
                            ),
                            if (hasLocation)
                              OutlinedButton.icon(
                                onPressed: _openDirections,
                                icon: const Icon(
                                  Icons.near_me_rounded,
                                  size: AppIconSize.sm,
                                ),
                                label: const Text('Navigate'),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bio Section (if present)
          StreamBuilder<UserModel?>(
            stream: widget.doctorId != null
                ? _db.streamUser(widget.doctorId!)
                : null,
            builder: (context, snap) {
              final bio = snap.data?.about;
              if (bio == null || bio.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSectionHeader(title: 'About Doctor'),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: Text(
                      bio.trim(),
                      style: AppTypography.body.copyWith(color: textSecondary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              );
            },
          ),

          // Date Selection
          AppSectionHeader(title: 'Select Consultation Date'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 14,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final day = DateTime.now().add(Duration(days: index));
                final isSelected = day.day == _selectedDate.day &&
                    day.month == _selectedDate.month;

                return InkWell(
                  onTap: () {
                    setState(() => _selectedDate = day);
                    _generateSlotsForDate(day);
                  },
                  borderRadius: AppRadius.medium,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight),
                      borderRadius: AppRadius.medium,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                              [day.weekday % 7],
                          style: AppTypography.caption.copyWith(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.85)
                                : textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.day}',
                          style: AppTypography.section.copyWith(
                            color: isSelected ? Colors.white : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Available Slots
          AppSectionHeader(
            title: 'Available Time Slots',
            trailing: _availableSlots.isNotEmpty
                ? AppBadge(
                    label: '${_availableSlots.length} available',
                    variant: AppBadgeVariant.success,
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          if (_isLoadingSlots)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_availableSlots.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.lg,
                horizontal: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.event_busy_rounded,
                    size: AppIconSize.lg,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No slots open for selected date',
                    textAlign: TextAlign.center,
                    style: AppTypography.label.copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Please choose another day or consult another doctor',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _availableSlots.map((slot) {
                final isSelected = _selectedTimeSlot == slot;
                return InkWell(
                  onTap: () => setState(
                      () => _selectedTimeSlot = isSelected ? null : slot),
                  borderRadius: AppRadius.small,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    constraints: const BoxConstraints(
                      minHeight: AppMetrics.minTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight),
                      borderRadius: AppRadius.small,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      slot,
                      style: AppTypography.label.copyWith(
                        color: isSelected ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: AppSpacing.xl),

          // Patient Reviews
          AppSectionHeader(title: 'Patient Reviews'),
          const SizedBox(height: AppSpacing.sm),

          StreamBuilder<QuerySnapshot>(
            stream: widget.doctorId != null
                ? _db.streamReviewsForDoctor(widget.doctorId!)
                : null,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final reviews = snap.data!.docs.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final r = (d['rating'] as num?)?.toDouble() ?? 0.0;
                return r > 0;
              }).toList();

              if (reviews.isEmpty) {
                return AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Text(
                      'No verified patient reviews yet',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: textSecondary),
                    ),
                  ),
                );
              }

              return Column(
                children: reviews.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final double r = (d['rating'] as num?)?.toDouble() ?? 0.0;
                  final String patientName =
                      (d['patient_name'] ?? 'Patient').toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  patientName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              StarRatingWidget(
                                initialRating: r,
                                starSize: 13,
                                isReadOnly: true,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                r.toStringAsFixed(1),
                                style: AppTypography.caption.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if ((d['feedback_text'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              d['feedback_text'],
                              style: AppTypography.body.copyWith(
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTimeSlot != null
                          ? 'Selected Slot'
                          : 'Consultation Slot',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    Text(
                      _selectedTimeSlot != null
                          ? '${_selectedDate.day}/${_selectedDate.month} • $_selectedTimeSlot'
                          : 'Choose time slot above',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: _selectedTimeSlot != null
                            ? AppColors.primary
                            : textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton(
                onPressed: (_selectedTimeSlot == null || _isBooking)
                    ? null
                    : _bookAppointment,
                child: _isBooking
                    ? const SizedBox(
                        width: AppIconSize.md,
                        height: AppIconSize.md,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Book Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
