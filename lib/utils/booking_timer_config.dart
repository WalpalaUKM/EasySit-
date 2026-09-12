// lib/utils/booking_timer_config.dart

/// Central timing configuration for the EasySit library seat booking application.
/// All booking screens, background session watchers, and expiry services
/// reference this single source of truth.
class BookingTimerConfig {
  // ============================================================================
  // CENTRAL BOOKING & RESERVATION TIMING CONFIGURATION
  // ============================================================================

  // Active booking duration in minutes
  // Unit: Minutes (int).
  // Standard study session duration once a seat is confirmed/scanned.
  // 120 minutes = 2 hours.
  static const int activeBookingDurationMinutes = 120;

  // Pending reservation duration in minutes
  // Unit: Minutes (int).
  // Grace period allowed for a student to arrive and scan the QR code.
  // 20 minutes = 20 minutes.
  static const int pendingReservationDurationMinutes = 20;

  // Warning notification time in minutes
  // Unit: Minutes (int).
  // Threshold before session/reservation expiration when the warning notification is triggered.
  // 2 minutes = 2 minutes.
  static const int warningNotificationMinutes = 2;

  // ============================================================================
  // DERIVED DURATION OBJECTS (For Timer & DateTime calculations)
  // ============================================================================

  /// Active booking duration as a [Duration] object (2 hours).
  static const Duration activeBookingDuration =
      Duration(minutes: activeBookingDurationMinutes);

  /// Pending reservation duration as a [Duration] object (20 minutes).
  static const Duration pendingReservationDuration =
      Duration(minutes: pendingReservationDurationMinutes);

  /// Warning threshold as a [Duration] object (2 minutes).
  static const Duration warningNotificationDuration =
      Duration(minutes: warningNotificationMinutes);

  /// Warning threshold in seconds (120 seconds).
  static const int warningNotificationSeconds =
      warningNotificationMinutes * 60;
}
