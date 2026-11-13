import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../utils/date_utils.dart';
import '../../utils/feedback_helper.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/careflow_logo.dart';
import '../../providers/chat_provider.dart';
import 'doctor_search_screen.dart';
import 'voice_chat.dart';
import 'patient_map_screen.dart';
import '../common/schedule_screen.dart';
import '../common/profile_screen.dart';
import '../common/chats_list_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _selectedIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late final Stream<QuerySnapshot>? _chatStream = _uid.isEmpty
      ? null
      : FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: _uid)
          .snapshots();

  final List<Widget> _pages = [
    const PatientHomeContent(),
    const ScheduleScreen(isDoctor: false),
    const ChatsListScreen(),
    const ProfileScreen(),
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
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<QuerySnapshot>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  int unreadCount = 0;
                  if (snapshot.hasData) {
                    unreadCount = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data.containsKey('isRead') &&
                          data.containsKey('lastMessageSenderId')) {
                        return data['isRead'] == false &&
                            data['lastMessageSenderId'] != _uid;
                      }
                      return false;
                    }).length;
                  }
                  return _buildBadgeIcon(
                      Icons.chat_bubble_outline_rounded, unreadCount);
                },
              ),
              activeIcon: StreamBuilder<QuerySnapshot>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  int unreadCount = 0;
                  if (snapshot.hasData) {
                    unreadCount = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data.containsKey('isRead') &&
                          data.containsKey('lastMessageSenderId')) {
                        return data['isRead'] == false &&
                            data['lastMessageSenderId'] != _uid;
                      }
                      return false;
                    }).length;
                  }
                  return _buildBadgeIcon(
                      Icons.chat_bubble_rounded, unreadCount);
                },
              ),
              label: 'Messages',
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
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class PatientHomeContent extends StatefulWidget {
  const PatientHomeContent({super.key});

  @override
  State<PatientHomeContent> createState() => _PatientHomeContentState();
}

class _PatientHomeContentState extends State<PatientHomeContent> {
  final _db = DatabaseService();
  final User? user = AuthService().currentUser;
  FeedbackHelper? _feedbackHelper;

  // Stable subscriptions: recreating these inside build() caused the name and
  // avatar to fall back to placeholders whenever the screen rebuilt.
  Stream<UserModel?>? _userStream;

