import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_tokens.dart';
import '../../auth_wrapper.dart';
import '../../widgets/careflow_logo.dart';
import '../../widgets/app_card.dart';
import '../guest/guest_home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToPrevious;
  const LoginScreen({super.key, this.returnToPrevious = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isObscure = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.signIn(email, password);

      if (!mounted) return;

      // AuthWrapper is the single source of truth for role routing.
      // Never route straight to a dashboard from here: a failed or missing
      // profile read must not silently land a non-patient on the patient home.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void handlePasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address to reset password');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset link sent to your inbox'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      await _authService.signInWithGoogle();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Brand Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
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
                      if (widget.returnToPrevious || Navigator.canPop(context))
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.pop(context),
                        )
                      else
                        const SizedBox(width: AppSpacing.xs),
                      const CareFlowLogo(size: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'CareFlow',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.section.copyWith(color: textPrimary),
                      ),
                    ],
                  ),
                  // Action button
                  if (!widget.returnToPrevious)
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const GuestHomeScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: textSecondary,
                      ),
                      child: const Text('Explore as guest'),
                    ),
                ],
              ),
            ),

            Divider(
                height: 1, thickness: 1, color: Theme.of(context).dividerColor),

            // Form Container
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome Back',
                            style: AppTypography.display.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Sign in to manage appointments and records',
                            style: AppTypography.body.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Email
                          Text(
                            'Email Address',
                            style: AppTypography.label.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: AppTypography.body.copyWith(
                              color: textPrimary,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'name@example.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Password
                          Text(
                            'Password',
                            style: AppTypography.label.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: passwordController,
                            obscureText: isObscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => handleLogin(),
                            style: AppTypography.body.copyWith(
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: isObscure
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  isObscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => isObscure = !isObscure),
                              ),
                            ),
                          ),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: handlePasswordReset,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                              ),
                              child: const Text('Forgot Password?'),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          // Submit Button
                          SizedBox(
                            height: AppMetrics.controlHeight,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleLogin,
                              child: isLoading
                                  ? const SizedBox(
                                      width: AppIconSize.md,
                                      height: AppIconSize.md,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Google Sign-In Button
                          SizedBox(
                            height: AppMetrics.controlHeight,
                            child: OutlinedButton.icon(
                              onPressed: isLoading ? null : handleGoogleSignIn,
                              icon: Image.asset(
                                'assets/images/google_logo.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.g_mobiledata_rounded,
                                        size: 20),
                              ),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.md),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Switch to Register
                          Wrap(
                            alignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.xs,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: AppTypography.body.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const SignupScreen()),
                                  );
                                },
                                child: const Text('Register'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Trust Footer
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: AppIconSize.sm,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      '256-Bit SSL Encrypted Healthcare Portal',
                      maxLines: 2,
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
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
