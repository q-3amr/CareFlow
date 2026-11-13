import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/star_rating_widget.dart';
import 'doctor_details_screen.dart';

class DoctorsListScreen extends StatelessWidget {
  const DoctorsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Scaffold(
      appBar: AppBar(title: const Text('Available Doctors')),
      body: StreamBuilder<List<UserModel>>(
        stream: db.streamDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load directory',
              message: 'Check your connection and try again.',
              iconColor:
                  isDark ? const Color(0xFFFCD34D) : AppColors.warningText,
              iconBackgroundColor:
                  isDark ? AppColors.warningSoftDark : AppColors.warningLight,
            );
          }

          final doctors = snapshot.data ?? [];

          if (doctors.isEmpty) {
            return const AppEmptyState(
              icon: Icons.person_search_rounded,
              title: 'No doctors available',
              message: 'No doctors are currently accepting patients. '
                  'Please check back later.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: doctors.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              final initials = doctor.name.isNotEmpty
                  ? doctor.name
                      .trim()
                      .split(' ')
                      .map((n) => n.isNotEmpty ? n[0] : '')
                      .take(2)
                      .join()
                  : 'DR';

              return AppCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => DoctorDetailsScreen(
                        doctorName: doctor.name,
                        specialty: doctor.specialty ?? 'General',
                        doctorId: doctor.id,
                        latitude: doctor.latitude,
                        longitude: doctor.longitude,
                        distance: doctor.distance,
                      ),
                    ),
                  );
                },
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    AppAvatar(initials: initials, size: 48),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Dr. ${doctor.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.section.copyWith(
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              if (doctor.isVerified == true) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.primary,
                                  size: AppIconSize.sm,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              AppBadge(
                                label: doctor.specialty ?? 'General',
                                variant: AppBadgeVariant.primary,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  StarRatingWidget(
                                    initialRating: doctor.rating ?? 5.0,
                                    starSize: 12,
                                    isReadOnly: true,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    (doctor.rating ?? 5.0).toStringAsFixed(1),
                                    style: AppTypography.caption.copyWith(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textPrimary.withValues(alpha: 0.4),
                      size: AppIconSize.md,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
