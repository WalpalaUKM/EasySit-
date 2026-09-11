import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ExpiryDialog extends StatelessWidget {
  final String seatNumber;
  final String buildingName;
  final String roomName;
  final ValueNotifier<int>? countdownNotifier;

  const ExpiryDialog({
    super.key,
    required this.seatNumber,
    required this.buildingName,
    required this.roomName,
    this.countdownNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: EasySitColors.surface,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top warning icon
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: EasySitColors.warningBg,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 32,
                  color: EasySitColors.warning,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Dialog Title
            const Text(
              'Session Expiring',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: EasySitColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            // Seat & Location details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: EasySitColors.subtleSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: EasySitColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: EasySitColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chair_rounded,
                      color: EasySitColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seat $seatNumber',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: EasySitColors.textPrimary,
                          ),
                        ),
                        if (buildingName.isNotEmpty || roomName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            [buildingName, roomName]
                                .where((s) => s.isNotEmpty)
                                .join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: EasySitColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Live Countdown or Warning Pill
            if (countdownNotifier != null)
              ValueListenableBuilder<int>(
                valueListenable: countdownNotifier!,
                builder: (context, secs, _) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: EasySitColors.errorBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: EasySitColors.errorBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: EasySitColors.error,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          secs > 0
                              ? 'Auto-releasing in $secs s'
                              : 'Releasing now...',
                          style: const TextStyle(
                            color: EasySitColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: EasySitColors.warningBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EasySitColors.warningBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: EasySitColors.warning,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Session expiring soon',
                      style: TextStyle(
                        color: EasySitColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),
            const Text(
              'Would you like to extend your session by 4 minutes or release the seat for other students?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: EasySitColors.bodyText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EasySitColors.error,
                      side: const BorderSide(color: EasySitColors.errorBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Release Seat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasySitColors.primary,
                      foregroundColor: EasySitColors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 17,
                          color: EasySitColors.onPrimary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Extend (+4m)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
