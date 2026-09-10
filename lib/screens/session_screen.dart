import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'student_home_screen.dart';
import 'qr_scanner_screen.dart';
import 'profile_screen.dart';
import '../utils/app_page_route.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/reservation_expired_dialog.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  static bool isActive = false;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _activeBooking;
  Timer? _timer;
  int _remainingSeconds = 0;
  String _bookingStatus = '';
  bool _isLoading = true;

  StreamSubscription<QuerySnapshot>? _bookedSub;
  StreamSubscription<QuerySnapshot>? _pendingSub;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    SessionScreen.isActive = true;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _listenActiveBooking();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _bookedSub?.cancel();
    _pendingSub?.cancel();
    SessionScreen.isActive = false;
    super.dispose();
  }

  void _listenActiveBooking() {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _bookedSub?.cancel();
    _bookedSub = _firestore
        .collection('seats')
        .where('bookedBy', isEqualTo: _user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            _pendingSub?.cancel();
            _onBookingFound(snapshot.docs.first, 'booked');
          } else {
            _pendingSub?.cancel();
            _pendingSub = _firestore
                .collection('seats')
                .where('pendingBy', isEqualTo: _user.uid)
                .snapshots()
                .listen((pendingSnapshot) {
                  if (pendingSnapshot.docs.isNotEmpty) {
                    _onBookingFound(pendingSnapshot.docs.first, 'pending');
                  } else {
                    setState(() {
                      _activeBooking = null;
                      _bookingStatus = '';
                      _isLoading = false;
                    });
                    _timer?.cancel();
                  }
                });
          }
        });
  }

  Future<void> _onBookingFound(QueryDocumentSnapshot doc, String status) async {
    var data = doc.data() as Map<String, dynamic>;

    _timer?.cancel();

    if (status == 'pending') {
      Timestamp? pendingAt = data['pendingAt'] as Timestamp?;
      if (pendingAt != null) {
        DateTime expiresAt = pendingAt.toDate().add(
          const Duration(minutes: 10),
        );
        _startTimerForPending(
          doc.id,
          data['seatNumber']?.toString() ?? '?',
          expiresAt,
        );
      }
      setState(() {
        _activeBooking = {
          'docId': doc.id,
          'seatId': doc.id,
          'seatNumber': data['seatNumber'] ?? '?',
          'roomName': '',
          'floorName': '',
          'buildingName': '',
          'status': 'pending',
          'zone': data['zone'] ?? 'Quiet Zone',
        };
        _bookingStatus = 'pending';
        _isLoading = false;
      });
    } else if (status == 'booked') {
      Timestamp? bookedAt = data['bookedAt'] as Timestamp?;
      DateTime sessionEnd;
      if (bookedAt != null) {
        sessionEnd = bookedAt.toDate().add(const Duration(minutes: 5));
      } else {
        sessionEnd = DateTime.now().add(const Duration(minutes: 5));
      }
      _startTimerForBooked(
        doc.id,
        sessionEnd,
        data['seatNumber'] ?? '?',
        '',
        '',
      );
      setState(() {
        _activeBooking = {
          'docId': doc.id,
          'seatId': doc.id,
          'seatNumber': data['seatNumber'] ?? '?',
          'roomName': '',
          'floorName': '',
          'buildingName': '',
          'status': 'booked',
          'zone': data['zone'] ?? 'Quiet Zone',
        };
        _bookingStatus = 'booked';
        _isLoading = false;
      });
    }

    String roomId = data['roomId'] ?? '';
    String roomName = '';
    String floorName = '';
    String buildingName = '';
    if (roomId.isNotEmpty) {
      DocumentSnapshot roomDoc =
          await _firestore.collection('rooms').doc(roomId).get();
      var roomData = roomDoc.data() as Map<String, dynamic>?;
      roomName = roomData?['name'] ?? 'Room';
      String floorId = roomData?['floorId'] ?? '';
      if (floorId.isNotEmpty) {
        DocumentSnapshot floorDoc =
            await _firestore.collection('floors').doc(floorId).get();
        var floorData = floorDoc.data() as Map<String, dynamic>?;
        floorName = floorData?['name'] ?? 'Floor';
        String buildingId = floorData?['buildingId'] ?? '';
        if (buildingId.isNotEmpty) {
          DocumentSnapshot buildingDoc =
              await _firestore.collection('buildings').doc(buildingId).get();
          var buildingData = buildingDoc.data() as Map<String, dynamic>?;
          buildingName = buildingData?['name'] ?? 'Building';
        }
      }

      if (mounted) {
        setState(() {
          if (_activeBooking != null) {
            _activeBooking!['roomName'] = roomName;
            _activeBooking!['floorName'] = floorName;
            _activeBooking!['buildingName'] = buildingName;
          }
        });
      }
    }
  }

  void _startTimerForPending(
    String seatId,
    String seatNumber,
    DateTime expiresAt,
  ) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int secs = expiresAt.difference(DateTime.now()).inSeconds;
      if (secs <= 0) {
        timer.cancel();
        _releaseExpired(seatId);
      } else {
        setState(() => _remainingSeconds = secs);
      }
    });
    setState(
      () => _remainingSeconds = expiresAt.difference(DateTime.now()).inSeconds,
    );
  }

  void _startTimerForBooked(
    String seatId,
    DateTime sessionEnd,
    String seatNumber,
    String buildingName,
    String roomName,
  ) {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int secs = sessionEnd.difference(DateTime.now()).inSeconds;

      if (secs <= 0) {
        timer.cancel();
        _autoReleaseSeat(seatId);
        return;
      }

      setState(() => _remainingSeconds = secs);
    });

    setState(
      () => _remainingSeconds = sessionEnd.difference(DateTime.now()).inSeconds,
    );
  }

  Future<void> _releaseSeat(String seatId) async {
    _timer?.cancel();
    try {
      await _firestore.collection('seats').doc(seatId).update({
        'status': 'available',
        'bookedBy': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });
      await NotificationService.cancelAllNotifications();
      if (_user != null) {
        await NotificationService.clearUserNotifications(_user.uid);
      }
      if (mounted) {
        setState(() {
          _activeBooking = null;
          _bookingStatus = '';
        });
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (ctx) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2ECA7F,
                          ).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF2ECA7F),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Seat Released',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Your seat has been released successfully.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Thank you for using EasySit!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECA7F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'OK',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error releasing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autoReleaseSeat(String seatId) async {
    await _firestore.collection('seats').doc(seatId).update({
      'status': 'available',
      'bookedBy': FieldValue.delete(),
      'bookedAt': FieldValue.delete(),
      'pendingBy': FieldValue.delete(),
      'pendingAt': FieldValue.delete(),
    });
    _timer?.cancel();
    await NotificationService.cancelAllNotifications();
    if (_user != null) {
      await NotificationService.clearUserNotifications(_user.uid);
    }
    if (mounted) {
      setState(() {
        _activeBooking = null;
        _bookingStatus = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏰ Session expired. Seat released automatically.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _releaseExpired(String seatId) async {
    await _firestore.collection('seats').doc(seatId).update({
      'status': 'available',
      'pendingBy': FieldValue.delete(),
      'pendingAt': FieldValue.delete(),
    });
    await NotificationService.cancelAllNotifications();
    if (_user != null) {
      await NotificationService.clearUserNotifications(_user.uid);
    }
    if (mounted) {
      setState(() {
        _activeBooking = null;
        _bookingStatus = '';
      });
      ReservationExpiredDialog.show(context);
    }
  }

  Future<void> _confirmCancelOrRelease({
    required String seatId,
    required bool isRelease,
  }) async {
    final seatNum = _activeBooking?['seatNumber']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: Colors.white,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isRelease ? Icons.output_rounded : Icons.cancel_outlined,
                  color: Colors.red.shade600,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isRelease ? 'Release Seat?' : 'Cancel Reservation?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isRelease
                    ? 'Are you sure you want to end your session? Seat $seatNum will be released and made available for other students.'
                    : 'Are you sure you want to cancel your reservation for Seat $seatNum? The seat will be released immediately.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Keep Seat',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        isRelease ? 'Release' : 'Yes, Cancel',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _releaseSeat(seatId);
    }
  }

  Future<void> _manualReleaseSeat() async {
    if (_activeBooking == null) return;
    await _confirmCancelOrRelease(
      seatId: _activeBooking!['seatId'],
      isRelease: true,
    );
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onNavTab(int index) {
    if (index == 2) return;
    Widget screen;
    switch (index) {
      case 0:
        screen = const StudentHomeScreen();
        break;
      case 1:
        screen = const QrScannerScreen();
        break;
      case 3:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            AppPageRoute(
              builder: (_) => const StudentHomeScreen(),
            ),
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My session',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Your seat is now active',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  const NotificationBellButton(),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 2,
        onTabSelected: _onNavTab,
      ),
    ),
  );
}

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2ECA7F)),
      );
    }

    if (_activeBooking == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_seat, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Active Session',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Find and book a seat to start your session',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    bool isPending = _bookingStatus == 'pending';
    bool isBooked = _bookingStatus == 'booked';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        children: [
          // Status Header (Top static graphic removed)
          Column(
            children: [
              const SizedBox(height: 8),
              Text(
                isPending ? "Pending Confirmation" : "You're all set",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPending
                    ? "Please scan the QR on the seat"
                    : "Your session has started successfully",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ========== Animated Circular Timer & Creative Visuals ==========
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final val = _pulseAnimation.value;
              return SizedBox(
                width: 290,
                height: 290,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric animated pulsing rings (from top graphic, now animated)
                    Container(
                      width: 230 + (24 * val),
                      height: 230 + (24 * val),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECA7F).withValues(
                          alpha: 0.05 + (0.05 * val),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 185 + (16 * val),
                      height: 185 + (16 * val),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECA7F).withValues(
                          alpha: 0.08 + (0.08 * (1 - val)),
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 145,
                      height: 145,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECA7F).withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                    ),

                    // Floating animated sparkles and bubbles around the timer ring
                    // Top-left sparkle
                    Positioned(
                      top: 14 + (4 * (1 - val)),
                      left: 28 + (3 * val),
                      child: Transform.rotate(
                        angle: val * 0.3,
                        child: Icon(
                          Icons.star_border_rounded,
                          color: const Color(0xFF2ECA7F).withValues(
                            alpha: 0.4 + (0.5 * val),
                          ),
                          size: 26,
                        ),
                      ),
                    ),
                    // Top-right star
                    Positioned(
                      top: 22 + (5 * val),
                      right: 28 - (2 * val),
                      child: Transform.scale(
                        scale: 0.85 + (0.3 * val),
                        child: Icon(
                          Icons.auto_awesome,
                          color: const Color(0xFF2ECA7F).withValues(
                            alpha: 0.45 + (0.45 * (1 - val)),
                          ),
                          size: 22,
                        ),
                      ),
                    ),
                    // Left bubble
                    Positioned(
                      top: 130 + (6 * (val - 0.5)),
                      left: 6,
                      child: Icon(
                        Icons.radio_button_unchecked,
                        color: const Color(0xFF2ECA7F).withValues(
                          alpha: 0.35 + (0.35 * val),
                        ),
                        size: 16,
                      ),
                    ),
                    // Right small star
                    Positioned(
                      top: 120 - (4 * val),
                      right: 8,
                      child: Icon(
                        Icons.star_rounded,
                        color: const Color(0xFF2ECA7F).withValues(
                          alpha: 0.4 + (0.4 * val),
                        ),
                        size: 18,
                      ),
                    ),
                    // Bottom-left star
                    Positioned(
                      bottom: 26 - (3 * val),
                      left: 36,
                      child: Transform.rotate(
                        angle: -val * 0.25,
                        child: Icon(
                          Icons.star_border_rounded,
                          color: const Color(0xFF2ECA7F).withValues(
                            alpha: 0.35 + (0.45 * (1 - val)),
                          ),
                          size: 24,
                        ),
                      ),
                    ),
                    // Bottom-right bubble
                    Positioned(
                      bottom: 30 + (4 * val),
                      right: 38,
                      child: Icon(
                        Icons.radio_button_unchecked,
                        color: const Color(0xFF2ECA7F).withValues(
                          alpha: 0.3 + (0.4 * val),
                        ),
                        size: 14,
                      ),
                    ),

                    // Circular countdown progress indicator
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value:
                            _remainingSeconds > 0
                                ? _remainingSeconds /
                                    (isPending ? (10 * 60) : (5 * 60))
                                : 0,
                        strokeWidth: 11,
                        backgroundColor: const Color(0xFFEBEFEF),
                        color: const Color(0xFF2ECA7F), // Green progress
                        strokeCap: StrokeCap.round,
                      ),
                    ),

                    // Inside countdown information
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated pulsing live indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECA7F).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2ECA7F),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2ECA7F).withValues(
                                        alpha: 0.4 + (0.5 * val),
                                      ),
                                      blurRadius: 3 + (3 * val),
                                      spreadRadius: 1 * val,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPending ? 'TIME REMAINING' : 'SESSION ACTIVE',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: Color(0xFF0F5132),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F5132), // Dark green text
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'TOTAL DURATION',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F0), // Light green background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPending ? '10 mins' : '5 mins',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2ECA7F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 36),

          // ========== Seat Details Card ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2FAF5), // Very light green tint
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                // Left side icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: const Icon(
                    Icons.event_seat,
                    color: Color(0xFF2ECA7F),
                    size: 36,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seat ID',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activeBooking!['seatNumber'] ?? 'A03',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ECA7F),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeBooking!['zone'] ?? 'Quiet Zone',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_activeBooking!['buildingName'] ?? 'Admin'} • ${_activeBooking!['floorName'] ?? 'Floor 6'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ========== Action Buttons ==========
          const SizedBox(height: 24),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        AppPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C6FFF),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Scan QR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      if (_activeBooking != null) {
                        _confirmCancelOrRelease(
                          seatId: _activeBooking!['seatId'],
                          isRelease: false,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (isBooked)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  24,
                ), // Match upper card radius
                border: Border.all(color: Colors.red.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.05), // Softer shadow
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _manualReleaseSeat,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ), // Tighter padding for height match
                    child: Column(
                      children: [
                        Icon(
                          Icons.output_rounded,
                          color: Colors.red.shade500,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Release Seat',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'End session and make seat available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
