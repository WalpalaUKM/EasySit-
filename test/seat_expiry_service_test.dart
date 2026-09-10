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

    test('Booked seat within 2 minutes is NOT expired and has status booked', () {
      // 1 minute ago
      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_offline_A',
        'bookedAt': Timestamp.fromDate(oneMinuteAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('booked'));
    });

    test('Booked seat past 2 minutes IS expired and has effective status available (student offline)', () {
      // 3 minutes ago
      final threeMinutesAgo = DateTime.now().subtract(const Duration(minutes: 3));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_offline_A',
        'bookedAt': Timestamp.fromDate(threeMinutesAgo),
      };

      // Even though status in Firestore data is 'booked' because student A is offline,
      // SeatExpiryService must detect it as expired and return 'available'.
      expect(SeatExpiryService.isSeatExpired(seatData), isTrue);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
    });

    test('Pending reservation within 10 minutes is NOT expired', () {
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_B',
        'pendingAt': Timestamp.fromDate(fiveMinutesAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('pending'));
    });

    test('Pending reservation past 10 minutes IS expired and releases to available', () {
      final elevenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 11));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_B',
        'pendingAt': Timestamp.fromDate(elevenMinutesAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isTrue);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
    });

    test('Room available seats calculation immediately counts expired seat as available for Student C', () {
      final threeMinutesAgo = DateTime.now().subtract(const Duration(minutes: 3));
      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));

      final roomSeats = [
        {'id': 'seat_1', 'status': 'available'},
        {
          'id': 'seat_2',
          'status': 'booked',
          'bookedBy': 'offline_student',
          'bookedAt': Timestamp.fromDate(threeMinutesAgo), // expired!
        },
        {
          'id': 'seat_3',
          'status': 'booked',
          'bookedBy': 'active_student',
          'bookedAt': Timestamp.fromDate(oneMinuteAgo), // active!
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
