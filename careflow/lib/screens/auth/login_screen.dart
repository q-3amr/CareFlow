import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../auth_wrapper.dart';
import '../patient/patient_home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool returnToPrevious;
  const LoginScreen({super.key, this.returnToPrevious = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _dbService = DatabaseService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isObscure = true;

  void handleLogin() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showError('Please enter both Email and Password!');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.signIn(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null && mounted) {
        final userModel = await _dbService.getUserById(firebaseUser.uid);

        await _dbService.updateToken(firebaseUser.uid);

        if (!mounted) return;

        if (userModel != null &&
            userModel.isDoctor &&
            userModel.isVerified != true) {
          await _authService.signOut();
          if (!mounted) return;
          _showPendingApprovalDialog();
        } else {
          if (mounted) {
            if (userModel != null && !userModel.isPatient) {
              
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
                (route) => false,
              );
            } else {
              
              
              
              if (widget.returnToPrevious) {
                Navigator.pop(context);
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PatientHomeScreen()),
                  (route) => false,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void handlePasswordReset() async {
    if (emailController.text.trim().isEmpty) {
      _showError('Please enter your email address first');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If this email exists, a password reset link has been sent. '
              'Please check your inbox.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color.fromARGB(255, 220, 53, 69),
      ),
    );
  }

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pending Approval'),
        content: const Text('Your account is currently under review.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color labelColor = Color(0xFF374151);
    const Color borderColor = Color(0xFFD1D5DB);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 30),
                        Container(
                          height: 250,
                          width: double.infinity,
                          alignment: Alignment.center,
                          child: Image.asset(
                            'assets/images/doctor_login.png',
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Icon(
                              Icons.image_not_supported,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Log in',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: kPrimaryBlue,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildLabeledField(
                          label: 'Email Address',
                          child: TextField(
                            controller: emailController,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Enter your Email Address',
                              borderColor: borderColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildLabeledField(
                          label: 'Password',
                          child: TextField(
                            controller: passwordController,
                            obscureText: isObscure,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Enter your Password',
                              borderColor: borderColor,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  isObscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade600,
                                  size: 26,
                                ),
                                onPressed: () =>
                                    setState(() => isObscure = !isObscure),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: handlePasswordReset,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: labelColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimaryBlue,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Don't have an account? ",
                                style: TextStyle(
                                  color: labelColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignupScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Sign up',
                                  style: TextStyle(
                                    color: kPrimaryBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    decoration: TextDecoration.underline,
                                    decorationColor: kPrimaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required Color borderColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      filled: true,
      fillColor: Colors.grey.shade50,
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor, width: 2.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: kPrimaryBlue, width: 2.5),
      ),
    );
  }
}
