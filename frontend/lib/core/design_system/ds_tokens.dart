// Design System — canonical tokens (Trust Blue / Roboto / Lucide-style).
//
// Enterprise SaaS baseline: clean, structured, professional. No gradients,
// excessive rounding or decorative noise — every token has a purpose.
// Colors follow the existing Trust Blue direction; accents are subtle.
import 'package:flutter/material.dart';

class Ds {
  // ------------------------------------------------------------------ Colors
  // Trust Blue palette (primary, light, dark, muted)
  static const Color trustBlue = Color(0xFF1055C2);
  static const Color trustBlueDark = Color(0xFF0E3E97);
  static const Color trustBlueLight = Color(0xFFDCE9FF);
  static const Color trustBlueMuted = Color(0xFFEDF4FC);
  // Subtle green accents
  static const Color accentGreen = Color(0xFF228B57);
  static const Color accentGreenSoft = Color(0xFFE6F4EF);
  // Status
  static const Color dangerRed = Color(0xFFC62828);
  static const Color dangerRedSoft = Color(0xFFFDEAEA);
  static const Color warningAmber = Color(0xFFC78600);
  static const Color warningAmberSoft = Color(0xFFFDEDD1);
  // Neutrals
  static const Color bgPage = Color(0xFFFAFAFC);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E7EB);
  static const Color borderStrong = Color(0xFFC9CED6);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ------------------------------------------------------------- Spacing
  // 4px base scale: s2, s4, s8, s12, s16, s20, s24, s32, s40, s48, s64
  static const double s2 = 2.0;
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;

  // --------------------------------------------------------------- Radius
  static const double rNone = 0.0;
  static const double rXs = 3.0;
  static const double rSm = 4.0;
  static const double rMd = 6.0;
  static const double rLg = 8.0;
  static const double rXl = 12.0;
  static const double rFull = 999.0;

  // ---------------------------------------------------------------- Shadows
  static const List<BoxShadow> elevation1 = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const List<BoxShadow> elevation2 = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 2), blurRadius: 4),
  ];
  static const List<BoxShadow> elevation3 = [
    BoxShadow(color: Color(0x14101828), offset: Offset(0, 4), blurRadius: 12),
  ];
  static const List<BoxShadow> elevation4 = [
    BoxShadow(color: Color(0x1A000000), offset: Offset(0, 8), blurRadius: 24),
  ];

  // -------------------------------------------------------------- Typography
  // Roboto scale, enterprise-SaaS values.
  static const String fontFamily = 'Roboto';
  static const double _lh = 1.45;

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.25,
    color: textPrimary,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33,
    color: textPrimary,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: textPrimary,
  );
  static const TextStyle h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: textPrimary,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.06,
    color: textMuted,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: textSecondary,
  );
  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: _lh,
    color: textSecondary,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: _lh,
    color: textSecondary,
  );
  static const TextStyle labelStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textMuted,
  );
  static const TextStyle captionStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );
  static const TextStyle metric = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: textPrimary,
  );
  static const TextStyle mono = TextStyle(
    fontFamily: 'Courier New',
    fontSize: 12,
    color: textSecondary,
  );

  // ------------------------------------------------------- Button hierarchy
  static const TextStyle btnPrimary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: onPrimary,
  );
  static const TextStyle btnSecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: trustBlue,
  );
  static const TextStyle btnTertiary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: textSecondary,
  );

  // ---------------------------------------------------------- Input/Focus
  static const double inputBorderRadius = rLg;
  static const BoxBorder inputBorder = Border.fromBorderSide(BorderSide(
    color: border,
    width: 1,
  ));
  static const Color inputFocusedBorder = trustBlue;
  static const List<BoxShadow> inputFocusShadow = elevation2;

  static const double avatarRadius = rFull;
}
