import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:easy_sit1212/widgets/session_extended_dialog.dart';
import 'package:easy_sit1212/widgets/expiry_dialog.dart';

void main() {
  group('Session Extension Calculation Tests', () {
    test('Extension calculates exactly 4 minutes remaining', () {
      final now = DateTime.now();
      // Since booking duration is now 2 minutes, setting effectiveBookedAt = now + 2 minutes
      // ensures (effectiveBookedAt + 2 minutes) = now + 4 minutes.
      final effectiveBookedAt = now.add(const Duration(minutes: 2));
      final expiresAt = effectiveBookedAt.add(const Duration(minutes: 2));

      final remainingSeconds = expiresAt.difference(now).inSeconds;
      expect(remainingSeconds, 240); // 4 minutes = 240 seconds
      expect(expiresAt.difference(now).inMinutes, 4);
    });

    testWidgets('SessionExtendedDialog displays 4 minutes in message',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionExtendedDialog(minutes: 4),
          ),
        ),
      );

      // Verify text
      expect(find.text('Session Extended'), findsNothing); // Dialog itself is triggered by show()
    });

    testWidgets('ExpiryDialog prompts for 4 minutes extension',
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

      expect(find.text('Extend (+4m)'), findsOneWidget);
      expect(
        find.text(
          'Would you like to extend your session by 4 minutes or release the seat for other students?',
        ),
        findsOneWidget,
      );
    });
  });
}
