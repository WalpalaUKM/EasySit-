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

// ============================================================
// EASYSIT DESIGN PALETTE (From Guidelines Document)
// ============================================================
class EasySitColors {
  // Brand & Identity
  static const Color primary = Color(0xFF386CD1);       // Logo blue - primary action & active nav
  static const Color deepPurple = Color(0xFF29234F);    // Deep purple - logo backdrop & headers
  static const Color logoLavender = Color(0xFFB5BBDB);  // Easy text on dark logo bg
  static const Color mutedLavender = Color(0xFF989CBC); // Tagline on dark

  // Interactive States
  static const Color hover = Color(0xFF2E5DB8);
  static const Color pressed = Color(0xFF254D9B);
  static const Color focusRing = Color(0xFF254D9B);
  static const Color primaryTint = Color(0xFFEDF3FF);   // Selected navigation & filter bg
  static const Color softBlueBorder = Color(0xFFBED0F5);
  static const Color purpleAccent = Color(0xFF6D28D9);
  static const Color accentTint = Color(0xFFF3EEFF);

  // Surfaces & Backgrounds
  static const Color appBackground = Color(0xFFF7F8FC); // Main screen background
  static const Color surface = Color(0xFFFFFFFF);       // Cards, drawer, dialogs & fields
  static const Color subtleSurface = Color(0xFFF1F5F9); // Secondary panels & icon containers

  // Typography & Boundaries
  static const Color mainText = Color(0xFF0F172A);      // Titles, key values
  static const Color bodyText = Color(0xFF334155);      // Descriptions & field labels
  static const Color secondaryText = Color(0xFF64748B); // Helper text, timestamps, placeholders
  static const Color divider = Color(0xFFE2E8F0);       // Subtle card edges & separators
  static const Color inputBorder = Color(0xFF7C899D);   // Editable field boundaries
  static const Color disabledFill = Color(0xFFE2E8F0);
  static const Color disabledText = Color(0xFF64748B);

  // Feedback & Statuses
  // Success / Available / Active
  static const Color successFg = Color(0xFF15803D);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  // Warning / Pending
  static const Color warningFg = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Error / Blocked / Destructive
  static const Color errorFg = Color(0xFFB91C1C);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  // Information
  static const Color infoFg = Color(0xFF386CD1);
  static const Color infoBg = Color(0xFFEDF3FF);
  static const Color infoBorder = Color(0xFFBED0F5);

  // Booked / Occupied
  static const Color bookedFg = Color(0xFF475569);
  static const Color bookedBg = Color(0xFFE2E8F0);
}

