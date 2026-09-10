import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialIdentifier;

  const ForgotPasswordScreen({
    super.key,
    this.initialIdentifier,
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _identifierController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isSuccess = false;
  String _successMessage = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialIdentifier != null &&
        widget.initialIdentifier!.trim().isNotEmpty) {
      _identifierController.text = widget.initialIdentifier!.trim();
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
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
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}*@$domain';
    }
    return '${name.substring(0, 2)}${'*' * (name.length - 2)}@$domain';
  }

  String _studentIdToLegacyEmail(String studentId) {
    final trimmed = studentId.trim().toLowerCase();
    if (trimmed.startsWith('admin@')) {
      final adminName =
          trimmed.substring(6).replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      return 'admin_$adminName@easysit.app';
    }
    final cleaned = trimmed.replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    return '$cleaned@easysit.app';
  }

  Future<void> _handlePasswordReset() async {
    final input = _identifierController.text.trim();

    if (input.isEmpty) {
      _showError('Please enter your registered email address or Student ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _isSuccess = false;
    });

    try {
      if (input.contains('@') && !input.startsWith('admin@')) {
        // Direct email provided
        await _sendResetToEmail(input);
      } else {
        // Student ID or Admin ID provided -> Look up in Firestore
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('studentId', isEqualTo: input)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final registeredEmail = (data['email'] ?? '').toString().trim();

          if (registeredEmail.isNotEmpty && registeredEmail.contains('@')) {
            // Try sending to the registered email found in Firestore
            try {
              await FirebaseAuth.instance
                  .sendPasswordResetEmail(email: registeredEmail);
              if (mounted) {
                setState(() {
                  _isSuccess = true;
                  _successMessage =
                      'Password reset email sent to your registered email (${_maskEmail(registeredEmail)})! Please check your inbox and spam folder.';
                  _isLoading = false;
                });
              }
              return;
            } on FirebaseAuthException catch (authEx) {
              if (authEx.code == 'user-not-found') {
                // The user in Firebase Auth might have been created with legacy student alias
                final legacyEmail = _studentIdToLegacyEmail(input);
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: legacyEmail);
                  if (mounted) {
                    setState(() {
                      _isSuccess = true;
                      _successMessage =
                          'Password reset instructions initiated for Student ID $input. If you do not receive an email, please contact the library desk.';
                      _isLoading = false;
                    });
                  }
                  return;
                } catch (_) {
                  _showError(
                    'Account found for $input, but password reset requires admin assistance. Please contact the library administrator.',
                  );
                  return;
                }
              } else {
                rethrow;
              }
            }
          } else {
            // No email found in document, try legacy alias
            final legacyEmail = _studentIdToLegacyEmail(input);
            await FirebaseAuth.instance
                .sendPasswordResetEmail(email: legacyEmail);
            if (mounted) {
              setState(() {
                _isSuccess = true;
                _successMessage =
                    'Password reset email initiated for Student ID $input. Please check your inbox or contact the library desk.';
                _isLoading = false;
              });
            }
          }
        } else {
          // Check if it's an admin ID
          if (input.startsWith('admin@')) {
            final legacyEmail = _studentIdToLegacyEmail(input);
            await FirebaseAuth.instance
                .sendPasswordResetEmail(email: legacyEmail);
            if (mounted) {
              setState(() {
                _isSuccess = true;
                _successMessage =
                    'Password reset initiated for Admin account. Please check your associated email.';
                _isLoading = false;
              });
            }
          } else {
            _showError(
              'No account found matching Student ID "$input". Please check your ID or register.',
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg =
              'No account found with this email or Student ID. Please check your input or register.';
          break;
        case 'invalid-email':
          msg = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          msg =
              'Network error. Please check your internet connection and try again.';
          break;
        case 'too-many-requests':
          msg =
              'Too many requests. Please wait a few minutes before trying again.';
          break;
        default:
          msg = e.message ?? 'Failed to send reset link. Please try again.';
      }
      _showError(msg);
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted && !_isSuccess) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendResetToEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _successMessage =
            'A password reset link has been sent to $email.\n\nPlease check your inbox (and spam folder) and follow the link to reset your password.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Header Illustration / Icon Card
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D6EFD).withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 46,
                      color: Color(0xFF0D6EFD),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (!_isSuccess) ...[
                // Instruction Text
                const Center(
                  child: Text(
                    'Forgot Your Password?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Enter your registered email address or Student ID below to receive password reset instructions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Error Message banner
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Input Field
                TextField(
                  controller: _identifierController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handlePasswordReset(),
                  decoration: InputDecoration(
                    labelText: 'Email Address or Student ID',
                    hintText: 'e.g. name@gmail.com or CT20xxxxx',
                    helperText:
                        'You can use either your Gmail or your Student ID',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      color: Color(0xFF0D6EFD),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D6EFD),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handlePasswordReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6EFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Send Reset Instructions',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Help box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Need quick assistance? You can also visit the library help desk or contact an admin to verify your account credentials.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Success View
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Check Your Email',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _successMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF15803D),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Resend button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isSuccess = false;
                        _errorMessage = '';
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0D6EFD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Resend or Try Another Email',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF0D6EFD),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Return to Login Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D6EFD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Return to Login',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Back to Login Link
              if (!_isSuccess)
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: Color(0xFF0D6EFD),
                    ),
                    label: const Text(
                      'Back to Login',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF0D6EFD),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
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
