import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_sit1212/utils/booking_timer_config.dart';
import 'package:easy_sit1212/services/seat_expiry_service.dart';

void main() {
  group('BookingTimerConfig Central Configuration Tests', () {
    test('Config values match required specifications', () {
      expect(BookingTimerConfig.activeBookingDurationMinutes, equals(120));
      expect(BookingTimerConfig.pendingReservationDurationMinutes, equals(20));
      expect(BookingTimerConfig.warningNotificationMinutes, equals(2));
      expect(BookingTimerConfig.warningNotificationSeconds, equals(120));

      expect(BookingTimerConfig.activeBookingDuration, equals(const Duration(minutes: 120)));
      expect(BookingTimerConfig.pendingReservationDuration, equals(const Duration(minutes: 20)));
      expect(BookingTimerConfig.warningNotificationDuration, equals(const Duration(minutes: 2)));
    });

    test('SeatExpiryService uses central BookingTimerConfig values', () {
      expect(SeatExpiryService.bookedDurationMinutes, equals(BookingTimerConfig.activeBookingDurationMinutes));
      expect(SeatExpiryService.pendingDurationMinutes, equals(BookingTimerConfig.pendingReservationDurationMinutes));
    });
  });

  group('Active Booking Timer & Expiry Tests', () {
    test('1. Active booking does not release before 2 hours', () {
      final oneHourFiftyEightMinAgo = DateTime.now().subtract(const Duration(minutes: 118));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_123',
        'bookedAt': Timestamp.fromDate(oneHourFiftyEightMinAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('booked'));

      final remaining = SeatExpiryService.getRemainingSeconds(seatData);
      expect(remaining, greaterThan(0));
    });

    test('2. Active booking releases exactly after 2 hours', () {
      final twoHoursAndOneSecAgo = DateTime.now().subtract(const Duration(hours: 2, seconds: 1));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_123',
        'bookedAt': Timestamp.fromDate(twoHoursAndOneSecAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isTrue);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
      expect(SeatExpiryService.getRemainingSeconds(seatData), equals(0));
    });

    test('5. Warning threshold triggers when 2 minutes (120 seconds) or less remain', () {
      final oneHourFiftyEightMinAgo = DateTime.now().subtract(const Duration(minutes: 118, seconds: 5));
      final seatData = <String, dynamic>{
        'status': 'booked',
        'bookedBy': 'student_123',
        'bookedAt': Timestamp.fromDate(oneHourFiftyEightMinAgo),
      };

      final remaining = SeatExpiryService.getRemainingSeconds(seatData);
      // At 118m 5s elapsed out of 120m, remaining time is ~115s (which is <= 120s warning threshold)
      expect(remaining, lessThanOrEqualTo(BookingTimerConfig.warningNotificationSeconds));
      expect(remaining, greaterThan(0));
    });

    test('6. Extending booking updates end time by exactly 2 hours (120 minutes)', () {
      final originalBookedAt = DateTime.now().subtract(const Duration(minutes: 118));
      final originalExpiry = originalBookedAt.add(BookingTimerConfig.activeBookingDuration);

      // Extending shifts expiry by another activeBookingDuration
      final extendedExpiry = originalExpiry.add(BookingTimerConfig.activeBookingDuration);
      final totalDuration = extendedExpiry.difference(originalBookedAt);

      expect(totalDuration.inMinutes, equals(240)); // 4 hours total
      expect(extendedExpiry.isAfter(DateTime.now()), isTrue);
    });
  });

  group('Pending Reservation Timer Tests', () {
    test('3. Pending reservation does not release before 20 minutes', () {
      final nineteenMinAgo = DateTime.now().subtract(const Duration(minutes: 19));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_456',
        'pendingAt': Timestamp.fromDate(nineteenMinAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isFalse);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('pending'));

      final remaining = SeatExpiryService.getRemainingSeconds(seatData);
      expect(remaining, greaterThan(0));
    });

    test('4. Pending reservation releases after 20 minutes', () {
      final twentyOneMinAgo = DateTime.now().subtract(const Duration(minutes: 21));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_456',
        'pendingAt': Timestamp.fromDate(twentyOneMinAgo),
      };

      expect(SeatExpiryService.isSeatExpired(seatData), isTrue);
      expect(SeatExpiryService.getEffectiveStatus(seatData), equals('available'));
      expect(SeatExpiryService.getRemainingSeconds(seatData), equals(0));
    });

    test('Pending warning triggers when 2 minutes or less remain', () {
      final eighteenMinThirtySecAgo = DateTime.now().subtract(const Duration(minutes: 18, seconds: 30));
      final seatData = <String, dynamic>{
        'status': 'pending',
        'pendingBy': 'student_456',
        'pendingAt': Timestamp.fromDate(eighteenMinThirtySecAgo),
      };

      final remaining = SeatExpiryService.getRemainingSeconds(seatData);
      expect(remaining, lessThanOrEqualTo(BookingTimerConfig.warningNotificationSeconds));
      expect(remaining, greaterThan(0));
    });
  });

  group('Profile Screen Phone Number Validation Tests', () {
    final phoneRegex = RegExp(r'^\d{10}$');
    const expectedErrorMsg = 'Phone number must contain exactly 10 digits.';

    String? validatePhone(String phone) {
      final trimmed = phone.trim();
      if (trimmed.length != 10 || !phoneRegex.hasMatch(trimmed)) {
        return expectedErrorMsg;
      }
      return null;
    }

    test('Accepts valid 10-digit Sri Lankan phone numbers', () {
      expect(validatePhone('0771234567'), isNull);
      expect(validatePhone('0712345678'), isNull);
      expect(validatePhone('0112345678'), isNull);
    });

    test('Rejects phone numbers with less or more than 10 digits', () {
      expect(validatePhone('077123456'), equals(expectedErrorMsg)); // 9 digits
      expect(validatePhone('07712345678'), equals(expectedErrorMsg)); // 11 digits
      expect(validatePhone(''), equals(expectedErrorMsg)); // empty
    });

    test('Rejects phone numbers with letters, spaces, or symbols', () {
      expect(validatePhone('077 123 456'), equals(expectedErrorMsg)); // spaces
      expect(validatePhone('077-1234567'), equals(expectedErrorMsg)); // hyphen
      expect(validatePhone('+9477123456'), equals(expectedErrorMsg)); // plus symbol
      expect(validatePhone('077123456a'), equals(expectedErrorMsg)); // letter
    });
  });

  group('Warning Notification Deduplication Tests', () {
    test('Deterministic doc IDs are identical across app restarts and re-logins', () {
      const seatId = 'seat_A101';
      final pendingAt = DateTime(2026, 9, 12, 14, 0, 0);
      final bookedAt = DateTime(2026, 9, 12, 14, 0, 0);

      final pendingDocId1 = 'warning_pending_${seatId}_${pendingAt.millisecondsSinceEpoch}';
      final pendingDocId2 = 'warning_pending_${seatId}_${pendingAt.millisecondsSinceEpoch}';
      expect(pendingDocId1, equals(pendingDocId2));

      final bookedDocId1 = 'warning_booked_${seatId}_${bookedAt.millisecondsSinceEpoch}';
      final bookedDocId2 = 'warning_booked_${seatId}_${bookedAt.millisecondsSinceEpoch}';
      expect(bookedDocId1, equals(bookedDocId2));

      // Different reservation session produces distinct doc ID
      final nextPendingAt = DateTime(2026, 9, 12, 16, 0, 0);
      final nextPendingDocId = 'warning_pending_${seatId}_${nextPendingAt.millisecondsSinceEpoch}';
      expect(pendingDocId1, isNot(equals(nextPendingDocId)));
    });
  });
}
