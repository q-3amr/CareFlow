import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
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

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  bool isLoading = false;
  bool isObscure = true;
  String? emailError;
  String? passwordError;

  // Animation controllers
  late final AnimationController _morphController;
  late final AnimationController _successController;
  late final Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.easeOutCubic),
    );

    // Focus listeners for micro-interactions
    emailFocus.addListener(_onEmailFocusChange);
    passwordFocus.addListener(_onPasswordFocusChange);

    // Controllers for inline validation
    emailController.addListener(_onEmailChanged);
    passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    _morphController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    if (!emailFocus.hasFocus && emailController.text.isNotEmpty) {
      _validateEmail();
    }
    setState(() {});
  }

  void _onPasswordFocusChange() {
    if (!passwordFocus.hasFocus && passwordController.text.isNotEmpty) {
      _validatePassword();
    }
    setState(() {});
  }

  void _onEmailChanged() {
    if (emailError != null && emailController.text.isNotEmpty) {
      setState(() => emailError = null);
    }
  }

  void _onPasswordChanged() {
    if (passwordError != null && passwordController.text.isNotEmpty) {
      setState(() => passwordError = null);
    }
  }

  bool _validateEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      emailError = 'Required';
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      emailError = 'Enter a valid email';
      return false;
    }
    emailError = null;
    return true;
  }

  bool _validatePassword() {
    final password = passwordController.text;
    if (password.isEmpty) {
      passwordError = 'Required';
      return false;
    }
    if (password.length < 6) {
      passwordError = 'Password too short';
      return false;
    }
    passwordError = null;
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
    );
  }

  Future<void> handleLogin() async {
    final emailValid = _validateEmail();
    final passwordValid = _validatePassword();
    setState(() {});

    if (!emailValid || !passwordValid) {
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => isLoading = true);
    await _morphController.forward();

    try {
      await _authService.signIn(email, password);

      if (!mounted) return;

      // Play success animation
      await _successController.forward();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        await _morphController.reverse();
        setState(() => isLoading = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> handleGoogleSignIn() async {
    if (isLoading) return;

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
      if (mounted) {
        setState(() => isLoading = false);
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void handlePasswordReset() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address to reset password');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Enter a valid email');
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
            shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final divider = Theme.of(context).dividerColor;

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Brand Header
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
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  // Logo + app name
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
                  // Guest button
                  if (!widget.returnToPrevious)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const GuestHomeScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Explore as guest'),
                      ).animate(
                        effects: reduceMotion
                            ? []
                            : [
                                FadeEffect(duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic),
                                SlideEffect(begin: const Offset(0.2, 0), end: Offset.zero, duration: 400.ms, delay: 200.ms, curve: Curves.easeOutCubic),
                              ],
                      ),
                    ),
                ],
              ),
            ).animate(
              effects: reduceMotion
                  ? []
                  : [
                      FadeEffect(duration: 400.ms, curve: Curves.easeOutCubic),
                      SlideEffect(begin: const Offset(0, -0.3), end: Offset.zero, duration: 400.ms, curve: Curves.easeOutCubic),
                    ],
            ),

            // Top accent line
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0),
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ).animate(
              effects: reduceMotion
                  ? []
                  : [
                      FadeEffect(duration: 600.ms, delay: 100.ms, curve: Curves.easeOutCubic),
                      SlideEffect(begin: const Offset(0, -0.5), end: Offset.zero, duration: 600.ms, delay: 100.ms, curve: Curves.easeOutCubic),
                    ],
            ),

            // Optional subtle ambient motion (very low opacity)
            if (!reduceMotion)
              SizedBox(
                height: 120,
                child: Center(
                  child: Opacity(
                    opacity: 0.03,
                    child: Lottie.asset(
                      'assets/animations/loading_spinner.json',
                      repeat: true,
                      animate: true,
                      width: 200,
                      height: 200,
                      filterQuality: FilterQuality.low,
                    ),
                  ),
                ),
              ),

            // Form Container
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            'Welcome Back',
                            style: AppTypography.display.copyWith(color: textPrimary),
                          ).animate(
                            effects: reduceMotion
                                ? []
                                : [
                                    FadeEffect(duration: 400.ms, delay: 100.ms, curve: Curves.easeOutCubic),
                                    SlideEffect(begin: const Offset(0, 0.2), end: Offset.zero, duration: 400.ms, delay: 100.ms, curve: Curves.easeOutCubic),
                                  ],
                          ),

                          const SizedBox(height: AppSpacing.xl),

                          // Email Field
                          _AnimatedFormField(
                            label: 'Email Address',
                            hint: 'name@example.com',
                            controller: emailController,
                            focusNode: emailFocus,
                            errorText: emailError,
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                            delay: 180,
                            reduceMotion: reduceMotion,
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Password Field
                          _AnimatedFormField(
                            label: 'Password',
                            hint: 'Enter your password',
                            controller: passwordController,
                            focusNode: passwordFocus,
                            errorText: passwordError,
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: isObscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            suffixIcon: IconButton(
                              tooltip: isObscure ? 'Show password' : 'Hide password',
                              icon: Icon(
                                isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() => isObscure = !isObscure),
                            ),
                            onFieldSubmitted: (_) => handleLogin(),
                            delay: 260,
                            reduceMotion: reduceMotion,
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: handlePasswordReset,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                              ),
                              child: const Text('Forgot Password?'),
                            ),
                          ).animate(
                            effects: reduceMotion
                                ? []
                                : [
                                    FadeEffect(duration: 300.ms, delay: 340.ms, curve: Curves.easeOut),
                                  ],
                          ),

                          const SizedBox(height: AppSpacing.sm),

                          // Sign In Button (Morphing)
                          AnimatedBuilder(
                            animation: Listenable.merge([_morphController, _successController]),
                            builder: (context, child) {
                              final isMorphing = _morphController.value > 0;
                              final showSpinner = _morphController.value > 0.3 && _morphController.value < 0.9;
                              final showCheckmark = _successController.value > 0;
                              final progress = _morphController.value;

                              return Transform.scale(
                                scale: _buttonScaleAnimation.value,
                                child: SizedBox(
                                  height: AppMetrics.controlHeight,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Base button (fades out during morph)
                                      Opacity(
                                        opacity: 1.0 - progress,
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOutCubic,
                                          width: isMorphing ? AppMetrics.controlHeight : double.infinity,
                                          child: ElevatedButton(
                                            onPressed: isLoading ? null : handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(
                                                  isMorphing ? 24 : AppRadius.md,
                                                ),
                                              ),
                                              elevation: isMorphing ? 0 : 0,
                                            ),
                                            child: const Text('Sign In'),
                                          ),
                                        ),
                                      ),

                                      // Loading spinner (Lottie) - appears during morph
                                      if (showSpinner)
                                        SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Lottie.asset(
                                            'assets/animations/loading_spinner.json',
                                            repeat: true,
                                            animate: true,
                                          ),
                                        ),

                                      // Success checkmark (Lottie) - appears after success
                                      if (showCheckmark)
                                        SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Lottie.asset(
                                            'assets/animations/check_success.json',
                                            repeat: false,
                                            controller: _successController,
                                            onLoaded: (composition) {
                                              _successController.duration = composition.duration;
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ).animate(
                            effects: reduceMotion
                                ? []
                                : [
                                    FadeEffect(duration: 400.ms, delay: 400.ms, curve: Curves.easeOutBack),
                                    ScaleEffect(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 400.ms, delay: 400.ms, curve: Curves.easeOutBack),
                                  ],
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
                                    const Icon(Icons.g_mobiledata_rounded, size: 20),
                              ),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: divider,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                            ),
                          ).animate(
                            effects: reduceMotion
                                ? []
                                : [
                                    FadeEffect(duration: 400.ms, delay: 460.ms, curve: Curves.easeOutCubic),
                                    SlideEffect(begin: const Offset(0, 0.2), end: const Offset(0, 0), duration: 400.ms, delay: 460.ms, curve: Curves.easeOutCubic),
                                  ],
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
                                style: AppTypography.body.copyWith(color: textSecondary),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                                  );
                                },
                                child: const Text('Register'),
                              ),
                            ],
                          ).animate(
                            effects: reduceMotion
                                ? []
                                : [
                                    FadeEffect(duration: 300.ms, delay: 520.ms, curve: Curves.easeOut),
                                  ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).animate(
              effects: reduceMotion
                  ? []
                  : [
                      FadeEffect(duration: 400.ms, delay: 50.ms, curve: Curves.easeOutCubic),
                      SlideEffect(begin: const Offset(0, 0.15), end: Offset.zero, duration: 400.ms, delay: 50.ms, curve: Curves.easeOutCubic),
                    ],
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
                      style: AppTypography.caption.copyWith(color: textSecondary),
                    ),
                  ),
                ],
              ),
            ).animate(
              effects: reduceMotion
                  ? []
                  : [
                      FadeEffect(duration: 400.ms, delay: 580.ms, curve: Curves.easeOut),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated form field with micro-interactions
class _AnimatedFormField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final void Function(String)? onFieldSubmitted;
  final int delay;
  final bool reduceMotion;

  const _AnimatedFormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffixIcon,
    this.onFieldSubmitted,
    required this.delay,
    required this.reduceMotion,
  });

  @override
  State<_AnimatedFormField> createState() => _AnimatedFormFieldState();
}

