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
      final userRef = _firestore.collection('users').doc(userId);
      final DateTime effectiveBookedAt = bookedAt ?? DateTime.now();
      final String sessionKey = '${seatId}_${effectiveBookedAt.millisecondsSinceEpoch}';

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
        List<dynamic> usedSeats = List<dynamic>.from(data['usedSeats'] ?? []);

        sessionsCompleted += 1;
        totalMinutesStudied += durationMinutes;
        if (!usedSeats.contains(seatId)) {
          usedSeats.add(seatId);
        }

        double hoursStudied = double.parse((totalMinutesStudied / 60.0).toStringAsFixed(1));

        tx.set(userRef, {
          'sessionsCompleted': sessionsCompleted,
          'totalMinutesStudied': totalMinutesStudied,
          'hoursStudied': hoursStudied,
          'differentSeatsUsed': usedSeats.length,
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
      final userRef = _firestore.collection('users').doc(userId);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? {};

        List<dynamic> usedSeats = List<dynamic>.from(data['usedSeats'] ?? []);
        if (!usedSeats.contains(seatId)) {
          usedSeats.add(seatId);
          tx.set(userRef, {
            'usedSeats': usedSeats,
            'differentSeatsUsed': usedSeats.length,
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('UserStatsService: Error recording booked seat: $e');
    }
  }
}
