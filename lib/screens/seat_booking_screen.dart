import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'student_home_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/app_page_route.dart';
import '../widgets/notification_bell_button.dart';

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

  Future<bool> _hasExistingBooking(String uid) async {
    QuerySnapshot pending =
        await _firestore
            .collection('seats')
            .where('pendingBy', isEqualTo: uid)
            .limit(1)
            .get();
    if (pending.docs.isNotEmpty) return true;
    QuerySnapshot booked =
        await _firestore
            .collection('seats')
            .where('bookedBy', isEqualTo: uid)
            .limit(1)
            .get();
    if (booked.docs.isNotEmpty) return true;
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
                      color: const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF5C55F2).withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chair_rounded,
                        color: Color(0xFF5C55F2),
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
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFF5C55F2),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Seat $seatNumber • ${widget.roomName}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
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
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFFFD54F),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Color(0xFFE65100),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.grey.shade800,
                                height: 1.4,
                              ),
                              children: const [
                                TextSpan(text: 'You have '),
                                TextSpan(
                                  text: '10 minutes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100),
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
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
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
                              backgroundColor: const Color(0xFF5C55F2),
                              foregroundColor: Colors.white,
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cancel_outlined,
                        color: Colors.red,
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
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to release Seat $seatNumber?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.grey.shade600,
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
                              foregroundColor: const Color(0xFF64748B),
                              side: BorderSide(color: Colors.grey.shade300),
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
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        widget.roomName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Admin • ${widget.buildingName} • ${widget.floorName}',
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
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF5F7FA), Colors.white],
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      _firestore
                          .collection('seats')
                          .where('roomId', isEqualTo: widget.roomId)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
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
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No seats available in this room',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
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
                              _legendItem(Colors.green.shade600, 'Available'),
                              const SizedBox(width: 12),
                              _legendItem(Colors.amber.shade600, 'Pending'),
                              const SizedBox(width: 12),
                              _legendItem(Colors.red.shade600, 'Booked'),
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

                                Color bgColor;
                                Color borderColor;
                                Color iconColor;
                                Color textColor;
                                bool isMine = false;
                                VoidCallback? onTap;

                                if (status == 'available') {
                                  bgColor = Colors.green.shade50;
                                  borderColor = Colors.green.shade400;
                                  iconColor = Colors.green.shade600;
                                  textColor = Colors.green.shade800;
                                  onTap =
                                      () => _reserveSeat(seatId, seatNumber);
                                } else if (status == 'pending') {
                                  isMine = pendingBy == myUid;
                                  bgColor =
                                      isMine
                                          ? Colors.amber.shade50
                                          : Colors.grey.shade100;
                                  borderColor =
                                      isMine
                                          ? Colors.amber.shade400
                                          : Colors.grey.shade400;
                                  iconColor =
                                      isMine
                                          ? Colors.amber.shade600
                                          : Colors.grey;
                                  textColor =
                                      isMine
                                          ? Colors.amber.shade800
                                          : Colors.grey.shade600;
                                  if (isMine) {
                                    onTap =
                                        () =>
                                            _cancelPending(seatId, seatNumber);
                                  }
                                } else {
                                  isMine = bookedBy == myUid;
                                  bgColor =
                                      isMine
                                          ? Colors.blue.shade50
                                          : Colors.red.shade50;
                                  borderColor =
                                      isMine
                                          ? Colors.blue.shade400
                                          : Colors.red.shade400;
                                  iconColor =
                                      isMine
                                          ? Colors.blue.shade600
                                          : Colors.red.shade600;
                                  textColor =
                                      isMine
                                          ? Colors.blue.shade800
                                          : Colors.red.shade800;
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
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: borderColor.withValues(
                                            alpha: 0.15,
                                          ),
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
                                              ? Icons.person
                                              : Icons.event_seat,
                                          size: 26,
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
                                        if (isMine && status == 'pending')
                                          Container(
                                            margin: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Mine',
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.amber.shade800,
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
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTabSelected: _onNavTab,
      ),
    ),
  );
}

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
