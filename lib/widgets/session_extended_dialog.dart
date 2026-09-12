import 'package:flutter/material.dart';
import '../navigator_key.dart';
import '../utils/app_colors.dart';

class SessionExtendedDialog extends StatelessWidget {
  final int minutes;

  const SessionExtendedDialog({super.key, this.minutes = 120});

  static bool _isShowing = false;
  static DateTime? _lastShownAt;

  static void show([BuildContext? context, int minutes = 120]) {
    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) return;

    final String durationText = minutes >= 60
        ? '${minutes ~/ 60} ${minutes ~/ 60 == 1 ? "hour" : "hours"}'
        : '$minutes minutes';

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
          backgroundColor: EasySitColors.surface,
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
                    color: EasySitColors.successBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: EasySitColors.successBorder),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.more_time_rounded,
                      size: 36,
                      color: EasySitColors.success,
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
                    color: EasySitColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your session has been successfully extended by $durationText.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: EasySitColors.textSecondary,
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
                    color: EasySitColors.successBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EasySitColors.successBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: EasySitColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+$durationText added',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: EasySitColors.success,
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
