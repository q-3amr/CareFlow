import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
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

  Future<void> _openMapPicker() async {
    final LatLng? pickedLocation = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DoctorMapScreen()),
    );

    if (pickedLocation != null) {
      setState(() {
        _selectedLatitude = pickedLocation.latitude;
        _selectedLongitude = pickedLocation.longitude;

        locationController.text = '📍 Location selected successfully';
      });
    }
  }

  void handleSignup() async {
    if (passwordController.text != confirmPassController.text) {
      _showError('Passwords do not match!');
      return;
    }
    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      _showError('Please fill all required fields!');
      return;
    }
    if (isDoctor) {
      if (selectedSpecialty == null ||
          locationController.text.trim().isEmpty ||
          _selectedLatitude == null) {
        _showError('Please fill all doctor fields and pick a location!');
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      await _authService.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
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
        const SnackBar(
          content: Text(
            'Account created successfully! Please Login with your new account.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      if (!mounted) return;
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    const Color labelColor = Color(0xFF374151);
    const Color borderColor = Color(0xFFD1D5DB);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Sign up',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: kPrimaryBlue,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Create your new account',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 30),
                _buildField(
                  label: 'Full Name',
                  controller: nameController,
                  hint: 'Enter your full name',
                  icon: Icons.person_outline,
                  borderColor: borderColor,
                  labelColor: labelColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  label: 'Email Address',
                  controller: emailController,
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  borderColor: borderColor,
                  labelColor: labelColor,
                ),
                const SizedBox(height: 20),
                _buildField(
                  label: 'Password',
                  controller: passwordController,
                  hint: 'Create password',
                  icon: Icons.lock_outline,
                  borderColor: borderColor,
                  labelColor: labelColor,
                  isPass: true,
                  isObscure: isObscurePass,
                  onEyeTap: () =>
                      setState(() => isObscurePass = !isObscurePass),
                ),
                const SizedBox(height: 20),
                _buildField(
                  label: 'Confirm Password',
                  controller: confirmPassController,
                  hint: 'Re-enter password',
                  icon: Icons.lock_outline,
                  borderColor: borderColor,
                  labelColor: labelColor,
                  isPass: true,
                  isObscure: isObscureConfirm,
                  onEyeTap: () =>
                      setState(() => isObscureConfirm = !isObscureConfirm),
                ),
                const SizedBox(height: 25),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDoctor
                        ? kPrimaryBlue.withValues(alpha: 0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDoctor ? kPrimaryBlue : borderColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.medical_services,
                        color: isDoctor ? kPrimaryBlue : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Register as a Doctor',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDoctor ? kPrimaryBlue : labelColor,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: isDoctor,
                        thumbColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.selected)
                              ? kPrimaryBlue
                              : Colors.white,
                        ),
                        onChanged: (val) => setState(() => isDoctor = val),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  reverseDuration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: animation,
                      axisAlignment: -1.0,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: isDoctor
                      ? Column(
                          key: const ValueKey('doctor_fields'),
                          children: [
                            const SizedBox(height: 20),
                            _buildSpecialtyDropdown(
                              labelColor: labelColor,
                              borderColor: borderColor,
                            ),
                            const SizedBox(height: 20),
                            _buildField(
                              label: 'Clinic Location',
                              controller: locationController,
                              hint: 'Tap to pick location from map',
                              icon: Icons.map_outlined,
                              borderColor: borderColor,
                              labelColor: labelColor,
                              readOnly: true,
                              onTap: _openMapPicker,
                            ),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : handleSignup,
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
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
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
                          builder: (context) => const LoginScreen(),
                        ),
                      ),
                      child: const Text(
                        'Login',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialtyDropdown({
    required Color labelColor,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialty',
          style: TextStyle(
            color: labelColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selectedSpecialty != null ? kPrimaryBlue : borderColor,
              width: selectedSpecialty != null ? 2.5 : 2.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSpecialty,
              hint: Padding(
                padding: const EdgeInsets.only(left: 18),
                child: Text(
                  'Select your specialty',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
              isExpanded: true,
              icon: Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey.shade600,
                  size: 28,
                ),
              ),
              borderRadius: BorderRadius.circular(16),
              dropdownColor: Colors.white,
              elevation: 8,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              items: kSpecialties.map((String specialty) {
                return DropdownMenuItem<String>(
                  value: specialty,
                  child: Text(specialty),
                );
              }).toList(),
              onChanged: (String? newValue) =>
                  setState(() => selectedSpecialty = newValue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color borderColor,
    required Color labelColor,
    bool isPass = false,
    bool isObscure = false,
    VoidCallback? onEyeTap,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPass ? isObscure : false,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderColor, width: 2.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kPrimaryBlue, width: 2.5),
            ),
            suffixIcon: isPass
                ? IconButton(
                    icon: Icon(
                      isObscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.grey.shade600,
                      size: 26,
                    ),
                    onPressed: onEyeTap,
                  )
                : Icon(icon, color: Colors.grey.shade400, size: 24),
          ),
        ),
      ],
    );
  }
}
