// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/password_validator.dart';
import '../widgets/password_strength_indicator.dart';
import '../utils/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onFieldChanged);
    _confirmPasswordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onFieldChanged);
    _confirmPasswordController.removeListener(_onFieldChanged);
    _fullNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: EasySitColors.errorFg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ============================================================================
  // [STUDENT ID FORMAT VALIDATION]
  // ============================================================================
  /// Enforces valid university student ID or admin handle formatting:
  /// - Admin account format: Starts with "admin@" (e.g. admin@library).
  /// - Student ID format: Must start with department prefixes "ct", "et", or "cs" (e.g. CT2021001).
  /// How to change safely: Add additional faculty prefixes (e.g. "it", "bm") to the `!lower.startsWith(...)` condition.
  String? _validateStudentId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter a Student ID';
    }
    final lower = trimmed.toLowerCase();
    // Check for admin handle (must start with admin@)
    if (lower.startsWith('admin@')) {
      if (lower.length <= 6) {
        return 'Please enter a valid admin username (e.g. admin@username)';
      }
      return null; // Valid admin ID
    }
    // Student ID must start with ct, et, or cs
    if (!lower.startsWith('ct') &&
        !lower.startsWith('et') &&
        !lower.startsWith('cs')) {
      return 'Student ID must start with "ct", "et", or "cs" (e.g. CT2021001)';
    }
    return null; // Valid
  }

  /// Converts student ID or admin handle to internal Firebase Auth email
  String _studentIdToEmail(String studentId) {
    final trimmed = studentId.trim().toLowerCase();
    if (trimmed.startsWith('admin@')) {
      final adminName = trimmed.substring(6).replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      return 'admin_$adminName@easysit.app';
    }
    // Sanitize any slashes, spaces, or illegal email chars
    final cleaned = trimmed.replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    return '$cleaned@easysit.app';
  }

  // ============================================================================
  // [SRI LANKAN PHONE NUMBER VALIDATION]
  // ============================================================================
  /// Validates that phone number is a valid 10-digit Sri Lankan phone number.
  /// - Sri Lankan phone numbers: 10 digits starting with 0.
  /// - Mobile operators: 070, 071, 072, 074, 075, 076, 077, 078.
  /// - Landlines: 011, 021-027, 031-038, 041-047, 051-057, 063-067, 081, 091.
  bool _isValidSriLankanPhone(String phone) {
    final clean = phone.trim();
    if (clean.length != 10) return false;
    final slMobileRegex = RegExp(r'^07[01245678]\d{7}$');
    final slGeneralRegex = RegExp(r'^0[1-9]\d{8}$');
    return slMobileRegex.hasMatch(clean) || slGeneralRegex.hasMatch(clean);
  }

  Future<void> _register() async {
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    final fullName = _fullNameController.text.trim();
    final studentId = _studentIdController.text.trim();
    final emailInput = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. Check for empty fields
    if (fullName.isEmpty ||
        studentId.isEmpty ||
        emailInput.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('All fields are required. Please fill in all details.');
      return;
    }

    // 2. Validate Student ID
    final String? idError = _validateStudentId(studentId);
    if (idError != null) {
      _showError(idError);
      return;
    }

    // 3. Validate Sri Lankan phone number (must be exactly 10 digits, numbers only, valid SL prefix)
    if (!_isValidSriLankanPhone(phone)) {
      _showError(
        'Please enter a valid 10-digit Sri Lankan phone number (e.g. 07XXXXXXXX)',
      );
      return;
    }

    // 4. Validate University Email format
    // Format: name-ct23001@stu.kln.ac.lk
    // - name: student name
    // - department: ct, cs, or et
    // - academic year: 2 digits (e.g. 23 for 2023)
    // - student registered number: 3 digits (e.g. 001)
    // - domain: @stu.kln.ac.lk
    final bool isAdmin = studentId.toLowerCase().startsWith('admin@');
    if (!isAdmin) {
      final RegExp uniEmailRegex = RegExp(
        r'^[a-zA-Z0-9._%+-]+-(ct|cs|et)\d{2}\d{3}@stu\.kln\.ac\.lk$',
        caseSensitive: false,
      );
      if (!uniEmailRegex.hasMatch(emailInput)) {
        _showError(
          'Please enter a valid university email (e.g. name-ct23001@stu.kln.ac.lk where department is ct, cs, or et)',
        );
        return;
      }
    } else {
      if (!emailInput.contains('@') || !emailInput.contains('.')) {
        _showError('Please enter a valid email address');
        return;
      }
    }

    // 5. Password strength validation
    final String? passwordError = PasswordValidator.getErrorMessage(password);
    if (passwordError != null) {
      _showError(passwordError);
      return;
    }

    // 6. Check if passwords match
    if (password != confirmPassword) {
      _showError('Password and Confirm Password do not match');
      return;
    }

    try {
      final authEmail = _studentIdToEmail(studentId);
      final userType =
          studentId.trim().toLowerCase().startsWith('admin@') ? 'admin' : 'student';

      // Create Firebase Auth user
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: authEmail,
            password: password,
          );

      // Save user details to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'fullName': fullName,
            'studentId': studentId,
            'email': emailInput,
            'phone': phone,
            'userType': userType,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${userType == 'admin' ? 'Admin' : 'Student'} registration successful! Please log in.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: EasySitColors.successFg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This Student ID or email is already registered. Please log in.';
          break;
        case 'weak-password':
          msg = 'Password is too weak for Firebase. Please use a stronger password.';
          break;
        case 'invalid-email':
          msg = 'Invalid Student ID format for account creation.';
          break;
        case 'network-request-failed':
          msg = 'Network connection failed. Please check your internet.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait a moment and try again.';
          break;
        default:
          msg = e.message ?? 'Registration failed. Please check your details.';
      }
      _showError(msg);
    } catch (e) {
      _showError('Registration error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EasySitColors.appBackground,
      appBar: AppBar(
        title: const Text(
          'Register',
          style: TextStyle(
            color: EasySitColors.mainText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: EasySitColors.surface,
        foregroundColor: EasySitColors.mainText,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error Message
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EasySitColors.errorBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: EasySitColors.errorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: EasySitColors.errorFg),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: EasySitColors.errorFg),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorMessage.isNotEmpty) const SizedBox(height: 16),

              // Form Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: EasySitColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EasySitColors.divider, width: 1),
                  boxShadow: EasySitColors.cardShadows,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fill in your details to register',
                      style: TextStyle(
                        fontSize: 14,
                        color: EasySitColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'e.g. Tharusha Dilhara',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: EasySitColors.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: EasySitColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Student ID
                    TextField(
                      controller: _studentIdController,
                      decoration: InputDecoration(
                        labelText: 'Student ID',
                        hintText: 'e.g. CT23001',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
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

                    // Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'University Email',
                        hintText: 'e.g. name-ct23001@stu.kln.ac.lk',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: EasySitColors.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.email,
                          color: EasySitColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. 0712345678',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: EasySitColors.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.phone,
                          color: EasySitColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'e.g. StrongPass@123',
                        helperText:
                            'Must include uppercase, lowercase, number & special char',
                        helperMaxLines: 2,
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
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
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                    ),
                    PasswordStrengthIndicator(
                      password: _passwordController.text,
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter your password',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: EasySitColors.primary,
                            width: 2,
                          ),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: EasySitColors.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            );
                          },
                        ),
                      ),
                    ),
                    if (_confirmPasswordController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0, left: 4.0),
                        child: Row(
                          children: [
                            Icon(
                              _passwordController.text ==
                                      _confirmPasswordController.text
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              size: 14,
                              color:
                                  _passwordController.text ==
                                          _confirmPasswordController.text
                                      ? EasySitColors.successFg
                                      : EasySitColors.errorFg,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _passwordController.text ==
                                      _confirmPasswordController.text
                                  ? 'Passwords match'
                                  : 'Passwords do not match',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    _passwordController.text ==
                                            _confirmPasswordController.text
                                        ? EasySitColors.successFg
                                        : EasySitColors.errorFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Inline error banner right above button
                    if (_errorMessage.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: EasySitColors.errorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EasySitColors.errorBorder),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: EasySitColors.errorFg,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  color: EasySitColors.errorFg,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
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
                                  'Register',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      ' Login',
                      style: TextStyle(
                        color: EasySitColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
    );
  }
}
