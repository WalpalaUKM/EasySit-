import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_home_screen.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/app_page_route.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  DateTime? _localClearedAt;

  @override
  void initState() {
    super.initState();
    // Mark as seen immediately so red dot on bell icon is removed
    NotificationService.markNotificationsAsSeen();
  }

  @override
  void dispose() {
    // Auto clean notifications when user leaves this screen
    if (_user != null) {
      NotificationService.autoCleanNotifications(_user.uid);
    }
    super.dispose();
  }

  void _onBack() {
    if (_user != null) {
      NotificationService.autoCleanNotifications(_user.uid);
    }
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
  }

  void _onNavTab(int index) {
    if (_user != null) {
      NotificationService.autoCleanNotifications(_user.uid);
    }
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

  Future<void> _clearAll() async {
    if (_user == null) return;
    final now = DateTime.now();
    setState(() {
      _localClearedAt = now;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'All notifications cleared',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await NotificationService.autoCleanNotifications(_user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          toolbarHeight: 70,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Center(
              child: GestureDetector(
                onTap: _onBack,
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
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: const Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: TextButton(
                onPressed: _clearAll,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: Color(0xFF5C55F2),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: -1,
          onTabSelected: _onNavTab,
        ),
        body: _user == null
            ? _buildEmptyState()
            : StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(_user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  // Prevent rendering old notifications before cleared status is loaded
                  if (userSnap.connectionState == ConnectionState.waiting &&
                      !userSnap.hasData &&
                      _localClearedAt == null &&
                      NotificationService.clearedNotifier.value == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF5C55F2),
                      ),
                    );
                  }

                  Timestamp? remoteCreatedAt;
                  Timestamp? remoteClearedAt;
                  if (userSnap.hasData &&
                      userSnap.data != null &&
                      userSnap.data!.exists) {
                    final userData =
                        userSnap.data!.data() as Map<String, dynamic>?;
                    remoteCreatedAt = userData?['createdAt'] as Timestamp?;
                    remoteClearedAt =
                        userData?['clearedNotificationAt'] as Timestamp?;
                  }

                  // 1. Newly created user: do not show notifications before user creation
                  final userCreatedDate =
                      remoteCreatedAt?.toDate() ?? _user.metadata.creationTime;
                  final clearedDate = _localClearedAt ??
                      remoteClearedAt?.toDate() ??
                      NotificationService.clearedNotifier.value;

                  DateTime? cutoff = userCreatedDate;
                  if (clearedDate != null &&
                      (cutoff == null || clearedDate.isAfter(cutoff))) {
                    cutoff = clearedDate;
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('notifications')
                        .where('userId', whereIn: ['all', _user.uid])
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Filter out:
                      // - Notifications sent before new user was created
                      // - Notifications that have already been cleared
                      var docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ts = data['timestamp'] as Timestamp?;
                        if (ts == null) return true; // Newly sent
                        if (cutoff != null) {
                          return ts.toDate().isAfter(cutoff);
                        }
                        return true;
                      }).toList();

                      if (docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      // Sort by timestamp (newest first)
                      docs.sort((a, b) {
                        final ta = (a.data() as Map<String, dynamic>)['timestamp']
                            as Timestamp?;
                        final tb = (b.data() as Map<String, dynamic>)['timestamp']
                            as Timestamp?;
                        if (ta == null && tb == null) return 0;
                        if (ta == null) return 1;
                        if (tb == null) return -1;
                        return tb.compareTo(ta);
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final Timestamp? ts =
                              data['timestamp'] as Timestamp?;
                          String timeStr = '';

                          if (ts != null) {
                            final dt = ts.toDate();
                            List<String> months = [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec',
                            ];
                            String amPm = dt.hour >= 12 ? 'PM' : 'AM';
                            int hour12 = dt.hour > 12
                                ? dt.hour - 12
                                : (dt.hour == 0 ? 12 : dt.hour);
                            timeStr =
                                '${months[dt.month - 1]} ${dt.day}, ${hour12.toString()}:${dt.minute.toString().padLeft(2, '0')} $amPm';
                          }

                          final title = data['title'] ?? 'Notification';
                          bool isAlert =
                              title.toLowerCase().contains('expiring') ||
                              title.toLowerCase().contains('alert');

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () async {
                                  if (data['userId'] != 'all') {
                                    doc.reference.delete().catchError((_) {});
                                  }
                                  await NotificationService
                                      .autoCleanNotifications(
                                    _user.uid,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(
                                      context,
                                      title.contains('Expiring')
                                          ? 'session_expiring'
                                          : 'view_session',
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isAlert
                                              ? Colors.orange.shade50
                                              : Colors.blue.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isAlert
                                              ? Icons.warning_amber_rounded
                                              : Icons
                                                  .notifications_active_rounded,
                                          color: isAlert
                                              ? Colors.orange.shade600
                                              : Colors.blue.shade600,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                if (timeStr.isNotEmpty)
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              data['message'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Colors.blue.shade200,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up! We'll notify you\nwhen there's an update.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
