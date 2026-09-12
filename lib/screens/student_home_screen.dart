import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'qr_scanner_screen.dart';
import 'find_seats_screen.dart';
import 'session_screen.dart';
import '../services/user_stats_service.dart';
import '../services/seat_expiry_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import '../utils/booking_timer_config.dart';
import '../utils/app_page_route.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/reservation_expired_dialog.dart';
import '../widgets/building_rooms_section.dart';
import '../utils/greeting_helper.dart';
import '../utils/app_colors.dart';

class StudentHomeScreen extends StatefulWidget {
  final int initialIndex;

  const StudentHomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  late final PageController _pageController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  String _userName = 'Student';
  String _currentGreeting = GreetingHelper.getGreeting();
  Timer? _greetingTimer;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addObserver(this);
    _currentGreeting = GreetingHelper.getGreeting();
    _startGreetingTimer();
    _updateStatusBarForTab(_currentIndex);

    // Check for instant cached name from ProfileScreen notifier
    if (ProfileScreen.userNameNotifier.value.isNotEmpty) {
      _userName = ProfileScreen.userNameNotifier.value;
    }
    ProfileScreen.userNameNotifier.addListener(_onProfileUserNameChanged);

    _getUserName();
    _checkAndReleaseExpiredBookings();
  }

  void _onProfileUserNameChanged() {
    final name = ProfileScreen.userNameNotifier.value;
    if (name.isNotEmpty && name != _userName && mounted) {
      setState(() {
        _userName = name;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _greetingTimer?.cancel();
    _bookedListener?.cancel();
    _userDocSub?.cancel();
    ProfileScreen.userNameNotifier.removeListener(_onProfileUserNameChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateGreetingIfNeeded();
    }
  }

  // [TIME-BASED GREETING UPDATER]:
  // Unit: Seconds. Runs every 30 seconds (Duration(seconds: 30)).
  // Dynamically updates greeting ('Good Morning', 'Good Afternoon', etc.)
  // based on current Sri Lanka time (UTC+05:30) without needing app restart.
  void _startGreetingTimer() {
    _greetingTimer?.cancel();
    _greetingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateGreetingIfNeeded();
    });
  }

  void _updateGreetingIfNeeded() {
    final newGreeting = GreetingHelper.getGreeting();
    if (newGreeting != _currentGreeting && mounted) {
      setState(() {
        _currentGreeting = newGreeting;
      });
    }
  }

  StreamSubscription<QuerySnapshot>? _bookedListener;

  Future<void> _openNotificationScreen() async {
    final result = await Navigator.push<String>(
      context,
      AppPageRoute(builder: (_) => const NotificationScreen()),
    );
    if (result == 'view_session') {
      _onNavTab(2);
    }
  }

  Future<void> _getUserName() async {
    if (_user == null) return;
    try {
      // 1. Try to load from cache first for instant display
      try {
        DocumentSnapshot cacheDoc = await _firestore
            .collection('users')
            .doc(_user.uid)
            .get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && mounted) {
          final cachedName = (cacheDoc.get('fullName') ?? '').toString().trim();
          if (cachedName.isNotEmpty) {
            setState(() {
              _userName = cachedName;
            });
            if (ProfileScreen.userNameNotifier.value != cachedName) {
              ProfileScreen.userNameNotifier.value = cachedName;
            }
          }
        }
      } catch (_) {}

      // 2. Real-time stream subscription: auto-updates name the millisecond it changes
      _userDocSub?.cancel();
      _userDocSub = _firestore
          .collection('users')
          .doc(_user.uid)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              final remoteName =
                  (doc.data()?['fullName'] ?? '').toString().trim();
              if (remoteName.isNotEmpty && remoteName != _userName) {
                setState(() {
                  _userName = remoteName;
                });
                if (ProfileScreen.userNameNotifier.value != remoteName) {
                  ProfileScreen.userNameNotifier.value = remoteName;
                }
              }
            }
          });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _onNavTab(0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6F8),
        body: PageView(
          controller: _pageController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (index) {
            _updateStatusBarForTab(index);
            if (index == 0 &&
                ProfileScreen.userNameNotifier.value.isNotEmpty &&
                _userName != ProfileScreen.userNameNotifier.value) {
              setState(() => _userName = ProfileScreen.userNameNotifier.value);
            }
            setState(() => _currentIndex = index);
          },
          children: [
            _buildHomeTab(),
            QrScannerScreen(
              isTab: true,
              isActive: _currentIndex == 1,
              onTabSelected: _onNavTab,
            ),
            SessionScreen(
              isTab: true,
              onTabSelected: _onNavTab,
            ),
            ProfileScreen(
              isTab: true,
              onTabSelected: _onNavTab,
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          onTabSelected: _onNavTab,
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD6E4FF), // Light blue
            Colors.white,      // White
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: EasySitColors.appBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 84,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentGreeting,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: EasySitColors.darkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userName,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: EasySitColors.deepDarkBlue,
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

  // ============================================================================
  // [STARTUP SEAT EXPIRATION & AUTO-RELEASE SWEEP]
  // ============================================================================
  /// Triggered on home screen load:
  /// 1. Sweeps entire Firestore database to release all expired seats globally.
  /// 2. Checks active booked seat: Expiry duration is 2 hours (120 minutes) (unit: minutes).
  ///    If expired, records completed study stats and releases seat.
  /// 3. Checks pending reservation: Grace duration is 20 minutes (unit: minutes).
  ///    If expired, releases seat and displays ReservationExpiredDialog.
  Future<void> _checkAndReleaseExpiredBookings() async {
    // Release any expired seats across the whole database
    await SeatExpiryService.releaseAllExpiredSeatsGlobal();

    if (_user == null) return;
    try {
      final now = DateTime.now();

      // Check user's booked seat (2-hour session duration)
      QuerySnapshot bookedSeats =
          await _firestore
              .collection('seats')
              .where('bookedBy', isEqualTo: _user.uid)
              .get();

      for (var doc in bookedSeats.docs) {
        var data = doc.data() as Map<String, dynamic>;
        Timestamp? bookedAt = data['bookedAt'] as Timestamp?;
        if (bookedAt != null) {
          // Active booking duration in minutes (120 min)
          DateTime expiresAt = bookedAt.toDate().add(
            BookingTimerConfig.activeBookingDuration,
          );
          if (now.isAfter(expiresAt)) {
            await UserStatsService.recordCompletedSession(
              userId: _user.uid,
              seatId: doc.id,
              bookedAt: bookedAt.toDate(),
              fallbackMinutes: BookingTimerConfig.activeBookingDurationMinutes,
            );
            await SeatExpiryService.releaseExpiredSeatIfNeeded(doc.id, data);
          }
        }
      }

      // Check user's pending reservation (20-minute grace period)
      QuerySnapshot pendingSeats =
          await _firestore
              .collection('seats')
              .where('pendingBy', isEqualTo: _user.uid)
              .get();

      for (var doc in pendingSeats.docs) {
        var data = doc.data() as Map<String, dynamic>;
        Timestamp? pendingAt = data['pendingAt'] as Timestamp?;
        if (pendingAt != null) {
          // Pending reservation duration in minutes (20 min)
          DateTime expiresAt = pendingAt.toDate().add(
            BookingTimerConfig.pendingReservationDuration,
          );
          if (DateTime.now().isAfter(expiresAt)) {
            await SeatExpiryService.releaseExpiredSeatIfNeeded(doc.id, data);
            if (mounted) {
              ReservationExpiredDialog.show(context);
            }
          }
        }
      }
    } catch (_) {}
  }

  void _updateStatusBarForTab(int index) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  void _onNavTab(int index) {
    if (index == _currentIndex) return;
    _updateStatusBarForTab(index);
    if (index == 0 &&
        ProfileScreen.userNameNotifier.value.isNotEmpty &&
        _userName != ProfileScreen.userNameNotifier.value) {
      setState(() => _userName = ProfileScreen.userNameNotifier.value);
    }
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
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
                  color: EasySitColors.mainText,
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
                    color: EasySitColors.primary,
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
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
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

                  return BuildingRoomsSection(
                    key: ValueKey(buildingId),
                    buildingId: buildingId,
                    buildingName: buildingName,
                    getAreaTheme: _getAreaTheme,
                  );
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              EasySitColors.deepPurple,
              EasySitColors.primary,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: EasySitColors.primary.withValues(alpha: 0.32),
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
                  child: Icon(icon, color: EasySitColors.primary, size: 24),
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
                      color: EasySitColors.mainText,
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
          color: EasySitColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: EasySitColors.cardShadows,
          border: Border.all(color: EasySitColors.divider),
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
                    color: EasySitColors.primaryTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: EasySitColors.primary, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: EasySitColors.subtleSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: EasySitColors.secondaryText,
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
                color: EasySitColors.mainText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: EasySitColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getAreaTheme(String roomName) {
    String lower = roomName.toLowerCase();
    IconData icon;
    if (lower.contains('quiet') ||
        lower.contains('silent') ||
        lower.contains('reading')) {
      icon = Icons.menu_book_rounded;
    } else if (lower.contains('group') ||
        lower.contains('collab') ||
        lower.contains('discussion')) {
      icon = Icons.groups_rounded;
    } else {
      icon = Icons.apartment_rounded;
    }

    return {
      'color': EasySitColors.areaOrangeBg,     // Light orange-mix-yellow icon background (#FEF3C7)
      'iconColor': EasySitColors.areaOrangeFg, // Orange-mix-yellow icon (#D97706)
      'icon': icon,
    };
  }
}
