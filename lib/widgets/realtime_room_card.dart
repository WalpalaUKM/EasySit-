import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/seat_expiry_service.dart';
import '../screens/seat_booking_screen.dart';
import '../utils/app_page_route.dart';
import '../utils/app_colors.dart';

class RealtimeRoomCard extends StatefulWidget {
  final Map<String, dynamic> room;
  final Map<String, dynamic> theme;
  final bool showBorder;
  final bool showSeatsWord;
  final List<BoxShadow>? customShadow;
  final Stream<QuerySnapshot>? seatStream;

  const RealtimeRoomCard({
    super.key,
    required this.room,
    required this.theme,
    this.showBorder = false,
    this.showSeatsWord = true,
    this.customShadow,
    this.seatStream,
  });

  @override
  State<RealtimeRoomCard> createState() => _RealtimeRoomCardState();
}

class _RealtimeRoomCardState extends State<RealtimeRoomCard> {
  late Stream<QuerySnapshot> _seatStream;
  String? _currentRoomId;
  Timer? _localExpiryTimer;
  static final Set<String> _releasingSeatIds = {};

  @override
  void initState() {
    super.initState();
    _currentRoomId = widget.room['roomId'] ?? '';
    _initSeatStream();
  }

  void _initSeatStream() {
    _seatStream = widget.seatStream ??
        FirebaseFirestore.instance
            .collection('seats')
            .where('roomId', isEqualTo: _currentRoomId)
            .snapshots();
  }

  @override
  void didUpdateWidget(covariant RealtimeRoomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newRoomId = widget.room['roomId'] ?? '';
    if (newRoomId != _currentRoomId) {
      _currentRoomId = newRoomId;
      _localExpiryTimer?.cancel();
      _initSeatStream();
    }
  }

  @override
  void dispose() {
    _localExpiryTimer?.cancel();
    super.dispose();
  }

  void _scheduleExpiryCheck(DateTime expiresAt) {
    final now = DateTime.now();
    if (expiresAt.isAfter(now)) {
      final remaining = expiresAt.difference(now) + const Duration(milliseconds: 200);
      _localExpiryTimer?.cancel();
      _localExpiryTimer = Timer(remaining, () {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final theme = widget.theme;
    final String roomId = room['roomId'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _seatStream,
      builder: (context, seatSnapshot) {
        int availableSeats = 0;
        DateTime? nextExpiry;
        List<Map<String, dynamic>> toRelease = [];

        if (seatSnapshot.hasData) {
          final now = DateTime.now();
          for (var d in seatSnapshot.data!.docs) {
            var data = d.data() as Map<String, dynamic>;
            final isExpired = SeatExpiryService.isSeatExpired(data);
            final status = data['status']?.toString() ?? 'available';

            if (isExpired) {
              availableSeats++;
              if (!_releasingSeatIds.contains(d.id)) {
                _releasingSeatIds.add(d.id);
                toRelease.add({'id': d.id, 'data': data});
              }
            } else if (status == 'available') {
              availableSeats++;
            } else {
              // Seat is currently booked or pending; track its expiration
              final exp = SeatExpiryService.getExpirationTime(data);
              if (exp != null && exp.isAfter(now)) {
                if (nextExpiry == null || exp.isBefore(nextExpiry)) {
                  nextExpiry = exp;
                }
              }
            }
          }
        } else {
          // Fallback to initial availableSeats count if present in room map
          availableSeats = (room['availableSeats'] as int?) ?? 0;
        }

        if (nextExpiry != null) {
          _scheduleExpiryCheck(nextExpiry);
        }

        if (toRelease.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            for (var item in toRelease) {
              final seatId = item['id'] as String;
              final data = item['data'] as Map<String, dynamic>;
              await SeatExpiryService.releaseExpiredSeatIfNeeded(seatId, data);
              _releasingSeatIds.remove(seatId);
            }
          });
        }

        final shadows = widget.customShadow ?? EasySitColors.cardShadows;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: EasySitColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: shadows,
            border: widget.showBorder
                ? Border.all(color: EasySitColors.divider)
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (availableSeats > 0) {
                Navigator.push(
                  context,
                  AppPageRoute(
                    builder: (_) => SeatBookingScreen(
                      roomId: roomId,
                      roomName: room['roomName'] ?? 'Room',
                      buildingName: room['buildingName'] ?? '',
                      floorName: room['floorName'] ?? '',
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No seats available in this room'),
                    backgroundColor: EasySitColors.warningFg,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme['color'] ?? EasySitColors.areaOrangeBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      theme['icon'] ?? Icons.apartment_rounded,
                      color: theme['iconColor'] ?? EasySitColors.areaOrangeFg,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room['roomName'] ?? 'Room',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: EasySitColors.mainText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${room['buildingName'] ?? ''} • ${room['floorName'] ?? ''}',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: EasySitColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.showSeatsWord
                                ? '$availableSeats seats'
                                : '$availableSeats',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: widget.showSeatsWord ? 14 : 22,
                              fontWeight: widget.showSeatsWord
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: availableSeats > 0
                                  ? EasySitColors.successFg
                                  : EasySitColors.neutralFg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'available',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: EasySitColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: EasySitColors.secondaryText,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
