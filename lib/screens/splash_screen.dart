import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_persistence_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  late AnimationController _dotController;

  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Subtle breathing animation for the chair icon (~2000ms loop)
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _breathingAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    // Sequential loop for the three blue dots (~1200ms loop)
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _loadStartupData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (disableAnimations) {
      if (_breathingController.isAnimating) _breathingController.stop();
      if (_dotController.isAnimating) _dotController.stop();
    } else {
      if (!_breathingController.isAnimating) {
        _breathingController.repeat(reverse: true);
      }
      if (!_dotController.isAnimating) {
        _dotController.repeat();
      }
    }
  }

  /// Loads essential startup data only, without artificial delays,
  /// and navigates immediately to the destination screen.
  Future<void> _loadStartupData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final bool isRemembered = await AuthPersistenceService.isRememberMe();
      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (isRemembered && currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get()
            .timeout(const Duration(seconds: 8));

        if (!mounted) return;

        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data['isBlocked'] == true) {
            await AuthPersistenceService.clear();
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
            return;
          }

          final userType = data?['userType'] ?? 'student';
          if (mounted) {
            if (userType == 'admin') {
              Navigator.pushReplacementNamed(context, '/admin_dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/student_home');
            }
            return;
          }
        } else {
          // If profile doc doesn't exist yet, proceed to student_home
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/student_home');
            return;
          }
        }
      } else {
        // Not remembered or no active user: clear any stale firebase session
        if (currentUser != null) {
          await FirebaseAuth.instance.signOut();
        }
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Unable to connect to the network. Please verify your connection.';
      });
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedDot(int index, bool disableAnimations) {
    if (disableAnimations) {
      return Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF386CD1),
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        // Phase shift: 0.0, 0.18, 0.36
        final double phase = (index * 0.18);
        double t = (_dotController.value - phase) % 1.0;
        if (t < 0) t += 1.0;

        // Wave pulse happens in the first 45% of the phase
        final double wave = (t <= 0.45) ? math.sin((t / 0.45) * math.pi) : 0.0;
        final double translateY = -5.0 * wave;
        final double opacity = 0.35 + (0.65 * wave);

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity.clamp(0.2, 1.0),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF386CD1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF29234F),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF29234F),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              Color(0xFF322A5E),
              Color(0xFF29234F),
              Color(0xFF1E193C),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Chair Icon with subtle breathing animation
                  disableAnimations
                      ? _buildChairIcon()
                      : AnimatedBuilder(
                          animation: _breathingAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _breathingAnimation.value,
                              child: child,
                            );
                          },
                          child: _buildChairIcon(),
                        ),

                  const SizedBox(height: 24),

                  // "EasySit" App Name: "Easy" in light lavender, "Sit" in blue
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Easy',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB5BBDB),
                            letterSpacing: 1.2,
                          ),
                        ),
                        TextSpan(
                          text: 'Sit',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF386CD1),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline: "No More Searching"
                  const Text(
                    'No More Searching',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF989CBC),
                      letterSpacing: 2.2,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Animated dots or Retry option on failure
                  if (_hasError) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(
                        _errorMessage ?? 'Startup failed. Please check your connection.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFB5BBDB),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadStartupData,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Retrying...' : 'Retry',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF386CD1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ] else ...[
                    // Three small blue dots animated sequentially
                    SizedBox(
                      height: 24,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAnimatedDot(0, disableAnimations),
                          const SizedBox(width: 8),
                          _buildAnimatedDot(1, disableAnimations),
                          const SizedBox(width: 8),
                          _buildAnimatedDot(2, disableAnimations),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChairIcon() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFF29234F),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF386CD1).withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/chair_icon.png',
          width: 104,
          height: 104,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/logo.png',
            width: 104,
            height: 104,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.chair_alt_rounded,
              color: Color(0xFF386CD1),
              size: 56,
            ),
          ),
        ),
      ),
    );
  }
}
