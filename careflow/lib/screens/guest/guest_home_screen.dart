import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/careflow_logo.dart';
import '../patient/doctor_search_screen.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  static const List<Map<String, dynamic>> _quickSpecialties = [
    {'name': 'General', 'icon': Icons.medical_services_outlined},
    {'name': 'Cardiology', 'icon': Icons.favorite_border_rounded},
    {'name': 'Dentistry', 'icon': Icons.mood_rounded},
    {'name': 'Pediatrics', 'icon': Icons.child_care_rounded},
    {'name': 'Dermatology', 'icon': Icons.spa_outlined},
    {'name': 'Neurology', 'icon': Icons.psychology_outlined},
    {'name': 'Orthopedics', 'icon': Icons.accessibility_new_rounded},
  ];

  void _openDoctorSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorSearchScreen()),
    );
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
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.sm,
                children: [
                  // Logo + app name (stay together on one line)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CareFlowLogo(size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'CareFlow',
                        style: AppTypography.section.copyWith(color: textPrimary),
                      ),
                    ],
                  ),
                  // Action buttons
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                          );
                        },
                        child: const Text('Sign in'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignupScreen()),
                          );
                        },
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(
                height: 1, thickness: 1, color: Theme.of(context).dividerColor),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Search Bar Trigger
                  AppCard(
                    onTap: () => _openDoctorSearch(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: AppIconSize.lg,
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
                        const AppBadge(label: 'Find'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Hero Clinical Banner
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadius.large,
                      boxShadow: isDark ? null : AppShadows.raised,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: AppRadius.small,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Colors.white,
                                    size: AppIconSize.sm,
                                  ),
                                  SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      'Certified Network',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '18+ Specialties',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Modern Healthcare, Streamlined.',
                          style: AppTypography.title.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Schedule appointments with verified doctors and get '
                          'instant symptom triage with clinical AI.',
                          style: AppTypography.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Specialties Section
                  AppSectionHeader(
                    title: 'Clinical Specialties',
                    actionLabel: 'View All',
                    onAction: () => _openDoctorSearch(context),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Horizontal Specialties Scroll
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickSpecialties.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final item = _quickSpecialties[index];
                        return InkWell(
                          onTap: () => _openDoctorSearch(context),
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
                                  padding: const EdgeInsets.all(
                                    AppSpacing.sm,
                                  ),
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
                  const SizedBox(height: AppSpacing.xl),

                  // CareFlow Pillars (2-column)
                  Text(
                    'Patient Services',
                    style: AppTypography.section.copyWith(color: textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: AppCard(
                            onTap: () => _openDoctorSearch(context),
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
                                    Icons.person_search_rounded,
                                    color: isDark
                                        ? const Color(0xFFBFDBFE)
                                        : AppColors.primary,
                                    size: AppIconSize.md,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Find Doctors',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Certified profiles & reviews',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppCard(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Sign in to access AI Symptom Consultations',
                                  ),
                                  backgroundColor: AppColors.warning,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
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
                                    Icons.record_voice_over_rounded,
                                    color: isDark
                                        ? const Color(0xFFBFDBFE)
                                        : AppColors.primary,
                                    size: AppIconSize.md,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'AI Triage',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Voice & symptom analysis',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Interactive Feature Row
                  AppCard(
                    onTap: () => _openDoctorSearch(context),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
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
                            Icons.map_outlined,
                            color: isDark
                                ? const Color(0xFFBFDBFE)
                                : AppColors.primary,
                            size: AppIconSize.lg,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clinic Locations & Maps',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label.copyWith(
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Discover verified clinics in your area',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: textSecondary,
                          size: AppIconSize.md,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),

            // Bottom Trust Banner
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                border: Border(
                  top: BorderSide(
                    color:
                        isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: AppIconSize.sm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'HIPAA Compliant • End-to-End Encrypted Healthcare',
                      maxLines: 2,
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
