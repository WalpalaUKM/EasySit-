import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/utils/greeting_helper.dart';

void main() {
  group('GreetingHelper Sri Lanka Time Boundaries (Asia/Colombo, UTC+05:30)', () {
    // Helper to construct a UTC DateTime that corresponds to a specific Sri Lanka local time
    DateTime createUtcForSriLankaTime({required int hour, required int minute, int second = 0}) {
      // Sri Lanka is UTC+05:30.
      // So UTC = Sri Lanka Time - 05:30
      final slDate = DateTime.utc(2026, 9, 10, hour, minute, second);
      return slDate.subtract(const Duration(hours: 5, minutes: 30));
    }

    test('00:00 - Good Night (start of midnight range)', () {
      final utc = createUtcForSriLankaTime(hour: 0, minute: 0);
      expect(GreetingHelper.getGreeting(utc), equals('Good Night'));
    });

    test('00:59 - Good Night (end of midnight range)', () {
      final utc = createUtcForSriLankaTime(hour: 0, minute: 59, second: 59);
      expect(GreetingHelper.getGreeting(utc), equals('Good Night'));
    });

    test('01:00 - Good Morning (start of morning range)', () {
      final utc = createUtcForSriLankaTime(hour: 1, minute: 0);
      expect(GreetingHelper.getGreeting(utc), equals('Good Morning'));
    });

    test('08:30 - Good Morning (mid-morning)', () {
      final utc = createUtcForSriLankaTime(hour: 8, minute: 30);
      expect(GreetingHelper.getGreeting(utc), equals('Good Morning'));
    });

    test('11:59 - Good Morning (end of morning range)', () {
      final utc = createUtcForSriLankaTime(hour: 11, minute: 59, second: 59);
      expect(GreetingHelper.getGreeting(utc), equals('Good Morning'));
    });

    test('12:00 - Good Afternoon (start of afternoon range)', () {
      final utc = createUtcForSriLankaTime(hour: 12, minute: 0);
      expect(GreetingHelper.getGreeting(utc), equals('Good Afternoon'));
    });

    test('15:15 - Good Afternoon (mid-afternoon)', () {
      final utc = createUtcForSriLankaTime(hour: 15, minute: 15);
      expect(GreetingHelper.getGreeting(utc), equals('Good Afternoon'));
    });

    test('16:59 - Good Afternoon (end of afternoon range)', () {
      final utc = createUtcForSriLankaTime(hour: 16, minute: 59, second: 59);
      expect(GreetingHelper.getGreeting(utc), equals('Good Afternoon'));
    });

    test('17:00 - Good Evening (start of evening range)', () {
      final utc = createUtcForSriLankaTime(hour: 17, minute: 0);
      expect(GreetingHelper.getGreeting(utc), equals('Good Evening'));
    });

    test('19:45 - Good Evening (mid-evening)', () {
      final utc = createUtcForSriLankaTime(hour: 19, minute: 45);
      expect(GreetingHelper.getGreeting(utc), equals('Good Evening'));
    });

    test('20:59 - Good Evening (end of evening range)', () {
      final utc = createUtcForSriLankaTime(hour: 20, minute: 59, second: 59);
      expect(GreetingHelper.getGreeting(utc), equals('Good Evening'));
    });

    test('21:00 - Good Night (start of night range)', () {
      final utc = createUtcForSriLankaTime(hour: 21, minute: 0);
      expect(GreetingHelper.getGreeting(utc), equals('Good Night'));
    });

    test('23:59 - Good Night (end of day night range)', () {
      final utc = createUtcForSriLankaTime(hour: 23, minute: 59, second: 59);
      expect(GreetingHelper.getGreeting(utc), equals('Good Night'));
    });

    test('Device timezone independence check', () {
      // Test with custom local DateTime (simulating non-UTC / non-SL device)
      final customTime = DateTime.parse('2026-09-10T14:30:00Z'); // 14:30 UTC -> 20:00 SL time
      expect(GreetingHelper.getGreeting(customTime), equals('Good Evening'));

      final nightTime = DateTime.parse('2026-09-10T18:00:00Z'); // 18:00 UTC -> 23:30 SL time
      expect(GreetingHelper.getGreeting(nightTime), equals('Good Night'));

      final morningTime = DateTime.parse('2026-09-10T02:00:00Z'); // 02:00 UTC -> 07:30 SL time
      expect(GreetingHelper.getGreeting(morningTime), equals('Good Morning'));
    });
  });
}
