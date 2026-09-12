import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../navigator_key.dart';
import '../widgets/expiry_dialog.dart';
import '../widgets/session_extended_dialog.dart';
import 'notification_service.dart';
import 'user_stats_service.dart';

class SessionWatcher {
  static Timer? _timer;
  static Timer? _countdownTimer;
  static bool _dialogShowing = false;
  static String? _currentSeatId;
  static final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(0);
  static final Set<String> _bookedNotifSent = {};
  static final Set<String> _pendingNotifSent = {};
  static DateTime? _lastKnownBookedAt;

  // ============================================================================
  // BACKGROUND REAL-TIME SESSION WATCHER (INTERVALS & TIMING UNITS)
  // ============================================================================
  /// Starts the background periodic timer.
  /// Unit: Seconds. Runs every 3 seconds (const Duration(seconds: 3)) to check
  /// active user bookings and pending reservations in Firestore.
  /// How to change safely: Modify Duration(seconds: 3) to e.g. 5 seconds if less frequency is desired.
  static void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _dialogShowing = false;
    _currentSeatId = null;
    _bookedNotifSent.clear();
    _pendingNotifSent.clear();
    _lastKnownBookedAt = null;
  }

  /// Core background validation function for the currently logged-in student.
  static Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      // Query currently active booked seat for this student
      final bookedSeats = await FirebaseFirestore.instance
          .collection('seats')
          .where('bookedBy', isEqualTo: user.uid)
          .get();

      for (var doc in bookedSeats.docs) {
        final data = doc.data();
        final bookedAt = data['bookedAt'] as Timestamp?;
        if (bookedAt == null) continue;

        // [BOOKED SESSION DURATION]: 2 hours (120 minutes) (unit: minutes).
        // How to change safely: Change Duration(hours: 2) to match SeatExpiryService.bookedDurationMinutes.
        final expiresAt = bookedAt.toDate().add(const Duration(hours: 2));
        final secs = expiresAt.difference(now).inSeconds; // unit: seconds

        if (_lastKnownBookedAt != bookedAt.toDate()) {
          _bookedNotifSent.clear();
          _lastKnownBookedAt = bookedAt.toDate();
        }

        // [EXPIRY WARNING NOTIFICATION]:
        // Threshold: 600 seconds (unit: seconds, 10 minutes before session ends).
        // Sends an in-app notification when 10 minutes remain before seat release.
        if (secs <= 600 && secs > 0 && !_bookedNotifSent.contains(doc.id)) {
          _bookedNotifSent.add(doc.id);
          await FirebaseFirestore.instance.collection('notifications').add({
            'title': 'Session Expiring',
            'message':
                'Your session at ${data['buildingName'] ?? ''}, ${data['roomName'] ?? ''} (Seat ${data['seatNumber']?.toString() ?? doc.id}) will expire in 10 minutes.',
            'timestamp': FieldValue.serverTimestamp(),
            'userId': user.uid,
          });
        }

        // [EXPIRY WARNING DIALOG POPUP]:
        // Threshold: 600 seconds (unit: seconds, 10 minutes before session ends).
        // Displays the countdown popup asking student to Extend (+2h) or Release seat.
        if (secs <= 600 && secs > 0 && !_dialogShowing) {
          _dialogShowing = true;
          _currentSeatId = doc.id;
          _showDialog(
            doc.id,
            data,
            expiresAt,
            data['seatNumber']?.toString() ?? doc.id,
            data['buildingName'] ?? '',
            data['roomName'] ?? '',
          );
        }

        // [AUTO-RELEASE ON SESSION EXPIRY]:
        // Triggered when remaining time drops to 0 seconds or below.
        // Saves student study statistics and resets seat to available.
        if (secs <= 0 && _dialogShowing && _currentSeatId == doc.id) {
          _dialogShowing = false;
          _currentSeatId = null;
          _countdownTimer?.cancel();
          UserStatsService.recordCompletedSession(
            userId: user.uid,
            seatId: doc.id,
            bookedAt: (data['bookedAt'] as Timestamp?)?.toDate(),
            fallbackMinutes: 120,
          );
          _releaseSeat(doc.id);
        }
      }

      // ========================================================================
      // PENDING RESERVATION CHECK (GRACE PERIOD)
      // ========================================================================
      final pendingSeats = await FirebaseFirestore.instance
          .collection('seats')
          .where('pendingBy', isEqualTo: user.uid)
          .get();

      if (pendingSeats.docs.isEmpty) {
        _pendingNotifSent.clear();
      }

      for (var doc in pendingSeats.docs) {
        final data = doc.data();
        final pendingAt = data['pendingAt'] as Timestamp?;
        if (pendingAt == null) continue;

        // [PENDING RESERVATION DURATION]: 20 minutes (unit: minutes).
        // How to change safely: Change Duration(minutes: 20) to match SeatExpiryService.pendingDurationMinutes.
        final expiresAt = pendingAt.toDate().add(const Duration(minutes: 20));
        final secs = expiresAt.difference(now).inSeconds; // unit: seconds

        // [PENDING WARNING NOTIFICATION]:
        // Threshold: 120 seconds (unit: seconds, 2 minutes before reservation expires).
        // Alerts student to scan QR code before grace period runs out.
        if (secs <= 120 && secs > 0 && !_pendingNotifSent.contains(doc.id)) {
          _pendingNotifSent.add(doc.id);
          await FirebaseFirestore.instance.collection('notifications').add({
            'title': 'Reservation Expiring',
            'message':
                'Your pending reservation for Seat ${data['seatNumber']?.toString() ?? doc.id} will expire in 2 minutes. Please scan the QR code to confirm.',
            'timestamp': FieldValue.serverTimestamp(),
            'userId': user.uid,
          });
        }

        // [AUTO-RELEASE ON PENDING EXPIRY]:
        // Automatically cancels pending reservation when remaining seconds reach 0.
        if (secs <= 0) {
          _releasePendingSeat(doc.id);
        }
      }
    } catch (_) {}
  }

  static void _showDialog(
    String seatId,
    Map<String, dynamic> data,
    DateTime expiresAt,
    String seatNumber,
    String buildingName,
    String roomName,
  ) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    int remainingSecs = expiresAt.difference(DateTime.now()).inSeconds;
    if (remainingSecs <= 0) {
      _releaseSeat(seatId);
      return;
    }

    _countdownNotifier.value = remainingSecs;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      int secs = expiresAt.difference(DateTime.now()).inSeconds;
      _countdownNotifier.value = secs;
      if (secs <= 0) {
        timer.cancel();
        if (_dialogShowing) {
          _dialogShowing = false;
          _currentSeatId = null;
          _releaseSeat(seatId);
        }
      }
    });

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExpiryDialog(
        seatNumber: seatNumber,
        buildingName: buildingName,
        roomName: roomName,
        countdownNotifier: _countdownNotifier,
      ),
    ).then((result) {
      _countdownTimer?.cancel();
      _dialogShowing = false;
      _currentSeatId = null;

      if (result == true) {
        _extendSeat(seatId);
      } else if (result == false) {
        _releaseSeat(seatId);
      } else {
        _releaseSeat(seatId);
      }
    });
  }

  // ============================================================================
  // SESSION EXTENSION & SEAT-RELEASE LOGIC
  // ============================================================================
  /// [SESSION EXTENSION LOGIC]:
  /// Extends the active study session by 2 hours (unit: hours / minutes).
  /// Calculation: Sets bookedAt = now, so when (bookedAt + 2 hours) is evaluated,
  /// the new expiration is now + 2 hours.
  /// How to change safely: Change `effectiveBookedAt` and message string to desired extension.
  static Future<void> _extendSeat(String seatId) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      final now = DateTime.now();
      // Set bookedAt so that (bookedAt + 2 hours) = now + 2 hours
      final effectiveBookedAt = now;
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'bookedAt': Timestamp.fromDate(effectiveBookedAt),
      });
      if (user != null) {
        await NotificationService.clearUserNotifications(user.uid);
        await FirebaseFirestore.instance.collection('notifications').add({
          'title': 'Session Extended',
          'message': 'Your session has been successfully extended by 2 hours.',
          'timestamp': FieldValue.serverTimestamp(),
          'userId': user.uid,
        });
      }

      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        SessionExtendedDialog.show(context, 120);
      }
    } catch (_) {}
  }

  /// [SEAT-RELEASE LOGIC FOR BOOKED SEATS]:
  /// 1. Records completed study duration into user profile stats.
  /// 2. Updates Firestore seat status to 'available'.
  /// 3. Deletes bookedBy, bookedAt, pendingBy, pendingAt fields.
  /// 4. Cleans up pending notifications.
  static Future<void> _releaseSeat(String seatId) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user != null) {
        DocumentSnapshot seatSnap = await FirebaseFirestore.instance.collection('seats').doc(seatId).get();
        if (seatSnap.exists) {
          final sData = seatSnap.data() as Map<String, dynamic>?;
          if (sData?['status'] == 'booked') {
            UserStatsService.recordCompletedSession(
              userId: user.uid,
              seatId: seatId,
              bookedAt: (sData?['bookedAt'] as Timestamp?)?.toDate(),
              fallbackMinutes: 120,
            );
          }
        }
      }
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'status': 'available',
        'bookedBy': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });
      if (user != null) {
        await NotificationService.clearUserNotifications(user.uid);
      }
    } catch (_) {}
  }

  /// [SEAT-RELEASE LOGIC FOR PENDING RESERVATIONS]:
  /// Resets pending reservation back to 'available' when 10-minute grace period expires without QR scan.
  static Future<void> _releasePendingSeat(String seatId) async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'status': 'available',
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });
      if (user != null) {
        await NotificationService.clearUserNotifications(user.uid, title: 'Reservation Expiring');
      }
    } catch (_) {}
  }
}