class _AnimatedFormFieldState extends State<_AnimatedFormField> {
  late final FocusNode _internalFocus;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _internalFocus = widget.focusNode;
    _internalFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _internalFocus.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _internalFocus.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final divider = Theme.of(context).dividerColor;

    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final isFocused = _hasFocus;
    final isFilled = widget.controller.text.isNotEmpty;

    // Color logic for background and borders
    Color fillColor;
    Color borderColor;
    Color focusedBorderColor;
    Color errorBorderColor;
    List<BoxShadow>? shadows;

    if (hasError) {
      fillColor = isDark ? AppColors.destructiveSoftDark : AppColors.destructiveLight;
      borderColor = AppColors.destructive.withValues(alpha: 0.5);
      focusedBorderColor = AppColors.destructive;
      errorBorderColor = AppColors.destructive;
      shadows = null;
    } else if (isFocused) {
      fillColor = isDark ? AppColors.cardDark : AppColors.cardLight;
      borderColor = divider;
      focusedBorderColor = AppColors.primary;
      errorBorderColor = AppColors.destructive;
      shadows = AppShadows.soft;
    } else if (isFilled) {
      fillColor = isDark ? AppColors.cardDark : AppColors.cardLight;
      borderColor = AppColors.success.withValues(alpha: 0.3);
      focusedBorderColor = AppColors.primary;
      errorBorderColor = AppColors.destructive;
      shadows = null;
    } else {
      fillColor = isDark ? AppColors.cardTintDark : AppColors.cardTintLight;
      borderColor = divider;
      focusedBorderColor = AppColors.primary;
      errorBorderColor = AppColors.destructive;
      shadows = null;
    }

