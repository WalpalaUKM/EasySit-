import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr/qr.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'login_screen.dart';
import '../utils/app_page_route.dart';
import '../services/auth_persistence_service.dart';

import '../utils/app_colors.dart';

// Shared UI Helpers
InputDecoration _buildEasySitInputDecoration({
  required String labelText,
  String? hintText,
  Widget? prefixIcon,
  String? errorText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    errorText: errorText,
    errorStyle: const TextStyle(color: EasySitColors.errorFg, fontSize: 12),
    labelStyle: const TextStyle(color: EasySitColors.bodyText, fontSize: 14),
    hintStyle: const TextStyle(color: EasySitColors.secondaryText, fontSize: 14),
    filled: true,
    fillColor: EasySitColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: EasySitColors.divider, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: EasySitColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: EasySitColors.errorFg, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: EasySitColors.errorFg, width: 2),
    ),
  );
}

Widget _buildEasySitCard({required Widget child, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding}) {
  return Card(
    elevation: 0,
    margin: margin ?? const EdgeInsets.only(bottom: 16),
    color: EasySitColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: EasySitColors.divider, width: 1),
    ),
    child: Padding(
      padding: padding ?? const EdgeInsets.all(20.0),
      child: child,
    ),
  );
}

// ============================================================
// MAIN ADMIN DASHBOARD
// ============================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  final List<String> _menuTitles = [
    'Home Overview',
    'Manage Buildings',
    'Manage Floors',
    'Manage Rooms',
    'Manage Seats & QR',
    'Student Activity & Access',
    'Send Notification',
    'Admin Profile',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard_rounded,
    Icons.apartment_rounded,
    Icons.layers_rounded,
    Icons.meeting_room_rounded,
    Icons.qr_code_2_rounded,
    Icons.manage_accounts_rounded,
    Icons.campaign_rounded,
    Icons.person_rounded,
  ];

  final List<Color> _menuIconColors = [
    EasySitColors.primary,
    EasySitColors.computerLabFg,
    EasySitColors.darkBlue,
    EasySitColors.purpleAccent,
    EasySitColors.purpleBlue,
    EasySitColors.primary,
    EasySitColors.pendingAccent,
    EasySitColors.secondaryText,
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: EasySitColors.appBackground,
        appBar: AppBar(
          leading: _selectedIndex != 0
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to Dashboard',
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                )
              : null,
          title: Text(
            _selectedIndex == 0 ? 'Admin Dashboard' : _menuTitles[_selectedIndex],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: EasySitColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Admin Profile',
              onPressed: () {
                setState(() {
                  _selectedIndex = 7;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: () async {
                await AuthPersistenceService.clear();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    AppPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: EasySitColors.surface,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                decoration: const BoxDecoration(
                  color: EasySitColors.deepPurple,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: EasySitColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'EasySit',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Administrator Portal',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: EasySitColors.logoLavender,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: EasySitColors.successFg,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Active Admin Session',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: _menuTitles.length,
                  itemBuilder: (context, index) {
                    final bool isSelected = _selectedIndex == index;
                    final Color itemColor = _menuIconColors[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSelected ? EasySitColors.primaryTint : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? Border.all(color: EasySitColors.softBlueBorder.withValues(alpha: 0.6))
                            : null,
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? itemColor.withValues(alpha: 0.16)
                                : itemColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _menuIcons[index],
                            color: itemColor,
                            size: 19,
                          ),
                        ),
                        title: Text(
                          _menuTitles[index],
                          style: TextStyle(
                            color: isSelected ? EasySitColors.primary : EasySitColors.mainText,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                        trailing: isSelected
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: EasySitColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: EasySitColors.divider, width: 1),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: EasySitColors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: EasySitColors.errorFg,
                      size: 19,
                    ),
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: EasySitColors.errorFg,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  onTap: () async {
                    await AuthPersistenceService.clear();
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        AppPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        body: _buildScreen(_selectedIndex),
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return AdminHomeScreen(
          onNavigate: (targetIndex) {
            setState(() {
              _selectedIndex = targetIndex;
            });
          },
        );
      case 1:
        return const ManageBuildingsScreen();
      case 2:
        return const ManageFloorsScreen();
      case 3:
        return const ManageRoomsScreen();
      case 4:
        return const ManageSeatsScreen();
      case 5:
        return const StudentActivityAccessScreen();
      case 6:
        return const SendNotificationScreen();
      case 7:
        return const AdminProfileScreen();
      default:
        return const Center(
          child: Text(
            'Unknown Screen',
            style: TextStyle(color: EasySitColors.mainText),
          ),
        );
    }
  }
}

// ============================================================
// 0. ADMIN HOME OVERVIEW SCREEN (Matches Design Mockup)
// ============================================================
class AdminHomeScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const AdminHomeScreen({super.key, required this.onNavigate});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: currentUser != null
                          ? firestore.collection('users').doc(currentUser.uid).get()
                          : null,
                      builder: (context, snapshot) {
                        String adminName = 'Admin';
                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>?;
                          if (data != null && data['fullName'] != null && (data['fullName'] as String).trim().isNotEmpty) {
                            adminName = (data['fullName'] as String).trim();
                          }
                        } else if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
                          adminName = currentUser.displayName!;
                        }

                        return Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_getGreeting()}, ',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: EasySitColors.secondaryText,
                                ),
                              ),
                              TextSpan(
                                text: adminName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: EasySitColors.mainText,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Spaces, seat usage and student access.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                        color: EasySitColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: EasySitColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EasySitColors.softBlueBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.shield_rounded,
                      size: 14,
                      color: EasySitColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Admin',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: EasySitColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Featured Dark Banner Card (Seat Usage Overview)
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('seats').snapshots(),
            builder: (context, seatsSnapshot) {
              int totalSeats = 0;
              int occupiedSeats = 0;
              int availableSeats = 0;

              if (seatsSnapshot.hasData) {
                totalSeats = seatsSnapshot.data!.docs.length;
                for (var doc in seatsSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String status = (data['status'] ?? 'available').toString();
                  if (status == 'booked' || status == 'occupied') {
                    occupiedSeats++;
                  } else if (status == 'available') {
                    availableSeats++;
                  }
                }
              }

              int occupiedPct = totalSeats > 0 ? ((occupiedSeats / totalSeats) * 100).round() : 0;
              double progressVal = totalSeats > 0 ? (occupiedSeats / totalSeats) : 0.0;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      EasySitColors.deepPurple,
                      EasySitColors.splashShadow,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: EasySitColors.deepPurple.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.pie_chart_rounded,
                                size: 16,
                                color: EasySitColors.logoLavender,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Seat Usage Overview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: EasySitColors.successFg,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'LIVE SYNC',
                                style: TextStyle(
                                  color: EasySitColors.logoLavender,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$occupiedPct%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'occupied right now',
                          style: TextStyle(
                            color: EasySitColors.logoLavender,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressVal,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(EasySitColors.primary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildHeroStatPill(
                            label: 'In Use',
                            value: occupiedSeats.toString(),
                            dotColor: EasySitColors.pendingPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHeroStatPill(
                            label: 'Available',
                            value: availableSeats.toString(),
                            dotColor: EasySitColors.successFg,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildHeroStatPill(
                            label: 'Total Capacity',
                            value: totalSeats.toString(),
                            dotColor: EasySitColors.softBlueBorder,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: const [
                        Icon(
                          Icons.sync_rounded,
                          size: 13,
                          color: EasySitColors.mutedLavender,
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Auto-updated real-time campus seating',
                            style: TextStyle(
                              color: EasySitColors.mutedLavender,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 2. Metric Summary Cards Row (Buildings, Rooms, Total seats)
          StreamBuilder<QuerySnapshot>(
            stream: firestore.collection('buildings').snapshots(),
            builder: (context, bSnapshot) {
              int buildingCount = bSnapshot.hasData ? bSnapshot.data!.docs.length : 0;
              String formattedBuildings = buildingCount.toString().padLeft(2, '0');

              return StreamBuilder<QuerySnapshot>(
                stream: firestore.collection('rooms').snapshots(),
                builder: (context, rSnapshot) {
                  int roomCount = rSnapshot.hasData ? rSnapshot.data!.docs.length : 0;
                  String formattedRooms = roomCount.toString().padLeft(2, '0');

                  return StreamBuilder<QuerySnapshot>(
                    stream: firestore.collection('seats').snapshots(),
                    builder: (context, sSnapshot) {
                      int seatCount = sSnapshot.hasData ? sSnapshot.data!.docs.length : 0;

                      return Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              number: formattedBuildings,
                              label: 'Buildings',
                              icon: Icons.apartment_rounded,
                              iconColor: EasySitColors.computerLabFg,
                              iconBg: EasySitColors.computerLabBg,
                              onTap: () => onNavigate(1),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              number: formattedRooms,
                              label: 'Rooms',
                              icon: Icons.meeting_room_rounded,
                              iconColor: EasySitColors.purpleAccent,
                              iconBg: EasySitColors.accentTint,
                              onTap: () => onNavigate(3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              number: seatCount.toString(),
                              label: 'Total seats',
                              icon: Icons.event_seat_rounded,
                              iconColor: EasySitColors.primary,
                              iconBg: EasySitColors.primaryTint,
                              onTap: () => onNavigate(4),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // 3. Student Access Card
          StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('users')
                .where('userType', isEqualTo: 'student')
                .snapshots(),
            builder: (context, uSnapshot) {
              int activeStudents = 0;
              int blockedStudents = 0;

              if (uSnapshot.hasData && uSnapshot.data != null) {
                for (var doc in uSnapshot.data!.docs) {
                  try {
                    final raw = doc.data();
                    if (raw is Map) {
                      final bool isBlocked = raw['isBlocked'] == true;
                      if (isBlocked) {
                        blockedStudents++;
                      } else {
                        activeStudents++;
                      }
                    }
                  } catch (_) {}
                }
              }

              String formattedActive = activeStudents.toString().padLeft(2, '0');
              String formattedBlocked = blockedStudents.toString().padLeft(2, '0');

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: EasySitColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: EasySitColors.divider, width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: EasySitColors.cardShadowColor,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: EasySitColors.primaryTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.manage_accounts_rounded,
                                  color: EasySitColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'Student Access Status',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: EasySitColors.mainText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Enrolled accounts & permissions',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: EasySitColors.secondaryText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => onNavigate(5),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Manage',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: EasySitColors.primary,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: EasySitColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: EasySitColors.successBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EasySitColors.successBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: EasySitColors.successFg,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formattedActive,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: EasySitColors.successFg,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Active',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: EasySitColors.successFg,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: EasySitColors.errorBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: EasySitColors.errorBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.block_rounded,
                                    color: EasySitColors.errorFg,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formattedBlocked,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: EasySitColors.errorFg,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Blocked',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: EasySitColors.errorFg,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: EasySitColors.secondaryText,
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Live access counts • Manage individual permissions in Student Activity',
                            style: TextStyle(
                              fontSize: 11,
                              color: EasySitColors.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. Quick Actions Section (2x2 Grid)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: EasySitColors.mainText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: EasySitColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Shortcuts',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: EasySitColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _buildQuickActionCard(
                icon: Icons.apartment_rounded,
                iconColor: EasySitColors.computerLabFg,
                iconBg: EasySitColors.computerLabBg,
                title: 'Manage Buildings',
                subtitle: 'Campus blocks',
                onTap: () => onNavigate(1),
              ),
              _buildQuickActionCard(
                icon: Icons.qr_code_2_rounded,
                iconColor: EasySitColors.purpleAccent,
                iconBg: EasySitColors.accentTint,
                title: 'Seats & QR Codes',
                subtitle: 'Layouts & codes',
                onTap: () => onNavigate(4),
              ),
              _buildQuickActionCard(
                icon: Icons.manage_accounts_rounded,
                iconColor: EasySitColors.primary,
                iconBg: EasySitColors.primaryTint,
                title: 'Student Activity',
                subtitle: 'Usage & access',
                onTap: () => onNavigate(5),
              ),
              _buildQuickActionCard(
                icon: Icons.campaign_rounded,
                iconColor: EasySitColors.pendingAccent,
                iconBg: EasySitColors.pendingBg,
                title: 'Send Notification',
                subtitle: 'Broadcast alerts',
                onTap: () => onNavigate(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Hero Stat Pill Helper
  Widget _buildHeroStatPill({
    required String label,
    required String value,
    required Color dotColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: EasySitColors.logoLavender,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Metric Card Helper
  Widget _buildMetricCard({
    required String number,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: EasySitColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EasySitColors.divider, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: EasySitColors.cardShadowColor,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                number,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: EasySitColors.mainText,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: EasySitColors.secondaryText,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Action Card Helper
  Widget _buildQuickActionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: EasySitColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: EasySitColors.divider, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: EasySitColors.cardShadowColor,
                blurRadius: 6,
                offset: Offset(0, 2),
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: iconColor, size: 19),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: EasySitColors.secondaryText.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: EasySitColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 1. MANAGE BUILDINGS SCREEN
// ============================================================
class ManageBuildingsScreen extends StatefulWidget {
  const ManageBuildingsScreen({super.key});

  @override
  State<ManageBuildingsScreen> createState() => _ManageBuildingsScreenState();
}

class _ManageBuildingsScreenState extends State<ManageBuildingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addBuilding() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter building name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('buildings').add({
        'name': _nameController.text.trim(),
        'isBlocked': false,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Building added!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteBuilding(String buildingId) async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: EasySitColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Building', style: TextStyle(color: EasySitColors.mainText, fontWeight: FontWeight.bold)),
            content: const Text(
              'This will delete ALL Floors, Rooms, and Seats inside this building. Continue?',
              style: TextStyle(color: EasySitColors.bodyText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: EasySitColors.errorFg),
                child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      QuerySnapshot floorsSnapshot =
          await _firestore
              .collection('floors')
              .where('buildingId', isEqualTo: buildingId)
              .get();

      for (var floorDoc in floorsSnapshot.docs) {
        String floorId = floorDoc.id;
        QuerySnapshot roomsSnapshot =
            await _firestore
                .collection('rooms')
                .where('floorId', isEqualTo: floorId)
                .get();

        for (var roomDoc in roomsSnapshot.docs) {
          String roomId = roomDoc.id;
          QuerySnapshot seatsSnapshot =
              await _firestore
                  .collection('seats')
                  .where('roomId', isEqualTo: roomId)
                  .get();
          for (var seatDoc in seatsSnapshot.docs) {
            await _firestore.collection('seats').doc(seatDoc.id).delete();
          }
          await _firestore.collection('rooms').doc(roomId).delete();
        }
        await _firestore.collection('floors').doc(floorId).delete();
      }
      await _firestore.collection('buildings').doc(buildingId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Building and all data deleted!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleBuildingMaintenance(
    String buildingId,
    String buildingName,
    bool isCurrentlyBlocked,
    String? currentReason,
  ) async {
    if (!isCurrentlyBlocked) {
      // Prompt admin to close/block building for maintenance
      final reasonController = TextEditingController(text: 'Facility maintenance & servicing');
      final notifyController = TextEditingController(
        text: '$buildingName is temporarily closed for maintenance. Any active seat bookings have been released, and seat reservations are paused until further notice.',
      );
      bool shouldNotify = true;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: EasySitColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.block_rounded, color: EasySitColors.warningFg),
                  SizedBox(width: 8),
                  Text(
                    'Close / Block Building',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.mainText,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Close "$buildingName" for maintenance or facility work.',
                      style: const TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EasySitColors.warningBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EasySitColors.warningBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: EasySitColors.warningFg, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All active and pending seat bookings in this building will be automatically released immediately. Students cannot book seats here until reopened.',
                              style: TextStyle(fontSize: 12, color: EasySitColors.warningFg, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Reason for Closure',
                        hintText: 'e.g. Electrical maintenance, deep cleaning',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: shouldNotify,
                          activeColor: EasySitColors.primary,
                          onChanged: (val) {
                            setDlgState(() => shouldNotify = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Send notification to all students',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EasySitColors.mainText),
                          ),
                        ),
                      ],
                    ),
                    if (shouldNotify) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notifyController,
                        maxLines: 3,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Notification Message',
                          hintText: 'Message to broadcast to students...',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasySitColors.warningFg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close Building & Release Seats'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        final reason = reasonController.text.trim().isEmpty ? 'Maintenance in progress' : reasonController.text.trim();

        // 1. Update building in Firestore
        await _firestore.collection('buildings').doc(buildingId).update({
          'isBlocked': true,
          'status': 'maintenance',
          'blockReason': reason,
          'blockedAt': FieldValue.serverTimestamp(),
        });

        // 2. Query all floors, rooms, and seats under this building to auto-release
        int releasedCount = 0;
        final floorsSnap = await _firestore.collection('floors').where('buildingId', isEqualTo: buildingId).get();

        for (var floorDoc in floorsSnap.docs) {
          final roomsSnap = await _firestore.collection('rooms').where('floorId', isEqualTo: floorDoc.id).get();
          for (var roomDoc in roomsSnap.docs) {
            final seatsSnap = await _firestore.collection('seats').where('roomId', isEqualTo: roomDoc.id).get();

            WriteBatch batch = _firestore.batch();
            int batchCount = 0;

            for (var seatDoc in seatsSnap.docs) {
              final sData = seatDoc.data();
              final status = sData['status'] ?? 'available';
              if (status == 'booked' || status == 'pending' || sData['bookedBy'] != null || sData['pendingBy'] != null) {
                releasedCount++;
              }

              batch.update(seatDoc.reference, {
                'status': 'unavailable',
                'isBuildingBlocked': true,
                'buildingId': buildingId,
                'blockedReason': reason,
                'bookedBy': FieldValue.delete(),
                'bookedAt': FieldValue.delete(),
                'pendingBy': FieldValue.delete(),
                'pendingAt': FieldValue.delete(),
              });
              batchCount++;

              if (batchCount >= 450) {
                await batch.commit();
                batch = _firestore.batch();
                batchCount = 0;
              }
            }

            if (batchCount > 0) {
              await batch.commit();
            }
          }
        }

        // 3. Send broadcast notification if selected
        if (shouldNotify && notifyController.text.trim().isNotEmpty) {
          await _firestore.collection('notifications').add({
            'title': '⚠️ Building Closed: $buildingName',
            'message': notifyController.text.trim(),
            'buildingId': buildingId,
            'buildingName': buildingName,
            'reason': reason,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': 'all',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Building closed. $releasedCount active bookings auto-released.'),
              backgroundColor: EasySitColors.warningFg,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
          );
        }
      }
      setState(() => _isLoading = false);
    } else {
      // Reopen building
      final notifyController = TextEditingController(
        text: '$buildingName is now reopened! Seats are once again available for reservation.',
      );
      bool shouldNotify = true;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: EasySitColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.lock_open_rounded, color: EasySitColors.successFg),
                  SizedBox(width: 8),
                  Text(
                    'Reopen Building',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.mainText,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reopen "$buildingName" for student bookings? All seats in this building will become available again.',
                      style: const TextStyle(fontSize: 13, color: EasySitColors.bodyText),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: shouldNotify,
                          activeColor: EasySitColors.primary,
                          onChanged: (val) {
                            setDlgState(() => shouldNotify = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Notify students that building is reopened',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EasySitColors.mainText),
                          ),
                        ),
                      ],
                    ),
                    if (shouldNotify) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notifyController,
                        maxLines: 3,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Notification Message',
                          hintText: 'Message to broadcast to students...',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasySitColors.successFg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reopen Building'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        // 1. Update building doc in Firestore
        await _firestore.collection('buildings').doc(buildingId).update({
          'isBlocked': false,
          'status': 'active',
          'blockReason': FieldValue.delete(),
          'unblockedAt': FieldValue.serverTimestamp(),
        });

        // 2. Query all floors, rooms, and seats under this building to reset to available
        final floorsSnap = await _firestore.collection('floors').where('buildingId', isEqualTo: buildingId).get();

        for (var floorDoc in floorsSnap.docs) {
          final roomsSnap = await _firestore.collection('rooms').where('floorId', isEqualTo: floorDoc.id).get();
          for (var roomDoc in roomsSnap.docs) {
            final seatsSnap = await _firestore.collection('seats').where('roomId', isEqualTo: roomDoc.id).get();

            WriteBatch batch = _firestore.batch();
            int batchCount = 0;

            for (var seatDoc in seatsSnap.docs) {
              final sData = seatDoc.data();
              if (sData['isBuildingBlocked'] == true || sData['status'] == 'unavailable') {
                batch.update(seatDoc.reference, {
                  'status': 'available',
                  'isBuildingBlocked': FieldValue.delete(),
                  'blockedReason': FieldValue.delete(),
                });
                batchCount++;

                if (batchCount >= 450) {
                  await batch.commit();
                  batch = _firestore.batch();
                  batchCount = 0;
                }
              }
            }

            if (batchCount > 0) {
              await batch.commit();
            }
          }
        }

        // 3. Send notification if checked
        if (shouldNotify && notifyController.text.trim().isNotEmpty) {
          await _firestore.collection('notifications').add({
            'title': '✅ Building Reopened: $buildingName',
            'message': notifyController.text.trim(),
            'buildingId': buildingId,
            'buildingName': buildingName,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': 'all',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Building "$buildingName" reopened! Seats are now available.'),
              backgroundColor: EasySitColors.successFg,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
          );
        }
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBuildingNoticeDialog(String buildingId, String buildingName) async {
    final titleController = TextEditingController(text: 'Announcement: $buildingName');
    final messageController = TextEditingController();

    bool? send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EasySitColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.campaign_rounded, color: EasySitColors.pendingAccent),
            SizedBox(width: 8),
            Text(
              'Send Building Notice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: EasySitColors.mainText,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Broadcast an announcement about $buildingName to all students.',
                style: const TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: _buildEasySitInputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g. Science Library Notice',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: _buildEasySitInputDecoration(
                  labelText: 'Notice Message',
                  hintText: 'Enter notice details for students...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EasySitColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Broadcast'),
          ),
        ],
      ),
    );

    if (send != true) return;

    try {
      await _firestore.collection('notifications').add({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'buildingId': buildingId,
        'buildingName': buildingName,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': 'all',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Building notice broadcasted to all students!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
        );
      }
    }
  }

  void _showBuildingActionSheet(String buildingId, String buildingName, bool isBlocked, String? reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EasySitColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      buildingName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBlocked ? EasySitColors.warningBg : EasySitColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isBlocked ? EasySitColors.warningBorder : EasySitColors.successBorder),
                    ),
                    child: Text(
                      isBlocked ? 'Closed / Maintenance' : 'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? EasySitColors.warningFg : EasySitColors.successFg,
                      ),
                    ),
                  ),
                ],
              ),
              if (isBlocked && (reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(fontSize: 13, color: EasySitColors.warningFg, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: EasySitColors.divider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBlocked ? EasySitColors.successBg : EasySitColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                    size: 20,
                  ),
                ),
                title: Text(
                  isBlocked ? 'Reopen Building' : 'Close Building for Maintenance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                  ),
                ),
                subtitle: Text(
                  isBlocked
                      ? 'Resume student seat reservations'
                      : 'Auto-release active seats and pause reservations',
                  style: const TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleBuildingMaintenance(buildingId, buildingName, isBlocked, reason);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EasySitColors.pendingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: EasySitColors.pendingAccent,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Send Building Announcement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.mainText,
                  ),
                ),
                subtitle: const Text(
                  'Broadcast notice about this building to all students',
                  style: TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendBuildingNoticeDialog(buildingId, buildingName);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EasySitColors.errorBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: EasySitColors.errorFg,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete Building',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.errorFg,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete building and all its floors, rooms, and seats',
                  style: TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteBuilding(buildingId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Text(
            'Manage Buildings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add buildings, manage maintenance closures, and broadcast notices.',
            style: TextStyle(
              fontSize: 13,
              color: EasySitColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          _buildEasySitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Building Name',
                    hintText: 'e.g. Science Library',
                    prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addBuilding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasySitColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Text(
                            'Add Building',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Building List',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('buildings')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: EasySitColors.errorFg),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: EasySitColors.primary),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No buildings added yet.',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  final String buildingName = data['name'] ?? 'Unnamed';
                  final bool isBlocked = data['isBlocked'] ?? false;
                  final String? blockReason = data['blockReason'] as String?;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: EasySitColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBlocked ? EasySitColors.warningBorder : EasySitColors.divider,
                        width: isBlocked ? 1.5 : 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: EasySitColors.cardShadowColor,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showBuildingActionSheet(doc.id, buildingName, isBlocked, blockReason),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isBlocked ? EasySitColors.warningBg : EasySitColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isBlocked ? Icons.lock_clock_rounded : Icons.business_rounded,
                                color: isBlocked ? EasySitColors.warningFg : EasySitColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          buildingName,
                                          style: const TextStyle(
                                            color: EasySitColors.mainText,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBlocked ? EasySitColors.warningBg : EasySitColors.successBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isBlocked ? EasySitColors.warningBorder : EasySitColors.successBorder,
                                          ),
                                        ),
                                        child: Text(
                                          isBlocked ? 'Maintenance' : 'Active',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isBlocked ? EasySitColors.warningFg : EasySitColors.successFg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  if (isBlocked)
                                    Text(
                                      'Closed: ${blockReason ?? 'Maintenance in progress'}',
                                      style: const TextStyle(
                                        color: EasySitColors.warningFg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  else
                                    const Text(
                                      'Available for reservations',
                                      style: TextStyle(
                                        color: EasySitColors.secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                                    size: 20,
                                  ),
                                  tooltip: isBlocked ? 'Reopen Building' : 'Close for Maintenance',
                                  onPressed: () => _toggleBuildingMaintenance(doc.id, buildingName, isBlocked, blockReason),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.campaign_outlined, color: EasySitColors.pendingAccent, size: 20),
                                  tooltip: 'Send Notice',
                                  onPressed: () => _sendBuildingNoticeDialog(doc.id, buildingName),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: EasySitColors.errorFg, size: 20),
                                  onPressed: () => _deleteBuilding(doc.id),
                                  tooltip: 'Delete Building',
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
        ],
      ),
    );
  }
}

// ============================================================
// 2. MANAGE FLOORS SCREEN
// ============================================================
class ManageFloorsScreen extends StatefulWidget {
  const ManageFloorsScreen({super.key});

  @override
  State<ManageFloorsScreen> createState() => _ManageFloorsScreenState();
}

class _ManageFloorsScreenState extends State<ManageFloorsScreen> {
  final TextEditingController _floorNameController = TextEditingController();
  String? _selectedBuildingId;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _addFloor() async {
    if (_selectedBuildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a building first!')),
      );
      return;
    }
    if (_floorNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a floor name!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('floors').add({
        'buildingId': _selectedBuildingId,
        'name': _floorNameController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _floorNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor added!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteFloor(String floorId) async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: EasySitColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Floor', style: TextStyle(color: EasySitColors.mainText, fontWeight: FontWeight.bold)),
            content: const Text(
              'This will delete all Rooms and Seats in this floor. Continue?',
              style: TextStyle(color: EasySitColors.bodyText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: EasySitColors.errorFg),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      QuerySnapshot roomsSnapshot =
          await _firestore
              .collection('rooms')
              .where('floorId', isEqualTo: floorId)
              .get();

      for (var roomDoc in roomsSnapshot.docs) {
        String roomId = roomDoc.id;
        QuerySnapshot seatsSnapshot =
            await _firestore
                .collection('seats')
                .where('roomId', isEqualTo: roomId)
                .get();
        for (var seatDoc in seatsSnapshot.docs) {
          await _firestore.collection('seats').doc(seatDoc.id).delete();
        }
        await _firestore.collection('rooms').doc(roomId).delete();
      }
      await _firestore.collection('floors').doc(floorId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor and related data deleted!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFloorMaintenance(String floorId, String floorName, bool isBlocked, String? currentReason) async {
    if (!isBlocked) {
      // Close floor for maintenance
      final reasonController = TextEditingController(text: currentReason ?? 'Facility maintenance & repairs');
      final notifyController = TextEditingController(
        text: 'Floor "$floorName" is closed for maintenance until further notice. Any active bookings on this floor have been automatically released.',
      );
      bool shouldNotify = true;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: EasySitColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.build_circle_rounded, color: EasySitColors.warningFg),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Close Floor for Maintenance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Close "$floorName" for maintenance or facility work.',
                      style: const TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EasySitColors.warningBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EasySitColors.warningBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: EasySitColors.warningFg, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All active and pending seat bookings on this floor will be automatically released immediately. Students cannot book seats here until reopened.',
                              style: TextStyle(fontSize: 12, color: EasySitColors.warningFg, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Reason for Closure',
                        hintText: 'e.g. Renovation, electrical repairs, painting',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: shouldNotify,
                          activeColor: EasySitColors.primary,
                          onChanged: (val) {
                            setDlgState(() => shouldNotify = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Send notification to all students',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EasySitColors.mainText),
                          ),
                        ),
                      ],
                    ),
                    if (shouldNotify) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notifyController,
                        maxLines: 3,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Notification Message',
                          hintText: 'Message to broadcast to students...',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasySitColors.warningFg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close Floor & Release Seats'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        final reason = reasonController.text.trim().isEmpty ? 'Maintenance in progress' : reasonController.text.trim();

        // 1. Update floor doc
        await _firestore.collection('floors').doc(floorId).update({
          'isBlocked': true,
          'status': 'maintenance',
          'blockReason': reason,
          'blockedAt': FieldValue.serverTimestamp(),
        });

        // 2. Query all rooms and seats on this floor
        int releasedCount = 0;
        final roomsSnap = await _firestore.collection('rooms').where('floorId', isEqualTo: floorId).get();

        for (var roomDoc in roomsSnap.docs) {
          final seatsSnap = await _firestore.collection('seats').where('roomId', isEqualTo: roomDoc.id).get();

          WriteBatch batch = _firestore.batch();
          int batchCount = 0;

          for (var seatDoc in seatsSnap.docs) {
            final sData = seatDoc.data();
            final status = sData['status'] ?? 'available';
            if (status == 'booked' || status == 'pending' || sData['bookedBy'] != null || sData['pendingBy'] != null) {
              releasedCount++;
            }

            batch.update(seatDoc.reference, {
              'status': 'unavailable',
              'isFloorBlocked': true,
              'floorId': floorId,
              'blockedReason': reason,
              'bookedBy': FieldValue.delete(),
              'bookedAt': FieldValue.delete(),
              'pendingBy': FieldValue.delete(),
              'pendingAt': FieldValue.delete(),
            });
            batchCount++;

            if (batchCount >= 450) {
              await batch.commit();
              batch = _firestore.batch();
              batchCount = 0;
            }
          }

          if (batchCount > 0) {
            await batch.commit();
          }
        }

        // 3. Send notification
        if (shouldNotify && notifyController.text.trim().isNotEmpty) {
          await _firestore.collection('notifications').add({
            'title': '⚠️ Floor Closed: $floorName',
            'message': notifyController.text.trim(),
            'floorId': floorId,
            'floorName': floorName,
            'reason': reason,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': 'all',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Floor closed. $releasedCount active bookings auto-released.'),
              backgroundColor: EasySitColors.warningFg,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
          );
        }
      }
      setState(() => _isLoading = false);
    } else {
      // Reopen floor
      final notifyController = TextEditingController(
        text: 'Floor "$floorName" is now reopened! Seats on this floor are once again available for reservation.',
      );
      bool shouldNotify = true;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: EasySitColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.lock_open_rounded, color: EasySitColors.successFg),
                  SizedBox(width: 8),
                  Text(
                    'Reopen Floor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.mainText,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reopen "$floorName" for student bookings? Seats on this floor will become available again.',
                      style: const TextStyle(fontSize: 13, color: EasySitColors.bodyText),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: shouldNotify,
                          activeColor: EasySitColors.primary,
                          onChanged: (val) {
                            setDlgState(() => shouldNotify = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Notify students that floor is reopened',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EasySitColors.mainText),
                          ),
                        ),
                      ],
                    ),
                    if (shouldNotify) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notifyController,
                        maxLines: 3,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Notification Message',
                          hintText: 'Message to broadcast to students...',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasySitColors.successFg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reopen Floor'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        // 1. Update floor doc
        await _firestore.collection('floors').doc(floorId).update({
          'isBlocked': false,
          'status': 'active',
          'blockReason': FieldValue.delete(),
          'unblockedAt': FieldValue.serverTimestamp(),
        });

        // 2. Reopen seats under this floor
        final roomsSnap = await _firestore.collection('rooms').where('floorId', isEqualTo: floorId).get();

        for (var roomDoc in roomsSnap.docs) {
          final seatsSnap = await _firestore.collection('seats').where('roomId', isEqualTo: roomDoc.id).get();

          WriteBatch batch = _firestore.batch();
          int batchCount = 0;

          for (var seatDoc in seatsSnap.docs) {
            final sData = seatDoc.data();
            if (sData['isFloorBlocked'] == true || sData['status'] == 'unavailable') {
              batch.update(seatDoc.reference, {
                'status': 'available',
                'isFloorBlocked': FieldValue.delete(),
                'blockedReason': FieldValue.delete(),
              });
              batchCount++;

              if (batchCount >= 450) {
                await batch.commit();
                batch = _firestore.batch();
                batchCount = 0;
              }
            }
          }

          if (batchCount > 0) {
            await batch.commit();
          }
        }

        // 3. Send notification
        if (shouldNotify && notifyController.text.trim().isNotEmpty) {
          await _firestore.collection('notifications').add({
            'title': '✅ Floor Reopened: $floorName',
            'message': notifyController.text.trim(),
            'floorId': floorId,
            'floorName': floorName,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': 'all',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Floor "$floorName" reopened! Seats are now available.'),
              backgroundColor: EasySitColors.successFg,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
          );
        }
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFloorNoticeDialog(String floorId, String floorName) async {
    final titleController = TextEditingController(text: 'Announcement: $floorName');
    final messageController = TextEditingController();

    bool? send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EasySitColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.campaign_rounded, color: EasySitColors.pendingAccent),
            SizedBox(width: 8),
            Text(
              'Send Floor Notice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: EasySitColors.mainText,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Broadcast an announcement about $floorName to all students.',
                style: const TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: _buildEasySitInputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g. Ground Floor Notice',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: _buildEasySitInputDecoration(
                  labelText: 'Notice Message',
                  hintText: 'Enter notice details for students...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EasySitColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Broadcast'),
          ),
        ],
      ),
    );

    if (send != true) return;

    try {
      await _firestore.collection('notifications').add({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'floorId': floorId,
        'floorName': floorName,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': 'all',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floor notice broadcasted to all students!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
        );
      }
    }
  }

  void _showFloorActionSheet(String floorId, String floorName, bool isBlocked, String? reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EasySitColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      floorName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBlocked ? EasySitColors.warningBg : EasySitColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isBlocked ? EasySitColors.warningBorder : EasySitColors.successBorder),
                    ),
                    child: Text(
                      isBlocked ? 'Closed / Maintenance' : 'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? EasySitColors.warningFg : EasySitColors.successFg,
                      ),
                    ),
                  ),
                ],
              ),
              if (isBlocked && (reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(fontSize: 13, color: EasySitColors.warningFg, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: EasySitColors.divider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBlocked ? EasySitColors.successBg : EasySitColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                    size: 20,
                  ),
                ),
                title: Text(
                  isBlocked ? 'Reopen Floor' : 'Close Floor for Maintenance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                  ),
                ),
                subtitle: Text(
                  isBlocked
                      ? 'Resume student seat reservations on this floor'
                      : 'Auto-release active seats and pause reservations',
                  style: const TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleFloorMaintenance(floorId, floorName, isBlocked, reason);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EasySitColors.pendingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: EasySitColors.pendingAccent,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Send Floor Announcement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.mainText,
                  ),
                ),
                subtitle: const Text(
                  'Broadcast notice about this floor to all students',
                  style: TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendFloorNoticeDialog(floorId, floorName);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EasySitColors.errorBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: EasySitColors.errorFg,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete Floor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.errorFg,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete this floor and all its rooms and seats',
                  style: TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteFloor(floorId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Text(
            'Manage Floors',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 16),
          _buildEasySitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('buildings').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('No Buildings'),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Building',
                          prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    var items = snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(
                          data['name'] ?? 'Unnamed',
                          style: const TextStyle(color: EasySitColors.mainText),
                        ),
                      );
                    }).toList();
                    return DropdownButtonFormField<String>(
                      value: _selectedBuildingId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Building',
                        prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedBuildingId = value;
                        });
                      },
                      hint: const Text('Select Building', style: TextStyle(color: EasySitColors.secondaryText)),
                    );
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _floorNameController,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Floor Name (e.g. Ground Floor)',
                    prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addFloor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasySitColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Text(
                            'Add Floor',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Floor List',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('floors')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: EasySitColors.errorFg),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: EasySitColors.primary),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No floors added yet.',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  final String floorName = data['name'] ?? 'Unnamed';
                  final bool isBlocked = data['isBlocked'] ?? false;
                  final String? blockReason = data['blockReason'] as String?;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: EasySitColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBlocked ? EasySitColors.warningBorder : EasySitColors.divider,
                        width: isBlocked ? 1.5 : 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: EasySitColors.cardShadowColor,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showFloorActionSheet(doc.id, floorName, isBlocked, blockReason),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isBlocked ? EasySitColors.warningBg : EasySitColors.primaryTint,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isBlocked ? Icons.lock_clock_rounded : Icons.vertical_align_top,
                                color: isBlocked ? EasySitColors.warningFg : EasySitColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          floorName,
                                          style: const TextStyle(
                                            color: EasySitColors.mainText,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isBlocked ? EasySitColors.warningBg : EasySitColors.successBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isBlocked ? EasySitColors.warningBorder : EasySitColors.successBorder,
                                          ),
                                        ),
                                        child: Text(
                                          isBlocked ? 'Maintenance' : 'Active',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isBlocked ? EasySitColors.warningFg : EasySitColors.successFg,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: _firestore.collection('buildings').doc(data['buildingId']).get(),
                                    builder: (context, buildingSnapshot) {
                                      final bData = buildingSnapshot.data?.data() as Map<String, dynamic>?;
                                      final bName = bData?['name'] ?? 'Building';
                                      if (isBlocked) {
                                        return Text(
                                          'Closed: ${blockReason ?? 'Maintenance in progress'} • $bName',
                                          style: const TextStyle(
                                            color: EasySitColors.warningFg,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      }
                                      return Text(
                                        'Building: $bName • Available',
                                        style: const TextStyle(
                                          color: EasySitColors.secondaryText,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                                    size: 20,
                                  ),
                                  tooltip: isBlocked ? 'Reopen Floor' : 'Close for Maintenance',
                                  onPressed: () => _toggleFloorMaintenance(doc.id, floorName, isBlocked, blockReason),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.campaign_outlined, color: EasySitColors.pendingAccent, size: 20),
                                  tooltip: 'Send Notice',
                                  onPressed: () => _sendFloorNoticeDialog(doc.id, floorName),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: EasySitColors.errorFg, size: 20),
                                  onPressed: () => _deleteFloor(doc.id),
                                  tooltip: 'Delete Floor',
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
        ],
      ),
    );
  }
}

// ============================================================
// 3. MANAGE ROOMS SCREEN
// ============================================================
class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({super.key});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  final TextEditingController _roomNameController = TextEditingController();
  String? _selectedBuildingId;
  String? _selectedFloorId;
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> _getFloors() {
    if (_selectedBuildingId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('floors')
        .where('buildingId', isEqualTo: _selectedBuildingId)
        .snapshots();
  }

  Future<void> _addRoom() async {
    if (_selectedFloorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a floor first!')),
      );
      return;
    }
    if (_roomNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _firestore.collection('rooms').add({
        'floorId': _selectedFloorId,
        'name': _roomNameController.text.trim(),
        'capacity': 0,
        'rows': 0,
        'cols': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _roomNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room added!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteRoom(String roomId) async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: EasySitColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Room', style: TextStyle(color: EasySitColors.mainText, fontWeight: FontWeight.bold)),
            content: const Text(
              'This will delete all Seats in this room. Continue?',
              style: TextStyle(color: EasySitColors.bodyText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: EasySitColors.errorFg),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      QuerySnapshot seatsSnapshot =
          await _firestore
              .collection('seats')
              .where('roomId', isEqualTo: roomId)
              .get();
      for (var seatDoc in seatsSnapshot.docs) {
        await _firestore.collection('seats').doc(seatDoc.id).delete();
      }
      await _firestore.collection('rooms').doc(roomId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room and seats deleted!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleRoomMaintenance(String roomId, String roomName, bool isBlocked, String? currentReason) async {
    if (!isBlocked) {
      // Close room for maintenance
      final reasonController = TextEditingController(text: currentReason ?? 'Facility maintenance & servicing');
      final notifyController = TextEditingController(
        text: 'Room "$roomName" is closed for maintenance until further notice. Any active bookings in this room have been automatically released.',
      );
      bool shouldNotify = true;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: EasySitColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.build_circle_rounded, color: EasySitColors.warningFg),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Close Room for Maintenance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Close "$roomName" for maintenance or facility work.',
                      style: const TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: EasySitColors.warningBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: EasySitColors.warningBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: EasySitColors.warningFg, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All active and pending seat bookings in this room will be automatically released immediately. Students cannot book seats here until reopened.',
                              style: TextStyle(fontSize: 12, color: EasySitColors.warningFg, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Reason for Closure',
                        hintText: 'e.g. Air conditioning repair, cleaning, exams',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: shouldNotify,
                          activeColor: EasySitColors.primary,
                          onChanged: (val) {
                            setDlgState(() => shouldNotify = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Send notification to all students',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EasySitColors.mainText),
                          ),
                        ),
                      ],
                    ),
                    if (shouldNotify) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notifyController,
                        maxLines: 3,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Notification Message',
                          hintText: 'Message to broadcast to students...',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasySitColors.warningFg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Close Room & Release Seats'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        final reason = reasonController.text.trim().isEmpty ? 'Maintenance in progress' : reasonController.text.trim();

        // 1. Update room doc
        await _firestore.collection('rooms').doc(roomId).update({
          'isBlocked': true,
          'status': 'maintenance',
          'blockReason': reason,
          'blockedAt': FieldValue.serverTimestamp(),
        });

        // 2. Query all seats in this room to auto-release
        int releasedCount = 0;
        final seatsSnap = await _firestore.collection('seats').where('roomId', isEqualTo: roomId).get();

        WriteBatch batch = _firestore.batch();
        int batchCount = 0;

        for (var seatDoc in seatsSnap.docs) {
          final sData = seatDoc.data();
          final status = sData['status'] ?? 'available';
          if (status == 'booked' || status == 'pending' || sData['bookedBy'] != null || sData['pendingBy'] != null) {
            releasedCount++;
          }

          batch.update(seatDoc.reference, {
            'status': 'unavailable',
            'isRoomBlocked': true,
            'roomId': roomId,
            'blockedReason': reason,
            'bookedBy': FieldValue.delete(),
            'bookedAt': FieldValue.delete(),
            'pendingBy': FieldValue.delete(),
            'pendingAt': FieldValue.delete(),
          });
          batchCount++;

          if (batchCount >= 450) {
            await batch.commit();
            batch = _firestore.batch();
            batchCount = 0;
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }

        // 3. Send notification
        if (shouldNotify && notifyController.text.trim().isNotEmpty) {
          await _firestore.collection('notifications').add({
            'title': '⚠️ Room Closed: $roomName',
            'message': notifyController.text.trim(),
            'roomId': roomId,
            'roomName': roomName,
            'reason': reason,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': 'all',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Room closed. $releasedCount active bookings auto-released.'),
              backgroundColor: EasySitColors.warningFg,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
          );
        }
      }
      setState(() => _isLoading = false);
    } else {
      // Reopen room
      final notifyController = TextEditingController(
        text: 'Room "$roomName" is now reopened! Seats are once again available for reservation.',
      );
      bool shouldNotify = true;

      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: EasySitColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.lock_open_rounded, color: EasySitColors.successFg),
                  SizedBox(width: 8),
                  Text(
                    'Reopen Room',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: EasySitColors.mainText,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reopen "$roomName" for student bookings? All seats in this room will become available again.',
                      style: const TextStyle(fontSize: 13, color: EasySitColors.bodyText),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: shouldNotify,
                          activeColor: EasySitColors.primary,
                          onChanged: (val) {
                            setDlgState(() => shouldNotify = val ?? true);
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'Notify students that room is reopened',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EasySitColors.mainText),
                          ),
                        ),
                      ],
                    ),
                    if (shouldNotify) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: notifyController,
                        maxLines: 3,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Notification Message',
                          hintText: 'Message to broadcast to students...',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EasySitColors.successFg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reopen Room'),
                ),
              ],
            );
          },
        ),
      );

      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        // 1. Update room doc
        await _firestore.collection('rooms').doc(roomId).update({
          'isBlocked': false,
          'status': 'active',
          'blockReason': FieldValue.delete(),
          'unblockedAt': FieldValue.serverTimestamp(),
        });

        // 2. Reopen seats in this room
        final seatsSnap = await _firestore.collection('seats').where('roomId', isEqualTo: roomId).get();

        WriteBatch batch = _firestore.batch();
        int batchCount = 0;

        for (var seatDoc in seatsSnap.docs) {
          final sData = seatDoc.data();
          if (sData['isRoomBlocked'] == true || sData['status'] == 'unavailable') {
            batch.update(seatDoc.reference, {
              'status': 'available',
              'isRoomBlocked': FieldValue.delete(),
              'blockedReason': FieldValue.delete(),
            });
            batchCount++;

            if (batchCount >= 450) {
              await batch.commit();
              batch = _firestore.batch();
              batchCount = 0;
            }
          }
        }

        if (batchCount > 0) {
          await batch.commit();
        }

        // 3. Send notification
        if (shouldNotify && notifyController.text.trim().isNotEmpty) {
          await _firestore.collection('notifications').add({
            'title': '✅ Room Reopened: $roomName',
            'message': notifyController.text.trim(),
            'roomId': roomId,
            'roomName': roomName,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': 'all',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Room "$roomName" reopened! Seats are now available.'),
              backgroundColor: EasySitColors.successFg,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
          );
        }
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRoomNoticeDialog(String roomId, String roomName) async {
    final titleController = TextEditingController(text: 'Announcement: $roomName');
    final messageController = TextEditingController();

    bool? send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EasySitColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.campaign_rounded, color: EasySitColors.pendingAccent),
            SizedBox(width: 8),
            Text(
              'Send Room Notice',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: EasySitColors.mainText,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Broadcast an announcement about $roomName to all students.',
                style: const TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                decoration: _buildEasySitInputDecoration(
                  labelText: 'Notice Title',
                  hintText: 'e.g. Room 101 Notice',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 3,
                decoration: _buildEasySitInputDecoration(
                  labelText: 'Notice Message',
                  hintText: 'Enter notice details for students...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EasySitColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Broadcast'),
          ),
        ],
      ),
    );

    if (send != true) return;

    try {
      await _firestore.collection('notifications').add({
        'title': titleController.text.trim(),
        'message': messageController.text.trim(),
        'roomId': roomId,
        'roomName': roomName,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': 'all',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Room notice broadcasted to all students!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: EasySitColors.errorFg),
        );
      }
    }
  }

  void _showRoomActionSheet(String roomId, String roomName, bool isBlocked, String? reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: EasySitColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isBlocked ? EasySitColors.warningBg : EasySitColors.successBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isBlocked ? EasySitColors.warningBorder : EasySitColors.successBorder),
                    ),
                    child: Text(
                      isBlocked ? 'Closed / Maintenance' : 'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? EasySitColors.warningFg : EasySitColors.successFg,
                      ),
                    ),
                  ),
                ],
              ),
              if (isBlocked && (reason ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Reason: $reason',
                  style: const TextStyle(fontSize: 13, color: EasySitColors.warningFg, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(color: EasySitColors.divider),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isBlocked ? EasySitColors.successBg : EasySitColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                    size: 20,
                  ),
                ),
                title: Text(
                  isBlocked ? 'Reopen Room' : 'Close Room for Maintenance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                  ),
                ),
                subtitle: Text(
                  isBlocked
                      ? 'Resume student seat reservations in this room'
                      : 'Auto-release active seats and pause reservations',
                  style: const TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleRoomMaintenance(roomId, roomName, isBlocked, reason);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EasySitColors.pendingBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: EasySitColors.pendingAccent,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Send Room Announcement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.mainText,
                  ),
                ),
                subtitle: const Text(
                  'Broadcast notice about this room to all students',
                  style: TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendRoomNoticeDialog(roomId, roomName);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EasySitColors.errorBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: EasySitColors.errorFg,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Delete Room',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.errorFg,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete this room and all its seats',
                  style: TextStyle(fontSize: 12, color: EasySitColors.secondaryText),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteRoom(roomId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Text(
            'Manage Rooms',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 16),
          _buildEasySitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('buildings').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('No Buildings'),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Building',
                          prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    var items = snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(
                          data['name'] ?? 'Unnamed',
                          style: const TextStyle(color: EasySitColors.mainText),
                        ),
                      );
                    }).toList();
                    return DropdownButtonFormField<String>(
                      value: _selectedBuildingId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Building',
                        prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedBuildingId = value;
                          _selectedFloorId = null;
                        });
                      },
                      hint: const Text('Select Building', style: TextStyle(color: EasySitColors.secondaryText)),
                    );
                  },
                ),
                const SizedBox(height: 15),
                StreamBuilder<QuerySnapshot>(
                  stream: _getFloors(),
                  builder: (context, snapshot) {
                    if (_selectedBuildingId == null) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('Select Building first', style: TextStyle(color: EasySitColors.secondaryText)),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Floor',
                          prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('No Floors'),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Floor',
                          prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    var items = snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(
                          data['name'] ?? 'Unnamed',
                          style: const TextStyle(color: EasySitColors.mainText),
                        ),
                      );
                    }).toList();
                    return DropdownButtonFormField<String>(
                      value: _selectedFloorId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Floor',
                        prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedFloorId = value;
                        });
                      },
                      hint: const Text('Select Floor', style: TextStyle(color: EasySitColors.secondaryText)),
                    );
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _roomNameController,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Room Name (e.g. Room 101)',
                    prefixIcon: const Icon(Icons.door_front_door, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasySitColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Text(
                            'Add Room',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Room List',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 10),
          _selectedFloorId == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Select a building and floor to see rooms',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('rooms')
                      .where('floorId', isEqualTo: _selectedFloorId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: EasySitColors.errorFg),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: EasySitColors.primary),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text(
                            'No rooms added yet.',
                            style: TextStyle(color: EasySitColors.secondaryText),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        final String roomName = data['name'] ?? 'Unnamed';
                        final bool isBlocked = data['isBlocked'] ?? false;
                        final String? blockReason = data['blockReason'] as String?;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: EasySitColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isBlocked ? EasySitColors.warningBorder : EasySitColors.divider,
                              width: isBlocked ? 1.5 : 1.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: EasySitColors.cardShadowColor,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showRoomActionSheet(doc.id, roomName, isBlocked, blockReason),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isBlocked ? EasySitColors.warningBg : EasySitColors.primaryTint,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isBlocked ? Icons.lock_clock_rounded : Icons.door_front_door,
                                      color: isBlocked ? EasySitColors.warningFg : EasySitColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                roomName,
                                                style: const TextStyle(
                                                  color: EasySitColors.mainText,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isBlocked ? EasySitColors.warningBg : EasySitColors.successBg,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isBlocked ? EasySitColors.warningBorder : EasySitColors.successBorder,
                                                ),
                                              ),
                                              child: Text(
                                                isBlocked ? 'Maintenance' : 'Active',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isBlocked ? EasySitColors.warningFg : EasySitColors.successFg,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        if (isBlocked)
                                          Text(
                                            'Closed: ${blockReason ?? 'Maintenance in progress'}',
                                            style: const TextStyle(
                                              color: EasySitColors.warningFg,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        else
                                          const Text(
                                            'Available for reservations',
                                            style: TextStyle(
                                              color: EasySitColors.secondaryText,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                                          color: isBlocked ? EasySitColors.successFg : EasySitColors.warningFg,
                                          size: 20,
                                        ),
                                        tooltip: isBlocked ? 'Reopen Room' : 'Close for Maintenance',
                                        onPressed: () => _toggleRoomMaintenance(doc.id, roomName, isBlocked, blockReason),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.campaign_outlined, color: EasySitColors.pendingAccent, size: 20),
                                        tooltip: 'Send Notice',
                                        onPressed: () => _sendRoomNoticeDialog(doc.id, roomName),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: EasySitColors.errorFg, size: 20),
                                        onPressed: () => _deleteRoom(doc.id),
                                        tooltip: 'Delete Room',
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
        ],
      ),
    );
  }
}

