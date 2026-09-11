import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_home_screen.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/swipe_navigation_wrapper.dart';
import '../utils/app_page_route.dart';
import '../utils/app_colors.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/realtime_room_card.dart';
import '../services/seat_expiry_service.dart';
import 'dart:async';

class FindSeatsScreen extends StatefulWidget {
  const FindSeatsScreen({super.key});

  @override
  State<FindSeatsScreen> createState() => _FindSeatsScreenState();
}

class _FindSeatsScreenState extends State<FindSeatsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedBuildingId;
  String? _selectedBuildingName;
  String? _selectedFloorId;
  String? _selectedFloorName;
  String? _selectedAreaId;
  String? _selectedAreaName;

  late Stream<QuerySnapshot> _buildingsStream;
  late Stream<QuerySnapshot> _roomsStream;
  late Stream<List<Map<String, dynamic>>> _allRoomsStream;

  String? _lastBuildingIdForFloors;
  Stream<QuerySnapshot>? _floorsStream;

  @override
  void initState() {
    super.initState();
    _buildingsStream = _firestore.collection('buildings').snapshots();
    _roomsStream = _firestore.collection('rooms').snapshots();
    _allRoomsStream = _buildAllRoomsStream();
    SeatExpiryService.releaseAllExpiredSeatsGlobal();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                    .get();

            int availableSeats = 0;
            for (var seatDoc in seatsSnapshot.docs) {
              var sData = seatDoc.data() as Map<String, dynamic>;
              if (SeatExpiryService.isSeatExpired(sData) ||
                  (sData['status'] ?? 'available') == 'available') {
                availableSeats++;
              }
            }

            allRooms.add({
              'buildingId': buildingId,
              'buildingName': buildingName,
              'floorId': floorId,
              'floorName': floorName,
              'roomId': roomId,
              'roomName': roomName,
              'availableSeats': availableSeats,
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
        'color': EasySitColors.areaSilentBg,
        'iconColor': EasySitColors.areaSilentFg,
        'icon': Icons.menu_book_rounded,
      };
    } else if (lower.contains('group') ||
        lower.contains('collab') ||
        lower.contains('discussion')) {
      return {
        'color': EasySitColors.areaGroupBg,
        'iconColor': EasySitColors.areaGroupFg,
        'icon': Icons.groups_rounded,
      };
    } else {
      return {
        'color': EasySitColors.areaLabBg,
        'iconColor': EasySitColors.areaLabFg,
        'icon': Icons.apartment_rounded,
      };
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedBuildingId = null;
      _selectedBuildingName = null;
      _selectedFloorId = null;
      _selectedFloorName = null;
      _selectedAreaId = null;
      _selectedAreaName = null;
    });
  }

  Widget _buildFilterPill({
    required String defaultLabel,
    required String? selectedLabel,
    required bool isSelected,
    required String? currentValue,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final bool valueExists =
        currentValue != null && items.any((it) => it.value == currentValue);
    final String? effectiveValue = valueExists ? currentValue : null;
    final bool effectiveSelected = isSelected && valueExists;

    final String displayLabel =
        effectiveSelected && selectedLabel != null && selectedLabel.isNotEmpty
            ? selectedLabel
            : defaultLabel;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            effectiveSelected
                ? EasySitColors.primary
                : EasySitColors.subtleSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              effectiveSelected
                  ? EasySitColors.primary
                  : EasySitColors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: EasySitColors.cardShadow,
            blurRadius: effectiveSelected ? 8 : 4,
            offset: Offset(0, effectiveSelected ? 2 : 1),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: EasySitColors.surface,
          elevation: 4,
          menuMaxHeight: 300,
          iconSize: 18,
          icon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color:
                  effectiveSelected
                      ? EasySitColors.onPrimary
                      : EasySitColors.secondaryText,
            ),
          ),
          hint: Text(
            defaultLabel,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: EasySitColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          selectedItemBuilder:
              items.isEmpty
                  ? null
                  : (context) {
                    return items.map<Widget>((item) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          item.value == null ? defaultLabel : displayLabel,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color:
                                effectiveSelected
                                    ? EasySitColors.onPrimary
                                    : EasySitColors.textPrimary,
                            fontSize: 13,
                            fontWeight:
                                effectiveSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList();
                  },
          items: items.isEmpty ? null : items,
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }

  Widget _buildBuildingFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildingsStream,
      builder: (context, snapshot) {
        var items = <DropdownMenuItem<String>>[];
        if (snapshot.hasData) {
          items.add(
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All Buildings',
                style: TextStyle(
                  color: EasySitColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unnamed';
            final isCur = doc.id == _selectedBuildingId;
            items.add(
              DropdownMenuItem<String>(
                value: doc.id,
                child: Text(
                  name,
                  style: TextStyle(
                    color:
                        isCur
                            ? EasySitColors.primary
                            : EasySitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            );
          }
        }
        return _buildFilterPill(
          defaultLabel: 'Building',
          selectedLabel: _selectedBuildingName,
          isSelected: _selectedBuildingId != null,
          currentValue: _selectedBuildingId,
          items: items,
          onChanged: (value) {
            setState(() {
              _selectedBuildingId = value;
              _selectedFloorId = null;
              _selectedFloorName = null;
              _selectedAreaId = null;
              _selectedAreaName = null;
              if (value == null) {
                _selectedBuildingName = null;
              } else if (snapshot.hasData) {
                final match = snapshot.data!.docs.firstWhere(
                  (d) => d.id == value,
                );
                _selectedBuildingName = (match.data() as Map)['name'];
              }
            });
          },
        );
      },
    );
  }

  Widget _buildFloorFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFloorsStream(),
      builder: (context, snapshot) {
        var items = <DropdownMenuItem<String>>[];
        if (_selectedBuildingId != null && snapshot.hasData) {
          items.add(
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All Floors',
                style: TextStyle(
                  color: EasySitColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Floor';
            final isCur = doc.id == _selectedFloorId;
            items.add(
              DropdownMenuItem<String>(
                value: doc.id,
                child: Text(
                  name,
                  style: TextStyle(
                    color:
                        isCur
                            ? EasySitColors.primary
                            : EasySitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            );
          }
        }
        return _buildFilterPill(
          defaultLabel: 'Floor',
          selectedLabel: _selectedFloorName,
          isSelected: _selectedFloorId != null,
          currentValue: _selectedFloorId,
          items: items,
          onChanged: (value) {
            setState(() {
              _selectedFloorId = value;
              _selectedAreaId = null;
              _selectedAreaName = null;
              if (value == null) {
                _selectedFloorName = null;
              } else if (snapshot.hasData) {
                final match = snapshot.data!.docs.firstWhere(
                  (d) => d.id == value,
                );
                _selectedFloorName = (match.data() as Map)['name'];
              }
            });
          },
        );
      },
    );
  }

  Widget _buildAreaFilter() {
    return StreamBuilder<QuerySnapshot>(
      stream: _roomsStream,
      builder: (context, snapshot) {
        var items = <DropdownMenuItem<String>>[];
        if (snapshot.hasData) {
          items.add(
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'All Areas',
                style: TextStyle(
                  color: EasySitColors.secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
          var docs = snapshot.data!.docs;
          if (_selectedFloorId != null) {
            docs =
                docs
                    .where(
                      (d) => (d.data() as Map)['floorId'] == _selectedFloorId,
                    )
                    .toList();
          }
          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Area';
            final isCur = doc.id == _selectedAreaId;
            items.add(
              DropdownMenuItem<String>(
                value: doc.id,
                child: Text(
                  name,
                  style: TextStyle(
                    color:
                        isCur
                            ? EasySitColors.primary
                            : EasySitColors.textPrimary,
                    fontSize: 13,
                    fontWeight: isCur ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            );
          }
        }
        return _buildFilterPill(
          defaultLabel: 'Area',
          selectedLabel: _selectedAreaName,
          isSelected: _selectedAreaId != null,
          currentValue: _selectedAreaId,
          items: items,
          onChanged: (value) {
            setState(() {
              _selectedAreaId = value;
              if (value == null) {
                _selectedAreaName = null;
              } else if (snapshot.hasData) {
                final match = snapshot.data!.docs.firstWhere(
                  (d) => d.id == value,
                );
                _selectedAreaName = (match.data() as Map)['name'];
              }
            });
          },
        );
      },
    );
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
      child: SwipeNavigationWrapper(
        enableSwipeBack: true,
        onSwipeBack: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              AppPageRoute(builder: (_) => const StudentHomeScreen()),
              (route) => false,
            );
          }
        },
        child: Scaffold(
          backgroundColor: EasySitColors.appBackground,
          appBar: AppBar(
            toolbarHeight: 84,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            backgroundColor: EasySitColors.screenHeaderBackground,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: EasySitColors.screenHeaderBackground,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
            leadingWidth: 64,
            leading: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: EasySitColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: EasySitColors.divider),
                  boxShadow: EasySitColors.cardShadows,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: EasySitColors.textPrimary,
                  ),
                  onPressed: () {
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
                ),
              ),
            ),
            titleSpacing: 0,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Find Seats',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Explore study spaces and availability',
                  style: TextStyle(
                    color: EasySitColors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: const [
              NotificationBellButton(),
              SizedBox(width: 20),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                  color: EasySitColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: EasySitColors.divider,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: EasySitColors.cardShadow,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: EasySitColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search building, floor, seat...',
                    hintStyle: const TextStyle(
                      color: EasySitColors.secondaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: EasySitColors.secondaryText,
                      size: 22,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: EasySitColors.secondaryText,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
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
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    _buildBuildingFilter(),
                    const SizedBox(width: 8),
                    _buildFloorFilter(),
                    const SizedBox(width: 8),
                    _buildAreaFilter(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Areas',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.textPrimary,
                    ),
                  ),
                  if (_selectedBuildingId != null ||
                      _selectedFloorId != null ||
                      _selectedAreaId != null ||
                      _searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAllFilters,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EasySitColors.primaryTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: EasySitColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
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
                    return const Center(child: CircularProgressIndicator(color: EasySitColors.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: EasySitColors.error)));
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
                    if (_selectedAreaId != null) {
                      filteredRooms =
                          filteredRooms
                              .where(
                                (room) => room['roomId'] == _selectedAreaId,
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
                          Icon(Icons.search_off, size: 72, color: EasySitColors.secondaryText),
                          SizedBox(height: 16),
                          Text(
                            'No areas found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: EasySitColors.secondaryText,
                            ),
                          ),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(fontSize: 14, color: EasySitColors.secondaryText),
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

                      return RealtimeRoomCard(
                        key: ValueKey(room['roomId']),
                        room: room,
                        theme: theme,
                        showBorder: true,
                        showSeatsWord: false,
                        customShadow: [
                          BoxShadow(
                            color: EasySitColors.cardShadow,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: -1,
          onTabSelected: _onNavTab,
        ),
      ),
    ),
  );
}
}
