// ============================================================================
// GREETING HELPER & TIMEZONE UTILITY (HOURS, MINUTES & OPERATING TIMES)
// ============================================================================
/// Helper to calculate the home screen greeting using Sri Lanka time (Asia/Colombo, UTC+05:30),
/// regardless of the user device's local timezone.
///
/// Can also be utilized if library opening / closing operating hours need to be enforced.
class GreetingHelper {
  // [TIMEZONE OFFSET]:
  // Units: Hours (5) and Minutes (30).
  // Asia/Colombo is UTC + 5 hours 30 minutes.
  // How to change safely: Modify Duration(hours: 5, minutes: 30) if targeting a different timezone.
  static const Duration sriLankaOffset = Duration(hours: 5, minutes: 30);

  /// Converts any [DateTime] (or [DateTime.now()] if null) to Sri Lanka local time.
  static DateTime toSriLankaTime([DateTime? dateTime]) {
    final utc = (dateTime ?? DateTime.now()).toUtc();
    return utc.add(sriLankaOffset);
  }

  // ============================================================================
  // [GREETING TIME RANGES & OPERATING HOURS]
  // ============================================================================
  /// Returns greeting string based on 24-hour Sri Lanka local time:
  /// * Good Morning:   01:00 – 11:59 (hours >= 1 && < 12)
  /// * Good Afternoon: 12:00 – 16:59 (hours >= 12 && < 17)
  /// * Good Evening:   17:00 – 20:59 (hours >= 17 && < 21)
  /// * Good Night:     21:00 – 00:59 (hours >= 21 || hours == 0)
  ///
  /// Units: Hours (24-hour format: 0 to 23).
  ///
  /// [LIBRARY OPERATING HOURS NOTE]:
  /// If library opening (e.g. 08:00 AM) and closing (e.g. 08:00 PM) need to be enforced,
  /// you can add a method here:
  /// ```dart
  /// static bool isLibraryOpen() {
  ///   final int hour = toSriLankaTime().hour;
  ///   return hour >= 8 && hour < 20; // Open between 08:00 and 20:00
  /// }
  /// ```
  static String getGreeting([DateTime? dateTime]) {
    final slTime = toSriLankaTime(dateTime);
    final int hour = slTime.hour; // Unit: Hours (0 - 23)

    if (hour >= 1 && hour < 12) {
      return 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening';
    } else {
      return 'Good Night';
    }
  }
}
