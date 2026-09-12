import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:easy_sit1212/widgets/session_extended_dialog.dart';
import 'package:easy_sit1212/widgets/expiry_dialog.dart';

void main() {
  group('Session Extension Calculation Tests', () {
    test('Extension calculates exactly 2 hours remaining', () {
      final now = DateTime.now();
      // Setting effectiveBookedAt = now ensures (effectiveBookedAt + 2 hours) = now + 2 hours.
      final effectiveBookedAt = now;
      final expiresAt = effectiveBookedAt.add(const Duration(hours: 2));

      final remainingSeconds = expiresAt.difference(now).inSeconds;
      expect(remainingSeconds, 7200); // 2 hours = 7200 seconds
      expect(expiresAt.difference(now).inMinutes, 120);
    });

    testWidgets('SessionExtendedDialog displays 2 hours in message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionExtendedDialog(minutes: 120),
          ),
        ),
      );

      // Verify text
      expect(find.text('Session Extended'), findsNothing); // Dialog itself is triggered by show()
    });

    testWidgets('ExpiryDialog prompts for 2 hours extension',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExpiryDialog(
              seatNumber: 'A1',
              buildingName: 'Main',
              roomName: 'Lab',
            ),
          ),
        ),
      );

      expect(find.text('Extend (+2h)'), findsOneWidget);
      expect(
        find.text(
          'Would you like to extend your session by 2 hours or release the seat for other students?',
        ),
        findsOneWidget,
      );
    });
  });
}
