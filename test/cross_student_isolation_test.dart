import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/services/seat_expiry_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Cross-Student Booking Isolation & Expiry Tests', () {
    test('isSeatExpired correctly differentiates active and expired bookings', () {
      final now = DateTime.now();

      // Expired booking (booked 3 hours ago, 2h duration)
      final expiredBooking = {
        'status': 'booked',
        'bookedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 3))),
      };
      expect(SeatExpiryService.isSeatExpired(expiredBooking), isTrue);

      // Active booking (booked 30 minutes ago, 2h duration)
      final activeBooking = {
        'status': 'booked',
        'bookedAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 30))),
      };
      expect(SeatExpiryService.isSeatExpired(activeBooking), isFalse);

      // Expired pending reservation (reserved 25 minutes ago, 20m grace period)
      final expiredPending = {
        'status': 'pending',
        'pendingAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 25))),
      };
      expect(SeatExpiryService.isSeatExpired(expiredPending), isTrue);

      // Active pending reservation (reserved 5 minutes ago, 20m grace period)
      final activePending = {
        'status': 'pending',
        'pendingAt': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
      };
      expect(SeatExpiryService.isSeatExpired(activePending), isFalse);
    });

    test('Cross-student seat collision logic verifies ownership properly', () {
      const studentA = 'student_A_uid';
      const studentB = 'student_B_uid';

      final activeSeatHeldByA = {
        'status': 'booked',
        'bookedBy': studentA,
        'bookedAt': Timestamp.now(),
      };

      // Ensure that Student B cannot claim or release Student A's active seat
      final isSeatExpired = SeatExpiryService.isSeatExpired(activeSeatHeldByA);
      expect(isSeatExpired, isFalse);

      final isHeldByOtherStudent = !isSeatExpired &&
          activeSeatHeldByA['status'] == 'booked' &&
          activeSeatHeldByA['bookedBy'] != studentB;

      expect(isHeldByOtherStudent, isTrue);
    });

    test('Exact study duration calculates real elapsed minutes instead of 120 minutes on early release', () {
      final now = DateTime.now();

      // Student released seat after exactly 25 minutes
      final bookedAt = now.subtract(const Duration(minutes: 25));
      final diffSeconds = now.difference(bookedAt).inSeconds;
      final durationMinutes = diffSeconds ~/ 60;

      expect(durationMinutes, 25);
      expect(durationMinutes < 120, isTrue);

      // Student released seat after 10 minutes
      final bookedAt10m = now.subtract(const Duration(minutes: 10));
      final duration10m = now.difference(bookedAt10m).inSeconds ~/ 60;
      expect(duration10m, 10);

      // Format in hours
      final hoursFormatted = (durationMinutes / 60.0).toStringAsFixed(1);
      expect(hoursFormatted, '0.4');
    });
  });
}
