import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'seat_booking_screen.dart';
import 'student_home_screen.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_bottom_nav.dart';
import 'notification_screen.dart';
import '../utils/app_page_route.dart';

class FindSeatsScreen extends StatefulWidget {
  const FindSeatsScreen({super.key});

  @override
  State<FindSeatsScreen> createState() => _FindSeatsScreenState();
}

class _FindSeatsScreenState extends State<FindSeatsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String? _selectedBuildingId;
  String? _selectedFloorId;

  late Stream<QuerySnapshot> _buildingsStream;
  late Stream<List<Map<String, dynamic>>> _allRoomsStream;

  String? _lastBuildingIdForFloors;
  Stream<QuerySnapshot>? _floorsStream;

  @override
  void initState() {
    super.initState();
    _buildingsStream = _firestore.collection('buildings').snapshots();
    _allRoomsStream = _buildAllRoomsStream();
  }

  Stream<QuerySnapshot>? _getFloorsStream() {
    if (_selectedBuildingId == null) {
      return null;
    }
    if (_lastBuildingIdForFloors != _selectedBuildingId ||
        _floorsStream == null) {
      _lastBuildingIdForFloors = _selectedBuildingId;
      _floorsStream =
          _firestore
              .collection('floors')
              .where('buildingId', isEqualTo: _selectedBuildingId)
              .snapshots();
    }
    return _floorsStream;
  }

  Stream<List<Map<String, dynamic>>> _buildAllRoomsStream() {
    return _firestore.collection('buildings').snapshots().asyncMap((
      buildingSnapshot,
    ) async {
      List<Map<String, dynamic>> allRooms = [];

      for (var buildingDoc in buildingSnapshot.docs) {
        String buildingId = buildingDoc.id;
        String buildingName = (buildingDoc.data() as Map)['name'] ?? 'Unnamed';

        QuerySnapshot floorsSnapshot =
            await _firestore
                .collection('floors')
                .where('buildingId', isEqualTo: buildingId)
                .get();

        for (var floorDoc in floorsSnapshot.docs) {
          String floorId = floorDoc.id;
          String floorName = (floorDoc.data() as Map)['name'] ?? 'Floor';

          QuerySnapshot roomsSnapshot =
              await _firestore
                  .collection('rooms')
                  .where('floorId', isEqualTo: floorId)
                  .get();

          for (var roomDoc in roomsSnapshot.docs) {
            String roomId = roomDoc.id;
            String roomName = (roomDoc.data() as Map)['name'] ?? 'Room';

            QuerySnapshot seatsSnapshot =
                await _firestore
                    .collection('seats')
                    .where('roomId', isEqualTo: roomId)
                    .where('status', isEqualTo: 'available')
                    .get();

            allRooms.add({
              'buildingId': buildingId,
              'buildingName': buildingName,
              'floorId': floorId,
              'floorName': floorName,
              'roomId': roomId,
              'roomName': roomName,
              'availableSeats': seatsSnapshot.docs.length,
            });
          }
        }
      }

      return allRooms;
    });
  }

  void _onNavTab(int index) {
    Widget screen;
    switch (index) {
      case 0:
        screen = const StudentHomeScreen();
        break;
      case 1:
        screen = const QrScannerScreen();
        break;
      case 2:
        screen = const SessionScreen();
        break;
      case 3:
        screen = const ProfileScreen();
        break;
      default:
        return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  Map<String, dynamic> _getAreaTheme(String roomName) {
    String lower = roomName.toLowerCase();
    if (lower.contains('quiet') ||
        lower.contains('silent') ||
        lower.contains('reading')) {
      return {
        'color': const Color(0xFFE8F5E9),
        'iconColor': const Color(0xFF2E7D32),
        'icon': Icons.menu_book_rounded,
      };
    } else if (lower.contains('group') ||
        lower.contains('collab') ||
        lower.contains('discussion')) {
      return {
        'color': const Color(0xFFF3E5F5),
        'iconColor': const Color(0xFF7B1FA2),
        'icon': Icons.groups_rounded,
      };
    } else {
      return {
        'color': const Color(0xFFFFF8E1),
        'iconColor': const Color(0xFFF57F17),
        'icon': Icons.apartment_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            AppPageRoute(
              builder: (_) => const StudentHomeScreen(),
            ),
            (route) => false,
          );
        }
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Find Seats',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        _firestore
                            .collection('notifications')
                            .where(
                              'userId',
                              whereIn: [
                                'all',
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                              ],
                            )
                            .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData) {
                        count = snapshot.data!.docs.length;
                      }
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            AppPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.notifications_none,
                                color: Colors.black87,
                                size: 22,
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 10,
                                  top: 10,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search building, floor, seat...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Building Filter
                    StreamBuilder<QuerySnapshot>(
                      stream: _buildingsStream,
                      builder: (context, snapshot) {
                        var items = <DropdownMenuItem<String>>[];
                        if (snapshot.hasData) {
                          items = [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All Buildings',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ),
                            ...snapshot.data!.docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  data['name'] ?? 'Unnamed',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              );
                            }),
                          ];
                        }
                        bool isSelected = _selectedBuildingId != null;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF5C55F2)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF5C55F2)
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBuildingId,
                              items: items.isEmpty ? null : items,
                              hint: Text(
                                'Building',
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                              dropdownColor: Colors.white,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged:
                                  snapshot.hasData
                                      ? (value) {
                                        setState(() {
                                          _selectedBuildingId = value;
                                          _selectedFloorId = null;
                                        });
                                      }
                                      : null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    // Floor Filter
                    StreamBuilder<QuerySnapshot>(
                      stream: _getFloorsStream(),
                      builder: (context, snapshot) {
                        var items = <DropdownMenuItem<String>>[];
                        if (_selectedBuildingId != null && snapshot.hasData) {
                          items = [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'All Floors',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ),
                            ...snapshot.data!.docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  data['name'] ?? 'Floor',
                                  style: const TextStyle(color: Colors.black87),
                                ),
                              );
                            }),
                          ];
                        }
                        bool isSelected = _selectedFloorId != null;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF5C55F2)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(0xFF5C55F2)
                                      : Colors.grey.shade200,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFloorId,
                              items: items.isEmpty ? null : items,
                              hint: Text(
                                'Floor',
                                style: TextStyle(
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontSize: 13,
                                ),
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                              dropdownColor: Colors.white,
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              onChanged:
                                  items.isNotEmpty
                                      ? (value) {
                                        setState(() {
                                          _selectedFloorId = value;
                                        });
                                      }
                                      : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'Available Areas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Room List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _allRoomsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  List<Map<String, dynamic>> filteredRooms = [];
                  if (snapshot.hasData) {
                    filteredRooms = List.from(snapshot.data!);

                    if (_selectedBuildingId != null) {
                      filteredRooms =
                          filteredRooms
                              .where(
                                (room) =>
                                    room['buildingId'] == _selectedBuildingId,
                              )
                              .toList();
                    }
                    if (_selectedFloorId != null) {
                      filteredRooms =
                          filteredRooms
                              .where(
                                (room) => room['floorId'] == _selectedFloorId,
                              )
                              .toList();
                    }
                    if (_searchQuery.isNotEmpty) {
                      filteredRooms =
                          filteredRooms
                              .where(
                                (room) =>
                                    room['roomName'].toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    room['buildingName'].toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ||
                                    room['floorName'].toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                              )
                              .toList();
                    }
                    filteredRooms.sort(
                      (a, b) => (b['availableSeats'] ?? 0).compareTo(
                        a['availableSeats'] ?? 0,
                      ),
                    );
                  }

                  if (filteredRooms.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 72, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No areas found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      var room = filteredRooms[index];
                      var theme = _getAreaTheme(room['roomName']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            if (room['availableSeats'] > 0) {
                              Navigator.push(
                                context,
                                AppPageRoute(
                                  builder:
                                      (_) => SeatBookingScreen(
                                        roomId: room['roomId'],
                                        roomName: room['roomName'],
                                        buildingName: room['buildingName'],
                                        floorName: room['floorName'],
                                      ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No seats available in this room',
                                  ),
                                  backgroundColor: Colors.orange,
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
                                    color: theme['color'],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    theme['icon'],
                                    color: theme['iconColor'],
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        room['roomName'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${room['buildingName']} • ${room['floorName']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${room['availableSeats']}',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                room['availableSeats'] > 0
                                                    ? const Color(0xFF00C853)
                                                    : Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'available',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black87,
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
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTabSelected: _onNavTab,
      ),
    ),
  );
}
}
