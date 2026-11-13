import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// CareFlow brand lockup, using the supplied heart/flow mark.
class CareFlowLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final TextStyle? textStyle;
  final Color? textColor;

  const CareFlowLogo({
    super.key,
    this.size = 40,
    this.showText = false,
    this.textStyle,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText =
        textColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final wordmarkStyle = textStyle ??
        TextStyle(
          fontSize: size * 0.54,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.15,
        );

    final mark = Semantics(
      label: 'CareFlow',
      image: true,
      child: Image.asset(
        isDark
            ? 'assets/branding/careflow_logo_dark.png'
            : 'assets/branding/careflow_logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        fit: BoxFit.contain,
      ),
    );

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: size * 0.26),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Care',
                  style: wordmarkStyle.copyWith(color: primaryText),
                ),
                TextSpan(
                  text: 'Flow',
                  style: wordmarkStyle.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