bool isSeatNumberDuplicate(String seatNum, Iterable<String> existingNumbers) {
  final trimmed = seatNum.trim();
  if (trimmed.isEmpty) return false;
  final numVal = int.tryParse(trimmed);
  for (final existing in existingNumbers) {
    final existingTrimmed = existing.trim();
    if (existingTrimmed == trimmed) return true;
    if (numVal != null) {
      final existingNum = int.tryParse(existingTrimmed);
      if (existingNum != null && existingNum == numVal) return true;
    }
  }
  return false;
}

List<int>? parseBulkSeatInput(String input, Iterable<String> existingNumbers) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final rangeRegex = RegExp(r'^(\d+)\s*(?:-|–|—|to)\s*(\d+)$', caseSensitive: false);
  final match = rangeRegex.firstMatch(text);
  if (match != null) {
    int start = int.parse(match.group(1)!);
    int end = int.parse(match.group(2)!);
    if (start <= 0 || end <= 0 || start > end) {
      return null;
    }
    if (end - start + 1 > 500) {
      return null;
    }
    return [for (int i = start; i <= end; i++) i];
  }

  final count = int.tryParse(text);
  if (count != null && count > 0 && count <= 500) {
    int maxExisting = 0;
    for (final s in existingNumbers) {
      final val = int.tryParse(s.trim());
      if (val != null && val > maxExisting) {
        maxExisting = val;
      }
    }
    int startNumber = maxExisting + 1;
    return [for (int i = 0; i < count; i++) startNumber + i];
  }

  return null;
}

