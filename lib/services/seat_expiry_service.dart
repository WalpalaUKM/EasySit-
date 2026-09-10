import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_stats_service.dart';

class SeatExpiryService {
  static const int bookedDurationMinutes = 2;
  static const int pendingDurationMinutes = 10;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns true if the seat has status 'booked' or 'pending' but its expiration timestamp has elapsed.
  static bool isSeatExpired(Map<String, dynamic>? seatData) {
    if (seatData == null) return false;
    final String status = seatData['status']?.toString() ?? 'available';
    if (status == 'available') return false;

    final now = DateTime.now();

    if (status == 'booked') {
      final bookedAt = seatData['bookedAt'] as Timestamp?;
      if (bookedAt == null) return false;
      final expiresAt = bookedAt.toDate().add(
        const Duration(minutes: bookedDurationMinutes),
      );
      return now.isAfter(expiresAt);
    } else if (status == 'pending') {
      final pendingAt = seatData['pendingAt'] as Timestamp?;
      if (pendingAt == null) return false;
      final expiresAt = pendingAt.toDate().add(
        const Duration(minutes: pendingDurationMinutes),
      );
      return now.isAfter(expiresAt);
    }

    return false;
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

  /// Calculates the exact expiration DateTime for a booked or pending seat.
  static DateTime? getExpirationTime(Map<String, dynamic>? seatData) {
    if (seatData == null) return null;
    final String status = seatData['status']?.toString() ?? '';

    if (status == 'booked') {
      final bookedAt = seatData['bookedAt'] as Timestamp?;
      if (bookedAt == null) return null;
      return bookedAt.toDate().add(
        const Duration(minutes: bookedDurationMinutes),
      );
    } else if (status == 'pending') {
      final pendingAt = seatData['pendingAt'] as Timestamp?;
      if (pendingAt == null) return null;
      return pendingAt.toDate().add(
        const Duration(minutes: pendingDurationMinutes),
      );
    }

    return null;
  }

  static final Set<String> _inFlightReleases = {};

  /// Asynchronously releases an expired seat in Firestore so other online users see the update immediately.
  static Future<bool> releaseExpiredSeatIfNeeded(
    String seatId,
    Map<String, dynamic>? seatData,
  ) async {
    if (seatId.isEmpty || seatData == null) return false;
    if (!isSeatExpired(seatData)) return false;
    if (_inFlightReleases.contains(seatId)) return false;
    _inFlightReleases.add(seatId);

    try {
      final String status = seatData['status']?.toString() ?? '';
      final String? bookedBy = seatData['bookedBy'] as String?;
      final Timestamp? bookedAt = seatData['bookedAt'] as Timestamp?;

      if (status == 'booked' && bookedBy != null && bookedBy.isNotEmpty) {
        // Record completed study stats for the user whose session ended
        await UserStatsService.recordCompletedSession(
          userId: bookedBy,
          seatId: seatId,
          bookedAt: bookedAt?.toDate(),
          fallbackMinutes: bookedDurationMinutes,
        );
      }

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

  /// Global sweep across all booked and pending seats in Firestore.
  /// Releases any expired seat regardless of which user booked it or whether their app is closed.
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
