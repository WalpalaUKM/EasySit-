import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_sit1212/services/seat_expiry_service.dart';

void main() {
  group('SeatExpiryService Tests', () {
    test('Available seat is not expired and has effective status available', () {
      final seatData = <String, dynamic>{
        'status': 'available',
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
    });

    test('Booked seat within 2 hours is NOT expired and has status booked', () {
      // 60 minutes ago (within 2 hours)
      final sixtyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 60));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_offline_A',
        'bookedAt': Timestamp.fromDate(sixtyMinutesAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('booked'));
    });

    test('Booked seat past 2 hours IS expired and has effective status available (student offline)', () {
      // 125 minutes ago (exceeds 120 minutes / 2 hours)
      final pastTwoHoursAgo = DateTime.now().subtract(const Duration(minutes: 125));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_offline_A',
        'bookedAt': Timestamp.fromDate(pastTwoHoursAgo),
      };

      // Even though status in Firestore data is 'booked' because student A is offline,
      // SeatExpiryService must detect it as expired and return 'available'.
      expect(SeatExpiryService.isSeatExpired(seatData), isTrue);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
    });

    test('Pending reservation within 20 minutes is NOT expired', () {
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_B',
        'pendingAt': Timestamp.fromDate(tenMinutesAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('pending'));
    });

    test('Pending reservation past 20 minutes IS expired and releases to available', () {
      final twentyFiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 25));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_B',
        'pendingAt': Timestamp.fromDate(twentyFiveMinutesAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isTrue);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
    });

    test('Room available seats calculation immediately counts expired seat as available for Student C', () {
      final expiredBookedAgo = DateTime.now().subtract(const Duration(minutes: 130));
      final activeBookedAgo = DateTime.now().subtract(const Duration(minutes: 30));

      final roomSeats = [
        {'id': 'seat_1', 'status': 'available'},
        {
          'id': 'seat_2',
          'status': 'booked',
          'bookedBy': 'offline_student',
          'bookedAt': Timestamp.fromDate(expiredBookedAgo), // expired!
        },
        {
          'id': 'seat_3',
          'status': 'booked',
          'bookedBy': 'active_student',
          'bookedAt': Timestamp.fromDate(activeBookedAgo), // active!
        },
      ];

      // Filter using SeatExpiryService effective status
      final availableCount = roomSeats.where((s) {
        return SeatExpiryService.getEffectiveStatus(s) == 'available';
      }).length;

      // seat_1 (available) + seat_2 (expired booked) = 2 available seats
      expect(availableCount, equals(2));
    });
  });
}
