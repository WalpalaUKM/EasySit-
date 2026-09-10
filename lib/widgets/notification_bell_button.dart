import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/notification_screen.dart';
import '../utils/app_page_route.dart';
import '../services/notification_service.dart';

class NotificationBellButton extends StatelessWidget {
  final VoidCallback? onTap;

  const NotificationBellButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildBell(hasUnread: false, context: context);
    }

    return ValueListenableBuilder<DateTime?>(
      valueListenable: NotificationService.clearedNotifier,
      builder: (context, localCleared, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: NotificationService.lastSeenNotifier,
          builder: (context, localLastSeen, _) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                Timestamp? remoteLastSeen;
                Timestamp? remoteClearedAt;
                Timestamp? remoteCreatedAt;
                if (userSnap.hasData &&
                    userSnap.data != null &&
                    userSnap.data!.exists) {
                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>?;
                  remoteLastSeen =
                      userData?['lastSeenNotification'] as Timestamp?;
                  remoteClearedAt =
                      userData?['clearedNotificationAt'] as Timestamp?;
                  remoteCreatedAt = userData?['createdAt'] as Timestamp?;
                }

                final userCreatedDate =
                    remoteCreatedAt?.toDate() ?? user.metadata.creationTime;
                final remoteDate = remoteLastSeen?.toDate();
                final remoteClearedDate = remoteClearedAt?.toDate();

                DateTime? effectiveLastSeen;
                if (localLastSeen != null && remoteDate != null) {
                  effectiveLastSeen = localLastSeen.isAfter(remoteDate)
                      ? localLastSeen
                      : remoteDate;
                } else {
                  effectiveLastSeen = localLastSeen ?? remoteDate;
                }

                DateTime? effectiveCleared;
                if (localCleared != null && remoteClearedDate != null) {
                  effectiveCleared = localCleared.isAfter(remoteClearedDate)
                      ? localCleared
                      : remoteClearedDate;
                } else {
                  effectiveCleared = localCleared ?? remoteClearedDate;
                }

                DateTime? cutoff = userCreatedDate;
                if (effectiveLastSeen != null &&
                    (cutoff == null || effectiveLastSeen.isAfter(cutoff))) {
                  cutoff = effectiveLastSeen;
                }
                if (effectiveCleared != null &&
                    (cutoff == null || effectiveCleared.isAfter(cutoff))) {
                  cutoff = effectiveCleared;
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', whereIn: ['all', user.uid])
                      .snapshots(),
                  builder: (context, notifSnap) {
                    bool hasUnread = false;
                    if (notifSnap.hasData && notifSnap.data!.docs.isNotEmpty) {
                      for (final doc in notifSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ts = data['timestamp'] as Timestamp?;
                        if (ts == null) {
                          // Newly created notification awaiting server timestamp
                          hasUnread = true;
                          break;
                        } else if (cutoff != null) {
                          if (ts.toDate().isAfter(cutoff)) {
                            hasUnread = true;
                            break;
                          }
                        } else {
                          hasUnread = true;
                          break;
                        }
                      }
                    }

                    return _buildBell(hasUnread: hasUnread, context: context);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBell({required bool hasUnread, required BuildContext context}) {
    return GestureDetector(
      onTap: () async {
        if (onTap != null) {
          onTap!();
        } else {
          await Navigator.push(
            context,
            AppPageRoute(builder: (_) => const NotificationScreen()),
          );
        }
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
            if (hasUnread)
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
  }
}
