

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../utils/constants.dart';
import '../../auth_wrapper.dart';

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
  bool isLoading = true;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _selectedSpecialty;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    if (user == null) return;
    _emailController.text = user!.email ?? '';

    try {
      final userModel = await _db.getUserById(user!.uid);

      if (userModel != null) {
        String? dbSpecialty = userModel.specialty;
        if (dbSpecialty != null && !kSpecialties.contains(dbSpecialty)) {
          dbSpecialty = null;
        }

        if (mounted) {
          setState(() {
            isDoctor = userModel.isDoctor;
            _nameController.text = userModel.name;
            _bioController.text = userModel.about ?? '';
            _selectedSpecialty = dbSpecialty;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red : Colors.green,
        content: Text(message),
      ),
    );
  }

  void _updateProfile() async {
    if (user == null) return;
    setState(() => isLoading = true);

    try {
      final Map<String, dynamic> data = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      };

      if (isDoctor) {
        if (_selectedSpecialty == null) throw 'Please select a specialty';
        data['about'] = _bioController.text.trim();
        data['specialty'] = _selectedSpecialty;
      }

      await _db.updateUser(user!.uid, data);

      if (_emailController.text.trim() != user!.email) {
        await user!.verifyBeforeUpdateEmail(_emailController.text.trim());
        _showMessage(
          'Verification email sent to new address. Please verify.',
        );
      }

      if (_passwordController.text.isNotEmpty) {
        if (_passwordController.text.length < 6) {
          throw FirebaseAuthException(
            code: 'weak-password',
            message: 'Password must be at least 6 chars',
          );
        }
        await user!.updatePassword(_passwordController.text.trim());
        _showMessage('Password updated successfully!');
      } else {
        _showMessage('Profile Updated Successfully!');
      }

      if (mounted) {
        setState(() => isLoading = false);
        _passwordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => isLoading = false);
      if (e.code == 'requires-recent-login') {
        _showMessage(
          'Security Alert: Please Log out and Log in again to update sensitive info.',
          isError: true,
        );
      } else {
        _showMessage('Error: ${e.message}', isError: true);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please log out and log in again to delete your account.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
        }
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
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
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Text(
              'Are you sure? This cannot be undone and you will lose all your data.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteAccount();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: kPrimaryBlue,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 30),
            _buildTextField('Full Name', _nameController, Icons.person),
            const SizedBox(height: 15),
            _buildTextField(
              'Email Address',
              _emailController,
              Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              'New Password',
              _passwordController,
              Icons.lock,
              isPassword: true,
              helperText: 'Leave empty to keep current',
            ),
            const SizedBox(height: 15),
            if (isDoctor) ...[
              _buildSpecialtyDropdown(),
              const SizedBox(height: 15),
              _buildTextField(
                'About (Bio)',
                _bioController,
                Icons.info,
                maxLines: 3,
              ),
              const SizedBox(height: 15),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _showDeleteConfirmDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialtyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedSpecialty,
      items:
          kSpecialties.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
      onChanged:
          (newValue) => setState(() => _selectedSpecialty = newValue),
      decoration: InputDecoration(
        labelText: 'Specialty',
        prefixIcon: const Icon(Icons.work, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
