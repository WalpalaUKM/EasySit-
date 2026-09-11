import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserStatsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Records a completed session for the user and updates all three statistics in real time:
  /// 1. sessionsCompleted
  /// 2. hoursStudied / totalMinutesStudied
  /// 3. differentSeatsUsed / usedSeats
  ///
  /// Uses transaction and deduplication key to guarantee exact counting.
  static Future<void> recordCompletedSession({
    required String userId,
    required String seatId,
    DateTime? bookedAt,
    int? fallbackMinutes,
  }) async {
    if (userId.isEmpty || seatId.isEmpty) return;

    try {
      final String cleanSeatId = seatId.replaceFirst('SEAT:', '').trim();
      final userRef = _firestore.collection('users').doc(userId);
      final DateTime effectiveBookedAt = bookedAt ?? DateTime.now();
      final String sessionKey = bookedAt != null
          ? '${cleanSeatId}_${bookedAt.millisecondsSinceEpoch}'
          : '${cleanSeatId}_${effectiveBookedAt.millisecondsSinceEpoch ~/ 10000}';

      // Determine study duration in minutes (minimum 1 minute, default 10 minutes)
      int durationMinutes = fallbackMinutes ?? 10;
      if (bookedAt != null) {
        final diff = DateTime.now().difference(bookedAt).inMinutes;
        if (diff > 0) {
          durationMinutes = diff > 720 ? 10 : diff; // Safeguard against stale dates
        }
      }
      if (durationMinutes <= 0) durationMinutes = 1;

      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? {};

        List<dynamic> completedKeys = List<dynamic>.from(data['completedSessionKeys'] ?? []);
        if (completedKeys.contains(sessionKey)) {
          // Session was already recorded once
          return;
        }

        completedKeys.add(sessionKey);
        // Retain last 100 session keys to keep document lightweight
        if (completedKeys.length > 100) {
          completedKeys = completedKeys.sublist(completedKeys.length - 100);
        }

        int sessionsCompleted = (data['sessionsCompleted'] as num?)?.toInt() ?? 0;
        int totalMinutesStudied = (data['totalMinutesStudied'] as num?)?.toInt() ?? 0;

        // Strictly deduplicate used seats via Set so using the same seat multiple times only counts once
        final Set<String> uniqueSeats = (data['usedSeats'] as List? ?? [])
            .map((e) => e.toString().replaceFirst('SEAT:', '').trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        uniqueSeats.add(cleanSeatId);
        final List<String> usedSeats = uniqueSeats.toList();

        sessionsCompleted += 1;
        totalMinutesStudied += durationMinutes;

        double hoursStudied = double.parse((totalMinutesStudied / 60.0).toStringAsFixed(1));

        tx.set(userRef, {
          'sessionsCompleted': sessionsCompleted,
          'totalMinutesStudied': totalMinutesStudied,
          'hoursStudied': hoursStudied,
          'differentSeatsUsed': uniqueSeats.length,
          'usedSeats': usedSeats,
          'completedSessionKeys': completedKeys,
          'lastSessionCompletedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('UserStatsService: Error recording completed session: $e');
    }
  }

  /// Records seat usage when a seat is booked to ensure differentSeatsUsed is updated.
  static Future<void> recordSeatBooked({
    required String userId,
    required String seatId,
  }) async {
    if (userId.isEmpty || seatId.isEmpty) return;

    try {
      final String cleanSeatId = seatId.replaceFirst('SEAT:', '').trim();
      final userRef = _firestore.collection('users').doc(userId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? {};

        final Set<String> uniqueSeats = (data['usedSeats'] as List? ?? [])
            .map((e) => e.toString().replaceFirst('SEAT:', '').trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        final bool isNewSeat = !uniqueSeats.contains(cleanSeatId);
        uniqueSeats.add(cleanSeatId);
        final List<String> usedSeats = uniqueSeats.toList();

        if (isNewSeat || (data['differentSeatsUsed'] as num?)?.toInt() != uniqueSeats.length) {
          tx.set(userRef, {
            'usedSeats': usedSeats,
            'differentSeatsUsed': uniqueSeats.length,
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('UserStatsService: Error recording booked seat: $e');
    }
  }
}
