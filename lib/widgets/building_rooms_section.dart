import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'realtime_room_card.dart';

class BuildingRoomsSection extends StatefulWidget {
  final String buildingId;
  final String buildingName;
  final Map<String, dynamic> Function(String) getAreaTheme;

  const BuildingRoomsSection({
    super.key,
    required this.buildingId,
    required this.buildingName,
    required this.getAreaTheme,
  });

  @override
  State<BuildingRoomsSection> createState() => _BuildingRoomsSectionState();
}

class _BuildingRoomsSectionState extends State<BuildingRoomsSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rooms = [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  void didUpdateWidget(covariant BuildingRoomsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.buildingId != widget.buildingId) {
      _loadRooms();
    }
  }

  Future<void> _loadRooms() async {
    try {
      // First try to load from cache
      QuerySnapshot floorsSnapshot;
      try {
        floorsSnapshot = await _firestore
            .collection('floors')
            .where('buildingId', isEqualTo: widget.buildingId)
            .get(const GetOptions(source: Source.cache));
        if (floorsSnapshot.docs.isEmpty) {
          floorsSnapshot = await _firestore
              .collection('floors')
              .where('buildingId', isEqualTo: widget.buildingId)
              .get();
        }
      } catch (_) {
        floorsSnapshot = await _firestore
            .collection('floors')
            .where('buildingId', isEqualTo: widget.buildingId)
            .get();
      }

      List<Map<String, dynamic>> allRooms = [];
      for (var floorDoc in floorsSnapshot.docs) {
        final floorId = floorDoc.id;
        final floorData = floorDoc.data() as Map<String, dynamic>;
        final floorName = floorData['name'] ?? 'Floor';

        QuerySnapshot roomsSnapshot;
        try {
          roomsSnapshot = await _firestore
              .collection('rooms')
              .where('floorId', isEqualTo: floorId)
              .get(const GetOptions(source: Source.cache));
          if (roomsSnapshot.docs.isEmpty) {
            roomsSnapshot = await _firestore
                .collection('rooms')
                .where('floorId', isEqualTo: floorId)
                .get();
          }
        } catch (_) {
          roomsSnapshot = await _firestore
              .collection('rooms')
              .where('floorId', isEqualTo: floorId)
              .get();
        }

        for (var roomDoc in roomsSnapshot.docs) {
          final roomData = roomDoc.data() as Map<String, dynamic>;
          allRooms.add({
            'floorId': floorId,
            'floorName': floorName,
            'buildingName': widget.buildingName,
            'roomName': roomData['name'] ?? 'Room',
            'roomId': roomDoc.id,
          });
        }
      }

      if (mounted) {
        setState(() {
          _rooms = allRooms;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _rooms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_rooms.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: _rooms.map((room) {
        final theme = widget.getAreaTheme(room['roomName'] ?? '');
        return RealtimeRoomCard(
          key: ValueKey(room['roomId']),
          room: room,
          theme: theme,
        );
      }).toList(),
    );
  }
}
