import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_home_screen.dart';
import 'qr_scanner_screen.dart';
import 'session_screen.dart';
import 'profile_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/swipe_navigation_wrapper.dart';
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
    super.dispose();
  }

  void _onBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        AppPageRoute(builder: (_) => const StudentHomeScreen()),
        (route) => false,
      );
    }
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
      child: SwipeNavigationWrapper(
        enableSwipeBack: true,
        onSwipeBack: _onBack,
        child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          toolbarHeight: 70,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFF8FAFC),
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
        body:
            _user == null
                ? _buildEmptyState()
                : StreamBuilder<DocumentSnapshot>(
                  stream:
                      _firestore.collection('users').doc(_user.uid).snapshots(),
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
                        remoteCreatedAt?.toDate() ??
                        _user.metadata.creationTime;
                    final clearedDate =
                        _localClearedAt ??
                        remoteClearedAt?.toDate() ??
                        NotificationService.clearedNotifier.value;

                    DateTime? cutoff = userCreatedDate;
                    if (clearedDate != null &&
                        (cutoff == null || clearedDate.isAfter(cutoff))) {
                      cutoff = clearedDate;
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream:
                          _firestore
                              .collection('notifications')
                              .where('userId', whereIn: ['all', _user.uid])
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            ),
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
                        var docs =
                            snapshot.data!.docs.where((doc) {
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
                          final ta =
                              (a.data() as Map<String, dynamic>)['timestamp']
                                  as Timestamp?;
                          final tb =
                              (b.data() as Map<String, dynamic>)['timestamp']
                                  as Timestamp?;
                          if (ta == null && tb == null) return 0;
                          if (ta == null) return 1;
                          if (tb == null) return -1;
                          return tb.compareTo(ta);
                        });

                        // Group documents by date (Today, Yesterday, Date)
                        final now = DateTime.now();
                        final Map<String, List<QueryDocumentSnapshot>> groupedDocs = {};
                        for (var doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final ts = data['timestamp'] as Timestamp?;
                          final dt = ts?.toDate() ?? now;
                          final groupKey = _getDateGroupTitle(dt, now);
                          groupedDocs.putIfAbsent(groupKey, () => []).add(doc);
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            for (int groupIdx = 0; groupIdx < groupedDocs.length; groupIdx++) ...[
                              Builder(
                                builder: (context) {
                                  final entry = groupedDocs.entries.elementAt(groupIdx);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: 4,
                                          right: 4,
                                          top: groupIdx == 0 ? 8 : 20,
                                          bottom: 12,
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      for (var doc in entry.value)
                                        _buildNotificationCard(context, doc),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'] as Timestamp?;
    final title = data['title']?.toString() ?? 'Notification';
    final message = data['message']?.toString() ?? '';
    final styleConfig = _getNotificationStyle(title, message);

    String timeOnlyStr = '';
    String fullTimeStr = '';

    if (ts != null) {
      final dt = ts.toDate();
      timeOnlyStr = _formatTimeOnly(dt);
      fullTimeStr = _formatFullDateTime(dt);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade100,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            _showNotificationDetailDialog(
              context,
              data,
              fullTimeStr.isNotEmpty ? fullTimeStr : timeOnlyStr,
              styleConfig,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: styleConfig.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      styleConfig.icon,
                      color: styleConfig.iconColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (timeOnlyStr.isNotEmpty)
                            Text(
                              timeOnlyStr,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black87,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTimeOnly(DateTime dt) {
    final hour = dt.hour;
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${hour12.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  static String _formatFullDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final timeStr = _formatTimeOnly(dt);
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $timeStr';
  }

  static String _getDateGroupTitle(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays <= 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      if (dt.year == now.year) {
        return '${months[dt.month - 1]} ${dt.day}';
      } else {
        return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
      }
    }
  }

  static _NotificationStyleConfig _getNotificationStyle(String title, String message) {
    final lowerTitle = title.toLowerCase();
    final lowerMessage = message.toLowerCase();

    // 1. Feedback / Rating / Suggestions
    if (lowerTitle.contains('feedback') ||
        lowerTitle.contains('rating') ||
        lowerTitle.contains('review') ||
        lowerMessage.contains('feedback') ||
        lowerMessage.contains('suggestions')) {
      return const _NotificationStyleConfig(
        icon: Icons.star_outline_rounded,
        iconColor: Color(0xFFF59E0B),
        backgroundColor: Color(0xFFFEF9E7),
        borderColor: Color(0xFFFDE68A),
      );
    }

    // 2. Session Extended
    if (lowerTitle.contains('extended') || lowerMessage.contains('extended')) {
      return const _NotificationStyleConfig(
        icon: Icons.check_circle_outline_rounded,
        iconColor: Color(0xFF10B981),
        backgroundColor: Color(0xFFE8F8F0),
        borderColor: Color(0xFFA7F3D0),
      );
    }

    // 3. Session Ended / Released / Expired
    if (lowerTitle.contains('ended') ||
        lowerTitle.contains('released') ||
        lowerTitle.contains('cancelled') ||
        lowerTitle.contains('cancel') ||
        lowerMessage.contains('has ended') ||
        lowerMessage.contains('released')) {
      return const _NotificationStyleConfig(
        icon: Icons.logout_rounded,
        iconColor: Color(0xFFEF4444),
        backgroundColor: Color(0xFFFFEEEE),
        borderColor: Color(0xFFFECACA),
      );
    }

    // 4. Session Reminder / Expiring soon / Alert
    if (lowerTitle.contains('reminder') ||
        lowerTitle.contains('expiring') ||
        lowerTitle.contains('alert') ||
        lowerTitle.contains('warning') ||
        lowerMessage.contains('reminder') ||
        lowerMessage.contains('expire in')) {
      return const _NotificationStyleConfig(
        icon: Icons.notifications_none_rounded,
        iconColor: Color(0xFFF59E0B),
        backgroundColor: Color(0xFFFEF9E7),
        borderColor: Color(0xFFFDE68A),
      );
    }

    // 5. Session Started / Booked / Confirmed
    if (lowerTitle.contains('started') ||
        lowerTitle.contains('booked') ||
        lowerTitle.contains('confirmed') ||
        lowerMessage.contains('started successfully')) {
      return const _NotificationStyleConfig(
        icon: Icons.access_time_rounded,
        iconColor: Color(0xFF3B82F6),
        backgroundColor: Color(0xFFEFF4FF),
        borderColor: Color(0xFFBFDBFE),
      );
    }

    // 6. Library Notice / Maintenance / Announcement / Admin
    if (lowerTitle.contains('notice') ||
        lowerTitle.contains('library') ||
        lowerTitle.contains('maintenance') ||
        lowerTitle.contains('announcement') ||
        lowerTitle.contains('broadcast')) {
      return const _NotificationStyleConfig(
        icon: Icons.campaign_outlined,
        iconColor: Color(0xFF8B5CF6),
        backgroundColor: Color(0xFFF5EEFD),
        borderColor: Color(0xFFDDD6FE),
      );
    }

    // 7. Default
    return const _NotificationStyleConfig(
      icon: Icons.notifications_active_outlined,
      iconColor: Color(0xFF5C55F2),
      backgroundColor: Color(0xFFEEF2FF),
      borderColor: Color(0xFFC7D2FE),
    );
  }

  void _showNotificationDetailDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String timeStr,
    _NotificationStyleConfig styleConfig,
  ) {
    final title = data['title']?.toString() ?? 'Notification';
    final message = data['message']?.toString() ?? '';
    final isAlert = title.toLowerCase().contains('expiring') ||
        title.toLowerCase().contains('alert');

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.90, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: Colors.white,
          elevation: 12,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Leading Icon Badge + Title + Top-Right Close Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: styleConfig.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: styleConfig.borderColor, width: 1.2),
                      ),
                      child: Icon(
                        styleConfig.icon,
                        color: styleConfig.iconColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    // Close button at top right corner
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Timestamp Pill
                if (timeStr.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Full Message Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14.5,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bottom Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(
                              color: Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isAlert ||
                        title.toLowerCase().contains('session') ||
                        title.toLowerCase().contains('booked')) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.pushReplacement(
                                context,
                                AppPageRoute(
                                  builder: (_) => const SessionScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'View Session',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

class _NotificationStyleConfig {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  const _NotificationStyleConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}
