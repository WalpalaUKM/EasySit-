import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../navigator_key.dart';
import '../utils/booking_timer_config.dart';
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
  /// Unit: Seconds. Runs every 3 seconds to check
  /// active user bookings and pending reservations in Firestore.
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

        // Active booking duration (2 hours = 120 minutes)
        final expiresAt =
            bookedAt.toDate().add(BookingTimerConfig.activeBookingDuration);
        final secs = expiresAt.difference(now).inSeconds; // unit: seconds

        final String sessionKey =
            '${doc.id}_${bookedAt.millisecondsSinceEpoch}';
        if (_lastKnownBookedAt != bookedAt.toDate()) {
          _lastKnownBookedAt = bookedAt.toDate();
        }

        // Warning notification time (last 2 minutes / 120 seconds)
        // Sends an in-app notification once when 2 minutes remain before seat release.
        // Uses deterministic notification doc ID to prevent re-sending if student closes and re-opens app.
        if (secs <= BookingTimerConfig.warningNotificationSeconds &&
            secs > 0 &&
            !_bookedNotifSent.contains(sessionKey)) {
          _bookedNotifSent.add(sessionKey);
          final notifDocId =
              'warning_booked_${doc.id}_${bookedAt.millisecondsSinceEpoch}';
          final notifRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc(notifDocId);
          final notifSnap = await notifRef.get();
          if (!notifSnap.exists) {
            await notifRef.set({
              'title': 'Session Expiring Soon',
              'message':
                  'Your session at ${data['buildingName'] ?? ''}, ${data['roomName'] ?? ''} (Seat ${data['seatNumber']?.toString() ?? doc.id}) will expire in 2 minutes. Would you like to extend your booking?',
              'timestamp': FieldValue.serverTimestamp(),
              'userId': user.uid,
              'seatId': doc.id,
            });
            await NotificationService.showTwoMinuteWarning(
              data['seatNumber']?.toString() ?? doc.id,
              data['buildingName'] ?? '',
              data['roomName'] ?? '',
            );
          }
        }

        // [EXPIRY WARNING DIALOG POPUP]:
        // Displays the countdown popup asking student to Extend (+2h) or Release seat at 2 minutes remaining.
        if (secs <= BookingTimerConfig.warningNotificationSeconds &&
            secs > 0 &&
            !_dialogShowing) {
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
        // Reliably triggers when remaining time drops to 0 seconds or below.
        // Saves student study statistics and resets seat to available.
        if (secs <= 0) {
          if (_dialogShowing && _currentSeatId == doc.id) {
            _dialogShowing = false;
            _currentSeatId = null;
            _countdownTimer?.cancel();
          }
          await UserStatsService.recordCompletedSession(
            userId: user.uid,
            seatId: doc.id,
            bookedAt: (data['bookedAt'] as Timestamp?)?.toDate(),
            fallbackMinutes: BookingTimerConfig.activeBookingDurationMinutes,
          );
          await _releaseSeat(doc.id);
        }
      }

      // ========================================================================
      // PENDING RESERVATION CHECK (GRACE PERIOD: 20 MINUTES)
      // ========================================================================
      final pendingSeats = await FirebaseFirestore.instance
          .collection('seats')
          .where('pendingBy', isEqualTo: user.uid)
          .get();

      for (var doc in pendingSeats.docs) {
        final data = doc.data();
        final pendingAt = data['pendingAt'] as Timestamp?;
        if (pendingAt == null) continue;

        // Pending reservation duration (20 minutes)
        final expiresAt =
            pendingAt.toDate().add(BookingTimerConfig.pendingReservationDuration);
        final secs = expiresAt.difference(now).inSeconds; // unit: seconds

        final String pendingKey =
            '${doc.id}_${pendingAt.millisecondsSinceEpoch}';

        // Warning notification time (last 2 minutes / 120 seconds)
        // Alerts student to scan QR code before grace period runs out.
        // Uses deterministic notification doc ID so it will not re-send if the student closes the app and logs in again within the last 2 minutes.
        if (secs <= BookingTimerConfig.warningNotificationSeconds &&
            secs > 0 &&
            !_pendingNotifSent.contains(pendingKey)) {
          _pendingNotifSent.add(pendingKey);
          final notifDocId =
              'warning_pending_${doc.id}_${pendingAt.millisecondsSinceEpoch}';
          final notifRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc(notifDocId);
          final notifSnap = await notifRef.get();
          if (!notifSnap.exists) {
            await notifRef.set({
              'title': 'Reservation Expiring Soon',
              'message':
                  'Your pending reservation for Seat ${data['seatNumber']?.toString() ?? doc.id} will expire in 2 minutes. Please scan the QR code to confirm.',
              'timestamp': FieldValue.serverTimestamp(),
              'userId': user.uid,
              'seatId': doc.id,
            });
            await NotificationService.showTwoMinuteWarning(
              data['seatNumber']?.toString() ?? doc.id,
              data['buildingName'] ?? '',
              data['roomName'] ?? '',
            );
          }
        }

        // [AUTO-RELEASE ON PENDING EXPIRY]:
        // Automatically cancels pending reservation when remaining seconds reach 0.
        if (secs <= 0) {
          await _releasePendingSeat(doc.id);
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
      _countdownNotifier.value = secs > 0 ? secs : 0;
      if (secs <= 0) {
        timer.cancel();
        if (_dialogShowing) {
          _dialogShowing = false;
          _currentSeatId = null;
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
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
        // User explicitly tapped "Extend (+2h)"
        _extendSeat(seatId);
      } else if (result == false) {
        // User explicitly tapped "Release Seat"
        _releaseSeat(seatId);
      }
      // Note: If result is null (e.g. system dismissed), DO NOT release early!
      // The session continues until the timer reaches 0.
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
        SessionExtendedDialog.show(
          context,
          BookingTimerConfig.activeBookingDurationMinutes,
        );
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
    if (user == null) return;
    try {
      DocumentSnapshot seatSnap = await FirebaseFirestore.instance.collection('seats').doc(seatId).get();
      if (!seatSnap.exists) return;
      final sData = seatSnap.data() as Map<String, dynamic>?;
      if (sData?['bookedBy'] != user.uid) {
        // Seat belongs to another student, do not release
        return;
      }
      if (sData?['status'] == 'booked') {
        UserStatsService.recordCompletedSession(
          userId: user.uid,
          seatId: seatId,
          bookedAt: (sData?['bookedAt'] as Timestamp?)?.toDate(),
          fallbackMinutes: 120,
        );
      }
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'status': 'available',
        'bookedBy': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });
      await NotificationService.clearUserNotifications(user.uid);
    } catch (_) {}
  }

  /// [SEAT-RELEASE LOGIC FOR PENDING RESERVATIONS]:
  /// Resets pending reservation back to 'available' when 10-minute grace period expires without QR scan.
  static Future<void> _releasePendingSeat(String seatId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      DocumentSnapshot seatSnap = await FirebaseFirestore.instance.collection('seats').doc(seatId).get();
      if (!seatSnap.exists) return;
      final sData = seatSnap.data() as Map<String, dynamic>?;
      if (sData?['pendingBy'] != user.uid) {
        // Seat belongs to another student, do not release
        return;
      }
      await FirebaseFirestore.instance.collection('seats').doc(seatId).update({
        'status': 'available',
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });
      await NotificationService.clearUserNotifications(user.uid, title: 'Reservation Expiring');
    } catch (_) {}
  }
}
