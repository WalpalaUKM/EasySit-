// lib/utils/booking_timer_config.dart

/// Central timing configuration for the EasySit library seat booking application.
/// All booking screens, background session watchers, and expiry services
/// reference this single source of truth.
class BookingTimerConfig {
  // Duration values in minutes
  static const int activeBookingDurationMinutes = 120;
  static const int pendingReservationDurationMinutes = 20;
  static const int warningNotificationMinutes = 2;

  // Duration objects for timers and calculations

  /// Active booking duration as a [Duration] object (2 hours).
  static const Duration activeBookingDuration = Duration(
    minutes: activeBookingDurationMinutes,
  );

  /// Pending reservation duration as a [Duration] object (20 minutes).
  static const Duration pendingReservationDuration = Duration(
    minutes: pendingReservationDurationMinutes,
  );

  /// Warning threshold as a [Duration] object (2 minutes).
  static const Duration warningNotificationDuration = Duration(
    minutes: warningNotificationMinutes,
  );

  /// Warning threshold in seconds (120 seconds).
  static const int warningNotificationSeconds = warningNotificationMinutes * 60;
}
