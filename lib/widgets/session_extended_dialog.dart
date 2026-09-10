import 'package:flutter/material.dart';
import '../navigator_key.dart';

class SessionExtendedDialog extends StatelessWidget {
  final int minutes;

  const SessionExtendedDialog({super.key, this.minutes = 4});

  static bool _isShowing = false;
  static DateTime? _lastShownAt;

  static void show([BuildContext? context, int minutes = 4]) {
    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) return;

    final now = DateTime.now();
    if (_isShowing) return;
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 3)) {
      return;
    }

    _isShowing = true;
    _lastShownAt = now;

    showDialog(
      context: targetContext,
      barrierDismissible: true,
      builder: (ctx) {
        // Automatically disappears after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (ctx.mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.white,
          elevation: 10,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECA7F).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.more_time_rounded,
                      size: 36,
                      color: Color(0xFF2ECA7F),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Session Extended',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your session has been successfully extended by $minutes minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF2ECA7F),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$minutes minutes added',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2ECA7F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
