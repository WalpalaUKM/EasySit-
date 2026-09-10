import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'qr_scanner_screen.dart';
import 'find_seats_screen.dart';
import 'seat_booking_screen.dart';
import 'session_screen.dart';
import '../services/notification_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import '../utils/app_page_route.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/reservation_expired_dialog.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  String _userName = 'Student';

  @override
  void initState() {
    super.initState();
    _getUserName();
    _checkAndReleaseExpiredBookings();
  }

  @override
  void dispose() {
    _bookedListener?.cancel();
    super.dispose();
  }

  StreamSubscription<QuerySnapshot>? _bookedListener;

  Future<void> _openNotificationScreen() async {
    final result = await Navigator.push<String>(
      context,
      AppPageRoute(builder: (_) => const NotificationScreen()),
    );
    if (result == 'session_expiring') {
      await _showSessionActionDialog();
    } else if (result == 'view_session') {
      _onNavTab(2);
    }
  }

  Future<void> _showSessionActionDialog() async {
    if (_user == null) return;

    final snapshot =
        await _firestore
            .collection('seats')
            .where('bookedBy', isEqualTo: _user.uid)
            .get();

    if (snapshot.docs.isEmpty) {
      final pendingSnapshot =
          await _firestore
              .collection('seats')
              .where('pendingBy', isEqualTo: _user.uid)
              .get();
      if (pendingSnapshot.docs.isNotEmpty && mounted) {
        Navigator.push(
          context,
          AppPageRoute(builder: (_) => const SessionScreen()),
        );
      }
      return;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final seatNumber = data['seatNumber']?.toString() ?? doc.id;
    final buildingName = data['buildingName'] ?? '';
    final roomName = data['roomName'] ?? '';

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Session Expiring'),
            content: Text(
              'Your session for Seat $seatNumber at $buildingName - $roomName will expire soon.\n\n'
              'Would you like to extend your session by 4 minutes or release the seat now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'release'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Release Seat'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'extend'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text('Extend 4 Minutes'),
              ),
            ],
          ),
    );

    if (!mounted) return;

    if (action == 'extend') {
      await _firestore.collection('seats').doc(doc.id).update({
        'bookedAt': Timestamp.fromDate(DateTime.now()),
      });
      await NotificationService.clearUserNotifications(_user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session extended by 4 minutes!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (action == 'release') {
      await _firestore.collection('seats').doc(doc.id).update({
        'status': 'available',
        'bookedBy': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
        'pendingBy': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
      });
      await NotificationService.cancelAllNotifications();
      await NotificationService.clearUserNotifications(_user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seat released successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _getUserName() async {
    if (_user == null) return;
    try {
      // Try to load from cache first for instant display
      try {
        DocumentSnapshot cacheDoc = await _firestore
            .collection('users')
            .doc(_user.uid)
            .get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && mounted) {
          setState(() {
            _userName = cacheDoc.get('fullName') ?? 'Student';
          });
        }
      } catch (_) {}

      // Then update from server in the background
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userName = userDoc.get('fullName') ?? 'Student';
        });
      }
    } catch (_) {}
  }

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: _onNavTab,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 80,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: const Color(0xFFF5F6F8),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getGreeting(),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: NotificationBellButton(
              onTap: _openNotificationScreen,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkAndReleaseExpiredBookings() async {
    if (_user == null) return;
    try {
      final now = DateTime.now();

      QuerySnapshot bookedSeats =
          await _firestore
              .collection('seats')
              .where('bookedBy', isEqualTo: _user.uid)
              .get();

      for (var doc in bookedSeats.docs) {
        var data = doc.data() as Map<String, dynamic>;
        Timestamp? bookedAt = data['bookedAt'] as Timestamp?;
        if (bookedAt != null) {
          DateTime expiresAt = bookedAt.toDate().add(
            const Duration(minutes: 5),
          );
          if (now.isAfter(expiresAt)) {
            await _firestore.collection('seats').doc(doc.id).update({
              'status': 'available',
              'bookedBy': FieldValue.delete(),
              'bookedAt': FieldValue.delete(),
              'pendingBy': FieldValue.delete(),
              'pendingAt': FieldValue.delete(),
            });
          }
        }
      }

      QuerySnapshot pendingSeats =
          await _firestore
              .collection('seats')
              .where('pendingBy', isEqualTo: _user.uid)
              .get();

      for (var doc in pendingSeats.docs) {
        var data = doc.data() as Map<String, dynamic>;
        Timestamp? pendingAt = data['pendingAt'] as Timestamp?;
        if (pendingAt != null) {
          DateTime expiresAt = pendingAt.toDate().add(
            const Duration(minutes: 10),
          );
          if (DateTime.now().isAfter(expiresAt)) {
            await _firestore.collection('seats').doc(doc.id).update({
              'status': 'available',
              'pendingBy': FieldValue.delete(),
              'pendingAt': FieldValue.delete(),
            });
            if (mounted) {
              ReservationExpiredDialog.show(context);
            }
          }
        }
      }
    } catch (_) {}
  }

  void _onNavTab(int index) {
    if (index == _currentIndex) return;
    if (index == 0) {
      setState(() => _currentIndex = index);
      return;
    }
    Widget screen;
    switch (index) {
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

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // ========== Quick Actions (One Row, Two Columns) ==========
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              Expanded(
                child: _buildPrimaryActionCard(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Scan QR',
                  subtitle: 'Claim a seat instantly',
                  onTap: () => _onNavTab(1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildSecondaryActionCard(
                  icon: Icons.search,
                  title: 'Find Seats',
                  subtitle: 'Browse study areas',
                  onTap: () {
                    Navigator.push(
                      context,
                      AppPageRoute(builder: (_) => const FindSeatsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ========== Available Areas Section ==========
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
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    AppPageRoute(builder: (_) => const FindSeatsScreen()),
                  );
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5C55F2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ========== Area Cards ==========
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('buildings').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No buildings available yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var buildingDoc = snapshot.data!.docs[index];
                  var buildingData = buildingDoc.data() as Map<String, dynamic>;
                  String buildingId = buildingDoc.id;
                  String buildingName = buildingData['name'] ?? 'Unnamed';

                  return _buildBuildingCard(buildingId, buildingName);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF3B5DF8),
              Color(0xFF6B58F8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B5DF8).withValues(alpha: 0.32),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF3B5DF8), size: 24),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF1E293B),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16.0),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF5C55F2), size: 24),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.black54,
                    size: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildBuildingCard(String buildingId, String buildingName) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('floors')
              .where('buildingId', isEqualTo: buildingId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        List<Future<List<Map<String, dynamic>>>> roomFutures = [];
        for (var floorDoc in snapshot.data!.docs) {
          String floorId = floorDoc.id;
          var floorData = floorDoc.data() as Map<String, dynamic>;
          String floorName = floorData['name'] ?? 'Floor';

          roomFutures.add(_getRoomsForFloor(floorId, floorName, buildingName));
        }

        return FutureBuilder<List<List<Map<String, dynamic>>>>(
          future: Future.wait(roomFutures),
          builder: (context, roomSnapshot) {
            if (roomSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (roomSnapshot.hasError || roomSnapshot.data == null) {
              return const SizedBox.shrink();
            }

            var rooms =
                roomSnapshot.data!
                    .expand((x) => x)
                    .where((r) => r['roomId'] != '')
                    .toList();
            if (rooms.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                ...rooms.map((room) {
                  var theme = _getAreaTheme(room['roomName']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if ((room['availableSeats'] ?? 0) > 0) {
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
                              content: Text('No seats available in this room'),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room['roomName'],
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${room['buildingName']} • ${room['floorName']}',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF9E9E9E),
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
                                      '${room['availableSeats']} seats',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            (room['availableSeats'] ?? 0) > 0
                                                ? const Color(0xFF00C853)
                                                : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'available',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF9E9E9E),
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
                }),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getRoomsForFloor(
    String floorId,
    String floorName,
    String buildingName,
  ) async {
    try {
      QuerySnapshot roomsSnapshot;
      try {
        roomsSnapshot = await _firestore
            .collection('rooms')
            .where('floorId', isEqualTo: floorId)
            .get(const GetOptions(source: Source.cache));
        if (roomsSnapshot.docs.isEmpty) {
          roomsSnapshot =
              await _firestore
                  .collection('rooms')
                  .where('floorId', isEqualTo: floorId)
                  .get();
        }
      } catch (_) {
        roomsSnapshot =
            await _firestore
                .collection('rooms')
                .where('floorId', isEqualTo: floorId)
                .get();
      }

      if (roomsSnapshot.docs.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> results = [];
      for (var roomDoc in roomsSnapshot.docs) {
        var roomData = roomDoc.data() as Map<String, dynamic>;
        String roomId = roomDoc.id;
        String roomName = roomData['name'] ?? 'Room';

        QuerySnapshot seatsSnapshot =
            await _firestore
                .collection('seats')
                .where('roomId', isEqualTo: roomId)
                .where('status', isEqualTo: 'available')
                .get();

        int availableSeats = seatsSnapshot.docs.length;

        results.add({
          'floorId': floorId,
          'floorName': floorName,
          'buildingName': buildingName,
          'roomName': roomName,
          'availableSeats': availableSeats,
          'roomId': roomId,
        });
      }

      return results;
    } catch (e) {
      return [];
    }
  }
}