// Shared UI Helpers
InputDecoration _buildEasySitInputDecoration({
  required String labelText,
  String? hintText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
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
  int _selectedIndex = 0;

  final List<String> _menuTitles = [
    'Home Overview',
    'Manage Buildings',
    'Manage Floors',
    'Manage Rooms',
    'Manage Seats & QR',
    'Student Behavior',
    'Send Notification',
    'Admin Profile',
  ];

  final List<IconData> _menuIcons = [
    Icons.home_rounded,
    Icons.business,
    Icons.vertical_align_top,
    Icons.door_front_door,
    Icons.event_seat,
    Icons.analytics,
    Icons.notifications_active,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EasySitColors.appBackground,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: EasySitColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Admin Profile',
            onPressed: () {
              setState(() {
                _selectedIndex = 7;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
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
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
              decoration: const BoxDecoration(
                color: EasySitColors.deepPurple,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'EasySit',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Administrator Portal',
                    style: TextStyle(
                      fontSize: 13,
                      color: EasySitColors.logoLavender,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: _menuTitles.length,
                itemBuilder: (context, index) {
                  final bool isSelected = _selectedIndex == index;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? EasySitColors.primaryTint : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      leading: Icon(
                        _menuIcons[index],
                        color: isSelected ? EasySitColors.primary : EasySitColors.secondaryText,
                      ),
                      title: Row(
                        children: [
                          if (isSelected)
                            Container(
                              width: 4,
                              height: 18,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: EasySitColors.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              _menuTitles[index],
                              style: TextStyle(
                                color: isSelected ? EasySitColors.primary : EasySitColors.mainText,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
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
          ],
        ),
      ),
      body: _buildScreen(_selectedIndex),
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
        return const StudentBehaviorScreen();
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
          // Header / Tagline
          const Text(
            'YOUR CAMPUS AT A GLANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: EasySitColors.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
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

              return Text(
                '${_getGreeting()}, $adminName',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: EasySitColors.mainText,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          const Text(
            'Spaces, seat usage and student access.',
            style: TextStyle(
              fontSize: 14,
              color: EasySitColors.secondaryText,
            ),
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
                padding: const EdgeInsets.all(22.0),
                decoration: BoxDecoration(
                  color: EasySitColors.deepPurple,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: EasySitColors.deepPurple.withValues(alpha: 0.15),
                      blurRadius: 10,
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
                          'Seat usage',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LIVE DATA',
                            style: TextStyle(
                              color: EasySitColors.logoLavender,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '$occupiedPct% occupied',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$occupiedSeats in use  •  $availableSeats available',
                      style: const TextStyle(
                        color: EasySitColors.logoLavender,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progressVal,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(EasySitColors.primary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Live overview • updated in real-time',
                      style: TextStyle(
                        color: EasySitColors.mutedLavender,
                        fontSize: 11,
                      ),
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
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              number: formattedRooms,
                              label: 'Rooms',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricCard(
                              number: seatCount.toString(),
                              label: 'Total seats',
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

              if (uSnapshot.hasData) {
                for (var doc in uSnapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  bool isBlocked = data['isBlocked'] ?? false;
                  if (isBlocked) {
                    blockedStudents++;
                  } else {
                    activeStudents++;
                  }
                }
              }

              String formattedActive = activeStudents.toString().padLeft(2, '0');
              String formattedBlocked = blockedStudents.toString().padLeft(2, '0');

              return _buildEasySitCard(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: EasySitColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Who can use EasySit',
                      style: TextStyle(
                        fontSize: 13,
                        color: EasySitColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '$formattedActive active',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: EasySitColors.successFg,
                          ),
                        ),
                        const SizedBox(width: 32),
                        Text(
                          '$formattedBlocked blocked',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: EasySitColors.errorFg,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Live counts • access status, not usage behavior',
                      style: TextStyle(
                        fontSize: 11,
                        color: EasySitColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. Quick Actions Section (2x2 Grid)
          const Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _buildQuickActionCard(
                icon: Icons.business,
                label: 'Manage\nBuildings',
                onTap: () => onNavigate(1),
              ),
              _buildQuickActionCard(
                icon: Icons.event_seat,
                label: 'Manage Seats &\nQR',
                onTap: () => onNavigate(4),
              ),
              _buildQuickActionCard(
                icon: Icons.person_outline,
                label: 'Student\nBehavior',
                onTap: () => onNavigate(5),
              ),
              _buildQuickActionCard(
                icon: Icons.notifications_none,
                label: 'Send\nNotification',
                onTap: () => onNavigate(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Metric Card Helper
  Widget _buildMetricCard({required String number, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: EasySitColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EasySitColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: EasySitColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: EasySitColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Quick Action Card Helper
  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: EasySitColors.primaryTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EasySitColors.softBlueBorder.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: EasySitColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: EasySitColors.pressed,
                    height: 1.2,
                  ),
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
                        child: const Icon(Icons.business, color: EasySitColors.primary),
                      ),
                      title: Text(
                        data['name'] ?? 'Unnamed',
                        style: const TextStyle(
                          color: EasySitColors.mainText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: EasySitColors.errorFg),
                        onPressed: () => _deleteBuilding(doc.id),
                        tooltip: 'Delete Building',
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
                        initialValue: null,
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
                      initialValue: _selectedBuildingId,
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
                        child: const Icon(
                          Icons.vertical_align_top,
                          color: EasySitColors.primary,
                        ),
                      ),
                      title: Text(
                        data['name'] ?? 'Unnamed',
                        style: const TextStyle(
                          color: EasySitColors.mainText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: FutureBuilder<DocumentSnapshot>(
                        future:
                            _firestore
                                .collection('buildings')
                                .doc(data['buildingId'])
                                .get(),
                        builder: (context, buildingSnapshot) {
                          if (!buildingSnapshot.hasData) {
                            return const Text(
                              'Loading...',
                              style: TextStyle(color: EasySitColors.secondaryText, fontSize: 12),
                            );
                          }
                          var buildingData =
                              buildingSnapshot.data?.data()
                                  as Map<String, dynamic>?;
                          return Text(
                            'Building: ${buildingData?['name'] ?? 'Unknown'}',
                            style: const TextStyle(
                              color: EasySitColors.secondaryText,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: EasySitColors.errorFg),
                        onPressed: () => _deleteFloor(doc.id),
                        tooltip: 'Delete Floor',
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
                        initialValue: null,
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
                      initialValue: _selectedBuildingId,
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
                        initialValue: null,
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
                        initialValue: null,
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
                      initialValue: _selectedFloorId,
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
                              child: const Icon(
                                Icons.door_front_door,
                                color: EasySitColors.primary,
                              ),
                            ),
                            title: Text(
                              data['name'] ?? 'Unnamed',
                              style: const TextStyle(
                                color: EasySitColors.mainText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: EasySitColors.errorFg,
                              ),
                              onPressed: () => _deleteRoom(doc.id),
                              tooltip: 'Delete Room',
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
    int count = int.tryParse(_bulkCountController.text) ?? 0;
    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid seat count!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      QuerySnapshot existingSeats =
          await _firestore
              .collection('seats')
              .where('roomId', isEqualTo: _selectedRoomId)
              .get();

      int startNumber = existingSeats.docs.length + 1;

      for (int i = 0; i < count; i++) {
        int seatNum = startNumber + i;
        DocumentReference docRef = await _firestore.collection('seats').add({
          'roomId': _selectedRoomId,
          'seatNumber': seatNum.toString(),
          'status': 'available',
          'createdAt': FieldValue.serverTimestamp(),
        });
        await docRef.update({'qrData': 'SEAT:${docRef.id}'});
      }
      _bulkCountController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count seats added!'),
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

    setState(() => _isLoading = true);
    try {
      DocumentReference docRef = await _firestore.collection('seats').add({
        'roomId': _selectedRoomId,
        'seatNumber': seatNumber,
        'status': 'available',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await docRef.update({'qrData': 'SEAT:${docRef.id}'});
      _singleSeatController.clear();
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
    }
    setState(() => _isLoading = false);
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
                        initialValue: null,
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
                      initialValue: _selectedBuildingId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Building',
                        prefixIcon: const Icon(Icons.business, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedBuildingId = value;
                          _selectedFloorId = null;
                          _selectedRoomId = null;
                        });
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
                        initialValue: null,
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
                        initialValue: null,
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
                      initialValue: _selectedFloorId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Floor',
                        prefixIcon: const Icon(Icons.vertical_align_top, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedFloorId = value;
                          _selectedRoomId = null;
                        });
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
                        initialValue: null,
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
                        initialValue: null,
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
                      initialValue: _selectedRoomId,
                      items: items,
                      decoration: _buildEasySitInputDecoration(
                        labelText: 'Room',
                        prefixIcon: const Icon(Icons.door_front_door, color: EasySitColors.secondaryText),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedRoomId = value;
                        });
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
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _bulkCountController,
                        keyboardType: TextInputType.number,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Seat Count',
                        ),
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
                  children: [
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _singleSeatController,
                        decoration: _buildEasySitInputDecoration(
                          labelText: 'Seat Number',
                        ),
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
// 6. STUDENT BEHAVIOR SCREEN
// ============================================================
class StudentBehaviorScreen extends StatefulWidget {
  const StudentBehaviorScreen({super.key});

  @override
  State<StudentBehaviorScreen> createState() => _StudentBehaviorScreenState();
}

class _StudentBehaviorScreenState extends State<StudentBehaviorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  Future<void> _toggleBlockStatus(String userId, bool currentStatus) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBlocked': !currentStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentStatus ? 'Student blocked successfully.' : 'Student unblocked successfully.'),
            backgroundColor: !currentStatus ? EasySitColors.warningFg : EasySitColors.successFg,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: EasySitColors.errorFg,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Student Behavior',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: EasySitColors.mainText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage student access to the application.',
            style: TextStyle(fontSize: 13, color: EasySitColors.secondaryText),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: _buildEasySitInputDecoration(
              labelText: 'Search by Name, Email, or ID',
              prefixIcon: const Icon(Icons.search, color: EasySitColors.secondaryText),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase().trim();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .where('userType', isEqualTo: 'student')
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
                    child: Text(
                      'No students found.',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  );
                }

                var docs = snapshot.data!.docs.toList();
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String fullName = (data['fullName'] ?? '').toString().toLowerCase();
                    String email = (data['email'] ?? '').toString().toLowerCase();
                    String studentId = (data['studentId'] ?? '').toString().toLowerCase();
                    return fullName.contains(_searchQuery) || 
                           email.contains(_searchQuery) || 
                           studentId.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No matching students found.',
                      style: TextStyle(color: EasySitColors.secondaryText),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isBlocked = data['isBlocked'] ?? false;
                    String fullName = data['fullName'] ?? 'Unknown Name';
                    String studentId = data['studentId'] ?? 'Unknown ID';
                    String email = data['email'] ?? 'No email';

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
                            color: isBlocked ? EasySitColors.errorBg : EasySitColors.primaryTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isBlocked ? Icons.block : Icons.person,
                            color: isBlocked ? EasySitColors.errorFg : EasySitColors.primary,
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: EasySitColors.mainText,
                          ),
                        ),
                        subtitle: Text(
                          '$studentId • $email',
                          style: const TextStyle(color: EasySitColors.secondaryText, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Student access status badge per guidelines
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBlocked ? EasySitColors.errorBg : EasySitColors.successBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isBlocked ? EasySitColors.errorBorder : EasySitColors.successBorder,
                                ),
                              ),
                              child: Text(
                                isBlocked ? 'Blocked' : 'Active',
                                style: TextStyle(
                                  color: isBlocked ? EasySitColors.errorFg : EasySitColors.successFg,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isBlocked,
                              activeThumbColor: EasySitColors.errorFg,
                              onChanged: (value) => _toggleBlockStatus(doc.id, isBlocked),
                            ),
                          ],
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
    );
  }
}

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
