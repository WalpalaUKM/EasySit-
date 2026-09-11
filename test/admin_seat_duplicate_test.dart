import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/screens/admin_dashboard.dart';

void main() {
  group('Admin Seat Duplicate Validation Tests', () {
    final existingSeats1To10 = List.generate(10, (i) => (i + 1).toString()).toSet();

    test('If seats 1-10 exist, block adding any single seat from 1-10', () {
      for (int i = 1; i <= 10; i++) {
        expect(
          isSeatNumberDuplicate(i.toString(), existingSeats1To10),
          isTrue,
          reason: 'Seat $i should be detected as duplicate',
        );
      }
    });

    test('Allow adding seat 11 when seats 1-10 exist', () {
      expect(isSeatNumberDuplicate('11', existingSeats1To10), isFalse);
      expect(isSeatNumberDuplicate('12', existingSeats1To10), isFalse);
    });

    test('Block bulk ranges that overlap existing seats, such as 8-15', () {
      final seats8To15 = parseBulkSeatInput('8-15', existingSeats1To10);
      expect(seats8To15, isNotNull);
      expect(seats8To15, [8, 9, 10, 11, 12, 13, 14, 15]);

      final hasOverlap = seats8To15!.any((seat) => isSeatNumberDuplicate(seat.toString(), existingSeats1To10));
      expect(hasOverlap, isTrue, reason: 'Range 8-15 overlaps seats 8, 9, 10');
    });

    test('Allow bulk seats 11-20 when seats 1-10 exist', () {
      final seats11To20 = parseBulkSeatInput('11-20', existingSeats1To10);
      expect(seats11To20, isNotNull);
      expect(seats11To20, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);

      final hasOverlap = seats11To20!.any((seat) => isSeatNumberDuplicate(seat.toString(), existingSeats1To10));
      expect(hasOverlap, isFalse, reason: 'Range 11-20 has no overlap with seats 1-10');
    });

    test('Allow adding bulk count 10 when seats 1-10 exist, generating seats 11-20', () {
      final seatsCount10 = parseBulkSeatInput('10', existingSeats1To10);
      expect(seatsCount10, isNotNull);
      expect(seatsCount10, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);

      final hasOverlap = seatsCount10!.any((seat) => isSeatNumberDuplicate(seat.toString(), existingSeats1To10));
      expect(hasOverlap, isFalse);
    });

    test('Bulk count 10 on empty room generates seats 1-10', () {
      final seatsCount10 = parseBulkSeatInput('10', {});
      expect(seatsCount10, isNotNull);
      expect(seatsCount10, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('Invalid range inputs return null', () {
      expect(parseBulkSeatInput('15-8', existingSeats1To10), isNull);
      expect(parseBulkSeatInput('0-5', existingSeats1To10), isNull);
      expect(parseBulkSeatInput('-5', existingSeats1To10), isNull);
      expect(parseBulkSeatInput('abc', existingSeats1To10), isNull);
    });

    test('En-dash and "to" range formats work correctly', () {
      expect(parseBulkSeatInput('8–15', existingSeats1To10), [8, 9, 10, 11, 12, 13, 14, 15]);
      expect(parseBulkSeatInput('11 to 15', existingSeats1To10), [11, 12, 13, 14, 15]);
    });
  });
}