  static const List<Map<String, dynamic>> _quickSpecialties = [
    {'name': 'General', 'icon': Icons.medical_services_outlined},
    {'name': 'Cardiology', 'icon': Icons.favorite_border_rounded},
    {'name': 'Dentistry', 'icon': Icons.mood_rounded},
    {'name': 'Pediatrics', 'icon': Icons.child_care_rounded},
    {'name': 'Dermatology', 'icon': Icons.spa_outlined},
    {'name': 'Neurology', 'icon': Icons.psychology_outlined},
    {'name': 'Orthopedics', 'icon': Icons.accessibility_new_rounded},
  ];

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _userStream = _db.streamUser(user!.uid);
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
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const CareFlowLogo(size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'CareFlow',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.section.copyWith(color: textPrimary),
                    ),
                  ),
                  StreamBuilder<UserModel?>(
                    stream: _userStream,
                    builder: (context, snapshot) {
                      final name = snapshot.data?.name ?? '';
                      final initial =
                          name.isNotEmpty ? name[0].toUpperCase() : '';
                      return AppAvatar(
                        initials: initial,
                        size: 40,
                        icon: initial.isEmpty
                            ? Icons.person_outline_rounded
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Greeting & Status
                  StreamBuilder<UserModel?>(
                    stream: _userStream,
                    builder: (context, snapshot) {
                      final name = snapshot.data?.name.trim() ?? '';
                      final firstName =
                          name.isEmpty ? null : name.split(' ')[0];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstName == null
                                ? 'Good day'
                                : 'Good day, $firstName',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.display.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'How can we assist your health today?',
                            style: AppTypography.body.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Search Bar Trigger
                  AppCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (c) => const DoctorSearchScreen()),
                      );
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: AppIconSize.md,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Search doctors, specialties, or clinics...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const AppBadge(label: 'Search'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Upcoming Appointment Card
                  StreamBuilder<dynamic>(
                    stream: user?.uid != null
                        ? _db.streamAcceptedAppointmentsForPatient(user!.uid)
                        : null,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildEmptyBanner(
                            isDark, textPrimary, textSecondary);
                      }
                      var docs = snapshot.data!.docs;
                      var future = docs
                          .map((doc) {
                            final d = doc.data() as Map;
                            return {
                              'data': d,
                              'date': parseDate(d['appointmentDateTime']),
                            };
                          })
                          .where((item) => (item['date'] as DateTime)
                              .isAfter(DateTime.now()))
                          .toList();
                      if (future.isEmpty) {
                        return _buildEmptyBanner(
                            isDark, textPrimary, textSecondary);
                      }
                      future.sort((a, b) => (a['date'] as DateTime)
                          .compareTo(b['date'] as DateTime));
                      final next = future.first;
                      return LiveTimerBanner(
                        date: next['date'] as DateTime,
                        doctorName:
                            (next['data'] as Map)['doctor_name'] ?? 'Doctor',
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Quick Clinical Actions
                  Text(
                    'Clinical Services',
                    style: AppTypography.section.copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ServiceCard(
                            icon: Icons.person_search_rounded,
                            title: 'Find Doctor',
                            subtitle: 'Certified Specialists',
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (c) => const DoctorSearchScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ServiceCard(
                            icon: Icons.record_voice_over_rounded,
                            title: 'AI Assistant',
                            subtitle: 'Clinical Triage',
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => ChangeNotifierProvider(
                                  create: (_) => ChatProvider(),
                                  child: const VoiceChat(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ServiceCard(
                            icon: Icons.map_outlined,
                            title: 'Clinic Map',
                            subtitle: 'Nearby Locations',
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (c) => const PatientMapScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _ServiceCard(
                            icon: Icons.calendar_month_rounded,
                            title: 'Schedule',
                            subtitle: 'All Bookings',
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (c) =>
                                      const ScheduleScreen(isDoctor: false)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Specialties Row
                  AppSectionHeader(
                    title: 'Browse by Specialty',
                    actionLabel: 'View All',
                    onAction: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (c) => const DoctorSearchScreen()),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickSpecialties.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final item = _quickSpecialties[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) => DoctorSearchScreen(
                                    initialSpecialty: item['name'] as String),
                              ),
                            );
                          },
                          borderRadius: AppRadius.medium,
                          child: Container(
                            width: 88,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                              horizontal: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: AppRadius.medium,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.primaryContainerDark
                                        : AppColors.primaryLight,
                                    borderRadius: AppRadius.small,
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    color: isDark
                                        ? const Color(0xFFBFDBFE)
                                        : AppColors.primary,
                                    size: AppIconSize.md,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  item['name'] as String,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBanner(
      bool isDark, Color textPrimary, Color textSecondary) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryContainerDark
                      : AppColors.primaryLight,
                  borderRadius: AppRadius.small,
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: isDark ? const Color(0xFFBFDBFE) : AppColors.primary,
                  size: AppIconSize.lg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Upcoming Appointments',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Book a consultation with certified doctors',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (c) => const DoctorSearchScreen()),
                );
              },
              child: const Text('Book Appointment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryContainerDark
                  : AppColors.primaryLight,
              borderRadius: AppRadius.small,
            ),
            child: Icon(
              icon,
              color: isDark ? const Color(0xFFBFDBFE) : AppColors.primary,
              size: AppIconSize.md,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(color: textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class LiveTimerBanner extends StatefulWidget {
  final DateTime date;
  final String doctorName;

  const LiveTimerBanner(
      {super.key, required this.date, required this.doctorName});

  @override
  State<LiveTimerBanner> createState() => _LiveTimerBannerState();
}

class _LiveTimerBannerState extends State<LiveTimerBanner> {
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Duration diff = widget.date.difference(DateTime.now());
    if (diff.isNegative) return const SizedBox.shrink();

    String timeText = diff.inDays > 0
        ? '${diff.inDays}d ${diff.inHours % 24}h remaining'
        : '${diff.inHours}h ${diff.inMinutes % 60}m remaining';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.medium,
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: AppRadius.small,
            ),
            child: const Icon(
              Icons.alarm_rounded,
              color: Colors.white,
              size: AppIconSize.lg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.small,
                  ),
                  child: Text(
                    timeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Appointment with Dr. ${widget.doctorName}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: AppTypography.label.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
