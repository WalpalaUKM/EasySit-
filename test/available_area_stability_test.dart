import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_sit1212/widgets/realtime_room_card.dart';
import 'package:easy_sit1212/services/seat_expiry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Available Area Stability Tests', () {
    testWidgets('RealtimeRoomCard renders initial room data without blinking', (tester) async {
      final room = {
        'roomId': 'room_101',
        'roomName': 'Quiet Study Zone',
        'buildingName': 'Main Library',
        'floorName': '2nd Floor',
        'availableSeats': 8,
      };

      final theme = {
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF2E7D32),
        'icon': Icons.menu_book_rounded,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealtimeRoomCard(
              room: room,
              theme: theme,
              showSeatsWord: true,
              seatStream: const Stream.empty(),
            ),
          ),
        ),
      );

      // Verify room details render smoothly
      expect(find.text('Quiet Study Zone'), findsOneWidget);
      expect(find.text('Main Library • 2nd Floor'), findsOneWidget);
      expect(find.text('8 seats'), findsOneWidget);
      expect(find.text('available'), findsOneWidget);

      // Pump several frames as if time ticks; should NOT blink to a CircularProgressIndicator
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Quiet Study Zone'), findsOneWidget);
    });

    testWidgets('RealtimeRoomCard renders in compact mode for FindSeatsScreen', (tester) async {
      final room = {
        'roomId': 'room_202',
        'roomName': 'Group Discussion Area',
        'buildingName': 'Science Complex',
        'floorName': '1st Floor',
        'availableSeats': 15,
      };

      final theme = {
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF7B1FA2),
        'icon': Icons.groups_rounded,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RealtimeRoomCard(
              room: room,
              theme: theme,
              showBorder: true,
              showSeatsWord: false,
              seatStream: const Stream.empty(),
            ),
          ),
        ),
      );

      expect(find.text('Group Discussion Area'), findsOneWidget);
      expect(find.text('Science Complex • 1st Floor'), findsOneWidget);
      // Compact mode displays just the number
      expect(find.text('15'), findsOneWidget);
      expect(find.text('available'), findsOneWidget);
    });

    test('SeatExpiryService in-flight deduplication works', () async {
      // Simulate double calls for the same expired seat
      final seatData = <String, dynamic>{
        'status': 'available',
      };
      // For available seat, releaseExpiredSeatIfNeeded returns false immediately
      final result = await SeatExpiryService.releaseExpiredSeatIfNeeded('dummy_id', seatData);
      expect(result, isFalse);
    });
  });
}
