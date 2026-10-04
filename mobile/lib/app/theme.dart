import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// YUMN design tokens for one brightness, taken from the Claude Design
/// canvas (every screen there is drawn in a light and a dark variant).
@immutable
class YumnPalette {
  const YumnPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.outline,
    required this.text,
    required this.textSecondary,
    required this.subtext,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentBorder,
    required this.good,
    required this.warn,
    required this.warnEnd,
    required this.danger,
    required this.info,
    required this.sleep,
    required this.sleepEnd,
    required this.phaseDeep,
    required this.phaseRem,
    required this.phaseLight,
    required this.phaseAwake,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color outline;
  final Color text;
  final Color textSecondary;
  final Color subtext;

  /// Single accent: rings, links, active tab, primary buttons.
  final Color accent;

  /// Text and icons placed on [accent].
  final Color onAccent;

  /// Tinted cards (coach tips, banners) and their border.
  final Color accentSoft;
  final Color accentBorder;

  /// "Good" values: recovery, sleep score, low stress.
  final Color good;
  final Color warn;
  final Color warnEnd;
  final Color danger;
  final Color info;
  final Color sleep;
  final Color sleepEnd;

  /// Sleep phase strip (App-04-Sleep).
  final Color phaseDeep;
  final Color phaseRem;
  final Color phaseLight;
  final Color phaseAwake;

  static const light = YumnPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFECEFF3),
    outline: Color(0xFFE1E6EB),
    text: Color(0xFF101418),
    textSecondary: Color(0xFF39424E),
    subtext: Color(0xFF5F6874),
    accent: Color(0xFF3D4FD1),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEDEFFC),
    accentBorder: Color(0xFFD9DEFA),
    good: Color(0xFF00806E),
    warn: Color(0xFFB7791F),
    warnEnd: Color(0xFFC2410C),
    danger: Color(0xFFD33A4A),
    info: Color(0xFF2F6FDB),
    sleep: Color(0xFF3D4FD1),
    sleepEnd: Color(0xFF7C88E4),
    phaseDeep: Color(0xFF3D4FD1),
    phaseRem: Color(0xFF7C88E4),
    phaseLight: Color(0xFFA9B2EE),
    phaseAwake: Color(0xFFECEFF3),
  );

  static const dark = YumnPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0D1014),
    surface: Color(0xFF171B21),
    surfaceAlt: Color(0xFF12161B),
    outline: Color(0xFF2A313A),
    text: Color(0xFFF3F5F8),
    textSecondary: Color(0xFFC6CCD6),
    subtext: Color(0xFF8B94A1),
    accent: Color(0xFF8E9AF2),
    onAccent: Color(0xFF0D1014),
    accentSoft: Color(0xFF1C2136),
    accentBorder: Color(0xFFAAB4F6),
    good: Color(0xFF34C0A4),
    warn: Color(0xFFF2B84B),
    warnEnd: Color(0xFFFF8A5B),
    danger: Color(0xFFFF6B7A),
    info: Color(0xFF6E9BFF),
    sleep: Color(0xFF8E9AF2),
    sleepEnd: Color(0xFFAAB4F6),
    phaseDeep: Color(0xFF5D6CE6),
    phaseRem: Color(0xFF8E9AF2),
    phaseLight: Color(0xFFC3C9F7),
    phaseAwake: Color(0xFF2A313A),
  );
}

/// Theme factory plus shorthand access to the active palette.
///
/// `AppTheme.subtext` etc. read the palette of the theme currently applied
/// by [MaterialApp]; [sync] is called from `MaterialApp.builder` whenever the
/// theme changes. Widgets that use these getters must rebuild on theme
/// changes — every screen calls [watch] (or reads `Theme.of`) for that.
class AppTheme {
  AppTheme._();

  static YumnPalette _p = YumnPalette.dark;

  static YumnPalette get palette => _p;

  /// Called from `MaterialApp.builder` with the resolved theme brightness.
  static void sync(Brightness brightness) {
    _p = brightness == Brightness.light
        ? YumnPalette.light
        : YumnPalette.dark;
  }

  /// Registers a dependency on the theme so [context] rebuilds when the
  /// user (or the system) switches between light and dark.
  static YumnPalette watch(BuildContext context) {
    Theme.of(context);
    return _p;
  }

  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get outline => _p.outline;
  static Color get text => _p.text;
  static Color get textSecondary => _p.textSecondary;
  static Color get subtext => _p.subtext;
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;
  static Color get accentSoft => _p.accentSoft;
  static Color get accentBorder => _p.accentBorder;
  static Color get good => _p.good;
  static Color get warn => _p.warn;
  static Color get warnEnd => _p.warnEnd;
  static Color get danger => _p.danger;
  static Color get info => _p.info;
  static Color get sleep => _p.sleep;
  static Color get sleepEnd => _p.sleepEnd;

  /// Big numbers and headings: Manrope ExtraBold with tight tracking.
  /// Without [color] the text uses the palette's primary text colour.
  static TextStyle numeric({
    double fontSize = 21,
    Color? color,
    FontWeight fontWeight = FontWeight.w800,
  }) => GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? _p.text,
    letterSpacing: -0.02 * fontSize,
  );

  static ThemeData light() => _build(YumnPalette.light);

  static ThemeData dark() => _build(YumnPalette.dark);

  static ThemeData _build(YumnPalette p) {
    final isDark = p.brightness == Brightness.dark;
    final baseScheme = isDark
        ? const ColorScheme.dark()
        : const ColorScheme.light();
    final scheme = baseScheme.copyWith(
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.good,
      onSecondary: p.onAccent,
      error: p.danger,
      surface: p.surface,
      onSurface: p.text,
      outline: p.outline,
    );

    final baseText = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      textTheme: GoogleFonts.golosTextTextTheme(
        baseText,
      ).apply(bodyColor: p.text, displayColor: p.text),
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
        backgroundColor: p.bg,
        foregroundColor: p.text,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 23,
          fontWeight: FontWeight.w800,
          color: p.text,
          letterSpacing: -0.46,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: p.outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
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
          foregroundColor: p.text,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: p.outline),
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
        style: TextButton.styleFrom(foregroundColor: p.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      dividerTheme: DividerThemeData(color: p.outline, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: p.outline),
        backgroundColor: p.surfaceAlt,
        selectedColor: p.accentSoft,
        labelStyle: TextStyle(color: p.text),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.bg,
        selectedItemColor: p.accent,
        unselectedItemColor: p.subtext,
        type: BottomNavigationBarType.fixed,
      ),
      extensions: [
        AppColors(
          accent: p.accent,
          accent2: p.good,
          warn: p.warn,
          warnEnd: p.warnEnd,
          danger: p.danger,
          info: p.info,
          sleep: p.sleep,
          sleepEnd: p.sleepEnd,
          subtext: p.subtext,
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
  /// Reading this also subscribes the widget to theme changes.
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
