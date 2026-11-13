import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../utils/date_utils.dart';
import '../../utils/feedback_helper.dart';
import '../../widgets/action_button.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/careflow_logo.dart';
import '../common/schedule_screen.dart';
import '../common/profile_screen.dart';
import '../common/chats_list_screen.dart';
import 'doctor_requests_screen.dart';
import 'manage_slots_screen.dart';
import 'doctor_reviews_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _selectedIndex = 0;
  final String _uid = AuthService().currentUser?.uid ?? '';

  late final Stream<QuerySnapshot>? _pendingStream = _uid.isEmpty
      ? null
      : FirebaseFirestore.instance
          .collection('appointments')
          .where('doctor_id', isEqualTo: _uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();

  final List<Widget> _pages = const [
    DoctorDashboard(),
    ScheduleScreen(isDoctor: true),
    DoctorRequestsScreen(isTab: true),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Theme.of(context).cardColor,
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: _pendingStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return _buildBadgeIcon(
                      Icons.notifications_none_rounded, count);
                },
              ),
              activeIcon: StreamBuilder<QuerySnapshot>(
                stream: _pendingStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return _buildBadgeIcon(Icons.notifications_rounded, count);
                },
              ),
              label: 'Requests',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.destructive,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final db = DatabaseService();
  final User? user = AuthService().currentUser;
  FeedbackHelper? _feedbackHelper;

  // Stable subscriptions: creating these in build() re-subscribed on every
  // rebuild and briefly reset the greeting to its placeholder.
  Stream<dynamic>? _appointmentsStream;
  Stream<UserModel?>? _userStream;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      final uid = user!.uid;
      if (uid.isNotEmpty) {
        _appointmentsStream = db.streamAppointmentsForDoctor(uid);
        _userStream = db.streamUser(uid);
      }
      _feedbackHelper = FeedbackHelper(context: context, userId: user!.uid);
    }
  }

  @override
  void dispose() {
    _feedbackHelper?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<dynamic>(
          stream: _appointmentsStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            var pending = 0;
            var upcoming = 0;
            var hasNewReview = false;
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'pending') pending++;
              if (data['hasFeedback'] == true && data['isReviewSeen'] != true) {
                hasNewReview = true;
              }
              final rawDate = data['appointmentDateTime'];
              if (rawDate != null &&
                  data['status'] == 'accepted' &&
                  !isExpiredAppointment(parseDate(rawDate))) {
                upcoming++;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CareFlowLogo(size: 32, showText: true),
                      const Spacer(),
                      StreamBuilder<UserModel?>(
                        stream: _userStream,
                        builder: (context, userSnap) {
                          final name = userSnap.data?.name ?? '';
                          final initial =
                              name.isNotEmpty ? name[0].toUpperCase() : null;
                          return initial == null
                              ? const AppAvatar(
                                  initials: '',
                                  size: 40,
                                  icon: Icons.person_outline_rounded,
                                )
                              : AppAvatar(initials: initial, size: 40);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  StreamBuilder<UserModel?>(
                    stream: _userStream,
                    builder: (context, userSnap) {
                      final name = userSnap.data?.name.trim() ?? '';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical workspace',
                            style: AppTypography.caption
                                .copyWith(color: textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (name.isEmpty)
                            Container(
                              width: 150,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.border(isDark),
                                borderRadius: AppRadius.small,
                              ),
                            )
                          else
                            Text(
                              'Dr. $name',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.display
                                  .copyWith(color: textPrimary),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.notifications_active_outlined,
                            iconColor: AppColors.warning,
                            label: 'Pending',
                            value: '$pending',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.event_available_rounded,
                            iconColor: AppColors.primary,
                            label: 'Upcoming',
                            value: '$upcoming',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      color: isDark
                          ? AppColors.primaryContainerDark
                          : AppColors.primaryLight,
                      borderColor: AppColors.primary.withValues(alpha: 0.35),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_actions_rounded,
                            size: AppIconSize.md,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              '$pending request${pending == 1 ? '' : 's'} awaiting your review',
                              style: AppTypography.label
                                  .copyWith(color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const DoctorRequestsScreen(),
                              ),
                            ),
                            child: const Text('Review'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppSectionHeader(
                    title: 'Quick actions',
                    trailing: hasNewReview
                        ? const AppBadge(
                            label: 'New review',
                            variant: AppBadgeVariant.warning,
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ActionButton(
                            icon: const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.primary,
                              size: AppIconSize.lg,
                            ),
                            title: 'Manage slots',
                            color: AppColors.primary,
                            isSquare: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const ManageSlotsScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ActionButton(
                            icon: const Icon(
                              Icons.star_rate_rounded,
                              color: AppColors.primary,
                              size: AppIconSize.lg,
                            ),
                            title: 'Patient reviews',
                            color: AppColors.primary,
                            isSquare: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => const DoctorReviewsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ActionButton(
                    icon: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: AppColors.primary,
                      size: AppIconSize.lg,
                    ),
                    title: 'Session requests',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const DoctorRequestsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ActionButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.primary,
                      size: AppIconSize.lg,
                    ),
                    title: 'My chats',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) => const ChatsListScreen()),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: AppRadius.small,
            ),
            child: Icon(icon, size: AppIconSize.md, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display.copyWith(color: textPrimary),
          ),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
