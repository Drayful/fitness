import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// YUMN design system tokens (dark theme), taken from the Claude Design
/// canvas: Golos Text for UI, Manrope ExtraBold for headings and numbers,
/// indigo as the single accent and teal for "good" values.
class AppTheme {
  static const bg = Color(0xFF0D1014);
  static const surface = Color(0xFF171B21);
  static const surfaceAlt = Color(0xFF12161B);
  static const outline = Color(0xFF2A313A);
  static const text = Color(0xFFF3F5F8);
  static const textSecondary = Color(0xFFC6CCD6);
  static const subtext = Color(0xFF8B94A1);

  /// Primary accent: rings, links, active tab, primary buttons.
  static const accent = Color(0xFF8E9AF2);

  /// Softer indigo for tinted cards (coach tips, banners).
  static const accentSoft = Color(0xFF1C2136);
  static const accentBorder = Color(0xFFAAB4F6);

  /// "Good" values: recovery, sleep score, low stress.
  static const good = Color(0xFF34C0A4);
  static const warn = Color(0xFFF2B84B);
  static const warnEnd = Color(0xFFFF8A5B);
  static const danger = Color(0xFFFF6B7A);
  static const info = Color(0xFF6E9BFF);
  static const sleep = Color(0xFF8E9AF2);
  static const sleepEnd = Color(0xFFAAB4F6);

  /// Big numbers and headings: Manrope ExtraBold with tight tracking.
  static TextStyle numeric({
    double fontSize = 21,
    Color color = text,
    FontWeight fontWeight = FontWeight.w800,
  }) => GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: -0.02 * fontSize,
  );

  static ThemeData dark() {
    final scheme = const ColorScheme.dark().copyWith(
      primary: accent,
      onPrimary: bg,
      secondary: good,
      onSecondary: bg,
      error: danger,
      surface: surface,
      onSurface: text,
      outline: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.golosTextTextTheme(ThemeData.dark().textTheme)
          .apply(bodyColor: text, displayColor: text),
    );

    TextStyle? heading(
      TextStyle? s, {
      FontWeight w = FontWeight.w800,
      double ls = -0.4,
    }) => GoogleFonts.manrope(textStyle: s, fontWeight: w, letterSpacing: ls);

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: heading(base.textTheme.displaySmall),
        headlineMedium: heading(base.textTheme.headlineMedium),
        headlineSmall: heading(base.textTheme.headlineSmall),
        titleLarge: heading(base.textTheme.titleLarge, ls: -0.46),
        titleMedium: heading(
          base.textTheme.titleMedium,
          w: FontWeight.w700,
          ls: -0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: -0.46,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.golosText(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.golosText(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: outline),
        backgroundColor: surfaceAlt,
        selectedColor: accentSoft,
        labelStyle: const TextStyle(color: text),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: accent,
        unselectedItemColor: subtext,
        type: BottomNavigationBarType.fixed,
      ),
      extensions: const [
        AppColors(
          accent: accent,
          accent2: good,
          warn: warn,
          warnEnd: warnEnd,
          danger: danger,
          info: info,
          sleep: sleep,
          sleepEnd: sleepEnd,
          subtext: subtext,
        ),
      ],
    );
  }
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accent2,
    required this.warn,
    required this.warnEnd,
    required this.danger,
    required this.info,
    required this.sleep,
    required this.sleepEnd,
    required this.subtext,
  });

  final Color accent;

  /// Teal "good" colour in the YUMN palette.
  final Color accent2;
  final Color warn;
  final Color warnEnd;
  final Color danger;
  final Color info;
  final Color sleep;
  final Color sleepEnd;
  final Color subtext;

  Color get good => accent2;

  @override
  AppColors copyWith({
    Color? accent,
    Color? accent2,
    Color? warn,
    Color? warnEnd,
    Color? danger,
    Color? info,
    Color? sleep,
    Color? sleepEnd,
    Color? subtext,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      warn: warn ?? this.warn,
      warnEnd: warnEnd ?? this.warnEnd,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      sleep: sleep ?? this.sleep,
      sleepEnd: sleepEnd ?? this.sleepEnd,
      subtext: subtext ?? this.subtext,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnEnd: Color.lerp(warnEnd, other.warnEnd, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      sleep: Color.lerp(sleep, other.sleep, t)!,
      sleepEnd: Color.lerp(sleepEnd, other.sleepEnd, t)!,
      subtext: Color.lerp(subtext, other.subtext, t)!,
    );
  }
}

extension ThemeX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
