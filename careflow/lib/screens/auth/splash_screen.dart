import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/careflow_logo.dart';

/// Custom splash screen shown while Firebase initializes.
/// Shows logo + "CareFlow" text in primary blue, matching the app theme.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            const CareFlowLogo(size: 96)
                .animate()
                .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutBack),

            const SizedBox(height: AppSpacing.lg),

            // App name in primary blue
            Text(
              'CareFlow',
              style: AppTypography.display.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic)
                .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic),

            const SizedBox(height: AppSpacing.xl),

            // Subtle loading indicator
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary.withValues(alpha: 0.6)),
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: 500.ms, curve: Curves.easeOut)
                .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0), duration: 400.ms, delay: 500.ms, curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }
}