    // Label color
    Color labelColor;
    if (hasError) {
      labelColor = AppColors.destructive;
    } else if (isFocused) {
      labelColor = AppColors.primary;
    } else {
      labelColor = textPrimary;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: AppTypography.label.copyWith(color: labelColor),
        ).animate(
          effects: widget.reduceMotion
              ? []
              : [
                  FadeEffect(duration: 300.ms, delay: (widget.delay).ms, curve: Curves.easeOut),
                  SlideEffect(begin: const Offset(0, 0.1), end: Offset.zero, duration: 300.ms, delay: (widget.delay).ms, curve: Curves.easeOut),
                ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Field wrapper - only animates background color and shadow
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: AppRadius.medium,
            boxShadow: shadows,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _internalFocus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onSubmitted: widget.onFieldSubmitted,
            style: AppTypography.body.copyWith(color: textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTypography.body.copyWith(color: textTertiary),
              prefixIcon: Icon(widget.prefixIcon, color: isFocused ? AppColors.primary : textTertiary),
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: Colors.transparent, // Let AnimatedContainer handle background
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              // Borders drawn by TextField itself - no clipping issues
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: BorderSide(color: borderColor, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: BorderSide(color: focusedBorderColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: BorderSide(color: errorBorderColor, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: BorderSide(color: errorBorderColor, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.medium,
                borderSide: BorderSide(color: divider, width: 1),
              ),
            ),
          ),
        ).animate(
          effects: widget.reduceMotion
              ? []
              : [
                  FadeEffect(duration: 400.ms, delay: (widget.delay + 50).ms, curve: Curves.easeOutCubic),
                  SlideEffect(begin: const Offset(0, 0.2), end: Offset.zero, duration: 400.ms, delay: (widget.delay + 50).ms, curve: Curves.easeOutCubic),
                  ScaleEffect(begin: const Offset(0.98, 0.98), end: const Offset(1.0, 1.0), duration: 400.ms, delay: (widget.delay + 50).ms, curve: Curves.easeOutBack),
                ],
        ),

        // Error message
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
            child: Text(
              widget.errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.destructive),
            ),
          ).animate(
            effects: widget.reduceMotion
                ? []
                : [
                    FadeEffect(duration: 200.ms, curve: Curves.easeOut),
                    SlideEffect(begin: const Offset(0, -0.1), end: const Offset(0, 0), duration: 200.ms, curve: Curves.easeOut),
                    // Shake effect
                    ShakeEffect(
                      duration: 400.ms,
                      curve: Curves.easeOut,
                      hz: 3,
                      offset: const Offset(8.0, 0),
                    ),
                  ],
          ),
      ],
    );
  }
}