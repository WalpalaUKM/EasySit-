import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User Statistics Calculation & Deduplication Tests', () {
    test('Using same seat two different times counts as 1 different seat used', () {
      final List<dynamic> usedSeatsRaw = ['seat_A', 'SEAT:seat_A', 'seat_A '];

      final uniqueSeats = usedSeatsRaw
          .map((e) => e.toString().replaceFirst('SEAT:', '').trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      expect(uniqueSeats.length, 1);
      expect(uniqueSeats, contains('seat_A'));
    });

    test('Using multiple different seats counts distinct seats correctly', () {
      final List<dynamic> usedSeatsRaw = [
        'seat_A',
        'seat_B',
        'seat_A',
        'SEAT:seat_B',
        'seat_C',
        'SEAT:seat_A',
      ];

      final uniqueSeats = usedSeatsRaw
          .map((e) => e.toString().replaceFirst('SEAT:', '').trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      expect(uniqueSeats.length, 3);
      expect(uniqueSeats, containsAll(['seat_A', 'seat_B', 'seat_C']));
    });

    test('Hours studied calculation formats whole and decimal numbers properly', () {
      String formatHours(int totalMinutes, num hoursNum) {
        num val = totalMinutes > 0 ? (totalMinutes / 60.0) : hoursNum;
        if (val <= 0) return '0';
        if (val == val.roundToDouble()) {
          return val.toInt().toString();
        }
        return val.toStringAsFixed(1);
      }

      expect(formatHours(0, 0), '0');
      expect(formatHours(60, 1.0), '1');
      expect(formatHours(120, 2.0), '2');
      expect(formatHours(30, 0.5), '0.5');
      expect(formatHours(90, 1.5), '1.5');
      expect(formatHours(10, 0.2), '0.2');
    });
  });
}
