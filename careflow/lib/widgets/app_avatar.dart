import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/app_tokens.dart';

/// Shared initials avatar. One shape, one tint, one type scale.
class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ??
        (isDark ? AppColors.primaryContainerDark : AppColors.primaryLight);
    final fg = foregroundColor ?? AppColors.primary;
    final label = initials.trim().isEmpty ? '?' : initials.trim().toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.small,
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: fg, size: size * 0.44)
          : Text(
              label.length > 2 ? label.substring(0, 2) : label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.34,
                height: 1,
              ),
            ),
    );
  }
}
