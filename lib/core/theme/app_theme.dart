import 'package:flutter/material.dart';

/// Visual identity: white notebook + sea-green accent (UI redesign v1).
abstract final class AppTheme {
  // —— Surfaces ——
  static const paper = Color(0xFFFFFFFF);
  static const paperElevated = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFFAFAFA);
  static const surfaceHover = Color(0xFFF4F4F2);

  // —— Ink ——
  static const ink = Color(0xFF1C1B19);
  static const inkMuted = Color(0xFF6E6860);

  // —— Lines ——
  static const line = Color(0xFFE8E8E6);

  // —— Brand ——
  static const accent = Color(0xFF2F6F5E);
  static const accentSoft = Color(0xFFD7E8E1);
  static const onAccent = Color(0xFFFFFFFF);

  // —— Semantic ——
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFEE4E2);
  static const warning = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFEF0C7);

  // —— Dark (deferred polish; kept for system dark preference) ——
  static const paperDark = Color(0xFF141513);
  static const paperElevatedDark = Color(0xFF1E201D);
  static const inkDark = Color(0xFFF2EFE8);
  static const inkMutedDark = Color(0xFFA39C92);
  static const lineDark = Color(0xFF2C2F2B);
  static const accentDark = Color(0xFF6FBFAB);

  static const defaultSeed = accent;

  // —— Layout ——
  static const double readingMaxWidth = 720;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motion = Duration(milliseconds: 220);

  static ThemeData light([Color seed = accent]) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      surface: paper,
      onSurface: ink,
      onSurfaceVariant: inkMuted,
      outlineVariant: line,
      error: danger,
    ).copyWith(
      surfaceContainerLowest: paperElevated,
      surfaceContainerLow: surfaceMuted,
      surfaceContainerHighest: const Color(0xFFF0F0EE),
      primaryContainer: accentSoft,
      onPrimaryContainer: const Color(0xFF0F3D32),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: paper,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperElevated,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: paperElevated,
        indicatorColor: accentSoft,
        selectedIconTheme: IconThemeData(color: seed, size: 22),
        unselectedIconTheme: const IconThemeData(color: inkMuted, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: seed,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceMuted,
        hintStyle: const TextStyle(color: inkMuted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: seed, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: seed),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceMuted,
        selectedColor: accentSoft,
        disabledColor: line,
        deleteIconColor: inkMuted,
        side: const BorderSide(color: line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return seed;
            return inkMuted;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return accentSoft;
            return Colors.transparent;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: line)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        iconColor: inkMuted,
      ),
    );
  }

  static ThemeData dark([Color seed = accentDark]) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: seed,
      surface: paperDark,
      onSurface: inkDark,
      onSurfaceVariant: inkMutedDark,
      outlineVariant: lineDark,
    ).copyWith(
      surfaceContainerLowest: paperElevatedDark,
      primaryContainer: const Color(0xFF1F3D35),
      onPrimaryContainer: accentSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: paperDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: paperDark.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: inkDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: paperElevatedDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: lineDark),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lineDark, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperElevatedDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: seed, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: paperDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: paperDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Constrains markdown/reading content to a comfortable measure.
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
