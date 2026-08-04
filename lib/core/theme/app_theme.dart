import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Memos One visual system — inspired by AppFlowy / modern workspace tools.
/// Calm neutrals, soft dividers, restrained blue accent. No neo-brutalism.
abstract final class AppTheme {
  // —— Surfaces ——
  static const paper = Color(0xFFF7F8FA); // app / sidebar canvas
  static const paperElevated = Color(0xFFFFFFFF); // main content
  static const surfaceMuted = Color(0xFFF0F1F3);
  static const surfaceHover = Color(0xFFE8EAED);

  // —— Text ——
  static const ink = Color(0xFF1F2329);
  static const inkMuted = Color(0xFF8F959E);
  static const inkSubtle = Color(0xFFB0B5BD);

  // —— Borders ——
  static const line = Color(0xFFE8EAED);
  static const lineStrong = Color(0xFFDEE0E3);

  // —— Brand (calm workspace blue) ——
  static const accent = Color(0xFF00B5FF);
  static const accentSoft = Color(0xFFE6F7FF);
  static const onAccent = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF5B6BFF);
  static const secondarySoft = Color(0xFFEEF0FF);
  static const mint = Color(0xFF00C2A8);

  // —— Semantic ——
  static const danger = Color(0xFFE22C4A);
  static const dangerSoft = Color(0xFFFFF0F1);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFFF7E8);

  // —— Dark ——
  static const paperDark = Color(0xFF1A1A1A);
  static const paperElevatedDark = Color(0xFF232326);
  static const inkDark = Color(0xFFE8E8EA);
  static const inkMutedDark = Color(0xFF9B9BA1);
  static const lineDark = Color(0xFF333338);
  static const accentDark = Color(0xFF33C4FF);

  static const defaultSeed = accent;

  static const double readingMaxWidth = 720;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const Duration motionFast = Duration(milliseconds: 120);
  static const Duration motion = Duration(milliseconds: 180);

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: ink.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 1),
        ),
      ];

  static TextTheme _textTheme(TextTheme base, Color color) {
    // Inter ≈ AppFlowy / Notion productivity type.
    final display = GoogleFonts.interTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );
    return display.copyWith(
      displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineMedium: display.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: display.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        fontSize: 18,
      ),
      titleMedium: display.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      titleSmall: display.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      bodyLarge: display.bodyLarge?.copyWith(height: 1.55, fontSize: 15),
      bodyMedium: display.bodyMedium?.copyWith(height: 1.5, fontSize: 14),
      bodySmall: display.bodySmall?.copyWith(
        height: 1.4,
        fontSize: 12,
        color: inkMuted,
      ),
      labelLarge: display.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      labelMedium: display.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  /// Soft fill derived from the user's accent seed.
  static Color softOf(Color seed, {double t = 0.14}) =>
      Color.lerp(Colors.white, seed, t)!.withValues(alpha: 1);

  static Color onSoftOf(Color seed) =>
      Color.lerp(const Color(0xFF0A1620), seed, 0.65)!;

  static ThemeData light([Color seed = accent]) {
    final soft = softOf(seed);
    final onSoft = onSoftOf(seed);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        primary: seed,
        onPrimary: onAccent,
        secondary: secondary,
        surface: paper,
        onSurface: ink,
        onSurfaceVariant: inkMuted,
        outline: lineStrong,
        outlineVariant: line,
        error: danger,
      ).copyWith(
        surfaceContainerLowest: paperElevated,
        surfaceContainerLow: surfaceMuted,
        surfaceContainerHighest: surfaceHover,
        primaryContainer: soft,
        onPrimaryContainer: onSoft,
        secondaryContainer: secondarySoft,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: paper,
      textTheme: _textTheme(base.textTheme, ink),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: paperElevated,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          color: ink,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperElevated,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: line, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperElevated,
        hintStyle: GoogleFonts.inter(color: inkSubtle, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paperElevated,
        selectedColor: soft,
        disabledColor: surfaceMuted,
        deleteIconColor: inkMuted,
        side: const BorderSide(color: lineStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return seed;
            return inkMuted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.selected)) return soft;
            return paperElevated;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: lineStrong),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return seed;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) {
            return seed.withValues(alpha: 0.35);
          }
          return null;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        iconColor: inkMuted,
        dense: true,
      ),
      iconTheme: const IconThemeData(color: inkMuted, size: 20),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
      ),
    );
  }

  static ThemeData dark([Color seed = accentDark]) {
    final soft = Color.lerp(paperElevatedDark, seed, 0.35)!;
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        primary: seed,
        onPrimary: paperDark,
        surface: paperDark,
        onSurface: inkDark,
        onSurfaceVariant: inkMutedDark,
        outlineVariant: lineDark,
      ).copyWith(
        surfaceContainerLowest: paperElevatedDark,
        primaryContainer: soft,
        onPrimaryContainer: inkDark,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: paperDark,
      textTheme: _textTheme(base.textTheme, inkDark),
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperElevatedDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lineDark),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lineDark, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: paperDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: seed),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: paperDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
    );
  }
}

/// Dynamic brand colors from [ThemeData.colorScheme] (user accent seed).
extension BrandColorsX on BuildContext {
  Color get brand => Theme.of(this).colorScheme.primary;
  Color get brandSoft => Theme.of(this).colorScheme.primaryContainer;
  Color get onBrand => Theme.of(this).colorScheme.onPrimary;
  Color get onBrandSoft => Theme.of(this).colorScheme.onPrimaryContainer;
}

class ReadingWidth extends StatelessWidget {
  const ReadingWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? AppTheme.readingMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
