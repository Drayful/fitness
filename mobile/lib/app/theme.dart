import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark() {
    const bg = Color(0xFF0A0E13);
    const surface = Color(0xFF101924);
    const surface2 = Color(0xFF0E1620);
    const outline = Color(0xFF1C2838);
    const text = Color(0xFFF2F6FF);
    const subtext = Color(0xFF7E90AA);

    const accent = Color(0xFF34F5A0);
    const accent2 = Color(0xFF36E0FF);
    const warn = Color(0xFFFFB23E);
    const warnEnd = Color(0xFFFF7A59);
    const danger = Color(0xFFFF5C7A);
    const info = Color(0xFF6E9BFF);
    const sleep = Color(0xFF8AA6FF);
    const sleepEnd = Color(0xFF9B8CFF);

    final scheme = const ColorScheme.dark().copyWith(
      primary: accent,
      secondary: accent2,
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
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
    );

    TextStyle? grotesk(TextStyle? s, {FontWeight w = FontWeight.w700, double? ls}) =>
        GoogleFonts.spaceGrotesk(textStyle: s, fontWeight: w, letterSpacing: ls);

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: grotesk(base.textTheme.displaySmall),
        headlineMedium: grotesk(base.textTheme.headlineMedium),
        headlineSmall: grotesk(base.textTheme.headlineSmall),
        titleLarge: grotesk(base.textTheme.titleLarge, ls: -0.4),
        titleMedium: grotesk(base.textTheme.titleMedium, w: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: outline, thickness: 1),
      chipTheme: base.chipTheme.copyWith(
        side: const BorderSide(color: outline),
        backgroundColor: surface2,
        selectedColor: surface,
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
          accent2: accent2,
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
  final Color accent2;
  final Color warn;
  final Color warnEnd;
  final Color danger;
  final Color info;
  final Color sleep;
  final Color sleepEnd;
  final Color subtext;

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
