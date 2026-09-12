import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../utils/app_page_route.dart';
import '../utils/app_colors.dart';
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
  int _prevInputLength = 0;

  @override
  void initState() {
    super.initState();
    _studentNumberController.addListener(_onStudentNumberChanged);
  }

  // ============================================================================
  // [UNIVERSITY EMAIL AUTOFILL ON '@' SYMBOL]
  // ============================================================================
  /// Automatically completes "stu.kln.ac.lk" when the student enters '@'
  /// in the identifier field.
  void _onStudentNumberChanged() {
    final text = _studentNumberController.text;
    if (text.length > _prevInputLength && text.endsWith('@')) {
      final prefix = text.substring(0, text.length - 1);
      if (!prefix.contains('@') && prefix.isNotEmpty) {
        final autofilled = '${text}stu.kln.ac.lk';
        _prevInputLength = autofilled.length;
        _studentNumberController.value = TextEditingValue(
          text: autofilled,
          selection: TextSelection.collapsed(offset: autofilled.length),
        );
        return;
      }
    }
    _prevInputLength = text.length;
  }

  @override
  void dispose() {
    _studentNumberController.removeListener(_onStudentNumberChanged);
    _studentNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================================
  // [AUTHENTICATION IDENTIFIER RESOLUTION & VALIDATION]
  // ============================================================================
  /// Converts entered Student ID or Admin handle to internal Firebase Auth email alias:
  /// - Admin format: admin@username -> admin_username@easysit.app
  /// - Student ID format: CT2021001 -> ct2021001@easysit.app
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

  // ============================================================================
  // [USER LOGIN & ROLE-BASED ACCESS CONTROL]
  // ============================================================================
  /// Authenticates user with Firebase Auth, validates account status (blocked check),
  /// and redirects based on user role:
  /// - 'admin' -> /admin_dashboard
  /// - 'student' -> /student_home
  Future<void> _login() async {
    final input = _studentNumberController.text.trim();
    final password = _passwordController.text;

    if (input.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both your credentials and password.'),
          backgroundColor: EasySitColors.errorFg,
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
        if (authEx.code == 'user-not-found' ||
            authEx.code == 'invalid-credential') {
          QuerySnapshot<Map<String, dynamic>> query;
          if (input.contains('@') && !input.toLowerCase().startsWith('admin@')) {
            query = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: input)
                .limit(1)
                .get();
          } else {
            query = await FirebaseFirestore.instance
                .collection('users')
                .where('studentId', isEqualTo: input)
                .limit(1)
                .get();
          }

          if (query.docs.isNotEmpty) {
            final data = query.docs.first.data();
            final realStudentId =
                (data['studentId'] ?? '').toString().trim();
            final authEmail = _studentNumberToEmail(
                realStudentId.isNotEmpty ? realStudentId : input);
            userCredential =
                await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: authEmail,
              password: password,
            );
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      // Fetch user profile from Firestore to inspect userType and blocked status
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();

      String userType = 'student';
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>?;
        // Blocked student validation
        if (data != null && data['isBlocked'] == true) {
          await AuthPersistenceService.clear();
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are temporarily blocked by the admin.'),
                backgroundColor: EasySitColors.errorFg,
              ),
            );
            setState(() => _isLoading = false);
          }
          return;
        }
        userType = data?['userType'] ?? 'student';
      }

      await AuthPersistenceService.setRememberMe(_rememberMe);

      // Route based on role
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
          SnackBar(content: Text(message), backgroundColor: EasySitColors.errorFg),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EasySitColors.appBackground,
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
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
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
                          color: EasySitColors.primary,
                          size: 60,
                        ),
                  ),
                ),
                const SizedBox(height: 36),
                // Text Fields
                TextField(
                  controller: _studentNumberController,
                  style: const TextStyle(color: EasySitColors.mainText),
                  decoration: InputDecoration(
                    labelText: 'Student Number / Email',
                    labelStyle: const TextStyle(color: EasySitColors.bodyText),
                    hintText: 'e.g. CT23001 or university email',
                    hintStyle: const TextStyle(color: EasySitColors.secondaryText),
                    filled: true,
                    fillColor: EasySitColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: EasySitColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: EasySitColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: EasySitColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.badge,
                      color: EasySitColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: EasySitColors.mainText),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: EasySitColors.bodyText),
                    hintText: 'At least 6 characters',
                    hintStyle: const TextStyle(color: EasySitColors.secondaryText),
                    filled: true,
                    fillColor: EasySitColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: EasySitColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: EasySitColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: EasySitColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: EasySitColors.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: EasySitColors.secondaryText,
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
                            activeColor: EasySitColors.primary,
                            side: const BorderSide(
                              color: EasySitColors.inputBorder,
                              width: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(
                            color: EasySitColors.bodyText,
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
                          color: EasySitColors.primary,
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
                      backgroundColor: EasySitColors.primary,
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
                                color: EasySitColors.onPrimary,
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
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: EasySitColors.secondaryText,
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
                          color: EasySitColors.primary,
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
