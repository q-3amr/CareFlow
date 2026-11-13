import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/app_tokens.dart';
import '../../utils/constants.dart';
import '../../widgets/careflow_logo.dart';
import '../../widgets/app_card.dart';
import '../../auth_wrapper.dart';
import 'login_screen.dart';
import '../doctors/doctor_map_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = AuthService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPassController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  String? selectedSpecialty;
  bool isLoading = false;
  bool isObscurePass = true;
  bool isObscureConfirm = true;
  bool isDoctor = false;

  double? _selectedLatitude;
  double? _selectedLongitude;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPassController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final LatLng? pickedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorMapScreen()),
    );

    if (pickedLocation != null) {
      setState(() {
        _selectedLatitude = pickedLocation.latitude;
        _selectedLongitude = pickedLocation.longitude;
        locationController.text = 'Location confirmed on map';
      });
    }
  }

  void handleSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmPassController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Please fill in all required fields');
      return;
    }

    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (isDoctor) {
      if (selectedSpecialty == null || _selectedLatitude == null) {
        _showError('Select your medical specialty and clinic location');
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      await _authService.signUp(
        email: email,
        password: password,
        name: name,
        role: isDoctor ? 'doctor' : 'patient',
        specialty: isDoctor ? selectedSpecialty : null,
        location: isDoctor ? locationController.text.trim() : null,
        latitude: isDoctor ? _selectedLatitude : null,
        longitude: isDoctor ? _selectedLongitude : null,
      );

      await _authService.signOut();

      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDoctor
                ? 'Doctor account submitted for approval. Please sign in.'
                : 'Account created successfully! Please sign in.',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        _showError(e.toString());
      }
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
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back to sign in',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                  ),
                  const CareFlowLogo(size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Create account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.section.copyWith(color: textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor),

            // Form Container
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create Account',
                            style: AppTypography.display.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Select your role and enter credentials',
                            style: AppTypography.body.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Segmented Role Selector (Patient vs Doctor)
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.backgroundDark
                                  : AppColors.surfaceSunken,
                              borderRadius: AppRadius.medium,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _RoleOption(
                                    label: 'Patient',
                                    icon: Icons.person_rounded,
                                    selected: !isDoctor,
                                    isDark: isDark,
                                    onTap: () =>
                                        setState(() => isDoctor = false),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: _RoleOption(
                                    label: 'Doctor',
                                    icon: Icons.medical_services_rounded,
                                    selected: isDoctor,
                                    isDark: isDark,
                                    onTap: () =>
                                        setState(() => isDoctor = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Full Name
                          _buildField(
                            label: 'Full Name',
                            controller: nameController,
                            hint: isDoctor
                                ? 'e.g. Dr. Sarah Jenkins'
                                : 'e.g. Alex Morgan',
                            icon: Icons.person_outline_rounded,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Email
                          _buildField(
                            label: 'Email Address',
                            controller: emailController,
                            hint: 'name@example.com',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Password
                          _buildField(
                            label: 'Password',
                            controller: passwordController,
                            hint: 'Min 6 characters',
                            icon: Icons.lock_outline_rounded,
                            obscureText: isObscurePass,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            textInputAction: TextInputAction.next,
                            suffixIcon: IconButton(
                              tooltip: isObscurePass
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                isObscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                  () => isObscurePass = !isObscurePass),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Confirm Password
                          _buildField(
                            label: 'Confirm Password',
                            controller: confirmPassController,
                            hint: 'Re-enter password',
                            icon: Icons.lock_outline_rounded,
                            obscureText: isObscureConfirm,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              tooltip: isObscureConfirm
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                isObscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(() =>
                                  isObscureConfirm = !isObscureConfirm),
                            ),
                          ),

                          // Doctor-Specific Fields
                          if (isDoctor) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Medical Specialty',
                              style: AppTypography.label.copyWith(
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              constraints: const BoxConstraints(
                                minHeight: AppMetrics.controlHeight,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.cardDark
                                    : AppColors.cardLight,
                                borderRadius: AppRadius.medium,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.borderDark
                                      : AppColors.borderLight,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedSpecialty,
                                  isExpanded: true,
                                  isDense: true,
                                  dropdownColor: isDark
                                      ? AppColors.cardDark
                                      : AppColors.cardLight,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                  hint: Text(
                                    'Select specialty',
                                    style: AppTypography.body.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                  items: kSpecialties.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.body.copyWith(
                                          color: textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) => setState(
                                      () => selectedSpecialty = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Clinic Location',
                              style: AppTypography.label.copyWith(
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            InkWell(
                              onTap: _openMapPicker,
                              borderRadius: AppRadius.medium,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: AppMetrics.controlHeight,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.cardDark
                                      : AppColors.cardLight,
                                  borderRadius: AppRadius.medium,
                                  border: Border.all(
                                    color: _selectedLatitude != null
                                        ? AppColors.primary
                                        : (isDark
                                            ? AppColors.borderDark
                                            : AppColors.borderLight),
                                    width:
                                        _selectedLatitude != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedLatitude != null
                                          ? Icons.check_circle_rounded
                                          : Icons.map_outlined,
                                      color: _selectedLatitude != null
                                          ? AppColors.primary
                                          : textSecondary,
                                      size: AppIconSize.md,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        _selectedLatitude != null
                                            ? 'Clinic location confirmed'
                                            : 'Tap to select location on map',
                                        style: AppTypography.body.copyWith(
                                          color: _selectedLatitude != null
                                              ? AppColors.primary
                                              : textSecondary,
                                          fontWeight: _selectedLatitude != null
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.primary,
                                      size: AppIconSize.md,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.xl),

                          // Submit Button
                          SizedBox(
                            height: AppMetrics.controlHeight,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : handleSignup,
                              child: isLoading
                                  ? const SizedBox(
                                      width: AppIconSize.md,
                                      height: AppIconSize.md,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isDoctor
                                          ? 'Register as Doctor'
                                          : 'Create Patient Account',
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Google Sign-In Button (Patient only)
                          if (!isDoctor)
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

                          const SizedBox(height: AppSpacing.md),

                          // Login Link
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.xs,
                            children: [
                              Text(
                                'Already have an account?',
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
                                            const LoginScreen()),
                                  );
                                },
                                child: const Text('Sign In'),
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
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color textPrimary,
    required Color textSecondary,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction textInputAction = TextInputAction.next,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label.copyWith(color: textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          style: AppTypography.body.copyWith(color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.small,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.cardTintDark : AppColors.cardLight)
                : Colors.transparent,
            borderRadius: AppRadius.small,
            boxShadow: selected && !isDark ? AppShadows.soft : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: AppIconSize.sm,
                color: selected ? AppColors.primary : textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: selected ? AppColors.primary : textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
