/// Helper to calculate the home screen greeting using Sri Lanka time (Asia/Colombo, UTC+05:30),
/// regardless of the user device's local timezone.
class GreetingHelper {
  /// Sri Lanka timezone offset: Asia/Colombo is UTC+05:30
  static const Duration sriLankaOffset = Duration(hours: 5, minutes: 30);

  /// Converts any [DateTime] (or [DateTime.now()] if null) to Sri Lanka local time.
  static DateTime toSriLankaTime([DateTime? dateTime]) {
    final utc = (dateTime ?? DateTime.now()).toUtc();
    return utc.add(sriLankaOffset);
  }

  /// Returns greeting string for Sri Lanka time:
  /// * Good Morning: 01:00–11:59
  /// * Good Afternoon: 12:00–16:59
  /// * Good Evening: 17:00–20:59
  /// * Good Night: 21:00–23:59 and 00:00–00:59
  static String getGreeting([DateTime? dateTime]) {
    final slTime = toSriLankaTime(dateTime);
    final int hour = slTime.hour;

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
