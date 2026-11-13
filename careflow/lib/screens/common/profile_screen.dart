import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../auth_wrapper.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_tokens.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _db = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;

  bool isDoctor = false;
  bool isSaving = false;
  bool _profileLoaded = false;
  bool _obscurePassword = true;
  StreamSubscription<UserModel?>? _userSub;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedSpecialty;

  @override
  void initState() {
    super.initState();
    _emailController.text = user?.email ?? '';
    if (user != null) {
      _userSub = _db.streamUser(user!.uid).listen((userModel) {
        if (!mounted || userModel == null) return;
        setState(() {
          isDoctor = userModel.isDoctor;
          if (!_profileLoaded) {
            _profileLoaded = true;
            _nameController.text = userModel.name;
            _bioController.text = userModel.about ?? '';
            String? specialty = userModel.specialty;
            if (specialty != null && !kSpecialties.contains(specialty)) {
              specialty = null;
            }
            _selectedSpecialty = specialty;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.destructive : AppColors.success,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  void _updateProfile() async {
    if (user == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Name cannot be empty', isError: true);
      return;
    }

    setState(() => isSaving = true);

    try {
      final Map<String, dynamic> data = {
        'name': name,
        'email': _emailController.text.trim(),
      };

      if (isDoctor) {
        if (_selectedSpecialty == null) {
          throw 'Please select your medical specialty';
        }
        data['about'] = _bioController.text.trim();
        data['specialty'] = _selectedSpecialty;
      }

      await _db.updateUser(user!.uid, data);

      if (_emailController.text.trim() != user!.email) {
        await user!.verifyBeforeUpdateEmail(_emailController.text.trim());
        _showMessage('Verification email sent to new address. Please verify.');
      }

      if (_passwordController.text.isNotEmpty) {
        if (_passwordController.text.length < 6) {
          throw FirebaseAuthException(
            code: 'weak-password',
            message: 'Password must be at least 6 characters',
          );
        }
        await user!.updatePassword(_passwordController.text.trim());
        _showMessage('Profile and password updated successfully');
      } else {
        _showMessage('Profile updated successfully');
      }

      if (mounted) {
        setState(() => isSaving = false);
        _passwordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => isSaving = false);
      if (e.code == 'requires-recent-login') {
        _showMessage(
          'Security Alert: Please log out and sign in again to update sensitive details.',
          isError: true,
        );
      } else {
        _showMessage('Error: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      _showMessage('Error: $e', isError: true);
    }
  }

  void _deleteAccount() async {
    if (user == null) return;
    try {
      await _db.deleteUser(user!.uid);
      await user!.delete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showMessage('Please sign in again before deleting your account.',
            isError: true);
      } else {
        _showMessage('Error: ${e.message}', isError: true);
      }
    } catch (e) {
      _showMessage('Error deleting account: $e', isError: true);
    }
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  void _showDeleteConfirmDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.destructive,
              size: AppIconSize.lg,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Delete account', style: AppTypography.title.copyWith(color: textPrimary))),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your CareFlow account? This action is permanent and cannot be undone.',
          style: AppTypography.body.copyWith(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTypography.label.copyWith(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, AppMetrics.controlHeight),
            ),
            child: Text('Delete permanently', style: AppTypography.label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimary(isDark);
    final textSecondary = AppColors.textSecondary(isDark);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final initials = _nameController.text.isNotEmpty
        ? _nameController.text
            .trim()
            .split(' ')
            .map((n) => n.isNotEmpty ? n[0] : '')
            .take(2)
            .join()
        : (isDoctor ? 'DR' : 'PT');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.primary,
              size: AppIconSize.md,
            ),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User header
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(initials: initials, size: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.isNotEmpty
                              ? (isDoctor
                                  ? 'Dr. ${_nameController.text}'
                                  : _nameController.text)
                              : 'CareFlow user',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTypography.title.copyWith(color: textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _emailController.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption
                              .copyWith(color: textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            AppBadge(
                              label: isDoctor
                                  ? 'Certified doctor'
                                  : 'Verified patient',
                            ),
                            if (isDoctor && _selectedSpecialty != null)
                              AppBadge(
                                label: _selectedSpecialty!,
                                variant: AppBadgeVariant.neutral,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Appearance & theme
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardTintDark
                          : AppColors.surfaceSunken,
                      borderRadius: AppRadius.small,
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: AppIconSize.md,
                      color: isDark ? AppColors.primary : AppColors.warningText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appearance',
                          style:
                              AppTypography.label.copyWith(color: textPrimary),
                        ),
                        Text(
                          isDark ? 'Dark theme' : 'Light theme',
                          style: AppTypography.caption
                              .copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    onChanged: (val) {
                      themeProvider.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Profile edit form
            const AppSectionHeader(title: 'Account information'),
            const SizedBox(height: AppSpacing.sm),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full name
                  _buildLabel('Full name', textPrimary),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Email
                  _buildLabel('Email address', textPrimary),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Password
                  _buildLabel('New password (optional)', textPrimary),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Leave blank to keep unchanged',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: AppIconSize.md,
                        ),
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  if (isDoctor) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildLabel('Medical specialty', textPrimary),
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
                            ? AppColors.cardTintDark
                            : AppColors.surfaceSunken,
                        borderRadius: AppRadius.medium,
                        border: Border.all(color: AppColors.border(isDark)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSpecialty,
                          isExpanded: true,
                          dropdownColor: AppColors.card(isDark),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: AppIconSize.md,
                          ),
                          style:
                              AppTypography.body.copyWith(color: textPrimary),
                          hint: Text(
                            'Select a specialty',
                            style: AppTypography.body.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                          items: kSpecialties.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedSpecialty = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildLabel('Doctor bio and qualifications', textPrimary),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe your clinical background and practice areas.',
                        contentPadding: EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Save changes
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _updateProfile,
                      child: isSaving
                          ? const SizedBox(
                              width: AppIconSize.md,
                              height: AppIconSize.md,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Danger zone
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete account',
                    style: AppTypography.label
                        .copyWith(color: AppColors.destructive),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Permanently erase your profile and medical data.',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showDeleteConfirmDialog,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: AppIconSize.md,
                      ),
                      label: const Text('Delete account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                        side: const BorderSide(color: AppColors.destructive),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: AppTypography.label.copyWith(color: color),
    );
  }
}
