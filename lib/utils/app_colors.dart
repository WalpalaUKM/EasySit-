import 'package:flutter/material.dart';

/// EasySit Shared Design Palette
/// Defined in "EasySit Colour Palette and Usage Guidelines"
class EasySitColors {
  // ============================================================
  // 1. Logo and Brand Identity (Page 1)
  // ============================================================
  /// Chair symbol and Sit text; primary app colour (#386CD1)
  static const Color primary = Color(0xFF386CD1);
  static const Color logoBlue = Color(0xFF386CD1);

  /// Logo backdrop and splash screen (#29234F)
  static const Color deepPurple = Color(0xFF29234F);

  /// Easy text on the dark logo background (#B5BBDB)
  static const Color logoLavender = Color(0xFFB5BBDB);

  /// Tagline on dark backgrounds (#989CBC)
  static const Color mutedLavender = Color(0xFF989CBC);

  /// Optional radial background highlight (#322A5E)
  static const Color splashHighlight = Color(0xFF322A5E);

  /// Optional darker splash edges (#1E193C)
  static const Color splashShadow = Color(0xFF1E193C);

  // ============================================================
  // 2. Primary Actions and Navigation (Page 2)
  // ============================================================
  /// Pointer hover on web and desktop (#2E5DB8)
  static const Color hover = Color(0xFF2E5DB8);

  /// Pressed primary controls (#254D9B)
  static const Color pressed = Color(0xFF254D9B);

  /// Focus outline separated by a white gap (#254D9B)
  static const Color focusRing = Color(0xFF254D9B);

  /// Selected navigation and filters (#EDF3FF)
  static const Color primaryTint = Color(0xFFEDF3FF);

  /// Decorative selection accents (#BED0F5)
  static const Color softBlueBorder = Color(0xFFBED0F5);

  /// Text and icons on primary buttons (#FFFFFF)
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Limited feature and category accents (#6D28D9)
  static const Color purpleAccent = Color(0xFF6D28D9);

  /// Background behind purple accents (#F3EEFF)
  static const Color accentTint = Color(0xFFF3EEFF);

  /// Dark blue for active navigation and headers (#1E3A8A)
  static const Color darkBlue = Color(0xFF1E3A8A);

  /// Deep dark blue for user titles (#0F2557)
  static const Color deepDarkBlue = Color(0xFF0F2557);

  /// Purple with blue (indigo) for active navigation icons (#4338CA)
  static const Color purpleBlue = Color(0xFF4338CA);

  // ============================================================
  // 3. Surfaces, Typography and Boundaries (Page 3)
  // ============================================================
  /// Main screen background (#F7F8FC)
  static const Color appBackground = Color(0xFFF7F8FC);

  /// Cards, drawer, dialogs and fields (#FFFFFF)
  static const Color surface = Color(0xFFFFFFFF);

  /// Secondary panels and icon containers (#F1F5F9)
  static const Color subtleSurface = Color(0xFFF1F5F9);

  /// Titles, key values and seat numbers (#0F172A)
  static const Color mainText = Color(0xFF0F172A);
  static const Color textPrimary = Color(0xFF0F172A);

  /// Descriptions and field labels (#334155)
  static const Color bodyText = Color(0xFF334155);

  /// Helper text, timestamps and placeholders (#64748B)
  static const Color secondaryText = Color(0xFF64748B);
  static const Color textSecondary = Color(0xFF64748B);

  /// Subtle card edges and separators (#E2E8F0)
  static const Color divider = Color(0xFFE2E8F0);

  /// Editable field boundaries (#7C899D)
  static const Color inputBorder = Color(0xFF7C899D);

  /// Disabled controls (#E2E8F0)
  static const Color disabledFill = Color(0xFFE2E8F0);

  /// Disabled labels and icons (#64748B)
  static const Color disabledText = Color(0xFF64748B);

  // ============================================================
  // 4. Feedback and Seat States (Page 4)
  // ============================================================
  // Success / Available / Active (Light fresh green)
  static const Color success = Color(0xFF16A34A);
  static const Color successFg = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFF0FDF4);
  static const Color successBorder = Color(0xFFBBF7D0);

