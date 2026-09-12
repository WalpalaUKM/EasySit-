import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../widgets/app_bottom_nav.dart';
import 'student_home_screen.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'notification_screen.dart';
import '../utils/app_page_route.dart';
import '../utils/app_colors.dart';
import '../widgets/notification_bell_button.dart';
import '../services/auth_persistence_service.dart';
import '../utils/booking_timer_config.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  final ValueChanged<int>? onTabSelected;

  const ProfileScreen({super.key, this.isTab = false, this.onTabSelected});

  static Map<String, dynamic>? cachedBooking;
  static String cachedStatus = '';
  static final ValueNotifier<String> userNameNotifier =
      ValueNotifier<String>('');

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  String _fullName = '';
  String _studentNumber = '';
  String _email = '';
  String _phone = '';
  String _userType = 'Student';
  Map<String, dynamic>? _activeBooking;
  String _bookingStatus = '';

  // ============================================================================
  // [STUDENT STUDY METRICS & STATISTICS (UNITS)]
  // ============================================================================
  // sessionsCompleted: Total number of finished study sessions (unit: count).
  // totalMinutesStudied: Total minutes recorded in Firestore (unit: minutes).
  // hoursStudiedNum / _hoursStudiedFormatted: totalMinutesStudied / 60.0 (unit: hours, 1 decimal place).
  // differentSeatsUsed: Count of unique seat IDs used by this student (unit: count).
  int _sessionsCompleted = 0;
  num _hoursStudiedNum = 0;
  int _totalMinutesStudied = 0;
  int _differentSeatsUsed = 0;

  /// Formats total minutes studied into decimal hours (e.g. 0.2, 1.5 hrs).
  String get _hoursStudiedFormatted {
    num totalMinutes = _totalMinutesStudied > 0 ? _totalMinutesStudied : (_hoursStudiedNum * 60);
    if (totalMinutes <= 0) return '0';
    double hours = totalMinutes / 60.0;
    if (hours == hours.roundToDouble()) {
      return hours.toInt().toString();
    }
    return hours.toStringAsFixed(1);
  }

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _studentNumberCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  bool _isSaving = false;

  StreamSubscription<QuerySnapshot>? _bookedSub;
  StreamSubscription<QuerySnapshot>? _pendingSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    final cached = ProfileScreen.cachedBooking;
    final cachedOwner = cached?['bookedBy'] ?? cached?['pendingBy'];
    if (cached != null && (_user == null || cachedOwner == null || cachedOwner == _user.uid)) {
      _activeBooking = cached;
      _bookingStatus = ProfileScreen.cachedStatus;
    } else {
      _activeBooking = null;
      _bookingStatus = '';
    }
    _loadUserData();
    _listenActiveBooking();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _studentNumberCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bookedSub?.cancel();
    _pendingSub?.cancel();
    _userDocSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _activeBooking != null) {
        setState(() {});
      }
    });
  }

  Future<void> _loadUserData() async {
    if (_user == null) return;
    try {
      // 1. First try local cache for instant zero-latency render
      try {
        DocumentSnapshot cacheDoc = await _firestore
            .collection('users')
            .doc(_user.uid)
            .get(const GetOptions(source: Source.cache));
        if (cacheDoc.exists && mounted) {
          _applyUserData(cacheDoc.data() as Map<String, dynamic>);
        }
      } catch (_) {}

      // 2. Fetch fresh user document from server immediately
      try {
        DocumentSnapshot serverDoc = await _firestore
            .collection('users')
            .doc(_user.uid)
            .get(const GetOptions(source: Source.server));
        if (serverDoc.exists && mounted) {
          _applyUserData(serverDoc.data() as Map<String, dynamic>);
        }
      } catch (_) {}

      // 3. Real-time listener for ongoing user profile and statistics updates
      _userDocSub?.cancel();
      _userDocSub = _firestore
          .collection('users')
          .doc(_user.uid)
          .snapshots()
          .listen((doc) {
            if (doc.exists && mounted) {
              _applyUserData(doc.data() as Map<String, dynamic>);
            }
          });
    } catch (_) {}
  }

  void _applyUserData(Map<String, dynamic> data) {
    final name = (data['fullName'] ?? '').toString().trim();
    var studentNum =
        (data['studentId'] ?? data['studentNumber'] ?? '').toString().trim();
    final emailVal = (data['email'] ?? _user?.email ?? '').toString().trim();
    if (studentNum.isEmpty && emailVal.isNotEmpty) {
      final match = RegExp(r'[-_]([a-zA-Z]{2}\d{5})@').firstMatch(emailVal);
      if (match != null) {
        studentNum = match.group(1)?.toUpperCase() ?? '';
      }
    }
    if (name.isNotEmpty && ProfileScreen.userNameNotifier.value != name) {
      ProfileScreen.userNameNotifier.value = name;
    }
    setState(() {
      _fullName = name;
      _studentNumber = studentNum;
      _email = emailVal;
      _phone = data['phone'] ?? '';
      _userType = data['userType'] ?? 'Student';
      _sessionsCompleted = (data['sessionsCompleted'] as num?)?.toInt() ?? 0;
      _totalMinutesStudied =
          (data['totalMinutesStudied'] as num?)?.toInt() ?? 0;
      if (_totalMinutesStudied > 0) {
        _hoursStudiedNum = _totalMinutesStudied / 60.0;
      } else if (data['hoursStudied'] != null) {
        _hoursStudiedNum = data['hoursStudied'] as num;
      } else {
        _hoursStudiedNum = 0;
      }

      // Strictly deduplicate used seats via Set so using the same seat multiple times only counts once
      if (data['usedSeats'] != null && data['usedSeats'] is List) {
        final uniqueSeats = (data['usedSeats'] as List)
            .map((e) => e.toString().replaceFirst('SEAT:', '').trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        _differentSeatsUsed = uniqueSeats.length;

        // Auto-heal database record if stale duplicate count was previously saved
        if (_user != null && data['differentSeatsUsed'] != uniqueSeats.length) {
          _firestore.collection('users').doc(_user.uid).update({
            'differentSeatsUsed': uniqueSeats.length,
            'usedSeats': uniqueSeats.toList(),
          }).catchError((_) {});
        }
      } else if (data['differentSeatsUsed'] != null) {
        _differentSeatsUsed = (data['differentSeatsUsed'] as num).toInt();
      } else {
        _differentSeatsUsed = 0;
      }
    });
    _nameCtrl.text = _fullName;
    _studentNumberCtrl.text = _studentNumber;
    _emailCtrl.text = _email;
    _phoneCtrl.text = _phone;
  }

  void _listenActiveBooking() {
    if (_user == null) return;

    // Fast local cache lookup for instant load on launch
    if (_activeBooking == null) {
      _firestore
          .collection('seats')
          .where('bookedBy', isEqualTo: _user.uid)
          .get(const GetOptions(source: Source.cache))
          .then((snap) {
            if (snap.docs.isNotEmpty && mounted && _activeBooking == null) {
              _onBookingFound(snap.docs.first, 'booked');
            } else if (_activeBooking == null) {
              _firestore
                  .collection('seats')
                  .where('pendingBy', isEqualTo: _user.uid)
                  .get(const GetOptions(source: Source.cache))
                  .then((pSnap) {
                    if (pSnap.docs.isNotEmpty &&
                        mounted &&
                        _activeBooking == null) {
                      _onBookingFound(pSnap.docs.first, 'pending');
                    }
                  })
                  .catchError((_) {});
            }
          })
          .catchError((_) {});
    }

    _bookedSub?.cancel();
    _bookedSub = _firestore
        .collection('seats')
        .where('bookedBy', isEqualTo: _user.uid)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            _pendingSub?.cancel();
            _onBookingFound(snapshot.docs.first, 'booked');
          } else {
            _pendingSub?.cancel();
            _pendingSub = _firestore
                .collection('seats')
                .where('pendingBy', isEqualTo: _user.uid)
                .snapshots()
                .listen((pSnap) {
                  if (pSnap.docs.isNotEmpty) {
                    _onBookingFound(pSnap.docs.first, 'pending');
                  } else if (mounted) {
                    setState(() {
                      _activeBooking = null;
                      _bookingStatus = '';
                      ProfileScreen.cachedBooking = null;
                      ProfileScreen.cachedStatus = '';
                    });
                  }
                });
          }
        });
  }

  Future<void> _onBookingFound(QueryDocumentSnapshot doc, String status) async {
    var data = doc.data() as Map<String, dynamic>;

    String seatNumber = data['seatNumber']?.toString() ?? '?';
    String roomName = data['roomName']?.toString() ?? '';
    String floorName = data['floorName']?.toString() ?? '';
    String buildingName = data['buildingName']?.toString() ?? '';

    // 1. Immediately update UI state so current session card appears without delay!
    if (mounted) {
      setState(() {
        _activeBooking = {
          'docId': doc.id,
          'seatId': doc.id,
          'seatNumber': seatNumber,
          'roomName': roomName.isNotEmpty ? roomName : 'Room',
          'floorName': floorName,
          'buildingName': buildingName,
          'status': status,
          'bookedAt': data['bookedAt'],
          'pendingAt': data['pendingAt'],
        };
        _bookingStatus = status;
        ProfileScreen.cachedBooking = _activeBooking;
        ProfileScreen.cachedStatus = status;
      });
    }

    // 2. Fetch room/floor/building in background if not present on seat doc
    String roomId = (data['roomId'] ?? '').toString().trim();
    if (roomName.isEmpty || floorName.isEmpty || buildingName.isEmpty) {
      try {
        if (roomId.isNotEmpty) {
          DocumentSnapshot roomDoc =
              await _firestore.collection('rooms').doc(roomId).get();
          var roomData = roomDoc.data() as Map<String, dynamic>?;
          if (roomName.isEmpty) roomName = roomData?['name'] ?? roomName;
          String floorId = roomData?['floorId'] ?? '';
          if (floorId.isNotEmpty) {
            DocumentSnapshot floorDoc =
                await _firestore.collection('floors').doc(floorId).get();
            var floorData = floorDoc.data() as Map<String, dynamic>?;
            if (floorName.isEmpty) floorName = floorData?['name'] ?? floorName;
            String buildingId = floorData?['buildingId'] ?? '';
            if (buildingId.isNotEmpty && buildingName.isEmpty) {
              DocumentSnapshot buildingDoc =
                  await _firestore.collection('buildings').doc(buildingId).get();
              var buildingData = buildingDoc.data() as Map<String, dynamic>?;
              if (buildingName.isEmpty) buildingName = buildingData?['name'] ?? buildingName;
            }
          }
        }

        // If roomId was empty, lookup room by roomName
        if ((floorName.isEmpty || buildingName.isEmpty) && roomName.isNotEmpty) {
          QuerySnapshot rSnap = await _firestore
              .collection('rooms')
              .where('name', isEqualTo: roomName)
              .limit(1)
              .get();
          if (rSnap.docs.isNotEmpty) {
            var rData = rSnap.docs.first.data() as Map<String, dynamic>;
            String fId = (rData['floorId'] ?? '').toString().trim();
            if (fId.isNotEmpty) {
              DocumentSnapshot fDoc =
                  await _firestore.collection('floors').doc(fId).get();
              var fData = fDoc.data() as Map<String, dynamic>?;
              if (floorName.isEmpty) floorName = fData?['name'] ?? floorName;
              String bId = fData?['buildingId'] ?? '';
              if (bId.isNotEmpty && buildingName.isEmpty) {
                DocumentSnapshot bDoc =
                    await _firestore.collection('buildings').doc(bId).get();
                var bData = bDoc.data() as Map<String, dynamic>?;
                if (buildingName.isEmpty) buildingName = bData?['name'] ?? buildingName;
              }
            }
          }
        }

        if (mounted &&
            _activeBooking != null &&
            _activeBooking!['docId'] == doc.id) {
          setState(() {
            _activeBooking!['roomName'] =
                roomName.isNotEmpty ? roomName : 'Room';
            _activeBooking!['floorName'] = floorName;
            _activeBooking!['buildingName'] = buildingName;
            ProfileScreen.cachedBooking = _activeBooking;
          });
        }
      } catch (_) {}
    }
  }

  String _getRemainingTime() {
    if (_activeBooking == null) return '00:00';
    Timestamp? ts =
        (_activeBooking!['bookedAt'] ?? _activeBooking!['pendingAt'])
            as Timestamp?;
    if (ts == null) return '00:00';
    final bool isBooked =
        _activeBooking!['status'] == 'booked' ||
        _activeBooking!['bookedAt'] != null;
    // Calculates remaining session time using central durations from BookingTimerConfig
    final duration = isBooked
        ? BookingTimerConfig.activeBookingDuration
        : BookingTimerConfig.pendingReservationDuration;
    final expiresAt = ts.toDate().add(duration);
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return '00:00';
    if (diff.inHours > 0) {
      final hours = diff.inHours.toString().padLeft(2, '0');
      final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$mins:$secs';
    }
    final mins = diff.inMinutes.toString().padLeft(2, '0');
    final secs = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full name cannot be empty.'),
          backgroundColor: EasySitColors.errorFg,
        ),
      );
      return;
    }

    final newPhone = _phoneCtrl.text.trim();
    // Phone-number validation: must contain exactly 10 digits (digits only)
    if (newPhone.length != 10 || !RegExp(r'^\d{10}$').hasMatch(newPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number must contain exactly 10 digits.'),
          backgroundColor: EasySitColors.errorFg,
        ),
      );
      return;
    }

    ProfileScreen.userNameNotifier.value = newName;
    setState(() => _isSaving = true);
    try {
      // In Edit Profile, students can edit ONLY:
      // 1. Full name
      // 2. Phone number
      // Student number and university email are read-only.
      await _firestore.collection('users').doc(_user.uid).update({
        'fullName': newName,
        'phone': newPhone,
      });
      setState(() {
        _fullName = newName;
        _phone = newPhone;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    ProfileScreen.cachedBooking = null;
    ProfileScreen.cachedStatus = '';
    await AuthPersistenceService.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        AppPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onNavTab(int index) {
    if (widget.isTab && widget.onTabSelected != null) {
      widget.onTabSelected!(index);
      return;
    }
    if (index == 3) return;
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
      default:
        return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      AppPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  void _showEditProfileSheet() {
    _nameCtrl.text = _fullName;
    _emailCtrl.text = _email;
    _phoneCtrl.text = _phone;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: EasySitColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded, color: EasySitColors.secondaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Full Name (Editable)
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: EasySitColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EasySitColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: EasySitColors.focusRing,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Student Number (Read-only)
                    TextField(
                      controller: _studentNumberCtrl,
                      enabled: false,
                      style: TextStyle(color: Colors.grey.shade700),
                      decoration: InputDecoration(
                        labelText: 'Student Number (Read-only)',
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: EasySitColors.secondaryText,
                        ),
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: EasySitColors.secondaryText,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EasySitColors.divider),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EasySitColors.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // University Email (Read-only)
                    TextField(
                      controller: _emailCtrl,
                      enabled: false,
                      style: TextStyle(color: Colors.grey.shade700),
                      decoration: InputDecoration(
                        labelText: 'University Email (Read-only)',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: EasySitColors.secondaryText,
                        ),
                        suffixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: EasySitColors.secondaryText,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EasySitColors.divider),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EasySitColors.divider),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone Number (Editable - 10 digits only)
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. 0712345678',
                        helperText: 'Must contain exactly 10 digits',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: EasySitColors.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EasySitColors.inputBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: EasySitColors.focusRing,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            _isSaving
                                ? null
                                : () async {
                                  setModalState(() => _isSaving = true);
                                  await _saveProfile();
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EasySitColors.primary,
                          foregroundColor: EasySitColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child:
                            _isSaving
                                ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: EasySitColors.onPrimary,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpAndSupportDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: EasySitColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.help_outline_rounded, color: EasySitColors.primary),
                SizedBox(width: 10),
                Text(
                  'Help & Support',
                  style: TextStyle(fontWeight: FontWeight.bold, color: EasySitColors.textPrimary),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('For any inquiries or technical assistance:', style: TextStyle(color: EasySitColors.bodyText)),
                SizedBox(height: 12),
                Text(
                  'Email: support@easysit.app',
                  style: TextStyle(fontWeight: FontWeight.w600, color: EasySitColors.textPrimary),
                ),
                SizedBox(height: 4),
                Text(
                  'Phone: 0713393669',
                  style: TextStyle(fontWeight: FontWeight.w600, color: EasySitColors.textPrimary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: EasySitColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: EasySitColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: EasySitColors.primary),
                SizedBox(width: 10),
                Text(
                  'About EasySit',
                  style: TextStyle(fontWeight: FontWeight.bold, color: EasySitColors.textPrimary),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EasySit is a smart library seat booking system.', style: TextStyle(color: EasySitColors.bodyText)),
                SizedBox(height: 12),
                Text(
                  'Version: 1.0.0',
                  style: TextStyle(fontWeight: FontWeight.w600, color: EasySitColors.textPrimary),
                ),
                SizedBox(height: 4),
                Text(
                  'Developer: EasySit Team',
                  style: TextStyle(fontWeight: FontWeight.w600, color: EasySitColors.textPrimary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: EasySitColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
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
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: EasySitColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Manage your student account',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            if (_activeBooking != null &&
                (_bookingStatus == 'booked' ||
                    _bookingStatus == 'pending')) ...[
              const SizedBox(height: 16),
              _buildCurrentSession(),
            ],
            const SizedBox(height: 20),
            const Text(
              'Your Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: EasySitColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _buildStats(),
            const SizedBox(height: 18),
            _buildSettingsCard(),
            const SizedBox(height: 18),
            _buildLogoutButton(),
            const SizedBox(
              height: 100,
            ), // Space for floating bottom nav
          ],
        ),
      ),
      bottomNavigationBar:
          widget.isTab
              ? null
              : AppBottomNav(currentIndex: 3, onTabSelected: _onNavTab),
    );

    if (widget.isTab) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
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
      child: scaffold,
    );
  }

  // 1. User Info Card
  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EasySitColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: EasySitColors.divider, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: EasySitColors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [EasySitColors.primary, EasySitColors.focusRing],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: EasySitColors.cardShadow,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _fullName.trim().isNotEmpty
                        ? _fullName.trim()[0].toUpperCase()
                        : (_email.trim().isNotEmpty
                            ? _email.trim()[0].toUpperCase()
                            : 'S'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName.isNotEmpty ? _fullName : 'Student',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: EasySitColors.primaryTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.school_rounded,
                            size: 15,
                            color: EasySitColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _userType.isNotEmpty ? _userType : 'Student',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: EasySitColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: EasySitColors.divider),
          const SizedBox(height: 14),
          // Student Details: Full name, Student number, University email, Phone number
          _buildProfileDetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Full Name',
            value: _fullName.isNotEmpty ? _fullName : 'Not set',
          ),
          const SizedBox(height: 10),
          _buildProfileDetailRow(
            icon: Icons.badge_outlined,
            label: 'Student Number',
            value: _studentNumber.isNotEmpty ? _studentNumber : 'Not set',
            isReadOnly: true,
          ),
          const SizedBox(height: 10),
          _buildProfileDetailRow(
            icon: Icons.email_outlined,
            label: 'University Email',
            value: _email.isNotEmpty ? _email : 'Not set',
            isReadOnly: true,
          ),
          const SizedBox(height: 10),
          _buildProfileDetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: _phone.isNotEmpty ? _phone : 'Not set',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isReadOnly = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: EasySitColors.primaryTint,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: EasySitColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: EasySitColors.secondaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: EasySitColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (isReadOnly) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 11,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 3),
                Text(
                  'Read-only',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // 2. Current Session Card
  Widget _buildCurrentSession() {
    if (_activeBooking == null ||
        (_bookingStatus != 'booked' && _bookingStatus != 'pending')) {
      return const SizedBox.shrink();
    }

    final seatNumber = _activeBooking!['seatNumber']?.toString() ?? '?';
    final roomName = _activeBooking!['roomName']?.toString() ?? 'Room';
    final location = [
      _activeBooking!['buildingName']?.toString() ?? '',
      _activeBooking!['roomName']?.toString() ?? '',
      _activeBooking!['floorName']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(' • ');

    final isBooked = _bookingStatus == 'booked';
    final statusText = isBooked ? 'Active' : 'Pending';
    final endsInText = _getRemainingTime();

    final primaryColor =
        isBooked ? EasySitColors.success : EasySitColors.pendingPrimary;
    final accentTextColor =
        isBooked ? EasySitColors.successFg : EasySitColors.pendingDark;
    final secondaryBgColor =
        isBooked ? EasySitColors.successBg : EasySitColors.pendingBadge;
    final borderColor =
        isBooked ? EasySitColors.successBorder : EasySitColors.pendingBorder;
    final cardBgColor =
        isBooked ? EasySitColors.surface : EasySitColors.pendingBg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isBooked
                ? EasySitColors.cardShadow
                : EasySitColors.pendingPrimary.withValues(alpha: 0.10),
            blurRadius: 14,
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
              const Text(
                'Current Session',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: EasySitColors.textPrimary,
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    AppPageRoute(builder: (_) => const SessionScreen()),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isBooked
                            ? EasySitColors.primary
                            : EasySitColors.pendingAccent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isBooked
                          ? EasySitColors.primary
                          : EasySitColors.pendingAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: secondaryBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: isBooked
                      ? null
                      : Border.all(
                          color: EasySitColors.pendingBorder,
                          width: 1,
                        ),
                ),
                child: Center(
                  child: Icon(
                    Icons.chair_rounded,
                    size: 32,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seatNumber,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: accentTextColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 11,
                          color: isBooked
                              ? EasySitColors.secondaryText
                              : EasySitColors.pendingDark.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: secondaryBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: isBooked
                          ? null
                          : Border.all(
                              color: EasySitColors.pendingBorder,
                              width: 1,
                            ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isBooked
                                ? accentTextColor
                                : EasySitColors.pendingPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ends in ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isBooked
                              ? EasySitColors.secondaryText
                              : EasySitColors.pendingDark.withValues(alpha: 0.75),
                        ),
                      ),
                      Text(
                        endsInText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isBooked
                              ? EasySitColors.textPrimary
                              : EasySitColors.pendingDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Your Statistics Card
  Widget _buildStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        color: EasySitColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EasySitColors.divider, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: EasySitColors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Stat 1: Sessions Completed
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: EasySitColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.show_chart_rounded,
                      size: 24,
                      color: EasySitColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_sessionsCompleted',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Session\nCompleted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: EasySitColors.secondaryText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: EasySitColors.divider),
          // Stat 2: Hours Studied
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: EasySitColors.successBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.access_time_rounded,
                      size: 24,
                      color: EasySitColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _hoursStudiedFormatted,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Hours\nStudied',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: EasySitColors.secondaryText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 60, color: EasySitColors.divider),
          // Stat 3: Different Seats Used
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: EasySitColors.accentTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chair_rounded,
                      size: 24,
                      color: EasySitColors.purpleAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_differentSeatsUsed',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.purpleAccent,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Different\nSeats Used',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: EasySitColors.secondaryText,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Settings Options Card
  Widget _buildSettingsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: EasySitColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EasySitColors.divider, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: EasySitColors.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuRow(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            isFirst: true,
            onTap: _showEditProfileSheet,
          ),
          const Divider(height: 1, thickness: 1, color: EasySitColors.divider),
          _buildMenuRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notification',
            onTap: () {
              Navigator.push(
                context,
                AppPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
          const Divider(height: 1, thickness: 1, color: EasySitColors.divider),
          _buildMenuRow(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: _showHelpAndSupportDialog,
          ),
          const Divider(height: 1, thickness: 1, color: EasySitColors.divider),
          _buildMenuRow(
            icon: Icons.info_outline_rounded,
            title: 'About EasySit',
            isLast: true,
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(20) : Radius.zero,
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 22, color: EasySitColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: EasySitColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: EasySitColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. Logout Button
  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: EasySitColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EasySitColors.errorBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: EasySitColors.cardShadow,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _logout,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: EasySitColors.error, size: 22),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: EasySitColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
