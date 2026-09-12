import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/booking_timer_config.dart';
import 'user_stats_service.dart';

class SeatExpiryService {
  // ============================================================================
  // TIMING CONFIGURATION (REFERENCED FROM CENTRAL BOOKING TIMER CONFIG)
  // ============================================================================
  // Active booking duration in minutes (2 hours = 120 minutes)
  static const int bookedDurationMinutes =
      BookingTimerConfig.activeBookingDurationMinutes;

  // Pending reservation duration in minutes (20 minutes)
  static const int pendingDurationMinutes =
      BookingTimerConfig.pendingReservationDurationMinutes;

  // Warning notification time in minutes (2 minutes)
  static const int warningNotificationMinutes =
      BookingTimerConfig.warningNotificationMinutes;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// REAL-TIME CHECK: Returns true if seat status is 'booked' or 'pending'
  /// but its allotted duration has expired based on saved Firestore timestamp.
  static bool isSeatExpired(Map<String, dynamic>? seatData) {
    if (seatData == null) return false;
    final String status = seatData['status']?.toString() ?? 'available';
    if (status == 'available') return false;

    final exp = getExpirationTime(seatData);
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// Returns 'available' if the seat is expired or currently marked available;
  /// otherwise returns its current status ('booked' or 'pending').
  static String getEffectiveStatus(Map<String, dynamic>? seatData) {
    if (seatData == null) return 'available';
    if (isSeatExpired(seatData)) {
      return 'available';
    }
    return seatData['status']?.toString() ?? 'available';
  }

  /// Calculates the exact expiration DateTime for a booked or pending seat
  /// using the saved booking/reservation timestamp.
  static DateTime? getExpirationTime(Map<String, dynamic>? seatData) {
    if (seatData == null) return null;
    final String status = seatData['status']?.toString() ?? '';

    if (status == 'booked') {
      final bookedAt = seatData['bookedAt'] as Timestamp?;
      if (bookedAt == null) return null;
      return bookedAt.toDate().add(BookingTimerConfig.activeBookingDuration);
    } else if (status == 'pending') {
      final pendingAt = seatData['pendingAt'] as Timestamp?;
      if (pendingAt == null) return null;
      return pendingAt.toDate().add(BookingTimerConfig.pendingReservationDuration);
    }

    return null;
  }

  /// Returns remaining duration in seconds based on the saved timestamp.
  /// Returns 0 if expired or not active.
  static int getRemainingSeconds(Map<String, dynamic>? seatData) {
    final exp = getExpirationTime(seatData);
    if (exp == null) return 0;
    final diff = exp.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  static final Set<String> _inFlightReleases = {};

  /// SEAT-RELEASE LOGIC:
  /// Updates Firestore seat document to 'available', deletes booking fields,
  /// and saves the student's completed session study statistics.
  static Future<bool> releaseExpiredSeatIfNeeded(
    String seatId,
    Map<String, dynamic>? seatData,
  ) async {
    if (seatId.isEmpty || seatData == null) return false;
    if (!isSeatExpired(seatData)) return false;
    if (_inFlightReleases.contains(seatId)) return false;
    _inFlightReleases.add(seatId);

    try {
      // Re-fetch fresh document from Firestore to ensure we never release a newly booked seat
      final freshSnap = await _firestore.collection('seats').doc(seatId).get();
      if (!freshSnap.exists) return false;
      final freshData = freshSnap.data() as Map<String, dynamic>;
      if (!isSeatExpired(freshData)) return false;

      final String status = freshData['status']?.toString() ?? '';
      final String? bookedBy = freshData['bookedBy'] as String?;
      final Timestamp? bookedAt = freshData['bookedAt'] as Timestamp?;

      if (status == 'booked' && bookedBy != null && bookedBy.isNotEmpty) {
        // Record completed study stats for the user whose session ended
        await UserStatsService.recordCompletedSession(
          userId: bookedBy,
          seatId: seatId,
          bookedAt: bookedAt?.toDate(),
          fallbackMinutes: bookedDurationMinutes,
        );
      }

      // Reset seat in Firestore back to available so all users see it immediately
      await _firestore.collection('seats').doc(seatId).update({
        'status': 'available',
        'bookedBy': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });

      return true;
    } catch (_) {
      return false;
    } finally {
      _inFlightReleases.remove(seatId);
    }
  }

  /// GLOBAL SWEEP (SEAT-RELEASE LOGIC):
  /// Runs across all booked and pending seats in Firestore.
  /// Releases any expired seat regardless of whether the user who booked it is online.
  static Future<int> releaseAllExpiredSeatsGlobal() async {
    try {
      int releasedCount = 0;

      // Check all booked seats
      final bookedSnap = await _firestore
          .collection('seats')
          .where('status', isEqualTo: 'booked')
          .get();

      for (final doc in bookedSnap.docs) {
        final data = doc.data();
        if (isSeatExpired(data)) {
          final success = await releaseExpiredSeatIfNeeded(doc.id, data);
          if (success) releasedCount++;
        }
      }

      // Check all pending seats
      final pendingSnap = await _firestore
          .collection('seats')
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in pendingSnap.docs) {
        final data = doc.data();
        if (isSeatExpired(data)) {
          final success = await releaseExpiredSeatIfNeeded(doc.id, data);
          if (success) releasedCount++;
        }
      }

      return releasedCount;
    } catch (_) {
      return 0;
    }
  }
}
