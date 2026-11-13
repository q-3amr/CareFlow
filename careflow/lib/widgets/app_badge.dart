import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_tokens.dart';

enum AppBadgeVariant {
  primary,
  teal,
  mint,
  success,
  warning,
  destructive,
  neutral,
}

/// Compact status tag. Deliberately not a pill: a tag, not a button.
class AppBadge extends StatelessWidget {
  final String label;
  final Widget? icon;
  final AppBadgeVariant variant;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.icon,
    this.variant = AppBadgeVariant.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    Color? border;

    switch (variant) {
      case AppBadgeVariant.primary:
      case AppBadgeVariant.teal:
        bg = isDark ? AppColors.primaryContainerDark : AppColors.primaryLight;
        fg = isDark ? const Color(0xFFBFDBFE) : AppColors.primaryDark;
        break;
      case AppBadgeVariant.mint:
      case AppBadgeVariant.success:
        bg = isDark ? AppColors.successSoftDark : AppColors.successLight;
        fg = isDark ? const Color(0xFF6EE7B7) : AppColors.successText;
        break;
      case AppBadgeVariant.warning:
        bg = isDark ? AppColors.warningSoftDark : AppColors.warningLight;
        fg = isDark ? const Color(0xFFFCD34D) : AppColors.warningText;
        break;
      case AppBadgeVariant.destructive:
        bg = isDark ? AppColors.destructiveSoftDark : AppColors.destructiveLight;
        fg = isDark ? const Color(0xFFFCA5A5) : AppColors.destructiveText;
        break;
      case AppBadgeVariant.neutral:
        bg = isDark ? AppColors.cardTintDark : AppColors.surfaceSunken;
        fg = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        border = isDark ? AppColors.borderDark : AppColors.borderLight;
        break;
    }

    final widget = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.small,
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: fg, size: 12),
              child: icon!,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppRadius.small,
        child: widget,
      );
    }
    return widget;
  }
}
