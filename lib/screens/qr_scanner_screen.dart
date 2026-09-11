import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_screen.dart';
import 'student_home_screen.dart';
import 'profile_screen.dart';

import '../widgets/app_bottom_nav.dart';
import '../widgets/reservation_expired_dialog.dart';
import '../services/notification_service.dart';
import '../services/user_stats_service.dart';
import '../services/seat_expiry_service.dart';
import '../utils/app_page_route.dart';
import '../utils/app_colors.dart';

class QrScannerScreen extends StatefulWidget {
  final VoidCallback? onBookingComplete;
  final bool isTab;
  final bool? isActive;
  final ValueChanged<int>? onTabSelected;

  const QrScannerScreen({
    super.key,
    this.onBookingComplete,
    this.isTab = false,
    this.isActive,
    this.onTabSelected,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  static final Map<String, Map<String, String>> _roomDetailsCache = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetScanner() {
    if (mounted) {
      setState(() => _isProcessing = false);
      try {
        _controller.start();
      } catch (_) {}
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    final qrValue = barcode?.rawValue;
    if (qrValue == null || !qrValue.startsWith('SEAT:')) return;

    setState(() => _isProcessing = true);
    // Non-blocking camera stop to avoid freezing the thread
    _controller.stop().catchError((_) {});

    String seatId = qrValue.substring(5).trim();
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showError('Please login first');
      return;
    }

    try {
      // Concurrently fetch the seat document and check for existing bookings
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('seats')
            .doc(seatId)
            .get(),
        _hasExistingBooking(user.uid),
      ]);

      DocumentSnapshot seatDoc = results[0] as DocumentSnapshot;
      bool hasBooking = results[1] as bool;

      if (!seatDoc.exists) {
        _showError('Seat not found!');
        return;
      }

      var data = seatDoc.data() as Map<String, dynamic>;
      String roomId = data['roomId'] ?? '';
      String seatNumber = data['seatNumber']?.toString() ?? '?';
      String status = data['status'] ?? 'available';
      String? pendingBy = data['pendingBy'] as String?;

      String roomName = data['roomName'] ?? '';
      String floorName = data['floorName'] ?? '';
      String buildingName = data['buildingName'] ?? '';

      // Check fast in-memory cache first for instant 0ms resolution
      if ((roomName.isEmpty || buildingName.isEmpty) && roomId.isNotEmpty) {
        if (_roomDetailsCache.containsKey(roomId)) {
          final cached = _roomDetailsCache[roomId]!;
          if (roomName.isEmpty) roomName = cached['roomName'] ?? 'Room';
          if (floorName.isEmpty) floorName = cached['floorName'] ?? 'Floor';
          if (buildingName.isEmpty) buildingName = cached['buildingName'] ?? 'Building';
        } else {
          try {
            DocumentSnapshot roomDoc =
                await FirebaseFirestore.instance
                    .collection('rooms')
                    .doc(roomId)
                    .get();
            var roomData = roomDoc.data() as Map<String, dynamic>?;
            if (roomName.isEmpty) roomName = roomData?['name'] ?? 'Room';
            String floorId = roomData?['floorId'] ?? '';

            if (floorId.isNotEmpty) {
              DocumentSnapshot floorDoc =
                  await FirebaseFirestore.instance
                      .collection('floors')
                      .doc(floorId)
                      .get();
              var floorData = floorDoc.data() as Map<String, dynamic>?;
              if (floorName.isEmpty) floorName = floorData?['name'] ?? 'Floor';
              String buildingId = floorData?['buildingId'] ?? '';

              if (buildingId.isNotEmpty && buildingName.isEmpty) {
                DocumentSnapshot buildingDoc =
                    await FirebaseFirestore.instance
                        .collection('buildings')
                        .doc(buildingId)
                        .get();
                var buildingData = buildingDoc.data() as Map<String, dynamic>?;
                buildingName = buildingData?['name'] ?? 'Building';
              }
            }

            _roomDetailsCache[roomId] = {
              'roomName': roomName.isNotEmpty ? roomName : 'Room',
              'floorName': floorName.isNotEmpty ? floorName : 'Floor',
              'buildingName': buildingName.isNotEmpty ? buildingName : 'Building',
            };

            // Write back to seat document in background so future scans have them instantly
            FirebaseFirestore.instance.collection('seats').doc(seatId).update({
              'roomName': roomName,
              'floorName': floorName,
              'buildingName': buildingName,
            }).catchError((_) {});
          } catch (_) {}
        }
      }

      if (roomName.isEmpty) roomName = 'Room';
      if (buildingName.isEmpty) buildingName = 'Building';

      if (!mounted) return;

      // Real-time dynamic expiration check on scanned seat
      if (SeatExpiryService.isSeatExpired(data)) {
        SeatExpiryService.releaseExpiredSeatIfNeeded(seatId, data);
        status = 'available';
        data['status'] = 'available';
      }

      if (status == 'available') {
        if (hasBooking) {
          if (mounted) {
            _showActiveBookingPopup(context, scannedSeatNumber: seatNumber);
          }
          return;
        }
        _showDirectBookingDialog(
          seatId,
          seatNumber,
          roomName,
          buildingName,
          floorName,
          seatData: data,
        );
      } else if (status == 'pending') {
        if (pendingBy == user.uid) {
          // Check expiration
          Timestamp? pendingAt = data['pendingAt'] as Timestamp?;
          if (pendingAt != null) {
            DateTime expiresAt = pendingAt.toDate().add(
              const Duration(minutes: 10),
            );
            if (DateTime.now().isAfter(expiresAt)) {
              await FirebaseFirestore.instance
                  .collection('seats')
                  .doc(seatId)
                  .update({
                    'status': 'available',
                    'pendingBy': FieldValue.delete(),
                    'pendingAt': FieldValue.delete(),
                  });
              if (mounted) {
                _resetScanner();
                ReservationExpiredDialog.show(context);
              }
              return;
            }
          }

          _showConfirmBookingDialog(
            seatId,
            seatNumber,
            roomName,
            buildingName,
            floorName,
            seatData: data,
          );
        } else {
          _showAlreadyBookedPopup(
            seatNumber: seatNumber,
            roomName: roomName,
            buildingName: buildingName,
            floorName: floorName,
            isPending: true,
          );
        }
      } else if (status == 'booked') {
        String? bookedBy = data['bookedBy'] as String?;
        bool isMine = bookedBy == user.uid;
        _showAlreadyBookedPopup(
          seatNumber: seatNumber,
          roomName: roomName,
          buildingName: buildingName,
          floorName: floorName,
          isMine: isMine,
        );
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showDirectBookingDialog(
    String seatId,
    String seatNumber,
    String roomName,
    String buildingName,
    String floorName, {
    Map<String, dynamic>? seatData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: EasySitColors.surface,
            elevation: 12,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Icon Badge
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: EasySitColors.successBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EasySitColors.successBorder,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.event_seat_rounded,
                        size: 34,
                        color: EasySitColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dialog Title & Subtitle
                  const Text(
                    'Book This Seat',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Confirm your selection to start your session',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: EasySitColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Seat & Location Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: EasySitColors.subtleSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: EasySitColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: EasySitColors.primaryTint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: EasySitColors.softBlueBorder),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.chair_rounded,
                              color: EasySitColors.primary,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Seat $seatNumber',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: EasySitColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: EasySitColors.successBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: EasySitColors.successBorder,
                                      ),
                                    ),
                                    child: const Text(
                                      'Available',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: EasySitColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$buildingName • $floorName • $roomName',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: EasySitColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Session Duration Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: EasySitColors.successBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EasySitColors.successBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: EasySitColors.success,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your session will start immediately for 10 minutes.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: EasySitColors.success,
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
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _resetScanner();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EasySitColors.textSecondary,
                              side: const BorderSide(
                                color: EasySitColors.divider,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _bookSeatDirect(
                                seatId,
                                seatNumber,
                                roomName,
                                buildingName,
                                floorName,
                                seatData: seatData,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EasySitColors.primary,
                              foregroundColor: EasySitColors.onPrimary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Book Now',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
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
  }

  // 🟢 Confirm Booking Dialog
  void _showConfirmBookingDialog(
    String seatId,
    String seatNumber,
    String roomName,
    String buildingName,
    String floorName, {
    Map<String, dynamic>? seatData,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: EasySitColors.surface,
            elevation: 12,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Icon Badge
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: EasySitColors.successBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EasySitColors.successBorder,
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.verified_rounded,
                        size: 34,
                        color: EasySitColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Dialog Title & Subtitle
                  const Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Scan verified! Confirm to activate your session',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: EasySitColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Seat & Location Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: EasySitColors.subtleSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: EasySitColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: EasySitColors.primaryTint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: EasySitColors.softBlueBorder),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.chair_rounded,
                              color: EasySitColors.primary,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Seat $seatNumber',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: EasySitColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: EasySitColors.warningBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: EasySitColors.warningBorder,
                                      ),
                                    ),
                                    child: const Text(
                                      'Reserved',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: EasySitColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$buildingName • $floorName • $roomName',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: EasySitColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Session Duration Info Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: EasySitColors.successBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EasySitColors.successBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: EasySitColors.success,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your session will start now and last for 10 minutes.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: EasySitColors.success,
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
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _resetScanner();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: EasySitColors.textSecondary,
                              side: const BorderSide(
                                color: EasySitColors.divider,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _confirmBookingAndNavigate(
                                seatId,
                                seatNumber,
                                roomName,
                                buildingName,
                                floorName,
                                seatData: seatData,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: EasySitColors.primary,
                              foregroundColor: EasySitColors.onPrimary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Confirm & Start',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
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
  }

  Future<bool> _hasExistingBooking(String uid) async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('seats')
            .where('pendingBy', isEqualTo: uid)
            .limit(1)
            .get(),
        FirebaseFirestore.instance
            .collection('seats')
            .where('bookedBy', isEqualTo: uid)
            .limit(1)
            .get(),
      ]);

      final pending = results[0];
      final booked = results[1];

      if (pending.docs.isNotEmpty) {
        final pData = pending.docs.first.data();
        if (SeatExpiryService.isSeatExpired(pData)) {
          SeatExpiryService.releaseExpiredSeatIfNeeded(
            pending.docs.first.id,
            pData,
          );
        } else {
          return true;
        }
      }
      if (booked.docs.isNotEmpty) {
        final bData = booked.docs.first.data();
        if (SeatExpiryService.isSeatExpired(bData)) {
          SeatExpiryService.releaseExpiredSeatIfNeeded(
            booked.docs.first.id,
            bData,
          );
        } else {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _bookSeatDirect(
    String seatId,
    String seatNumber,
    String roomName,
    String buildingName,
    String floorName, {
    Map<String, dynamic>? seatData,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please login first');
      return;
    }
    try {
      DateTime now = DateTime.now();
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'status': 'booked',
        'bookedBy': user.uid,
        'bookedAt': Timestamp.fromDate(now),
        'buildingName': buildingName,
        'roomName': roomName,
        'floorName': floorName,
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });

      UserStatsService.recordSeatBooked(userId: user.uid, seatId: seatId);
      NotificationService.clearUserNotifications(user.uid);

      final sessionData = {
        'docId': seatId,
        'seatId': seatId,
        'seatNumber': seatNumber,
        'roomName': roomName,
        'floorName': floorName,
        'buildingName': buildingName,
        'status': 'booked',
        'bookedBy': user.uid,
        'bookedAt': Timestamp.fromDate(now),
        'zone': seatData?['zone'] ?? 'Quiet Zone',
      };
      ProfileScreen.cachedBooking = sessionData;
      ProfileScreen.cachedStatus = 'booked';

      if (mounted) {
        _showSuccessAndNavigate(sessionData);
      }
    } catch (e) {
      _showError('Booking failed: $e');
    }
  }

  // 🟢 Confirm booking from pending reservation
  Future<void> _confirmBookingAndNavigate(
    String seatId,
    String seatNumber,
    String roomName,
    String buildingName,
    String floorName, {
    Map<String, dynamic>? seatData,
  }) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please login first');
      return;
    }

    try {
      DateTime now = DateTime.now();

      // Update seat to 'booked' directly without duplicate seatDoc fetch
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'status': 'booked',
        'bookedBy': user.uid,
        'bookedAt': Timestamp.fromDate(now),
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
        'buildingName': buildingName,
        'roomName': roomName,
        'floorName': floorName,
      });

      UserStatsService.recordSeatBooked(userId: user.uid, seatId: seatId);
      NotificationService.clearUserNotifications(user.uid);

      final sessionData = {
        'docId': seatId,
        'seatId': seatId,
        'seatNumber': seatNumber,
        'roomName': roomName,
        'floorName': floorName,
        'buildingName': buildingName,
        'status': 'booked',
        'bookedBy': user.uid,
        'bookedAt': Timestamp.fromDate(now),
        'zone': seatData?['zone'] ?? 'Quiet Zone',
      };
      ProfileScreen.cachedBooking = sessionData;
      ProfileScreen.cachedStatus = 'booked';

      if (mounted) {
        _showSuccessAndNavigate(sessionData);
      }
    } catch (e) {
      _showError('Booking failed: $e');
    }
  }

  void _showSuccessAndNavigate(Map<String, dynamic> sessionData) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: EasySitColors.onPrimary, size: 22),
            SizedBox(width: 12),
            Text(
              'Session started successfully!',
              style: TextStyle(
                color: EasySitColors.onPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
        backgroundColor: EasySitColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(milliseconds: 2500),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );

    if (widget.onBookingComplete != null) {
      widget.onBookingComplete!();
    } else {
      Navigator.pushReplacement(
        context,
        AppPageRoute(
          builder: (_) => SessionScreen(
            initialBooking: sessionData,
            initialStatus: 'booked',
          ),
        ),
      );
    }
  }

  void _showActiveBookingPopup(BuildContext context, {String? scannedSeatNumber}) {
    if (!mounted) return;
    _resetScanner();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 4), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
            _resetScanner();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: EasySitColors.surface,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 26,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: EasySitColors.warningBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: EasySitColors.warning,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Active booking found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  scannedSeatNumber != null
                      ? 'You already have an active seat reservation. Please cancel or finish your current session before booking Seat $scannedSeatNumber.'
                      : 'Please cancel your current booking before booking another seat.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: EasySitColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _resetScanner();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: EasySitColors.textSecondary,
                          side: const BorderSide(color: EasySitColors.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Dismiss',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _onNavTab(2);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EasySitColors.primary,
                          foregroundColor: EasySitColors.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'View Session',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAlreadyBookedPopup({
    required String seatNumber,
    required String roomName,
    String buildingName = '',
    String floorName = '',
    bool isPending = false,
    bool isMine = false,
  }) {
    if (!mounted) return;
    _resetScanner();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 4), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
            _resetScanner();
          }
        });

        Color iconBg = isMine
            ? EasySitColors.primaryTint
            : (isPending ? EasySitColors.warningBg : EasySitColors.bookedFill);
        Color iconColor = isMine
            ? EasySitColors.primary
            : (isPending ? EasySitColors.warning : EasySitColors.bookedText);
        IconData iconData = isMine
            ? Icons.event_seat_rounded
            : (isPending
                ? Icons.hourglass_top_rounded
                : Icons.event_seat_rounded);
        String title = isMine
            ? 'Your Active Seat'
            : (isPending ? 'Seat Reserved' : 'Seat Already Booked');
        String message = isMine
            ? 'You are already occupying Seat $seatNumber.'
            : (isPending
                ? 'Seat $seatNumber is currently reserved by another student.'
                : 'Seat $seatNumber is already booked by another student. Please scan an available seat.');

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: EasySitColors.surface,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      size: 34,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: EasySitColors.subtleSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EasySitColors.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: EasySitColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Seat $seatNumber • $roomName',
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
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: EasySitColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                if (isMine)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onNavTab(2);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EasySitColors.primary,
                        foregroundColor: EasySitColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'View Active Session',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetScanner();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EasySitColors.primary,
                        foregroundColor: EasySitColors.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Scan Another Seat',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    _resetScanner();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: EasySitColors.error),
    );
  }

  void _onNavTab(int index) {
    if (widget.isTab && widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }
    if (index == 1) return;
    Widget screen;
    switch (index) {
      case 0: screen = const StudentHomeScreen(); break;
      case 2: screen = const SessionScreen(); break;
      case 3: screen = const ProfileScreen(); break;
      default: return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      extendBody: true,
      backgroundColor: EasySitColors.appBackground,
      appBar: AppBar(
        toolbarHeight: 72,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        backgroundColor: EasySitColors.appBackground,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: EasySitColors.appBackground,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleSpacing: 20,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: EasySitColors.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: EasySitColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: EasySitColors.divider),
              boxShadow: EasySitColors.cardShadows,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.flash_on_rounded,
                size: 20,
                color: EasySitColors.textPrimary,
              ),
              onPressed: () => _controller.toggleTorch(),
              tooltip: 'Toggle Flash',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: EasySitColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: EasySitColors.divider),
              boxShadow: EasySitColors.cardShadows,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.flip_camera_android_rounded,
                size: 20,
                color: EasySitColors.textPrimary,
              ),
              onPressed: () => _controller.switchCamera(),
              tooltip: 'Switch Camera',
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          if (widget.isActive ?? true)
            MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      bottomNavigationBar: widget.isTab
          ? null
          : AppBottomNav(
              currentIndex: 1,
              onTabSelected: _onNavTab,
            ),
    );

    if (widget.isTab) {
      return scaffold;
    }

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
      child: scaffold,
    );
  }
}
