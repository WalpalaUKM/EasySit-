import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../utils/app_page_route.dart';
import '../services/auth_persistence_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _studentNumberController =
      TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  String _studentNumberToEmail(String studentNumber) {
    final trimmed = studentNumber.trim().toLowerCase();
    if (trimmed.startsWith('admin@')) {
      final adminName =
          trimmed.substring(6).replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      return 'admin_$adminName@easysit.app';
    }
    final cleaned = trimmed.replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    return '$cleaned@easysit.app';
  }

  Future<void> _login() async {
    final input = _studentNumberController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both your credentials and password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String emailToAuth;
      if (input.contains('@') && !input.toLowerCase().startsWith('admin@')) {
        emailToAuth = input;
      } else {
        emailToAuth = _studentNumberToEmail(input);
      }

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailToAuth,
          password: password,
        );
      } on FirebaseAuthException catch (authEx) {
        if (authEx.code == 'user-not-found' && !input.contains('@')) {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('studentId', isEqualTo: input)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            final realEmail =
                (query.docs.first.data()['email'] ?? '').toString().trim();
            if (realEmail.isNotEmpty && realEmail.contains('@')) {
              userCredential =
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: realEmail,
                password: password,
              );
            } else {
              rethrow;
            }
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

      String userType = 'student';
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data['isBlocked'] == true) {
          await AuthPersistenceService.clear();
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are temporarily blocked by the admin.'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
        userType = data?['userType'] ?? 'student';
      }

      await AuthPersistenceService.setRememberMe(_rememberMe);

      if (mounted) {
        if (userType == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/student_home');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed.';
      if (e.code == 'user-not-found') {
        message = 'No user found.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // Logo
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                    width: 120,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.error,
                          color: Color(0xFF0D6EFD),
                          size: 60,
                        ),
                  ),
                ),
                const SizedBox(height: 36),
                // Text Fields
                TextField(
                  controller: _studentNumberController,
                  decoration: InputDecoration(
                    labelText: 'Student Number',
                    hintText: 'e.g. CT20xxxxx',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D6EFD),
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.badge,
                      color: Color(0xFF0D6EFD),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'At least 6 characters',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D6EFD),
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: Color(0xFF0D6EFD),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) {
                              setState(() {
                                _rememberMe = val ?? false;
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            activeColor: const Color(0xFF0D6EFD),
                            side: BorderSide(
                              color: Colors.grey.shade500,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          AppPageRoute(
                            builder: (_) => ForgotPasswordScreen(
                              initialIdentifier: _studentNumberController.text,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF0D6EFD),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6EFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            AppPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Color(0xFF0D6EFD),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
