import 'package:flutter/material.dart';
import '../navigator_key.dart';

class ReservationExpiredDialog extends StatelessWidget {
  const ReservationExpiredDialog({super.key});

  static bool _isShowing = false;
  static DateTime? _lastShownAt;

  static void show([BuildContext? context]) {
    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) return;

    final now = DateTime.now();
    if (_isShowing) return;
    if (_lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 4)) {
      return;
    }

    _isShowing = true;
    _lastShownAt = now;

    showDialog(
      context: targetContext,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () {
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_off_rounded,
                    size: 36,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reservation Expired',
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
                  'Your reservation time has expired. The seat has been released.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
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