  // Warning / Pending check-in
  static const Color warning = Color(0xFFB45309);
  static const Color warningFg = Color(0xFFB45309);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Pending Yellow-Mix-Orange Tokens (Amber palette)
  static const Color pendingPrimary = Color(0xFFF59E0B); // Vibrant yellow-mix-orange
  static const Color pendingAccent = Color(0xFFD97706);  // Warm yellow-orange accent
  static const Color pendingDark = Color(0xFFB45309);    // Deep yellow-orange text
  static const Color pendingBg = Color(0xFFFFFBEB);      // Soft yellow-orange background
  static const Color pendingBadge = Color(0xFFFEF3C7);   // Light yellow-orange badge
  static const Color pendingBorder = Color(0xFFFDE68A);  // Yellow-orange border

  // Error / Blocked / Destructive
  static const Color error = Color(0xFFB91C1C);
  static const Color errorFg = Color(0xFFB91C1C);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  // Information
  static const Color infoFg = Color(0xFF386CD1);
  static const Color infoBg = Color(0xFFEDF3FF);
  static const Color infoBorder = Color(0xFFBED0F5);

  // Booked / Occupied / Neutral
  static const Color bookedFg = Color(0xFF475569);
  static const Color bookedText = Color(0xFF475569);
  static const Color bookedBg = Color(0xFFE2E8F0);
  static const Color bookedFill = Color(0xFFE2E8F0);
  static const Color neutralFg = Color(0xFF475569);
  static const Color neutralBg = Color(0xFFF1F5F9);
  static const Color neutralBorder = Color(0xFFCBD5E1);
  static const Color unavailableFill = Color(0xFFF1F5F9);
  static const Color unavailableText = Color(0xFF475569);
  static const Color purpleAccentTint = Color(0xFFF3EEFF);

  // Seat map state helpers (Page 4)
  static const Color seatAvailableFill = Color(0xFFF0FDF4);
  static const Color seatAvailableText = Color(0xFF16A34A);
  static const Color seatSelectedFill = Color(0xFF386CD1);
  static const Color seatSelectedText = Color(0xFFFFFFFF);
  static const Color seatPendingFill = Color(0xFFFFFBEB);
  static const Color seatPendingText = Color(0xFFB45309);
  static const Color seatOccupiedFill = Color(0xFFE2E8F0);
  static const Color seatOccupiedText = Color(0xFF475569);
  static const Color seatUnavailableFill = Color(0xFFF1F5F9);
  static const Color seatUnavailableText = Color(0xFF475569);

  // ============================================================
  // 5. Study Areas (Page 5)
  // ============================================================
  /// Silent study (#16A34A / #F0FDFA)
  static const Color silentStudyFg = Color(0xFF16A34A);
  static const Color silentStudyBg = Color(0xFFF0FDFA);

  /// Group study (#6D28D9 / #F3EEFF)
  static const Color groupStudyFg = Color(0xFF6D28D9);
  static const Color groupStudyBg = Color(0xFFF3EEFF);

  /// Computer lab / general study (#0369A1 / #F0F9FF)
  static const Color computerLabFg = Color(0xFF0369A1);
  static const Color computerLabBg = Color(0xFFF0F9FF);

  /// Area category aliases (Page 5)
  static const Color areaSilentFg = Color(0xFF16A34A);
  static const Color areaSilentBg = Color(0xFFF0FDFA);
  static const Color areaGroupFg = Color(0xFF6D28D9);
  static const Color areaGroupBg = Color(0xFFF3EEFF);
  static const Color areaLabFg = Color(0xFF0369A1);
  static const Color areaLabBg = Color(0xFFF0F9FF);

  /// Available Area orange-mix-yellow theme
  static const Color areaOrangeFg = Color(0xFFD97706); // Orange-mix-yellow
  static const Color areaOrangeBg = Color(0xFFFEF3C7); // Light orange-mix-yellow
  static const Color areaOrangeBorder = Color(0xFFFDE68A);

  // ============================================================
  // Helpers
  // ============================================================
  /// Subtle card shadow (8% opacity of #0F172A)
  static const Color cardShadow = Color(0x140F172A);
  static const Color cardShadowColor = Color(0x140F172A);

  /// Default card shadow list
  static List<BoxShadow> get cardShadows => const [
        BoxShadow(
          color: Color(0x140F172A),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  /// Branded gradient (#29234F to #386CD1)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF29234F), Color(0xFF386CD1)],
  );

  /// Student screens top header gradient (Light blue to white)
  static const LinearGradient studentHeaderGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFD6E4FF),
      Colors.white,
    ],
  );

  /// Top header background color for screens other than Student Home (#E8E8E8)
  static const Color screenHeaderBackground = Color(0xFFE8E8E8);
}
