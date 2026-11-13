import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_tokens.dart';

class ActionButton extends StatelessWidget {
  final dynamic icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isSquare;

  const ActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;

    final tile = Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: AppRadius.small,
      ),
      child: icon is Widget
          ? icon
          : Icon(icon as IconData, color: color, size: AppIconSize.lg),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.medium,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: AppRadius.medium,
            border: Border.all(color: borderColor),
          ),
          child: isSquare
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      tile,
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(color: textColor),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      tile,
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.label.copyWith(color: textColor),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: textColor.withValues(alpha: 0.4),
                        size: AppIconSize.md,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
