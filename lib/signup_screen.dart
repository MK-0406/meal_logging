import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'authentication.dart';
import 'login_screen.dart';
import 'user/input_personal_health_info.dart';
import '../functions.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String selectedRole = 'user';
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _handleSignup() async {
    setState(() => _isLoading = true);

    final error = await _authService.signUp(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error == null) {
      final user = FirebaseAuth.instance.currentUser!;
      await _createUserDocument(user.uid, user.email!);
      
      if (!mounted) return;
      _showSnackBar('Signup Successful! Please complete your profile.', Colors.green);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileFormScreen()));
    } else {
      _showSnackBar(error, Colors.redAccent);
    }
  }

  Future<void> _handleGoogleSignup() async {
    setState(() => _isLoading = true);
    final userCredential = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (userCredential != null) {
      final userDoc = await Database.getDocument('users', userCredential.user!.uid);
      
      if (!userDoc.exists) {
        await _createUserDocument(userCredential.user!.uid, userCredential.user!.email!);
        if (!mounted) return;
        _showSnackBar('Account Created with Google!', Colors.green);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileFormScreen()));
      } else {
        if (!mounted) return;
        _showSnackBar('Account already exists. Please login.', const Color(0xFF1E88E5));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  Future<void> _createUserDocument(String uid, String email) async {
    final status = (selectedRole == 'admin') ? 'pending' : 'approved';
    await Database.setItems('users', uid, {
      'email': email,
      'role': selectedRole,
      'registrationStatus': status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _showSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Create Account',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1), letterSpacing: -1.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join FoodWise today to start your journey!',
                    style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 15))],
                    ),
                    child: Column(
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(value: 'user', label: Text('User'), icon: Icon(Icons.person_rounded, size: 18)),
                            ButtonSegment<String>(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_rounded, size: 18)),
                          ],
                          selected: <String>{selectedRole},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() => selectedRole = newSelection.first);
                          },
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            backgroundColor: Colors.grey.shade50,
                            selectedBackgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.1),
                            selectedForegroundColor: const Color(0xFF1E88E5),
                            side: BorderSide(color: Colors.grey.shade100),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: emailController,
                                label: 'Email Address',
                                icon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your email';
                                  if (!RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$').hasMatch(value)) return 'Enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: passwordController,
                                label: 'Password',
                                icon: Icons.lock_rounded,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your password';
                                  if (value.length < 6) return 'Password must be 6+ characters';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: confirmPasswordController,
                                label: 'Confirm Password',
                                icon: Icons.lock_clock_rounded,
                                isPassword: true,
                                obscureText: _obscureConfirmPassword,
                                onTogglePassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please confirm your password';
                                  if (value != passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildSignupButton(),
                        const SizedBox(height: 16),
                        _buildGoogleButton(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?", style: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500)),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                        child: const Text('Login', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueGrey.shade300, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFF1E88E5), size: 22),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.blueGrey.shade200, size: 20),
                onPressed: onTogglePassword,
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade50,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF42A5F5), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

  Widget _buildSignupButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)]),
          boxShadow: [BoxShadow(color: const Color(0xFF42A5F5).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () {
            if (_formKey.currentState!.validate() && !_isLoading) {
              _handleSignup();
            }
          },
          child: _isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignup,
        icon: Image.network('https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', height: 24, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 28)),
        label: const Text('Sign Up with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
