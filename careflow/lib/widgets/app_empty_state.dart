import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_tokens.dart';

/// Calm, consistent empty / no-result state used across the app.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;
  final Color? iconColor;
  final Color? iconBackgroundColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
    this.iconColor,
    this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 44 : 56,
                height: compact ? 44 : 56,
                decoration: BoxDecoration(
                  color: iconBackgroundColor ??
                      (isDark
                          ? AppColors.primaryContainerDark
                          : AppColors.primaryLight),
                  borderRadius: AppRadius.medium,
                ),
                child: Icon(
                  icon,
                  color: iconColor ??
                      (isDark ? const Color(0xFFBFDBFE) : AppColors.primary),
                  size: compact ? AppIconSize.md : AppIconSize.lg,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.section.copyWith(color: textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: textSecondary),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
