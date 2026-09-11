import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'student_home_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../utils/app_page_route.dart';
import '../widgets/notification_bell_button.dart';
import '../services/seat_expiry_service.dart';
import '../utils/app_colors.dart';

class SeatBookingScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String buildingName;
  final String floorName;
  final VoidCallback? onBookingComplete;

  const SeatBookingScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.buildingName,
    required this.floorName,
    this.onBookingComplete,
  });

  @override
  State<SeatBookingScreen> createState() => _SeatBookingScreenState();
}

class _SeatBookingScreenState extends State<SeatBookingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot> _seatStream;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _seatStream = _firestore
        .collection('seats')
        .where('roomId', isEqualTo: widget.roomId)
        .snapshots();
    // Real-time ticker to immediately update seat status the instant a booking expires
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<bool> _hasExistingBooking(String uid) async {
    QuerySnapshot pending =
        await _firestore
            .collection('seats')
            .where('pendingBy', isEqualTo: uid)
            .limit(1)
            .get();
    if (pending.docs.isNotEmpty) {
      final pData = pending.docs.first.data() as Map<String, dynamic>;
      if (SeatExpiryService.isSeatExpired(pData)) {
        await SeatExpiryService.releaseExpiredSeatIfNeeded(
          pending.docs.first.id,
          pData,
        );
      } else {
        return true;
      }
    }
    QuerySnapshot booked =
        await _firestore
            .collection('seats')
            .where('bookedBy', isEqualTo: uid)
            .limit(1)
            .get();
    if (booked.docs.isNotEmpty) {
      final bData = booked.docs.first.data() as Map<String, dynamic>;
      if (SeatExpiryService.isSeatExpired(bData)) {
        await SeatExpiryService.releaseExpiredSeatIfNeeded(
          booked.docs.first.id,
          bData,
        );
      } else {
        return true;
      }
    }
    return false;
  }

  void _showActiveBookingPopup(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Active booking found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Please cancel your current booking before booking another seat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reserveSeat(String seatId, String seatNumber) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    bool hasBooking = await _hasExistingBooking(user.uid);
    if (hasBooking) {
      if (mounted) {
        _showActiveBookingPopup(context);
      }
      return;
    }

    if (!mounted) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            elevation: 10,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Seat Badge Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: EasySitColors.primaryTint,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EasySitColors.softBlueBorder,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chair_rounded,
                        color: EasySitColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Reserve Seat',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Seat & Location pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: EasySitColors.primaryTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: EasySitColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Seat $seatNumber • ${widget.roomName}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: EasySitColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 10-minute warning alert card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: EasySitColors.warningBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: EasySitColors.warningBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: EasySitColors.warningFg,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: EasySitColors.bodyText,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(text: 'You have '),
                                TextSpan(
                                  text: '10 minutes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: EasySitColors.warningFg,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' to arrive and scan the QR code at the seat to confirm your booking.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: EasySitColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: EasySitColors.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Reserve Button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EasySitColors.primary,
                              foregroundColor: EasySitColors.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Reserve Now',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
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

    if (confirm != true) return;

    try {
      await _firestore.collection('seats').doc(seatId).update({
        'status': 'pending',
        'pendingBy': user.uid,
        'pendingAt': Timestamp.fromDate(DateTime.now()),
        'buildingName': widget.buildingName,
        'roomName': widget.roomName,
        'bookedBy': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
      });

      if (mounted) {
        if (widget.onBookingComplete != null) {
          widget.onBookingComplete!();
        } else {
          Navigator.pushReplacement(
            context,
            AppPageRoute(builder: (_) => const SessionScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.error),
        );
      }
    }
  }

  Future<void> _cancelPending(String seatId, String seatNumber) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: EasySitColors.surface,
            elevation: 10,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: EasySitColors.errorBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EasySitColors.errorBorder,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cancel_outlined,
                        color: EasySitColors.error,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cancel Reservation',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to release Seat $seatNumber?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: EasySitColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EasySitColors.secondaryText,
                              side: const BorderSide(color: EasySitColors.divider),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Keep Seat',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EasySitColors.error,
                              foregroundColor: EasySitColors.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Release',
                              style: TextStyle(fontWeight: FontWeight.w600),
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

    if (confirm != true) return;

    try {
      await _firestore.collection('seats').doc(seatId).update({
        'status': 'available',
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat $seatNumber released.'),
            backgroundColor: EasySitColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.error),
        );
      }
    }
  }

  void _onNavTab(int index) {
    if (index == 0) {
      Navigator.pushAndRemoveUntil(
        context,
        AppPageRoute(builder: (_) => const StudentHomeScreen()),
        (route) => false,
      );
      return;
    }
    Widget screen;
    switch (index) {
      case 1:
        screen = const QrScannerScreen();
        break;
      case 2:
        screen = const SessionScreen();
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
      child: SwipeNavigationWrapper(
        enableSwipeBack: true,
        onSwipeBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              AppPageRoute(builder: (_) => const StudentHomeScreen()),
              (route) => false,
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: EasySitColors.studentHeaderGradient,
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              toolbarHeight: 84,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
              ),
              leadingWidth: 64,
              leading: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: EasySitColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: EasySitColors.divider),
                    boxShadow: EasySitColors.cardShadows,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: EasySitColors.textPrimary,
                    ),
                    onPressed: () {
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
                  ),
                ),
              ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.roomName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.buildingName} • ${widget.floorName}',
                    style: const TextStyle(
                      color: EasySitColors.secondaryText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: const [
                NotificationBellButton(),
                SizedBox(width: 20),
              ],
            ),
            body: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: EasySitColors.appBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _seatStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_seat,
                              size: 64,
                              color: EasySitColors.secondaryText,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No seats available in this room',
                              style: TextStyle(
                                fontSize: 18,
                                color: EasySitColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    var seats = snapshot.data!.docs;
                    seats.sort((a, b) {
                      var aNum =
                          int.tryParse(
                            (a.data() as Map)['seatNumber'] ?? '0',
                          ) ??
                          0;
                      var bNum =
                          int.tryParse(
                            (b.data() as Map)['seatNumber'] ?? '0',
                          ) ??
                          0;
                      return aNum.compareTo(bNum);
                    });

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _legendItem(EasySitColors.seatAvailableFill, EasySitColors.seatAvailableText, 'Available'),
                              const SizedBox(width: 12),
                              _legendItem(EasySitColors.seatPendingFill, EasySitColors.seatPendingText, 'Pending'),
                              const SizedBox(width: 12),
                              _legendItem(EasySitColors.seatOccupiedFill, EasySitColors.seatOccupiedText, 'Booked'),
                              const SizedBox(width: 12),
                              _legendItem(EasySitColors.seatSelectedFill, Colors.white, 'My Seat', isFilled: true),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.9,
                                  ),
                              itemCount: seats.length,
                              itemBuilder: (context, index) {
                                var seatData =
                                    seats[index].data() as Map<String, dynamic>;
                                String seatId = seats[index].id;
                                String seatNumber =
                                    seatData['seatNumber'] ?? '?';
                                String status =
                                    seatData['status'] ?? 'available';
                                String? pendingBy =
                                    seatData['pendingBy'] as String?;
                                String? bookedBy =
                                    seatData['bookedBy'] as String?;
                                User? user = FirebaseAuth.instance.currentUser;
                                String myUid = user?.uid ?? '';

                                // Dynamic real-time expiration check
                                bool isExpired = SeatExpiryService.isSeatExpired(seatData);
                                String effectiveStatus = isExpired ? 'available' : status;
                                if (isExpired) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    SeatExpiryService.releaseExpiredSeatIfNeeded(seatId, seatData);
                                  });
                                }

                                Color bgColor;
                                Color borderColor;
                                Color iconColor;
                                Color textColor;
                                bool isMine = false;
                                VoidCallback? onTap;

                                if (effectiveStatus == 'available') {
                                  bgColor = EasySitColors.seatAvailableFill;
                                  borderColor = EasySitColors.seatAvailableText;
                                  iconColor = EasySitColors.seatAvailableText;
                                  textColor = EasySitColors.seatAvailableText;
                                  onTap =
                                      () => _reserveSeat(seatId, seatNumber);
                                } else if (effectiveStatus == 'pending') {
                                  isMine = pendingBy == myUid;
                                  bgColor = EasySitColors.seatPendingFill;
                                  borderColor = isMine ? EasySitColors.primary : EasySitColors.seatPendingText;
                                  iconColor = EasySitColors.seatPendingText;
                                  textColor = EasySitColors.seatPendingText;
                                  if (isMine) {
                                    onTap =
                                        () =>
                                            _cancelPending(seatId, seatNumber);
                                  } else {
                                    onTap = () {
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Seat $seatNumber is currently pending confirmation by another student.',
                                          ),
                                          backgroundColor: EasySitColors.warningFg,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    };
                                  }
                                } else {
                                  // Booked or occupied
                                  isMine = bookedBy == myUid;
                                  bgColor =
                                      isMine
                                          ? EasySitColors.seatSelectedFill
                                          : EasySitColors.seatOccupiedFill;
                                  borderColor =
                                      isMine
                                          ? EasySitColors.focusRing
                                          : EasySitColors.divider;
                                  iconColor =
                                      isMine
                                          ? EasySitColors.onPrimary
                                          : EasySitColors.seatOccupiedText;
                                  textColor =
                                      isMine
                                          ? EasySitColors.onPrimary
                                          : EasySitColors.seatOccupiedText;
                                }

                                return GestureDetector(
                                  onTap: onTap,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 2.0,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: EasySitColors.cardShadow,
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isMine
                                              ? (effectiveStatus == 'pending' ? Icons.access_time_rounded : Icons.check_circle_outline)
                                              : (effectiveStatus == 'pending'
                                                  ? Icons.access_time_rounded
                                                  : (effectiveStatus == 'available' ? Icons.event_seat : Icons.lock_outline)),
                                          size: 24,
                                          color: iconColor,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          seatNumber,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        if (effectiveStatus == 'pending')
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: EasySitColors.warningBorder,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isMine ? 'Mine' : 'Pending',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                color: EasySitColors.warningFg,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              onTabSelected: _onNavTab,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color fill, Color border, String label, {bool isFilled = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border, width: 1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isFilled ? EasySitColors.textPrimary : border, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

