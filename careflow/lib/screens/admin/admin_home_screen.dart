import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_section_header.dart';
import '../../auth_wrapper.dart';

class AdminHomeScreen extends StatelessWidget {
  final DatabaseService? databaseService;
  final AuthService? authService;

  const AdminHomeScreen({
    super.key,
    this.databaseService,
    this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final db = databaseService ?? DatabaseService();
    final auth = authService ?? AuthService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = AppColors.textSecondary(isDark);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Admin dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.primary,
              size: AppIconSize.md,
            ),
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
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: db.streamUnverifiedDoctors(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not load verifications',
              message: '${snapshot.error}',
              iconColor: AppColors.destructive,
              iconBackgroundColor: isDark
                  ? AppColors.destructiveSoftDark
                  : AppColors.destructiveLight,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final doctors = snapshot.data!;

          if (doctors.isEmpty) {
            return const AppEmptyState(
              icon: Icons.verified_rounded,
              title: 'All caught up',
              message: 'No pending doctor verifications.',
            );
          }

          return ListView.builder(
            padding: AppSpacing.screen,
            itemCount: doctors.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionHeader(
                        title: 'Pending verifications',
                        trailing: AppBadge(
                          label: '${doctors.length} pending',
                          variant: AppBadgeVariant.warning,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Review credentials before approval',
                        style: AppTypography.caption
                            .copyWith(color: textSecondary),
                      ),
                    ],
                  ),
                );
              }

              final doctor = doctors[index - 1];
              final initial =
                  doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D';

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppAvatar(initials: initial, size: 44),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doctor.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.section.copyWith(
                                    color: AppColors.textPrimary(isDark),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  doctor.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption
                                      .copyWith(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppBadge(
                        label: doctor.specialty ?? 'General',
                        variant: AppBadgeVariant.neutral,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await db.deleteUser(doctor.id);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.destructive,
                                side: const BorderSide(
                                  color: AppColors.destructive,
                                ),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await db.approveDoctor(doctor.id);
                              },
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
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