// ============================================================
// 4. MANAGE SEATS & QR SCREEN
// ============================================================
class ManageSeatsScreen extends StatefulWidget {
  const ManageSeatsScreen({super.key});

  @override
  State<ManageSeatsScreen> createState() => _ManageSeatsScreenState();
}

class _ManageSeatsScreenState extends State<ManageSeatsScreen> {
  String? _selectedBuildingId;
  String? _selectedFloorId;
  String? _selectedRoomId;
  final TextEditingController _bulkCountController = TextEditingController();
  final TextEditingController _singleSeatController = TextEditingController();
  bool _isLoading = false;
  final Set<String> _downloadingSeats = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<String> _existingSeatNumbers = {};
  StreamSubscription<QuerySnapshot>? _seatsSubscription;
  String? _singleSeatError;
  String? _bulkSeatError;

  void _onRoomChanged(String? roomId) {
    _seatsSubscription?.cancel();
    _existingSeatNumbers.clear();
    setState(() {
      _selectedRoomId = roomId;
      _singleSeatError = null;
      _bulkSeatError = null;
    });
    if (roomId != null) {
      _seatsSubscription = _firestore
          .collection('seats')
          .where('roomId', isEqualTo: roomId)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _existingSeatNumbers = snapshot.docs.map((doc) {
              final data = doc.data();
              return (data['seatNumber'] ?? '').toString().trim();
            }).where((s) => s.isNotEmpty).toSet();
          });
        }
      });
    }
  }

  bool _isSeatNumberDuplicate(String seatNum, Iterable<String> existingNumbers) =>
      isSeatNumberDuplicate(seatNum, existingNumbers);

  List<int>? _parseBulkInput(String input, Iterable<String> existingNumbers) =>
      parseBulkSeatInput(input, existingNumbers);

  // QR Code Image Generation Function
  Future<Uint8List?> _generateQrImageBytes(String data) async {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.Q,
      );
      final qrImage = QrImage(qrCode);
      final moduleCount = qrCode.moduleCount;
      const scale = 8;

      final img = im.Image(
        width: moduleCount * scale,
        height: moduleCount * scale,
        numChannels: 3,
      );

      for (int y = 0; y < moduleCount; y++) {
        for (int x = 0; x < moduleCount; x++) {
          final dark = qrImage.isDark(y, x);
          final v = dark ? 0 : 255;
          for (int dy = 0; dy < scale; dy++) {
            for (int dx = 0; dx < scale; dx++) {
              img.setPixelRgb(x * scale + dx, y * scale + dy, v, v, v);
            }
          }
        }
      }

      final jpgBytes = im.encodeJpg(img, quality: 90);
      return Uint8List.fromList(jpgBytes);
    } catch (e) {
      debugPrint('❌ QR Generation Error: $e');
      return null;
    }
  }

  // PDF Download Function
  Future<void> _downloadPdf(Uint8List bytes, String filename) async {
    try {
      if (Platform.isAndroid) {
        const platform = MethodChannel('easy_sit/pdf');
        await platform.invokeMethod('savePdf', {'bytes': bytes, 'filename': filename});
      } else {
        Directory dir;
        try {
          dir = await getApplicationDocumentsDirectory();
        } catch (_) {
          dir = Directory.systemTemp;
        }
        await File('${dir.path}/$filename').writeAsBytes(bytes);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF saved to Downloads!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      try {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: EasySitColors.errorFg,
            ),
          );
        }
      }
    }
  }

  Stream<QuerySnapshot> _getFloors() {
    if (_selectedBuildingId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('floors')
        .where('buildingId', isEqualTo: _selectedBuildingId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getRooms() {
    if (_selectedFloorId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('rooms')
        .where('floorId', isEqualTo: _selectedFloorId)
        .snapshots();
  }

  Stream<QuerySnapshot> _getSeats() {
    if (_selectedRoomId == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('seats')
        .where('roomId', isEqualTo: _selectedRoomId)
        .snapshots();
  }

  Future<void> _addSeatsBulk() async {
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room first!')),
      );
      return;
    }
    String bulkInput = _bulkCountController.text.trim();
    if (bulkInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a seat count or range!')),
      );
      return;
    }

    final seatsToAdd = _parseBulkInput(bulkInput, _existingSeatNumbers);
    if (seatsToAdd == null || seatsToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid seat count (e.g. 10) or range (e.g. 11-20)!')),
      );
      return;
    }

    // 1. UI Check: Check if any seat number already exists in this room
    bool hasDuplicate = seatsToAdd.any((seat) => _isSeatNumberDuplicate(seat.toString(), _existingSeatNumbers));
    if (hasDuplicate) {
      setState(() {
        _bulkSeatError = 'This seat number already exists in this room.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This seat number already exists in this room.'),
          backgroundColor: EasySitColors.errorFg,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 2. Database Check: Query Firestore directly for existing seats in room
      QuerySnapshot existingInDb = await _firestore
          .collection('seats')
          .where('roomId', isEqualTo: _selectedRoomId)
          .get();

      Set<String> dbSeatNumbers = existingInDb.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['seatNumber'] ?? '').toString().trim();
      }).where((s) => s.isNotEmpty).toSet();

      _existingSeatNumbers.addAll(dbSeatNumbers);

      final finalSeatsToAdd = _parseBulkInput(bulkInput, dbSeatNumbers) ?? seatsToAdd;

      bool hasDbDuplicate = finalSeatsToAdd.any((seat) => _isSeatNumberDuplicate(seat.toString(), dbSeatNumbers));
      if (hasDbDuplicate) {
        setState(() {
          _bulkSeatError = 'This seat number already exists in this room.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This seat number already exists in this room.'),
              backgroundColor: EasySitColors.errorFg,
            ),
          );
        }
        return;
      }

      WriteBatch batch = _firestore.batch();
      for (int seatNum in finalSeatsToAdd) {
        DocumentReference docRef = _firestore.collection('seats').doc();
        batch.set(docRef, {
          'roomId': _selectedRoomId,
          'seatNumber': seatNum.toString(),
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
          'qrData': 'SEAT:${docRef.id}',
        });
      }
      await batch.commit();

      _bulkCountController.clear();
      setState(() {
        _bulkSeatError = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${finalSeatsToAdd.length} seats added!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSingleSeat() async {
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room first!')),
      );
      return;
    }
    String seatNumber = _singleSeatController.text.trim();
    if (seatNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a seat number!')));
      return;
    }

    // 1. UI Check against live cached existing seats in this room
    if (_isSeatNumberDuplicate(seatNumber, _existingSeatNumbers)) {
      setState(() {
        _singleSeatError = 'This seat number already exists in this room.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This seat number already exists in this room.'),
          backgroundColor: EasySitColors.errorFg,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 2. Database Check: Query Firestore directly for existing seats in room
      QuerySnapshot existingInDb = await _firestore
          .collection('seats')
          .where('roomId', isEqualTo: _selectedRoomId)
          .get();

      Set<String> dbSeatNumbers = existingInDb.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['seatNumber'] ?? '').toString().trim();
      }).where((s) => s.isNotEmpty).toSet();

      _existingSeatNumbers.addAll(dbSeatNumbers);

      if (_isSeatNumberDuplicate(seatNumber, dbSeatNumbers)) {
        setState(() {
          _singleSeatError = 'This seat number already exists in this room.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This seat number already exists in this room.'),
              backgroundColor: EasySitColors.errorFg,
            ),
          );
        }
        return;
      }

      DocumentReference docRef = await _firestore.collection('seats').add({
        'roomId': _selectedRoomId,
        'seatNumber': seatNumber,
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await docRef.update({'qrData': 'SEAT:${docRef.id}'});
      _singleSeatController.clear();
      setState(() {
        _singleSeatError = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seat added!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSeat(String seatId) async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: EasySitColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Seat', style: TextStyle(color: EasySitColors.mainText, fontWeight: FontWeight.bold)),
            content: const Text('Are you sure?', style: TextStyle(color: EasySitColors.bodyText)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: EasySitColors.secondaryText)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: EasySitColors.errorFg),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    try {
      await _firestore.collection('seats').doc(seatId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seat deleted!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
  }

  // All QR Codes PDF
  Future<void> _printAllQrs() async {
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room first!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String buildingName = 'Unknown';
      String floorName = 'Unknown';
      String roomName = 'Unknown';

      if (_selectedBuildingId != null) {
        final bDoc = await _firestore.collection('buildings').doc(_selectedBuildingId).get();
        if (bDoc.exists) buildingName = bDoc.data()?['name'] ?? 'Unknown';
      }
      if (_selectedFloorId != null) {
        final fDoc = await _firestore.collection('floors').doc(_selectedFloorId).get();
        if (fDoc.exists) floorName = fDoc.data()?['name'] ?? 'Unknown';
      }
      if (_selectedRoomId != null) {
        final rDoc = await _firestore.collection('rooms').doc(_selectedRoomId).get();
        if (rDoc.exists) roomName = rDoc.data()?['name'] ?? 'Unknown';
      }

      QuerySnapshot seatsSnapshot =
          await _firestore
              .collection('seats')
              .where('roomId', isEqualTo: _selectedRoomId)
              .get();

      if (seatsSnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No seats to export!')));
        }
        setState(() => _isLoading = false);
        return;
      }

      var sortedDocs = List<QueryDocumentSnapshot>.from(seatsSnapshot.docs);
      sortedDocs.sort((a, b) {
        var aNum = int.tryParse((a.data() as Map)['seatNumber'] ?? '0') ?? 0;
        var bNum = int.tryParse((b.data() as Map)['seatNumber'] ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

      final pdfDoc = pw.Document();

      const int cols = 4;
      const double qrImageSize = 100.0;
      const double cellHeight = 140.0;
      const double rowSpacing = 15.0;

      List<pw.Widget> allCells = [];

      for (int i = 0; i < sortedDocs.length; i++) {
        var data = sortedDocs[i].data() as Map<String, dynamic>;
        String seatNumber = data['seatNumber'] ?? '?';
        String seatId = sortedDocs[i].id;

        String qrData = data['qrData'] ?? 'SEAT:$seatId';
        Uint8List? qrBytes = await _generateQrImageBytes(qrData);

        allCells.add(
          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              qrBytes != null
                  ? pw.Image(
                      pw.MemoryImage(qrBytes),
                      width: qrImageSize,
                      height: qrImageSize,
                      fit: pw.BoxFit.fill,
                    )
                  : pw.Container(
                      width: qrImageSize,
                      height: qrImageSize,
                      color: pw_pdf.PdfColor.fromInt(0xffc8c8c8),
                      child: pw.Center(
                        child: pw.Text('QR Error', style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Seat $seatNumber',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        );
      }

      const double usablePageHeight = 801.89;
      const double headerHeight = 70.0;
      int rowsPerPage = ((usablePageHeight - headerHeight) / (cellHeight + rowSpacing)).floor();
      if (rowsPerPage < 2) rowsPerPage = 2;
      int itemsPerPage = cols * rowsPerPage;

      for (int start = 0; start < allCells.length; start += itemsPerPage) {
        int end = (start + itemsPerPage > allCells.length) ? allCells.length : start + itemsPerPage;
        var pageCells = allCells.sublist(start, end);

        List<pw.Widget> rows = [];
        for (int j = 0; j < pageCells.length; j += cols) {
          int rowEnd = (j + cols > pageCells.length) ? pageCells.length : j + cols;
          var rowCells = pageCells.sublist(j, rowEnd);

          rows.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: rowCells,
            ),
          );
          if (rowEnd < pageCells.length) {
            rows.add(pw.SizedBox(height: rowSpacing));
          }
        }

        pdfDoc.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(20),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  '$buildingName - $floorName - $roomName',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Seat QR Codes',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: pw_pdf.PdfColors.grey,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Column(children: rows),
              ],
            ),
          ),
        );
      }

      final pdfBytes = await pdfDoc.save();
      await _downloadPdf(pdfBytes, 'seats_qr_codes.pdf');
    } catch (e) {
      debugPrint('❌ PDF Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  // Single Seat QR PDF
  Future<void> _printSingleQr(
    String seatId,
    String seatNumber,
    String qrData,
  ) async {
    setState(() => _downloadingSeats.add(seatId));

    try {
      Uint8List? qrBytes = await _generateQrImageBytes(qrData);

      final pdfDoc = pw.Document();

      pdfDoc.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build:
              (context) => pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    if (qrBytes != null)
                      pw.Image(
                        pw.MemoryImage(qrBytes),
                        width: 250,
                        height: 250,
                        fit: pw.BoxFit.fill,
                      )
                    else
                      pw.Container(
                        width: 250,
                        height: 250,
                        color: pw_pdf.PdfColor.fromInt(0xffc8c8c8),
                        child: pw.Center(
                          child: pw.Text('QR Generation Failed'),
                        ),
                      ),
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Seat $seatNumber',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'EasySit - Scan to Book',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: pw_pdf.PdfColors.grey,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'ID: $seatId',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: pw_pdf.PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
        ),
      );

      final pdfBytes = await pdfDoc.save();
      await _downloadPdf(pdfBytes, 'seat_$seatNumber.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seat $seatNumber QR saved!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Single QR Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _downloadingSeats.remove(seatId));
  }

  // Seat Legend Helper Widget
  Widget _buildSeatLegendItem(String label, Color bg, Color border, Color text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: text),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Text(
            'Manage Seats & QR',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 16),
          _buildEasySitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Building Dropdown
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('buildings').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('No Buildings'),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Building',
                          prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    var items =
                        snapshot.data!.docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              data['name'] ?? 'Unnamed',
                              style: const TextStyle(color: EasySitColors.mainText),
                            ),
                          );
                        }).toList();
                    return DropdownButtonFormField<String>(
                      value: _selectedBuildingId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Building',
                        prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedBuildingId = value;
                          _selectedFloorId = null;
                        });
                        _onRoomChanged(null);
                      },
                      hint: const Text('Select Building', style: TextStyle(color: EasySitColors.secondaryText)),
                    );
                  },
                ),
                const SizedBox(height: 15),
                // Floor Dropdown
                StreamBuilder<QuerySnapshot>(
                  stream: _getFloors(),
                  builder: (context, snapshot) {
                    if (_selectedBuildingId == null) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('Select Building first', style: TextStyle(color: EasySitColors.secondaryText)),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Floor',
                          prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('No Floors'),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Floor',
                          prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    var items =
                        snapshot.data!.docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              data['name'] ?? 'Unnamed',
                              style: const TextStyle(color: EasySitColors.mainText),
                            ),
                          );
                        }).toList();
                    return DropdownButtonFormField<String>(
                      value: _selectedFloorId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Floor',
                        prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedFloorId = value;
                        });
                        _onRoomChanged(null);
                      },
                      hint: const Text('Select Floor', style: TextStyle(color: EasySitColors.secondaryText)),
                    );
                  },
                ),
                const SizedBox(height: 15),
                // Room Dropdown
                StreamBuilder<QuerySnapshot>(
                  stream: _getRooms(),
                  builder: (context, snapshot) {
                    if (_selectedFloorId == null) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('Select Floor first', style: TextStyle(color: EasySitColors.secondaryText)),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Room',
                          prefixIcon: const Icon(Icons.door_front_door, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return DropdownButtonFormField<String>(
                        value: null,
                        items: const [],
                        hint: const Text('No Rooms'),
                        onChanged: null,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Room',
                          prefixIcon: const Icon(Icons.door_front_door, color: EasySitColors.secondaryText),
                        ),
                      );
                    }
                    var items =
                        snapshot.data!.docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(
                              data['name'] ?? 'Unnamed',
                              style: const TextStyle(color: EasySitColors.mainText),
                            ),
                          );
                        }).toList();
                    return DropdownButtonFormField<String>(
                      value: _selectedRoomId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Room',
                        prefixIcon: const Icon(Icons.door_front_door, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        _onRoomChanged(value);
                      },
                      hint: const Text('Select Room', style: TextStyle(color: EasySitColors.secondaryText)),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Divider(color: EasySitColors.divider),
                const SizedBox(height: 10),
                // Bulk Add
                const Text(
                  'Bulk Add Seats',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: EasySitColors.mainText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bulkCountController,
                        keyboardType: TextInputType.text,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Seat Count / Range',
                          hintText: 'e.g. 10 or 8-15',
                          errorText: _bulkSeatError,
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty && _selectedRoomId != null) {
                            final seats = _parseBulkInput(val, _existingSeatNumbers);
                            if (seats != null &&
                                seats.any((seat) =>
                                    _isSeatNumberDuplicate(seat.toString(), _existingSeatNumbers))) {
                              setState(() {
                                _bulkSeatError = 'This seat number already exists in this room.';
                              });
                              return;
                            }
                          }
                          if (_bulkSeatError != null) {
                            setState(() {
                              _bulkSeatError = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addSeatsBulk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EasySitColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Add Bulk',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Single Add
                const Text(
                  'Add Single Seat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: EasySitColors.mainText,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _singleSeatController,
                        keyboardType: TextInputType.text,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Seat Number',
                          hintText: 'e.g. 11',
                          errorText: _singleSeatError,
                        ),
                        onChanged: (val) {
                          final trimmed = val.trim();
                          if (trimmed.isNotEmpty &&
                              _selectedRoomId != null &&
                              _isSeatNumberDuplicate(trimmed, _existingSeatNumbers)) {
                            setState(() {
                              _singleSeatError = 'This seat number already exists in this room.';
                            });
                          } else if (_singleSeatError != null) {
                            setState(() {
                              _singleSeatError = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addSingleSeat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EasySitColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Add',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
                if (_selectedRoomId != null) ...[
                  const SizedBox(height: 18),
                  const Divider(color: EasySitColors.divider),
                  const SizedBox(height: 10),
                  // Print All QR Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _printAllQrs,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.print, color: Colors.white),
                      label: const Text(
                        'Print / Download All QR Codes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: EasySitColors.successFg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Seats Map',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: EasySitColors.mainText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Seat Legend Guidelines Display
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildSeatLegendItem('Available', EasySitColors.successBg, EasySitColors.successBorder, EasySitColors.successFg, Icons.event_seat),
                const SizedBox(width: 8),
                _buildSeatLegendItem('Occupied', EasySitColors.bookedBg, EasySitColors.divider, EasySitColors.bookedFg, Icons.lock),
                const SizedBox(width: 8),
                _buildSeatLegendItem('Pending', EasySitColors.warningBg, EasySitColors.warningBorder, EasySitColors.warningFg, Icons.access_time),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: _getSeats(),
            builder: (context, snapshot) {
              if (_selectedRoomId == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Select a room to view seats',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: EasySitColors.errorFg),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: EasySitColors.primary),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No seats in this room. Add some!',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  ),
                );
              }
              var docs = snapshot.data!.docs;
              docs.sort((a, b) {
                var aNum =
                    int.tryParse((a.data() as Map)['seatNumber'] ?? '0') ?? 0;
                var bNum =
                    int.tryParse((b.data() as Map)['seatNumber'] ?? '0') ?? 0;
                return aNum.compareTo(bNum);
              });
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String seatNumber = data['seatNumber'] ?? '?';
                  String status = data['status'] ?? 'available';
                  String qrData = data['qrData'] ?? 'SEAT:${doc.id}';

                  // Map to exact guidelines colours
                  Color cardBg = EasySitColors.successBg;
                  Color textColor = EasySitColors.successFg;
                  Color borderColor = EasySitColors.successBorder;

                  if (status == 'booked') {
                    cardBg = EasySitColors.bookedBg;
                    textColor = EasySitColors.bookedFg;
                    borderColor = EasySitColors.divider;
                  } else if (status == 'pending') {
                    cardBg = EasySitColors.warningBg;
                    textColor = EasySitColors.warningFg;
                    borderColor = EasySitColors.warningBorder;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            seatNumber,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: GestureDetector(
                            onTap: () => _deleteSeat(doc.id),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: EasySitColors.errorFg,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: GestureDetector(
                            onTap:
                                _downloadingSeats.contains(doc.id)
                                    ? null
                                    : () => _printSingleQr(
                                      doc.id,
                                      seatNumber,
                                      qrData,
                                    ),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child:
                                  _downloadingSeats.contains(doc.id)
                                      ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: EasySitColors.primary,
                                        ),
                                      )
                                      : Icon(
                                        Icons.qr_code,
                                        size: 16,
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _seatsSubscription?.cancel();
    _bulkCountController.dispose();
    _singleSeatController.dispose();
    super.dispose();
  }
}

// ============================================================
// 5. SEND NOTIFICATION SCREEN
// ============================================================
class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _sendNotification() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await _firestore.collection('notifications').add({
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': 'all',
      });
      _titleController.clear();
      _messageController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent to all students!'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    setState(() => _isSending = false);
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await _firestore.collection('notifications').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted.'),
            backgroundColor: EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Text(
            'Send Notification to All Students',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'This notification will appear for all students in real-time.',
            style: TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
          ),
          const SizedBox(height: 18),
          _buildEasySitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Notification Title',
                    hintText: 'e.g. Library Closure Notice',
                    prefixIcon: const Icon(Icons.title, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Notification Message',
                    hintText: 'Type your message here...',
                    prefixIcon: const Icon(Icons.message, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendNotification,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    label: Text(
                      _isSending ? 'Sending...' : 'Send to All Students',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasySitColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Sent Notifications',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('notifications')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: EasySitColors.errorFg),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: EasySitColors.primary),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No notifications sent yet.',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  Timestamp? ts = data['timestamp'] as Timestamp?;
                  String timeStr = '';
                  if (ts != null) {
                    DateTime dt = ts.toDate();
                    timeStr =
                        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                  }
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: EasySitColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: EasySitColors.divider),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: EasySitColors.primaryTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications, color: EasySitColors.primary),
                      ),
                      title: Text(
                        data['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: EasySitColors.mainText,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            data['message'] ?? '',
                            style: const TextStyle(color: EasySitColors.bodyText),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 11,
                                color: EasySitColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: EasySitColors.errorFg),
                        onPressed: () => _deleteNotification(doc.id),
                        tooltip: 'Delete Notification',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 6. STUDENT ACTIVITY & ACCESS SCREEN
// ============================================================
class StudentActivityAccessScreen extends StatefulWidget {
  const StudentActivityAccessScreen({super.key});

  @override
  State<StudentActivityAccessScreen> createState() => _StudentActivityAccessScreenState();
}

enum _StudentFilterType { all, active, blocked, highActivity }

class _ParsedSessionRecord {
  final String rawSeatId;
  final String cleanSeatId;
  final DateTime? date;
  final bool isActive;
  final String status;

  _ParsedSessionRecord({
    required this.rawSeatId,
    required this.cleanSeatId,
    this.date,
    this.isActive = false,
    this.status = 'completed',
  });
}

class _StudentActivityAccessScreenState extends State<StudentActivityAccessScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  _StudentFilterType _selectedFilter = _StudentFilterType.all;

  // Safe timestamp parser from session keys ('{seatId}_{timestamp}')
  DateTime? _parseSessionTimestamp(String sessionKey) {
    final int lastUnderscore = sessionKey.lastIndexOf('_');
    if (lastUnderscore <= 0) return null;
    final String timeStr = sessionKey.substring(lastUnderscore + 1).trim();
    final int? val = int.tryParse(timeStr);
    if (val == null) return null;
    if (val > 100000000000) {
      // 11+ digits: milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(val);
    } else if (val > 1000000000) {
      // 10 digits: seconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(val * 1000);
    } else {
      // 8-9 digits: milliseconds ~/ 10000 (UserStatsService fallback)
      return DateTime.fromMillisecondsSinceEpoch(val * 10000);
    }
  }

  String _parseSeatIdFromKey(String sessionKey) {
    final int lastUnderscore = sessionKey.lastIndexOf('_');
    final String raw = lastUnderscore > 0 ? sessionKey.substring(0, lastUnderscore) : sessionKey;
    return raw.replaceFirst('SEAT:', '').trim();
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Date unavailable';
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$hour:$minute $ampm';

    if (isToday) {
      return 'Today • $timeString';
    } else if (isYesterday) {
      return 'Yesterday • $timeString';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $timeString';
    }
  }

  String _formatStudyHours(int totalMinutes) {
    if (totalMinutes <= 0) return '0 hrs';
    final double hours = totalMinutes / 60.0;
    if (hours < 1.0) {
      return '$totalMinutes mins';
    }
    return '${hours.toStringAsFixed(1)} hrs';
  }

  String _resolveSeatTitle(
    String seatId,
    Map<String, Map<String, dynamic>> seatsData,
    Map<String, String> roomNames,
  ) {
    final cleanId = seatId.replaceFirst('SEAT:', '').trim();
    final seat = seatsData[cleanId] ?? seatsData[seatId];
    if (seat != null) {
      final seatNum = seat['seatNumber']?.toString();
      final roomId = seat['roomId']?.toString() ?? '';
      final roomName = seat['roomName']?.toString() ?? roomNames[roomId] ?? '';
      if (seatNum != null && seatNum.isNotEmpty) {
        if (roomName.isNotEmpty) {
          return 'Seat #$seatNum • $roomName';
        }
        return 'Seat #$seatNum';
      }
    }
    if (cleanId.isNotEmpty) {
      final display = cleanId.length > 8 ? cleanId.substring(0, 8) : cleanId;
      return 'Seat $display';
    }
    return 'Seat (Recorded)';
  }

  Future<void> _confirmAndToggleBlock(
    BuildContext context, {
    required String userId,
    required String fullName,
    required String studentId,
    required bool currentIsBlocked,
  }) async {
    final bool willBlock = !currentIsBlocked;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: EasySitColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: willBlock ? EasySitColors.errorBg : EasySitColors.successBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                willBlock ? Icons.block : Icons.lock_open_rounded,
                color: willBlock ? EasySitColors.errorFg : EasySitColors.successFg,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                willBlock ? 'Block Student Access?' : 'Unblock Student Access?',
                style: const TextStyle(
                  color: EasySitColors.mainText,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          willBlock
              ? 'Are you sure you want to block $fullName ($studentId)?\n\n'
                'While blocked, this student will not be able to log in or reserve seats in the library until manually unblocked.'
              : 'Are you sure you want to unblock $fullName ($studentId)?\n\n'
                'The student will immediately regain access to log in and reserve seats.',
          style: const TextStyle(
            color: EasySitColors.secondaryText,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: EasySitColors.secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? EasySitColors.errorFg : EasySitColors.successFg,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              willBlock ? 'Block Student' : 'Unblock Student',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'isBlocked': willBlock,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                willBlock
                    ? '$fullName has been blocked.'
                    : '$fullName has been unblocked.',
              ),
              backgroundColor: willBlock ? EasySitColors.warningFg : EasySitColors.successFg,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating access status: $e'),
              backgroundColor: EasySitColors.errorFg,
            ),
          );
        }
      }
    }
  }

  void _showStudentDetailsSheet(
    BuildContext context, {
    required String userId,
    required Map<String, dynamic> studentData,
    required bool isBlocked,
    required int totalCompletedSessions,
    required int totalMinutesStudied,
    required int differentSeatsUsed,
    required int sessionsTodayCount,
    required int maxSessionsInSingleDay,
    required bool hasHighActivity,
    required List<_ParsedSessionRecord> sessions,
    required Map<String, dynamic>? activeBooking,
    required Map<String, Map<String, dynamic>> seatsData,
    required Map<String, String> roomNames,
  }) {
    final String fullName = studentData['fullName'] ?? 'Unknown Name';
    final String studentId = studentData['studentId'] ?? 'N/A';
    final String email = studentData['email'] ?? 'No email';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('users').doc(userId).snapshots(),
              builder: (context, userSnap) {
                bool currentIsBlocked = isBlocked;
                if (userSnap.hasData && userSnap.data!.exists) {
                  final liveData = userSnap.data!.data() as Map<String, dynamic>?;
                  if (liveData != null) {
                    currentIsBlocked = liveData['isBlocked'] == true;
                  }
                }

                return DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (_, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: EasySitColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          // Sheet drag handle
                          Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 8),
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: EasySitColors.divider,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                const Text(
                                  'Student Activity & Access',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: EasySitColors.mainText,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, color: EasySitColors.secondaryText),
                                  onPressed: () => Navigator.of(sheetContext).pop(),
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: EasySitColors.divider),
                          // Scrollable body
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(20),
                              children: [
                                // Student Profile Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: EasySitColors.appBackground,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: EasySitColors.divider),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: currentIsBlocked
                                            ? EasySitColors.errorBg
                                            : EasySitColors.primaryTint,
                                        child: Text(
                                          fullName.isNotEmpty
                                              ? fullName.substring(0, 1).toUpperCase()
                                              : 'S',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: currentIsBlocked
                                                ? EasySitColors.errorFg
                                                : EasySitColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fullName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: EasySitColors.mainText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'ID: $studentId',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                height: 1.4,
                                                color: EasySitColors.secondaryText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              email,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                height: 1.4,
                                                color: EasySitColors.secondaryText,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: currentIsBlocked
                                              ? EasySitColors.errorBg
                                              : EasySitColors.successBg,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: currentIsBlocked
                                                ? EasySitColors.errorBorder
                                                : EasySitColors.successBorder,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              currentIsBlocked
                                                  ? Icons.block
                                                  : Icons.check_circle_rounded,
                                              size: 14,
                                              color: currentIsBlocked
                                                  ? EasySitColors.errorFg
                                                  : EasySitColors.successFg,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              currentIsBlocked ? 'Blocked' : 'Active',
                                              style: TextStyle(
                                                color: currentIsBlocked
                                                    ? EasySitColors.errorFg
                                                    : EasySitColors.successFg,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // High Activity Banner (Amber Review Recommended)
                                if (hasHighActivity) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7), // Light amber bg
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFF59E0B)), // Amber border
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFB45309),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'High Activity – Review Recommended',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'This student has recorded 6 or more seat sessions in a single day '
                                                '($sessionsTodayCount sessions today, peak single-day usage: $maxSessionsInSingleDay). '
                                                'Student is not automatically blocked. Please review recent seat bookings.',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  color: Color(0xFF92400E),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // 2x2 Statistics Grid
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.task_alt_rounded,
                                        iconColor: EasySitColors.primary,
                                        label: 'Total Completed',
                                        value: '$totalCompletedSessions sessions',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.schedule_rounded,
                                        iconColor: EasySitColors.primary,
                                        label: 'Total Study Time',
                                        value: _formatStudyHours(totalMinutesStudied),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.event_seat_rounded,
                                        iconColor: EasySitColors.primary,
                                        label: 'Different Seats',
                                        value: '$differentSeatsUsed used',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMetricTile(
                                        icon: Icons.today_rounded,
                                        iconColor: sessionsTodayCount >= 6
                                            ? const Color(0xFFB45309)
                                            : EasySitColors.primary,
                                        label: 'Completed Today',
                                        value: '$sessionsTodayCount sessions',
                                        isWarning: sessionsTodayCount >= 6,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Currently Active Session (if any)
                                if (activeBooking != null) ...[
                                  const Text(
                                    'Active Session',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: EasySitColors.mainText,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: EasySitColors.primaryTint,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: EasySitColors.softBlueBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                            color: EasySitColors.successFg,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _resolveSeatTitle(
                                                  activeBooking['id'] ?? '',
                                                  seatsData,
                                                  roomNames,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 15,
                                                  color: EasySitColors.mainText,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                activeBooking['bookedAt'] != null
                                                    ? 'Booked: ${_formatDateTime((activeBooking['bookedAt'] as Timestamp).toDate())}'
                                                    : 'Status: In Progress',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w400,
                                                  height: 1.4,
                                                  color: EasySitColors.secondaryText,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Occupying Now',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: EasySitColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // Recently Used Seats
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Recently Used Seats',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: EasySitColors.mainText,
                                      ),
                                    ),
                                    Text(
                                      '${sessions.length} recorded',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: EasySitColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                if (sessions.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: EasySitColors.appBackground,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: EasySitColors.divider),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'No session history recorded yet.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          height: 1.4,
                                          color: EasySitColors.secondaryText,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ...sessions.take(15).map((sess) {
                                    final String seatTitle = _resolveSeatTitle(
                                      sess.cleanSeatId,
                                      seatsData,
                                      roomNames,
                                    );
                                    final String dateStr = _formatDateTime(sess.date);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: EasySitColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: EasySitColors.divider),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: sess.isActive
                                                  ? EasySitColors.primaryTint
                                                  : EasySitColors.appBackground,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              sess.isActive
                                                  ? Icons.event_seat
                                                  : Icons.chair_outlined,
                                              size: 18,
                                              color: sess.isActive
                                                  ? EasySitColors.primary
                                                  : EasySitColors.secondaryText,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  seatTitle,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15,
                                                    color: EasySitColors.mainText,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  dateStr,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w400,
                                                    height: 1.4,
                                                    color: EasySitColors.secondaryText,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (sess.isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: EasySitColors.successBg,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'Active',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: EasySitColors.successFg,
                                                ),
                                              ),
                                            )
                                          else
                                            const Text(
                                              'Completed',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: EasySitColors.secondaryText,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),

                                const SizedBox(height: 24),

                                // Access Action Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: currentIsBlocked
                                          ? EasySitColors.successFg
                                          : EasySitColors.errorFg,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: Icon(
                                      currentIsBlocked ? Icons.lock_open : Icons.block,
                                      size: 18,
                                    ),
                                    label: Text(
                                      currentIsBlocked
                                          ? 'Unblock Student Access'
                                          : 'Block Student Access',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () {
                                      _confirmAndToggleBlock(
                                        context,
                                        userId: userId,
                                        fullName: fullName,
                                        studentId: studentId,
                                        currentIsBlocked: currentIsBlocked,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFEF3C7) : EasySitColors.appBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWarning ? const Color(0xFFF59E0B) : EasySitColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                    color: isWarning ? const Color(0xFF92400E) : EasySitColors.secondaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isWarning ? const Color(0xFFB45309) : EasySitColors.mainText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          const Text(
            'Student Activity & Access',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Real-time seat usage, activity monitoring, and access controls.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: EasySitColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            decoration: _buildEasySitInputDecoration(
              labelText: 'Search by Name, Email, or Student ID',
              prefixIcon: const Icon(Icons.search, color: EasySitColors.secondaryText),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase().trim();
              });
            },
          ),
          const SizedBox(height: 12),

          // Stream rooms, seats, and users in real-time
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('rooms').snapshots(),
              builder: (context, roomsSnap) {
                final Map<String, String> roomNames = {};
                if (roomsSnap.hasData) {
                  for (final d in roomsSnap.data!.docs) {
                    final data = d.data() as Map<String, dynamic>?;
                    roomNames[d.id] = data?['name']?.toString() ?? 'Room';
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('seats').snapshots(),
                  builder: (context, seatsSnap) {
                    final Map<String, Map<String, dynamic>> seatsData = {};
                    final Map<String, Map<String, dynamic>> activeSessionByStudent = {};

                    if (seatsSnap.hasData) {
                      for (final d in seatsSnap.data!.docs) {
                        final data = d.data() as Map<String, dynamic>;
                        final map = Map<String, dynamic>.from(data);
                        map['id'] = d.id;
                        seatsData[d.id] = map;

                        final bookedBy = data['bookedBy']?.toString();
                        final pendingBy = data['pendingBy']?.toString();
                        if (bookedBy != null && bookedBy.isNotEmpty) {
                          activeSessionByStudent[bookedBy] = map;
                        } else if (pendingBy != null && pendingBy.isNotEmpty) {
                          activeSessionByStudent[pendingBy] = map;
                        }
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('users')
                          .where('userType', isEqualTo: 'student')
                          .snapshots(),
                      builder: (context, usersSnap) {
                        if (usersSnap.hasError) {
                          return Center(
                            child: Text(
                              'Error loading students: ${usersSnap.error}',
                              style: const TextStyle(
                                color: EasySitColors.errorFg,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        }
                        if (usersSnap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: EasySitColors.primary),
                          );
                        }
                        if (!usersSnap.hasData || usersSnap.data!.docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No registered students found.',
                              style: TextStyle(
                                color: EasySitColors.secondaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          );
                        }

                        // Pre-process student records
                        final allDocs = usersSnap.data!.docs;
                        final List<Map<String, dynamic>> processedStudents = [];

                        int countActive = 0;
                        int countBlocked = 0;
                        int countHighActivity = 0;

                        for (final doc in allDocs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String uid = doc.id;
                          final String fullName = data['fullName'] ?? 'Unknown Name';
                          final String studentId = data['studentId'] ?? 'Unknown ID';
                          final String email = data['email'] ?? 'No email';
                          final bool isBlocked = data['isBlocked'] == true;

                          if (isBlocked) {
                            countBlocked++;
                          } else {
                            countActive++;
                          }

                          final List<dynamic> rawCompletedKeys =
                              List<dynamic>.from(data['completedSessionKeys'] ?? []);
                          final int storedSessionsCompleted =
                              (data['sessionsCompleted'] as num?)?.toInt() ?? rawCompletedKeys.length;
                          final int totalCompletedSessions = storedSessionsCompleted >= rawCompletedKeys.length
                              ? storedSessionsCompleted
                              : rawCompletedKeys.length;

                          final int totalMinutesStudied =
                              (data['totalMinutesStudied'] as num?)?.toInt() ?? 0;

                          final Set<String> usedSeatsSet = (data['usedSeats'] as List? ?? [])
                              .map((e) => e.toString().replaceFirst('SEAT:', '').trim())
                              .where((e) => e.isNotEmpty)
                              .toSet();
                          final int storedDifferentSeats =
                              (data['differentSeatsUsed'] as num?)?.toInt() ?? usedSeatsSet.length;
                          final int differentSeatsUsed = storedDifferentSeats >= usedSeatsSet.length
                              ? storedDifferentSeats
                              : usedSeatsSet.length;

                          // Parse session keys
                          final List<_ParsedSessionRecord> sessions = [];
                          for (final keyObj in rawCompletedKeys) {
                            final key = keyObj.toString();
                            final date = _parseSessionTimestamp(key);
                            final cleanSeat = _parseSeatIdFromKey(key);
                            sessions.add(
                              _ParsedSessionRecord(
                                rawSeatId: key,
                                cleanSeatId: cleanSeat,
                                date: date,
                                isActive: false,
                                status: 'completed',
                              ),
                            );
                          }

                          // If lastSessionCompletedAt exists and newest session lacks date, fallback safely
                          if (data['lastSessionCompletedAt'] != null && sessions.isNotEmpty) {
                            final Timestamp ts = data['lastSessionCompletedAt'] as Timestamp;
                            if (sessions.last.date == null) {
                              final last = sessions.removeLast();
                              sessions.add(
                                _ParsedSessionRecord(
                                  rawSeatId: last.rawSeatId,
                                  cleanSeatId: last.cleanSeatId,
                                  date: ts.toDate(),
                                  isActive: false,
                                  status: 'completed',
                                ),
                              );
                            }
                          }

                          // Add active booking if exists
                          final Map<String, dynamic>? activeBooking = activeSessionByStudent[uid];
                          if (activeBooking != null) {
                            DateTime? activeDate;
                            final bookedAt = activeBooking['bookedAt'] as Timestamp?;
                            final pendingAt = activeBooking['pendingAt'] as Timestamp?;
                            if (bookedAt != null) {
                              activeDate = bookedAt.toDate();
                            } else if (pendingAt != null) {
                              activeDate = pendingAt.toDate();
                            }

                            sessions.insert(
                              0,
                              _ParsedSessionRecord(
                                rawSeatId: activeBooking['id'] ?? '',
                                cleanSeatId: (activeBooking['id'] ?? '').toString().replaceFirst('SEAT:', '').trim(),
                                date: activeDate,
                                isActive: true,
                                status: activeBooking['status'] ?? 'booked',
                              ),
                            );
                          }

                          // Sort sessions newest first (treating null dates as oldest)
                          sessions.sort((a, b) {
                            if (a.isActive && !b.isActive) return -1;
                            if (!a.isActive && b.isActive) return 1;
                            if (a.date == null && b.date == null) return 0;
                            if (a.date == null) return 1;
                            if (b.date == null) return -1;
                            return b.date!.compareTo(a.date!);
                          });

                          // Calculate sessions completed today
                          int sessionsTodayCount = 0;
                          final Map<String, int> dailyCounts = {};

                          for (final sess in sessions) {
                            if (sess.date != null) {
                              final dt = sess.date!;
                              final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
                              if (isToday) {
                                sessionsTodayCount++;
                              }
                              final dayKey = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                              dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
                            }
                          }

                          int maxDailyCount = sessionsTodayCount;
                          for (final count in dailyCounts.values) {
                            if (count > maxDailyCount) maxDailyCount = count;
                          }

                          // High activity threshold: 6 or more sessions in one day
                          // Do not automatically block them.
                          final bool hasHighActivity = sessionsTodayCount >= 6 || maxDailyCount >= 6;
                          if (hasHighActivity) {
                            countHighActivity++;
                          }

                          processedStudents.add({
                            'doc': doc,
                            'userId': uid,
                            'data': data,
                            'fullName': fullName,
                            'studentId': studentId,
                            'email': email,
                            'isBlocked': isBlocked,
                            'totalCompletedSessions': totalCompletedSessions,
                            'totalMinutesStudied': totalMinutesStudied,
                            'differentSeatsUsed': differentSeatsUsed,
                            'sessionsTodayCount': sessionsTodayCount,
                            'maxSessionsInSingleDay': maxDailyCount,
                            'hasHighActivity': hasHighActivity,
                            'sessions': sessions,
                            'activeBooking': activeBooking,
                          });
                        }

                        // Filter by search query
                        var filteredList = processedStudents;
                        if (_searchQuery.isNotEmpty) {
                          filteredList = filteredList.where((item) {
                            final name = item['fullName'].toString().toLowerCase();
                            final sid = item['studentId'].toString().toLowerCase();
                            final em = item['email'].toString().toLowerCase();
                            return name.contains(_searchQuery) ||
                                sid.contains(_searchQuery) ||
                                em.contains(_searchQuery);
                          }).toList();
                        }

                        // Filter by chip category
                        if (_selectedFilter == _StudentFilterType.active) {
                          filteredList = filteredList.where((item) => item['isBlocked'] == false).toList();
                        } else if (_selectedFilter == _StudentFilterType.blocked) {
                          filteredList = filteredList.where((item) => item['isBlocked'] == true).toList();
                        } else if (_selectedFilter == _StudentFilterType.highActivity) {
                          filteredList = filteredList.where((item) => item['hasHighActivity'] == true).toList();
                        }

                        return Column(
                          children: [
                            // Filter Chips Row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    label: 'All (${processedStudents.length})',
                                    selected: _selectedFilter == _StudentFilterType.all,
                                    onTap: () => setState(() => _selectedFilter = _StudentFilterType.all),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label: 'Active ($countActive)',
                                    selected: _selectedFilter == _StudentFilterType.active,
                                    onTap: () => setState(() => _selectedFilter = _StudentFilterType.active),
                                    activeColor: EasySitColors.successFg,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label: 'Blocked ($countBlocked)',
                                    selected: _selectedFilter == _StudentFilterType.blocked,
                                    onTap: () => setState(() => _selectedFilter = _StudentFilterType.blocked),
                                    activeColor: EasySitColors.errorFg,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    label: 'High Activity ($countHighActivity)',
                                    selected: _selectedFilter == _StudentFilterType.highActivity,
                                    onTap: () => setState(() => _selectedFilter = _StudentFilterType.highActivity),
                                    activeColor: const Color(0xFFB45309),
                                    isWarningChip: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // List of Students
                            Expanded(
                              child: filteredList.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No matching students found.',
                                        style: TextStyle(
                                          color: EasySitColors.secondaryText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredList[index];
                                        final String uid = item['userId'];
                                        final Map<String, dynamic> data = item['data'];
                                        final String fullName = item['fullName'];
                                        final String studentId = item['studentId'];
                                        final String email = item['email'];
                                        final bool isBlocked = item['isBlocked'];
                                        final int totalCompletedSessions = item['totalCompletedSessions'];
                                        final int totalMinutesStudied = item['totalMinutesStudied'];
                                        final int differentSeatsUsed = item['differentSeatsUsed'];
                                        final int sessionsTodayCount = item['sessionsTodayCount'];
                                        final int maxSessionsInSingleDay = item['maxSessionsInSingleDay'];
                                        final bool hasHighActivity = item['hasHighActivity'];
                                        final List<_ParsedSessionRecord> sessions = item['sessions'];
                                        final Map<String, dynamic>? activeBooking = item['activeBooking'];

                                        final _ParsedSessionRecord? mostRecent =
                                            sessions.isNotEmpty ? sessions.first : null;

                                        return Container(
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: EasySitColors.surface,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: hasHighActivity
                                                  ? const Color(0xFFF59E0B)
                                                  : EasySitColors.divider,
                                              width: hasHighActivity ? 1.5 : 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.03),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(12),
                                              onTap: () {
                                                _showStudentDetailsSheet(
                                                  context,
                                                  userId: uid,
                                                  studentData: data,
                                                  isBlocked: isBlocked,
                                                  totalCompletedSessions: totalCompletedSessions,
                                                  totalMinutesStudied: totalMinutesStudied,
                                                  differentSeatsUsed: differentSeatsUsed,
                                                  sessionsTodayCount: sessionsTodayCount,
                                                  maxSessionsInSingleDay: maxSessionsInSingleDay,
                                                  hasHighActivity: hasHighActivity,
                                                  sessions: sessions,
                                                  activeBooking: activeBooking,
                                                  seatsData: seatsData,
                                                  roomNames: roomNames,
                                                );
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(16.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // Top Row: Avatar, Name & ID, Status Chip
                                                    Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 20,
                                                          backgroundColor: isBlocked
                                                              ? EasySitColors.errorBg
                                                              : EasySitColors.primaryTint,
                                                          child: Text(
                                                            fullName.isNotEmpty
                                                                ? fullName.substring(0, 1).toUpperCase()
                                                                : 'S',
                                                            style: TextStyle(
                                                              color: isBlocked
                                                                  ? EasySitColors.errorFg
                                                                  : EasySitColors.primary,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                fullName,
                                                                style: const TextStyle(
                                                                  fontSize: 17,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: EasySitColors.mainText,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              const SizedBox(height: 3),
                                                              Text(
                                                                '$studentId • $email',
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight: FontWeight.w400,
                                                                  height: 1.4,
                                                                  color: EasySitColors.secondaryText,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        // Active or Blocked Badge
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                          decoration: BoxDecoration(
                                                            color: isBlocked
                                                                ? EasySitColors.errorBg
                                                                : EasySitColors.successBg,
                                                            borderRadius: BorderRadius.circular(12),
                                                            border: Border.all(
                                                              color: isBlocked
                                                                  ? EasySitColors.errorBorder
                                                                  : EasySitColors.successBorder,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            isBlocked ? 'Blocked' : 'Active',
                                                            style: TextStyle(
                                                              color: isBlocked
                                                                  ? EasySitColors.errorFg
                                                                  : EasySitColors.successFg,
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    // Amber Warning Badge for High Activity (>= 6 in one day)
                                                    if (hasHighActivity) ...[
                                                      const SizedBox(height: 10),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEF3C7),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: const Color(0xFFF59E0B)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: const [
                                                            Icon(
                                                              Icons.warning_amber_rounded,
                                                              size: 16,
                                                              color: Color(0xFFB45309),
                                                            ),
                                                            SizedBox(width: 6),
                                                            Flexible(
                                                              child: Text(
                                                                'High Activity – Review Recommended',
                                                                style: TextStyle(
                                                                  color: Color(0xFFB45309),
                                                                  fontWeight: FontWeight.w600,
                                                                  fontSize: 13,
                                                                ),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],

                                                    const SizedBox(height: 12),

                                                    // Quick Metrics Row (4 stats)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: EasySitColors.appBackground,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: _buildInlineStat(
                                                              label: 'Sessions',
                                                              value: '$totalCompletedSessions',
                                                            ),
                                                          ),
                                                          Container(width: 1, height: 28, color: EasySitColors.divider),
                                                          Expanded(
                                                            child: _buildInlineStat(
                                                              label: 'Hours',
                                                              value: _formatStudyHours(totalMinutesStudied),
                                                            ),
                                                          ),
                                                          Container(width: 1, height: 28, color: EasySitColors.divider),
                                                          Expanded(
                                                            child: _buildInlineStat(
                                                              label: 'Seats',
                                                              value: '$differentSeatsUsed',
                                                            ),
                                                          ),
                                                          Container(width: 1, height: 28, color: EasySitColors.divider),
                                                          Expanded(
                                                            child: _buildInlineStat(
                                                              label: 'Today',
                                                              value: '$sessionsTodayCount',
                                                              isWarning: sessionsTodayCount >= 6,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                    const SizedBox(height: 10),

                                                    // Recently Used Seat Line
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          mostRecent != null && mostRecent.isActive
                                                              ? Icons.circle
                                                              : Icons.history,
                                                          size: 15,
                                                          color: mostRecent != null && mostRecent.isActive
                                                              ? EasySitColors.successFg
                                                              : EasySitColors.secondaryText,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            mostRecent != null
                                                                ? (mostRecent.isActive
                                                                    ? 'Active now: ${_resolveSeatTitle(mostRecent.cleanSeatId, seatsData, roomNames)}'
                                                                    : 'Recent: ${_resolveSeatTitle(mostRecent.cleanSeatId, seatsData, roomNames)} (${_formatDateTime(mostRecent.date)})')
                                                                : 'No seat sessions recorded yet',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: mostRecent != null && mostRecent.isActive
                                                                  ? EasySitColors.primary
                                                                  : EasySitColors.secondaryText,
                                                              fontWeight: mostRecent != null && mostRecent.isActive
                                                                  ? FontWeight.w600
                                                                  : FontWeight.w400,
                                                              height: 1.4,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),

                                                    const SizedBox(height: 10),
                                                    const Divider(height: 1, color: EasySitColors.divider),
                                                    const SizedBox(height: 8),

                                                    // Action Row: View Activity Details & Manual Block/Unblock
                                                    Row(
                                                      children: [
                                                        TextButton.icon(
                                                          style: TextButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          ),
                                                          icon: const Icon(
                                                            Icons.info_outline,
                                                            size: 16,
                                                            color: EasySitColors.primary,
                                                          ),
                                                          label: const Text(
                                                            'View Activity Details',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: EasySitColors.primary,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            _showStudentDetailsSheet(
                                                              context,
                                                              userId: uid,
                                                              studentData: data,
                                                              isBlocked: isBlocked,
                                                              totalCompletedSessions: totalCompletedSessions,
                                                              totalMinutesStudied: totalMinutesStudied,
                                                              differentSeatsUsed: differentSeatsUsed,
                                                              sessionsTodayCount: sessionsTodayCount,
                                                              maxSessionsInSingleDay: maxSessionsInSingleDay,
                                                              hasHighActivity: hasHighActivity,
                                                              sessions: sessions,
                                                              activeBooking: activeBooking,
                                                              seatsData: seatsData,
                                                              roomNames: roomNames,
                                                            );
                                                          },
                                                        ),
                                                        const Spacer(),
                                                        OutlinedButton.icon(
                                                          style: OutlinedButton.styleFrom(
                                                            side: BorderSide(
                                                              color: isBlocked
                                                                  ? EasySitColors.successBorder
                                                                  : EasySitColors.errorBorder,
                                                            ),
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            minimumSize: Size.zero,
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                          ),
                                                          icon: Icon(
                                                            isBlocked ? Icons.lock_open : Icons.block,
                                                            size: 15,
                                                            color: isBlocked ? EasySitColors.successFg : EasySitColors.errorFg,
                                                          ),
                                                          label: Text(
                                                            isBlocked ? 'Unblock' : 'Block',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: isBlocked ? EasySitColors.successFg : EasySitColors.errorFg,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            _confirmAndToggleBlock(
                                                              context,
                                                              userId: uid,
                                                              fullName: fullName,
                                                              studentId: studentId,
                                                              currentIsBlocked: isBlocked,
                                                            );
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStat({
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isWarning ? const Color(0xFFB45309) : EasySitColors.mainText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: EasySitColors.secondaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Color activeColor = EasySitColors.primary,
    bool isWarningChip = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isWarningChip ? const Color(0xFFFEF3C7) : activeColor.withValues(alpha: 0.12))
              : EasySitColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isWarningChip ? const Color(0xFFF59E0B) : activeColor)
                : EasySitColors.divider,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isWarningChip ? const Color(0xFFB45309) : activeColor)
                : EasySitColors.bodyText,
          ),
        ),
      ),
    );
  }
}

// Backward compatibility alias
typedef StudentBehaviorScreen = StudentActivityAccessScreen;

// ============================================================
// 7. ADMIN PROFILE SCREEN
// ============================================================
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(_user.uid).get();
      if (doc.exists && mounted) {
        var data = doc.data() as Map<String, dynamic>;
        _nameCtrl.text = data['fullName'] ?? _user.displayName ?? '';
        _emailCtrl.text = data['email'] ?? _user.email ?? '';
        _phoneCtrl.text = data['phone'] ?? '';
      } else if (mounted) {
        _nameCtrl.text = _user.displayName ?? '';
        _emailCtrl.text = _user.email ?? '';
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firestore.collection('users').doc(_user.uid).set({
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'userType': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: EasySitColors.primary),
      );
    }

    String fullName = _nameCtrl.text.trim();
    String initialLetter = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A';

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        children: [
          const Text(
            'Admin Profile',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 16),

          // Header Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EasySitColors.deepPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: EasySitColors.primary,
                  child: Text(
                    initialLetter,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'Administrator',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailCtrl.text,
                        style: const TextStyle(
                          fontSize: 13,
                          color: EasySitColors.logoLavender,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: EasySitColors.successBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: EasySitColors.successBorder),
                        ),
                        child: const Text(
                          'Administrator',
                          style: TextStyle(
                            color: EasySitColors.successFg,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Edit Profile Form Card
          _buildEasySitCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.mainText,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameCtrl,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: const Icon(Icons.person, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  enabled: false,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Email Address (Read-only)',
                    prefixIcon: const Icon(Icons.email, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _buildEasySitInputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: const Icon(Icons.phone, color: EasySitColors.secondaryText),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.white, size: 18),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Profile Changes',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasySitColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Sign Out Card
          _buildEasySitCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Session Control',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sign out of your admin session',
                      style: TextStyle(
                        fontSize: 12,
                        color: EasySitColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        AppPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: EasySitColors.errorFg, size: 18),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: EasySitColors.errorFg, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: EasySitColors.errorBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
